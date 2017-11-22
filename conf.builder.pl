#!/usr/bin/perl

use warnings;
use strict;

open (our $template_fh, "<start.template.sh") or die "Could not open file '$template_fh': $!";
open (our $startscript_fh, ">start.sh") or die "Could not open file '$startscript_fh': $!";

while ( defined(my $line = <$template_fh>) ) {

    my %queues;

    # First of all, find all environment variables that correspond to RT's "queue"-pattern and 
    # store these in the queues-hash for later use in building the configuration.
    foreach (sort keys %ENV) {
	my $env = $_;
	if ( $env =~ /RT_Q[0-9]+/ ) {
	    $queues{$env} = $ENV{$env};
	}
    }

    # Search for the PLACEHOLDER-string(s) to replace them with config taken from environment
    if ( $line =~ /###PLACEHOLDER1###/ ) {

	# Config looks something like this: Set(\$RTAddressRegexp, '^($RT_Q1|###PLACEHOLDER1###$RT_DEFAULTEMAIL)(-comment)?\@$RT_HOSTNAME$');
	# Config *should* look like this: Set(\$RTAddressRegexp, '^($RT_Q1|$RT_Q2|$RT_Q3|$RT_Q4|$RT_DEFAULTEMAIL)(-comment)?\@$RT_HOSTNAME$');

	my $regexp;

	# Sort & add all queues into the RTAddressRegexp-variable. Skip RT_Q1 as this is static and used as a default in the config.
	my @q = sort { $a cmp $b } keys %queues;
	foreach my $queue ( @q ) {
	    next if $queue =~ /RT_Q1$/;
	    $regexp .= "\$$queue\|";
	}

	# If no environment is found, simply remove the PLACEHOLDER anyways to make the config parseable.
	if ( defined($regexp) ) {
	    $line =~ s/###PLACEHOLDER1###/$regexp/;
	} else {
	    $line =~ s/###PLACEHOLDER1###//;
	}

	printf $startscript_fh $line;

    } elsif ( $line =~ /###PLACEHOLDER2###/ ) {

	# Config should look something like this:
	# $RT_Q2:         	     "|/opt/rt4/bin/rt-mailgate --queue $RT_Q2 --action correspond --url https://$RT_HOSTNAME"
	# ${RT_Q2}-comment:            "|/opt/rt4/bin/rt-mailgate --queue $RT_Q2 --action comment --url https://$RT_HOSTNAME"
	$line =~ s/###PLACEHOLDER2###//;
	my @q = sort { $a cmp $b } keys %queues;
	foreach my $queue ( @q ) {
	    next if $queue =~ /RT_Q1$/;
	    printf $startscript_fh "\$$queue:\t\t\t\"\|/opt/rt4/bin/rt-mailgate --queue \$$queue --action correspond --url https://\$RT_HOSTNAME\"\n";
	    printf $startscript_fh "\$$queue-comment:\t\t\"\|/opt/rt4/bin/rt-mailgate --queue \$$queue --action comment --url https://\$RT_HOSTNAME\"\n";
	}

    } else {

	# If nothing to change is found; just pass-through to the config
	print $startscript_fh $line;

    }

}

# Cleanup then make the generated script executable & execute it
close $template_fh;
close $startscript_fh;

system("chmod a+rx start.sh");
system("/bin/sh start.sh");
