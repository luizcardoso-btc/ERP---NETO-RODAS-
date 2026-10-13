# Dockerfile autossuficiente: nao depende de nenhuma pasta auxiliar alem do codigo.
FROM php:8.3-apache

RUN docker-php-ext-install pdo_mysql \
 && a2enmod headers \
 && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf

RUN printf '%s\n' 'ServerTokens Prod' 'ServerSignature Off' '<Directory /var/www/html/public/uploads>' '    <FilesMatch "\.(php|phtml|phar)$">' '        Require all denied' '    </FilesMatch>' '    Options -Indexes' '</Directory>' '<FilesMatch "^\.">' '    Require all denied' '</FilesMatch>' > /etc/apache2/conf-available/erp.conf
RUN a2enconf erp

WORKDIR /var/www/html
COPY . .
RUN mkdir -p public/uploads && chown -R www-data:www-data public/uploads

RUN printf '%s\n' '#!/bin/sh' 'set -e' 'PORT="${PORT:-80}"' 'sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf' 'sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf' 'mkdir -p /var/www/html/public/uploads' 'chown -R www-data:www-data /var/www/html/public/uploads || true' 'i=0' 'until php bin/migrate.php; do' '  i=$((i+1))' '  if [ "$i" -ge 20 ]; then echo "Banco indisponivel apos 20 tentativas."; exit 1; fi' '  echo "Aguardando banco... ($i)"; sleep 3' 'done' 'php bin/create-admin.php --if-empty || true' 'exec apache2-foreground' > /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
