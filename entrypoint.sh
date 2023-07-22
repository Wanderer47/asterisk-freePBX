#!/bin/bash

service mariadb start

./start_asterisk start
./install -n

fwconsole ma install pm2

# configure apache2
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/${PHP_VERSION}/cli/php.ini
sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/${PHP_VERSION}/apache2/php.ini

a2enmod rewrite
service apache2 restart
