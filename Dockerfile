# Use the specified PHP version and variant
FROM php:7.4-apache

# Install necessary system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libmagickwand-dev \
    libicu-dev \
    libwebp-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        mysqli \
        opcache \
        pdo_mysql \
        zip \
    && pecl install imagick-3.7.0 \
    && docker-php-ext-enable imagick

# Set recommended PHP.ini settings
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini \
    && { \
        echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors_max_len = 1024'; \
        echo 'ignore_repeated_errors = On'; \
        echo 'ignore_repeated_source = Off'; \
        echo 'html_errors = Off'; \
    } > /usr/local/etc/php/conf.d/error-logging.ini

# Enable Apache modules
RUN a2enmod rewrite expires

# Download and extract WordPress
ARG WORDPRESS_VERSION=5.9.9
ARG WORDPRESS_SHA1=0eeb0527d8dd92d84e416a2468ac5b7e67f6a9ee

RUN curl -o wordpress.tar.gz -fL "https://wordpress.org/wordpress-$WORDPRESS_VERSION.tar.gz" \
    && echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
    && mkdir -p /usr/src/wordpress \
    && tar -xzf wordpress.tar.gz -C /usr/src/wordpress --strip-components=1 \
    && rm wordpress.tar.gz \
    && mv /usr/src/wordpress /var/www/html \
    && chown -R www-data:www-data /var/www/html

# Set recommended WordPress permissions
RUN mkdir -p /var/www/html/wp-content \
    && chown -R www-data:www-data /var/www/html/wp-content \
    && chmod -R 1777 /var/www/html/wp-content

# Start Apache
CMD ["apache2-foreground"]
