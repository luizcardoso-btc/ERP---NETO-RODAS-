# Dockerfile autossuficiente: nao depende de nenhuma pasta auxiliar alem do codigo.
FROM php:8.3-apache

RUN docker-php-ext-install pdo_mysql \
 && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf

RUN printf '%s\n' 'ServerTokens Prod' 'ServerSignature Off' 'ServerName localhost' '<Directory /var/www/html/public/uploads>' '    <FilesMatch "\.(php|phtml|phar)$">' '        Require all denied' '    </FilesMatch>' '    Options -Indexes' '</Directory>' '<FilesMatch "^\.">' '    Require all denied' '</FilesMatch>' > /etc/apache2/conf-available/erp.conf
RUN a2enconf erp
RUN printf '%s\n' 'display_errors=Off' 'log_errors=On' 'error_log=/dev/stderr' 'upload_max_filesize=4M' 'post_max_size=8M' 'date.timezone=America/Bahia' > /usr/local/etc/php/conf.d/erp.ini

WORKDIR /var/www/html
COPY . .
# Falha cedo, com mensagem clara, se o upload para o GitHub ficou incompleto.
RUN for f in bin/migrate.php bin/create-admin.php src/bootstrap.php src/Database.php src/Diagnostics.php pages/login.php public/index.php migrations/001_init.sql; do \
      [ -f "$f" ] || { echo "ERRO: $f nao esta no repositorio. Upload para o GitHub incompleto (faltam pastas)."; ls -la; exit 1; }; \
    done
RUN mkdir -p public/uploads && chown -R www-data:www-data public/uploads

RUN printf '%s\n' '#!/bin/sh' 'PORT="${PORT:-80}"' 'sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf' 'sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf' 'mkdir -p /var/www/html/public/uploads' 'chown -R www-data:www-data /var/www/html/public/uploads || true' 'cd /var/www/html' '(' '  i=0' '  until php bin/migrate.php; do' '    i=$((i+1))' '    if [ "$i" -ge 60 ]; then echo "[ERP] Banco indisponivel; migracoes nao aplicadas."; exit 1; fi' '    echo "[ERP] Aguardando banco... ($i)"; sleep 5' '  done' '  php bin/create-admin.php --if-empty || echo "[ERP] Admin nao criado: defina ADMIN_PASSWORD (10+ caracteres)."' ') &' 'echo "[ERP] Iniciando servidor web na porta ${PORT}"' 'exec ${ERP_WEB_CMD:-apache2-foreground}' > /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
