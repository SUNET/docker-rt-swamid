#!/usr/bin/perl

use warnings;
use strict;

foreach my $line ( <STDIN> ) {

  my %queues;

  # First of all, find all environment variables that correspond to RT's "queue"-pattern and 
  # store these in the queues-hash for later use in building the configuration.
  foreach (sort keys %ENV) {
    my $env = $_;
    if ( $env =~ /RT_Q[0-9]+/ ) { 
      $queues{$env} = $ENV{$env};
    }
  }

  # Search for the PLACEHOLDERS to replace them with the config from environment
  if ( $line =~ /PLACEHOLDER1/ ) {
    # Config *should* look like this: Set(\$RTAddressRegexp, '^($RT_Q1|$RT_Q2|$RT_Q3|$RT_Q4|$RT_DEFAULTEMAIL)(-comment)?\@$RT_HOSTNAME$');
    # Config looks something like this: Set(\$RTAddressRegexp, '^($RT_Q1|PLACEHOLDER1$RT_DEFAULTEMAIL)(-comment)?\@$RT_HOSTNAME$');

    my $regexp;

    my @q = sort { $a cmp $b } keys %queues;
    foreach my $queue ( @q ) {
      next if $queue =~ /RT_Q1$/;
      $regexp .= "\$$queue\|";
    }
    $line =~ s/PLACEHOLDER1/$regexp/;
    printf $line;
    
  } elsif ( $line =~ /#PLACEHOLDER2/ ) {
      # Config should look something like this:
      # $RT_Q2:         	     "|/opt/rt4/bin/rt-mailgate --queue $RT_Q2 --action correspond --url https://$RT_HOSTNAME"
      # ${RT_Q2}-comment:            "|/opt/rt4/bin/rt-mailgate --queue $RT_Q2 --action comment --url https://$RT_HOSTNAME"
      $line =~ s/#PLACEHOLDER1//;
      my @q = sort { $a cmp $b } keys %queues;
      foreach my $queue ( @q ) {
        next if $queue =~ /RT_Q1$/;
        printf "\$$queue:\t\t\t\"\|/opt/rt4/bin/rt-mailgate --queue \$$queue --action correspond --url https://\$RT_HOSTNAME\"\n";
        printf "\$$queue-comment:\t\t\"\|/opt/rt4/bin/rt-mailgate --queue \$$queue --action comment --url https://\$RT_HOSTNAME\"\n";
      }
  } else {

  # If nothing to change is found; just pass-through the config
  print "$line";

  }
} 
