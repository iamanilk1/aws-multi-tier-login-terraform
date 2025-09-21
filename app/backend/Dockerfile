FROM php:8.2-apache

RUN docker-php-ext-install pdo pdo_mysql

# Suppress Apache FQDN warning by setting a global ServerName
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
	&& a2enconf servername

ENV APACHE_DOCUMENT_ROOT /var/www/html
WORKDIR /var/www/html

COPY . /var/www/html

EXPOSE 80
