FROM ubuntu

WORKDIR /asterisk

ENV PHP_VERSION=7.4 \
	ASTERISK_VERSION=19.8.1

EXPOSE 5060/udp 5060/tcp

## for apt to be noninteractive
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

## preesed tzdata, update package index, upgrade packages and install needed software
RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.txt; \
    echo "tzdata tzdata/Zones/Europe select Berlin" >> /tmp/preseed.txt; \
    debconf-set-selections /tmp/preseed.txt && \
    apt-get update && \
    apt-get install -y tzdata

RUN apt-get update && apt-get upgrade -y

# ====== Asterisk ======
RUN apt -y install gnupg2 software-properties-common git curl wget \
		libnewt-dev libssl-dev libncurses5-dev subversion \
		libsqlite3-dev build-essential libjansson-dev libxml2-dev uuid-dev

RUN wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz
RUN tar zxvf asterisk-${ASTERISK_VERSION}.tar.gz && rm asterisk-${ASTERISK_VERSION}.tar.gz
WORKDIR asterisk-${ASTERISK_VERSION}

# insrall mp3 moduls with dependencies
RUN /bin/bash contrib/scripts/get_mp3_source.sh
RUN /bin/bash contrib/scripts/install_prereq install
RUN ./configure

RUN make menuselect/menuselect menuselect-tree menuselect.makeopts
RUN menuselect/menuselect --disable BUILD_NATIVE menuselect.makeopts \
	menuselect/menuselect --enable BETTER_BACKTRACES menuselect.makeopts \
	menuselect/menuselect --enable chan_ooh323 menuselect.makeopts
RUN menuselect/menuselect --disable-category MENUSELECT_CORE_SOUNDS menuselect.makeopts \
	menuselect/menuselect --disable-category MENUSELECT_MOH menuselect.makeopts \
	menuselect/menuselect --disable-category MENUSELECT_EXTRA_SOUNDS menuselect.makeopts

RUN make && make install && make samples && make basic-pbx && make config
RUN ldconfig

RUN adduser --system --group --home /var/lib/asterisk --no-create-home --gecos "Asterisk PBX" asterisk

RUN usermod -a -G dialout,audio asterisk
RUN echo "$(ls -la /var/lib)" && sleep 5
RUN echo "runuser = asterisk;" >> /etc/asterisk/asterisk.conf
RUN echo "rungroup = asterisk;" >> /etc/asterisk/asterisk.conf
RUN echo "AST_USER=\"asterisk\"" >> /etc/default/asterisk && \
	echo "AST_GROUP=\"asterisk\"" >> /etc/default/asterisk

RUN service asterisk stop

#RUN chown -R asterisk:asterisk /etc/asterisk /var/*/asterisk /usr/lib/asterisk
RUN chown -R asterisk: /var/lib/asterisk /usr/lib/asterisk /etc/asterisk && \
	chown -R asterisk: /var/log/asterisk /usr/lib/asterisk /etc/asterisk && \
	chown -R asterisk: /var/run/asterisk /usr/lib/asterisk /etc/asterisk && \
	chown -R asterisk: /var/spool/asterisk /usr/lib/asterisk /etc/asterisk
RUN	chmod -R 750 /var/lib/asterisk /usr/lib/asterisk /etc/asterisk && \
	chmod -R 750 /var/log/asterisk /usr/lib/asterisk /etc/asterisk && \
	chmod -R 750 /var/run/asterisk /usr/lib/asterisk /etc/asterisk && \
	chmod -R 750 /var/spool/asterisk /usr/lib/asterisk /etc/asterisk

# ====== FreePBX ======
#RUN apt-get install software-properties-common -y
RUN add-apt-repository ppa:ondrej/php -y
RUN apt update

RUN apt-get install apache2 mariadb-server -y
RUN apt-get install -y php${PHP_VERSION}

RUN apt-get install -y  libapache2-mod-php${PHP_VERSION} php${PHP_VERSION}-common \
						php${PHP_VERSION}-curl php${PHP_VERSION}-mbstring php${PHP_VERSION}-xmlrpc \
						php${PHP_VERSION}-mysql php${PHP_VERSION}-gd php${PHP_VERSION}-xml \
						php${PHP_VERSION}-intl php${PHP_VERSION}-ldap php${PHP_VERSION}-imagick \
						php${PHP_VERSION}-json php${PHP_VERSION}-cli php${PHP_VERSION}-cgi \
						php${PHP_VERSION}-bcmath php${PHP_VERSION}-zip php${PHP_VERSION}-imap \
						php${PHP_VERSION}-snmp

# php-pear install
RUN wget http://pear.php.net/go-pear.phar
RUN php go-pear.phar

RUN wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-16.0-latest.tgz
RUN tar -xvzf freepbx-16.0-latest.tgz && rm -rf freepbx-16.0-latest.tgz
WORKDIR freepbx

RUN apt-get install -y apache2 nodejs npm
RUN apt-get install -y cron

RUN cp /etc/asterisk/asterisk.conf.old /etc/asterisk/asterisk.conf

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
