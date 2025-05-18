# syntax=docker/dockerfile:1
FROM php:8.1-cli

# Install system dependencies (including ca-certificates for HTTPS)
RUN apt-get update && \
    apt-get install -y git unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Xdebug for code coverage
RUN pecl install xdebug-3.1.6 \
    && docker-php-ext-enable xdebug

# Install runkit7
RUN pecl install runkit7-alpha \
    && docker-php-ext-enable runkit7

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set workdir
WORKDIR /app

# Copy project files
COPY . .

# Test network connectivity before installing dependencies
RUN php -r "echo 'Testing DNS...\n'; var_dump(gethostbyname('github.com')); echo 'Testing HTTP...\n'; var_dump(file_get_contents('https://api.github.com/'));" || (echo 'Network test failed' && exit 1)

RUN composer install --no-interaction --no-progress

# Enable Xdebug coverage mode for code coverage
ENV XDEBUG_MODE=coverage

# Run tests
CMD ["./vendor/bin/phpunit", "--coverage-text", "--coverage-filter=src/"]
