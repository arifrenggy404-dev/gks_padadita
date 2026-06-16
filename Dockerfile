FROM php:8.5-cli-alpine

# Install tools dan ekstensi yang diperlukan Laravel 13
# Ditambahkan: nodejs, npm, dan library untuk gd, zip, intl, bcmath
RUN apk add --no-cache \
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
    libxml2-dev

# Install PHP extensions yang dibutuhkan oleh Laravel & packages (phpspreadsheet, dompdf)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo_mysql \
    gd \
    zip \
    intl \
    bcmath \
    mbstring

# Install Composer versi terbaru
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Menyalin seluruh file project ke dalam container
COPY . /app

# Jalankan Composer Install (tanpa dev dependencies untuk production)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Build assets menggunakan Vite (Wajib agar CSS/JS muncul di production)
RUN npm install && npm run build

# Memastikan izin folder storage dan cache aman
RUN chmod -R 777 /app/storage /app/bootstrap/cache

# Railway menggunakan port dinamis via environment variable $PORT
# Default ke 8080 jika tidak ada
CMD php artisan migrate --force && php artisan serve --host=0.0.0.0 --port=${PORT:-8080}
