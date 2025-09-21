FROM php:8.2-apache

RUN docker-php-ext-install pdo pdo_mysql

ENV APACHE_DOCUMENT_ROOT /var/www/html
WORKDIR /var/www/html

COPY . /var/www/html

EXPOSE 80
