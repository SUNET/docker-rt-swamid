#!/bin/sh -x

printenv

if [ "x${SP_HOSTNAME}" = "x" ]; then
   SP_HOSTNAME="`hostname`"
fi

if [ "x${SP_CONTACT}" = "x" ]; then
   SP_CONTACT="info@${SP_HOSTNAME}"
fi

if [ "x${SP_ABOUT}" = "x" ]; then
   SP_ABOUT="/about"
fi

if ["x${DEFAULT_LOGIN}" = "x" ]; then
   DEFAULT_LOGIN="seamless-access"
fi

if ["x${RT_OWNER}" = "x" ]; then
   RT_OWNER="root@localhost"
fi

if ["x${RT_PASSWORD}" = "x" ]; then
   RT_PASSWORD="password"
fi
if ["x${POSTGRES_PASSWORD}" = "x" ]; then
   POSTGRES_PASSWORD="password"
fi


# These are the queues to be added to RT manually. They are here so that the RT-mailgate can be setup.
# UPDATE: 2017-11-22 this was changed using "conf.builder.pl" so that *ALL* environment using the form
# "RT_Q[digit]" will be converted to RT and mail configuration automatically!!! No more static config!
if ["x${RT_Q1}" = "x" ]; then
   RT_Q1="rt"
fi
if ["x${RT_Q2}" = "x" ]; then
   RT_Q2="bugs"
fi

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR
if [ ! -f "$KEYDIR/private/shibsp-${SP_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/shibsp-${SP_HOSTNAME}.crt" ]; then
   shib-keygen -o /tmp -h $SP_HOSTNAME 2>/dev/null
   mv /tmp/sp-key.pem "$KEYDIR/private/shibsp-${SP_HOSTNAME}.key"
   mv /tmp/sp-cert.pem "$KEYDIR/certs/shibsp-${SP_HOSTNAME}.crt"
fi

if [ ! -f "$KEYDIR/private/${SP_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/${SP_HOSTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${SP_HOSTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${SP_HOSTNAME}.crt"
fi

CHAINSPEC=""
export CHAINSPEC
if [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}-chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}-chain.crt"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain.crt"
elif [ -f "$KEYDIR/certs/chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.crt"
elif [ -f "$KEYDIR/certs/chain.pem" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.pem"
fi

cat>/etc/apache2/conf-available/acme.conf<<EOF
ProxyPass /.well-known/acme-challenge http://acme-c.sunet.se/.well-known/acme-challenge/
ProxyPassReverse /.well-known/acme-challenge http://acme-c.sunet.se/.well-known/acme-challenge/
EOF

a2enconf acme

cat>/etc/shibboleth/shibboleth2.xml<<EOF
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"    
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    logger="syslog.logger"
    clockSkew="180">

    <ApplicationDefaults entityID="https://${SP_HOSTNAME}/shibboleth"
                         REMOTE_USER="eppn persistent-id targeted-id">

        <Sessions lifetime="28800" timeout="3600" redirectLimit="exact" relayState="ss:mem"
                  checkAddress="false" handlerSSL="true" cookieProps="https">
            <Logout>SAML2 Local</Logout>
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>

            <md:AssertionConsumerService Location="/SAML2/POST"
                                         index="1"
                                         Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                                         conf:ignoreNoPassive="true" />

            <!-- Seamless Access -->
            <SessionInitiator type="Chaining" Location="/DS/seamless-access" id="seamless-access">
                <SessionInitiator type="SAML2" defaultACSIndex="1" template="bindingTemplate.html"/>
                <SessionInitiator type="SAMLDS" URL="https://service.seamlessaccess.org/ds/"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/nordu.net" id="md.nordu.net" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="http://md.nordu.net/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/kalmar2" id="kalmar2.org" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="https://kalmar2.org/simplesaml/module.php/discopower/disco.php"/>
            </SessionInitiator>
 
            <SessionInitiator type="Chaining" Location="/Login/feide" id="idp.feide.no" relayState="cookie" entityID="https://idp.feide.no">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/haka.funet.fi" id="haka.funet.fi" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="https://haka.funet.fi/shibboleth/WAYF"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/idp.funet.fi" id="funet" 
                relayState="cookie" entityID="https://idp.funet.fi/esso">
                <SessionInitiator type="SAML2" acsIndex="1" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" acsIndex="5"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/eduid-dev" id="eduid-dev" entityID="https://dev.idp.eduid.se/idp.xml" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/eduid" id="eduid" entityID="https://idp.eduid.se/idp.xml" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>
   
            <SessionInitiator type="Chaining" Location="/Login/unitedid" id="unitedid" entityID="https://idp.unitedid.org/idp/shibboleth" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/skolfederation" id="skolfederation" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="https://ds.skolfederation.se"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/kalmar2" id="kalmar2" relayState="cookie">
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="https://kalmar2.org/simplesaml/module.php/discopower/disco.php"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/nightly.pyff.io" id="pyff-test" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="http://nightly.pyff.io/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/md.nordu.net" id="md.nordu.net" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="https://md.nordu.net/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/swamid-test" id="ds-test" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="http://ds-test.swamid.se/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/loopback" id="loopback" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="SAMLDS" defaultACSIndex="5" URL="http://localhost:8080/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/box-idp.sunet.se" id="box-idp.sunet.se"
                        entityID="https://box-idp.sunet.se/simplesaml/saml2/idp/metadata.php" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/box-idp.nordu.net" id="box-idp.nordu.net"
                        entityID="https://box-idp.nordu.net/simplesaml/saml2/idp/metadata.php" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/socialproxy" id="socialproxy"
                        entityID="http://idp-test.social2saml.org/metadata" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/openidp" id="openidp"
                        entityID="https://openidp.feide.no" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="SAML2" Location="/Login/necs.sll.se" id="necs.sll.se" relayState="cookie" 
			      entityID="necs.sll.se" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>

        </Sessions>

        <Errors supportContact="${SP_CONTACT}"
            helpLocation="${SP_ABOUT}"
            styleSheet="/shibboleth-sp/main.css"/>

        <MetadataProvider type="XML" uri="http://mds.swamid.se/md/swamid-idp-transitive.xml"
           backingFilePath="swamid-1.0.xml" reloadInterval="300">
           <SignatureMetadataFilter certificate="md-signer2.crt"/>
        </MetadataProvider>

        <MetadataProvider type="XML" uri="http://mds.swamid.se/md/swamid-testing-1.0.xml"
           backingFilePath="swamid-testing-1.0.xml" reloadInterval="300">
           <SignatureMetadataFilter certificate="md-signer2.crt"/>
        </MetadataProvider>

        <MetadataProvider type="XML" uri="http://mds.swamid.se/md/swamid-fiv-test.xml"
           backingFilePath="swamid-fiv-test.xml" reloadInterval="300">
           <SignatureMetadataFilter certificate="md-signer2.crt"/>
        </MetadataProvider>

        <MetadataProvider type="XML" uri="http://mds.swamid.se/md/swamid-ki-sll-1.0.xml"
           backingFilePath="swamid-ki-sll-1.0.xml" reloadInterval="300">
           <SignatureMetadataFilter certificate="md-signer2.crt"/>
        </MetadataProvider>

        <MetadataProvider type="XML" uri=" https://fed.skolfederation.se/trial/md/skolfederation-trial-3_0.xml"
            backingFilePath="skolfederation-trial.xml" reloadInterval="300">
            <SignatureMetadataFilter certificate="skolfederation-trial.crt"/>
        </MetadataProvider>

        <MetadataProvider type="XML" uri="http://md.unitedid.org/idp.xml"
            backingFilePath="unitedid.xml" reloadInterval="300">
        </MetadataProvider>

        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <CredentialResolver type="File" key="$KEYDIR/private/shibsp-${SP_HOSTNAME}.key" certificate="$KEYDIR/certs/shibsp-${SP_HOSTNAME}.crt"/>
    </ApplicationDefaults>
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF

augtool -s --noautoload --noload <<EOF
set /augeas/load/xml/lens "Xml.lns"
set /augeas/load/xml/incl "/etc/shibboleth/shibboleth2.xml"
load
defvar si /files/etc/shibboleth/shibboleth2.xml/SPConfig/ApplicationDefaults/Sessions/SessionInitiator[#attribute/id="$DEFAULT_LOGIN"]
set \$si/#attribute/isDefault "true"
EOF

cat>/etc/apache2/sites-available/default.conf<<EOF
<VirtualHost *:80>
       ServerAdmin noc@sunet.se
       ServerName ${SP_HOSTNAME}
       DocumentRoot /var/www/

       RewriteEngine On
       RewriteCond %{HTTPS} off
       RewriteRule !_lvs.txt$ https://%{HTTP_HOST}%{REQUEST_URI}
</VirtualHost>
EOF

echo "swamid" > /var/www/_lvs.txt

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
ServerName ${SP_HOSTNAME}
FastCgiServer /opt/rt4/sbin/rt-server.fcgi -processes 5 -idle-timeout 300
<VirtualHost *:443>
        ServerName ${SP_HOSTNAME}
        SSLProtocol All -SSLv2 -SSLv3
        SSLCompression Off
        SSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+AESGCM EECDH EDH+AESGCM EDH+aRSA HIGH !MEDIUM !LOW !aNULL !eNULL !LOW !RC4 !MD5 !EXP !PSK !SRP !DSS"
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${SP_HOSTNAME}.crt
        ${CHAINSPEC}
        SSLCertificateKeyFile $KEYDIR/private/${SP_HOSTNAME}.key
        DocumentRoot /opt/rt4/share/html
        
        Alias /shibboleth-sp/ /usr/share/shibboleth/

        ServerName ${SP_HOSTNAME}
        ServerAdmin noc@nordu.net

        AddDefaultCharset utf-8

        ErrorLog /var/log/apache2/error.log
        LogLevel warn
        CustomLog /var/log/apache2/access.log combined
        ServerSignature off

        Alias /secure /var/www/secure
        <Location /secure>
                AuthType shibboleth
                ShibRequireSession On
                ShibUseHeaders On
                Options +ExecCGI
                AddHandler cgi-script .cgi
        </Location>


        ScriptAlias / /opt/rt4/sbin/rt-server.fcgi/
        <Location />
           AuthType shibboleth
           ShibRequireSession On
           ShibUseHeaders On
           require valid-user
           Options +ExecCGI
           AddHandler fcgid-script fcgi .fcgi
        </Location>

        <Location /REST/1.0/NoAuth>
           SetHandler fastcgi-script
           allow from all
           satisfy any
        </Location>
        <Location /NoAuth>
           SetHandler fastcgi-script
           allow from all
           satisfy any
        </Location>
        <Location /.well-known>
           SetHandler fastcgi-script
           allow from all
           satisfy any
        </Location>

        <Location /Admin>
           SetHandler fastcgi-script
           allow from all
           satisfy any
        </Location>

</VirtualHost>
EOF

cat>/opt/rt4/etc/RT_SiteConfig.pm<<EOF
Set(\$rtname , 'Sunet');
Set(\$Organization , "Sunet");
Set(\$Timezone , 'Europe/Stockholm');
Set(\$WebRemoteUserAuth, 1);
Set(\$WebRemoteUserAutocreate , 1);
Set(\$LogToSTDERR, "debug");
Set(\$UserAutocreateDefaultsOnLogin, { 'Privileged' => 0 } );

# These are hacks to enable support for Shibboleth
Set(\$WebRemoteUser, 1);
Set(\$ExternalSettingsRemoteUser,
    { 'RemoteUser'             =>
        { 'type'               => 'shib',
          'attr_map'           =>
              { 'Name'         => [ 'HTTP_EPPN' ],
                'EmailAddress' => [ 'HTTP_MAIL' ],
                'RealName'     => [ 'HTTP_DISPLAYNAME','HTTP_CN','HTTP_GIVENNAME' ],
                'Organization' => [ 'HTTP_O' ],
		'MobilePhone'  => [ 'HTTP_MOBILE' ],
		'WorkPhone'    => [ 'HTTP_TELEPHONENUMBER' ],
		'Address1'     => [ 'HTTP_STREET' ],
		'City'         => [ 'HTTP_L' ],
		'State'        => [ 'HTTP_ST' ],
		'Zip'          => [ 'HTTP_POSTALCODE' ]
	      }
	}
    }
);

Set(\$DatabaseHost   , 'postgres');
Set(\$DatabaseRTHost , 'postgres');
Set(\$DatabaseUser , 'postgres');
Set(\$DatabasePassword , '$POSTGRES_PASSWORD');
Set(\$DatabaseName , 'postgres');

Set(\$WebPath , "");
Set(\$WebPort , 443);
Set(\$WebDomain, '$RT_HOSTNAME');
Set(\$WebBaseURL , "https://$RT_HOSTNAME:\$WebPort");
Set(\$WebURL , \$WebBaseURL . \$WebPath . "/");

Set(\$OwnerEmail, '$RT_OWNER');
Set(\$LoopsToRTOwner, 1);
Set(\$RTAddressRegexp, '^($RT_Q1|###PLACEHOLDER1###$RT_DEFAULTEMAIL)(-comment)?\@$RT_HOSTNAME$');

# Users should still be autocreated by RT as internal users if they
# fail to exist in an external service; this is so requestors (who
# are not in LDAP) can still be created when they email in.
Set(\$AutoCreateNonExternalUsers, 1);

# This is needed to be able to login as the internal root user for init of users etc. May be removed after
# initial setup of admin accounts/groups has been completed.
Set(\$WebFallbackToRTLogin, 1);
Set(\$MaxAttachmentSize, 41943040); # About 40 MB

1;
EOF
chown rt-service:www-data /opt/rt4/etc/RT_SiteConfig.pm
chmod 0660 /opt/rt4/etc/RT_SiteConfig.pm

# We had some issues with permissions for postfix and after that RT, this may not be needed in other installations
chown root:postdrop /usr/sbin/postqueue /usr/sbin/postdrop && chmod 2555 /usr/sbin/postqueue /usr/sbin/postdrop && chown -R postfix:postfix /var/lib/postfix
chown -R rt-service:www-data /opt/rt4 && chmod 0770 /opt/rt4/etc && chmod 0770 /opt/rt4/var 

# Set aliases for rt-mailgate then configure Postfix
cat >> /etc/aliases <<EOF
$RT_Q1:         	     "|/opt/rt4/bin/rt-mailgate --queue $RT_Q1 --action correspond --url https://$RT_HOSTNAME"
${RT_Q1}-comment: 	     "|/opt/rt4/bin/rt-mailgate --queue $RT_Q1 --action comment --url https://$RT_HOSTNAME"
###PLACEHOLDER2###
$RT_DEFAULTEMAIL:	     "|/opt/rt4/bin/rt-mailgate --queue $RT_Q1 --action correspond --url https://$RT_HOSTNAME"
${RT_DEFAULTEMAIL}-comment:  "|/opt/rt4/bin/rt-mailgate --queue $RT_Q1 --action comment --url https://$RT_HOSTNAME"
EOF
newaliases
echo "postfix postfix/main_mailer_type string Internet site" > /tmp/preseed.txt
echo "postfix postfix/mailname string $RT_HOSTNAME" >> /tmp/preseed.txt
debconf-set-selections /tmp/preseed.txt
cat >> /opt/postfix.sh <<EOF
#!/bin/bash
service postfix start
touch /var/log/mail.log
tail -f /var/log/mail.log
EOF
chmod +x /opt/postfix.sh
postconf -e myhostname="$RT_HOSTNAME"
postconf -e myorigin="$RT_HOSTNAME"
postconf -e inet_interfaces=all
postconf -e inet_protocols=ipv4
postconf -e mydestination="$RT_HOSTNAME",localhost
postconf -e mynetworks=127.0.0.0/8
postconf -e relay_domains=
postconf -e relayhost="$RT_RELAYHOST"
postconf -e message_size_limit=41943040
/opt/postfix.sh &

adduser -- _shibd ssl-cert
mkdir -p /var/log/shibboleth
mkdir -p /var/log/apache2 /var/lock/apache2

echo "----"
cat /etc/shibboleth/shibboleth2.xml
echo "----"
cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl

service shibd start
rm -f /var/run/apache2/apache2.pid

env APACHE_LOCK_DIR=/var/lock/apache2 APACHE_RUN_DIR=/var/run/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 apache2 -DFOREGROUND

