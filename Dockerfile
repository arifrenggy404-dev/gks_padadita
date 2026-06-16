FROM php:8.5-fpm-alpine

# Install Nginx, Node.js, npm, and system libraries required by PHP extensions
RUN apk add --no-cache \
    nginx \
    git \
    unzip \
    bash \
    nodejs \
    npm \
    libpng-dev \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    curl-dev \
    lexbor-dev

# Install PHP extensions required by Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo_mysql \
    gd \
    zip \
    intl \
    bcmath \
    mbstring \
    xml \
    dom \
    curl \
    fileinfo

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy all project files
COPY . /app

# Install PHP dependencies (no dev) and build frontend assets
RUN composer install --no-dev --optimize-autoloader --no-interaction
RUN npm install && npm run build

# Set correct permissions on storage and cache directories
RUN chmod -R 777 /app/storage /app/bootstrap/cache

# Configure Nginx to listen on port 8080 and proxy PHP requests to PHP-FPM
RUN mkdir -p /etc/nginx/http.d && printf '\
server {\n\
    listen 8080;\n\
    root /app/public;\n\
    index index.php index.html;\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.php?$query_string;\n\
    }\n\
\n\
    location ~ \\.php$ {\n\
        fastcgi_pass 127.0.0.1:9000;\n\
        fastcgi_index index.php;\n\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n\
        include fastcgi_params;\n\
    }\n\
\n\
    location ~ /\\.ht {\n\
        deny all;\n\
    }\n\
}\n\
' > /etc/nginx/http.d/default.conf

# Create startup script: run migrations, start PHP-FPM, then start Nginx in foreground
RUN printf '#!/bin/sh\n\
set -e\n\
php /app/artisan migrate --force\n\
php-fpm -D\n\
exec nginx -g "daemon off;"\n\
' > /start.sh && chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
