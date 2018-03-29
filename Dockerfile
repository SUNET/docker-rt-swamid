FROM ubuntu:16.04
MAINTAINER el@sunet.se
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN echo 'deb http://se.archive.ubuntu.com/ubuntu/ xenial universe multiverse' > /etc/apt/sources.list.d/multiverse.list
RUN apt-get -q update
RUN apt-get -y upgrade
RUN apt-get -y install apache2 libapache2-mod-shib2 ssl-cert augeas-tools libapache2-mod-php libcgi-pm-perl \
    libemail-mime-encodings-perl libapache2-mod-fastcgi vim
RUN a2enmod rewrite ssl shib2 headers cgi proxy proxy_http fastcgi alias
ENV SP_HOSTNAME sp.example.com
ENV SP_CONTACT noc@nordu.net
ENV SP_ABOUT /
ENV METADATA_SIGNER md-signer2.crt
ENV DEFAULT_LOGIN md.nordu.net

# Perl settings -n to don't to tests
ENV RT_FIX_DEPS_CMD /usr/bin/cpanm
ENV PERL_CPANM_OPT -n

## Install tools and libraries
RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    build-essential ca-certificates cpanminus curl git gpgv2 graphviz make libexpat1-dev libpq-dev libgd-dev openssl perl postfix && \

# Create user and group
    groupadd -r rt-service && \
    useradd -r -g rt-service -G www-data rt-service && \
    usermod -a -G rt-service www-data && \
    mkdir -p --mode=750 /opt/rt4 && \
    chown rt-service:www-data /opt/rt4 && \
    mkdir -p /tmp/rt && \
    curl -SL https://download.bestpractical.com/pub/rt/release/rt.tar.gz | \
        tar -xzC /tmp/rt && \
    cd /tmp/rt/rt* && \
    echo "o conf init " | \
        perl -MCPAN -e shell && \
    ./configure \
        --enable-graphviz \
        --enable-gd \
        --enable-externalauth \
        --with-web-handler=fastcgi \
        --with-bin-owner=rt-service \
        --with-libs-owner=rt-service \
        --with-libs-group=www-data \
        --with-db-type=Pg \
        --with-web-user=www-data \
        --with-web-group=www-data \
        --prefix=/opt/rt4 \
        --with-rt-group=rt-service && \
    make fixdeps && \
    make testdeps && \
    make config-install dirs files-install fixperms instruct && \
    cpanm https://github.com/gbarr/perl-TimeDate.git && \
# Clean up
    apt-get remove -y git cpanminus build-essential && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cpan && \
    rm -rf /root/.cpanm && \
    rm -rf /preseed.txt /usr/share/doc && \
    rm -rf /usr/local/share/man /var/cache/debconf/*-old

RUN cp /opt/rt4/lib/RT/Interface/Web.pm /opt/rt4/lib/RT/Interface/Web_orig.pm
ADD Web.pm.patch /Web.pm.patch
RUN patch /opt/rt4/lib/RT/Interface/Web.pm /Web.pm.patch

RUN chmod 770 /opt/rt4/etc && \
    chmod 660 /opt/rt4/etc/RT_SiteConfig.pm && \
    chown rt-service:www-data /opt/rt4/var && \
    chmod 0770 /opt/rt4/var

RUN rm -f /etc/apache2/sites-available/*
RUN rm -f /etc/apache2/sites-enabled/*
ADD start.template.sh /start.template.sh
ADD conf.builder.pl /conf.builder.pl
RUN chmod a+rx /conf.builder.pl
ADD certs/ /etc/shibboleth/
ADD attribute-map.xml /etc/shibboleth/attribute-map.xml
ADD secure /var/www/secure
RUN chmod a+rx /var/www/secure/index.cgi
COPY /apache2.conf /etc/apache2/
ADD shibd.logger /etc/shibboleth/shibd.logger
ADD index.php /var/www/
EXPOSE 443
EXPOSE 80
EXPOSE 25
ENTRYPOINT ["/conf.builder.pl"]
