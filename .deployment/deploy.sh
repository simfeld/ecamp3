#!/bin/bash
set -e

# Travis CI uses OpenSSL 1.0.2g  1 Mar 2016. Files encrypted with newer versions of OpenSSL are not decryptable by
# the Travis CI version, error message is "bad decrypt". So to encrypt a file, use the following:
# docker run --rm -it -v $(pwd):/app -w /app frapsoft/openssl aes-256-cbc -k "<password>" -in <input_file> -out <output_file>
openssl aes-256-cbc -k "$ID_RSA_PASSWORD" -in .deployment/id_rsa_travis.enc -out .deployment/id_rsa_travis -d
eval "$(ssh-agent -s)"
chmod 600 .deployment/id_rsa_travis
ssh-add .deployment/id_rsa_travis

# Calculate short commit id
COMMIT_ID=$(git rev-parse --short "$TRAVIS_COMMIT")

# Inject environment secrets into backend config files
EDIT_SCRIPT=".deployment/edit_array_file.php"
DB_CONFIG_FILE=".deployment/dist/doctrine.local.prod.php"
cp backend/config/autoload/doctrine.docker.dist $DB_CONFIG_FILE
php $EDIT_SCRIPT $DB_CONFIG_FILE "doctrine.connection.orm_default.params.host" "${DB_HOST:-db}"
php $EDIT_SCRIPT $DB_CONFIG_FILE "doctrine.connection.orm_default.params.port" "${DB_PORT:-3306}"
php $EDIT_SCRIPT $DB_CONFIG_FILE "doctrine.connection.orm_default.params.user" "${DB_USER:-ecamp3}"
php $EDIT_SCRIPT $DB_CONFIG_FILE "doctrine.connection.orm_default.params.password" "${DB_PASS:-ecamp3}"
php $EDIT_SCRIPT $DB_CONFIG_FILE "doctrine.connection.orm_default.params.dbname" "${DB_NAME:-ecamp3dev}"
cp backend/config/autoload/mail.local.docker.dist .deployment/dist/mail.local.prod.php
cp backend/config/autoload/sessions.local.docker.dist .deployment/dist/sessions.local.prod.php
php $EDIT_SCRIPT .deployment/dist/sessions.local.prod.php "session_config.cookie_domain" "${SESSION_COOKIE_DOMAIN}"
cp backend/config/autoload/zfr_cors.global.php .deployment/dist/zfr_cors.global.php
php $EDIT_SCRIPT .deployment/dist/zfr_cors.global.php "zfr_cors.allowed_origins.0" "${FRONTEND_URL:-*}"
php $EDIT_SCRIPT .deployment/dist/zfr_cors.global.php "zfr_cors.allowed_origins.1" "${PRINT_SERVER_URL:-*}"
cp backend/config/sentry.config.php.dist .deployment/dist/sentry.config.php
php $EDIT_SCRIPT .deployment/dist/sentry.config.php "dsn" "${SENTRY_DSN}"
cp backend/config/autoload/amq.local.dev.dist .deployment/dist/amq.local.prod.php
php $EDIT_SCRIPT .deployment/dist/amq.local.prod.php "amqp.connection.host" "${RABBITMQ_HOST:-rabbitmq}"
php $EDIT_SCRIPT .deployment/dist/amq.local.prod.php "amqp.connection.port" "${RABBITMQ_PORT:-5672}"
php $EDIT_SCRIPT .deployment/dist/amq.local.prod.php "amqp.connection.vhost" "${RABBITMQ_VHOST:-/}"
php $EDIT_SCRIPT .deployment/dist/amq.local.prod.php "amqp.connection.user" "${RABBITMQ_USER:-guest}"
php $EDIT_SCRIPT .deployment/dist/amq.local.prod.php "amqp.connection.pass" "${RABBITMQ_PASS:-guest}"

# Inject environment variables into frontend config file
cp frontend/public/environment.dist .deployment/dist/frontend-environment.js
sed -ri "s~API_ROOT_URL: '.*'~API_ROOT_URL: '${BACKEND_URL}'~" .deployment/dist/frontend-environment.js
sed -ri "s~PRINT_SERVER: '.*'~PRINT_SERVER: '${PRINT_SERVER_URL}'~" .deployment/dist/frontend-environment.js
sed -ri "s~PRINT_FILE_SERVER: '.*'~PRINT_FILE_SERVER: '${PRINT_FILE_SERVER_URL}'~" .deployment/dist/frontend-environment.js
sed -ri "s~VERSION: '.*'~VERSION: '${COMMIT_ID}'~" .deployment/dist/frontend-environment.js
sed -ri "s~VERSION_LINK_TEMPLATE: '.*'~VERSION_LINK_TEMPLATE: '${VERSION_LINK_TEMPLATE:-https://github.com/ecamp/ecamp3/commits/\{version\}}'~" .deployment/dist/frontend-environment.js

# Inject environment variables into print env file
cp print/print.env .deployment/dist/print.env
sed -ri "s~INTERNAL_API_ROOT_URL=.*~API_ROOT_URL=${INTERNAL_BACKEND_URL:-http://backend/api}~" .deployment/dist/print.env
sed -ri "s~API_ROOT_URL=.*~API_ROOT_URL=${BACKEND_URL:-http://localhost:3001/api}~" .deployment/dist/print.env

# Inject environment secrets into print-worker-puppeteer config file
cp workers/print-puppeteer/environment.js .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~PRINT_SERVER: .*$~PRINT_SERVER: '${PRINT_SERVER_URL:-print}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~SESSION_COOKIE_DOMAIN: .*$~SESSION_COOKIE_DOMAIN: '${SESSION_COOKIE_DOMAIN:-backend}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~AMQP_HOST: .*$~AMQP_HOST: '${RABBITMQ_HOST:-rabbitmq}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~AMQP_PORT: .*$~AMQP_PORT: '${RABBITMQ_PORT:-5672}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~AMQP_VHOST: .*$~AMQP_VHOST: '${RABBITMQ_VHOST:-/}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~AMQP_USER: .*$~AMQP_USER: '${RABBITMQ_USER:-guest}',~" .deployment/dist/worker-print-puppeteer-environment.js
sed -ri "s~AMQP_PASS: .*$~AMQP_PASS: '${RABBITMQ_PASS:-guest}',~" .deployment/dist/worker-print-puppeteer-environment.js

# Inject environment secrets into print-worker-weasy config file
cp workers/print-weasy/environment.py .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~PRINT_SERVER = .*$~PRINT_SERVER = '${PRINT_SERVER_URL}'~" .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~AMQP_HOST = .*$~AMQP_HOST = '${RABBITMQ_HOST:-rabbitmq}'~" .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~AMQP_PORT = .*$~AMQP_PORT = '${RABBITMQ_PORT:-5672}'~" .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~AMQP_VHOST = .*$~AMQP_VHOST = '${RABBITMQ_VHOST:-/}'~" .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~AMQP_USER = .*$~AMQP_USER = '${RABBITMQ_USER:-guest}'~" .deployment/dist/worker-print-weasy-environment.py
sed -ri "s~AMQP_PASS = .*$~AMQP_PASS = '${RABBITMQ_PASS:-guest}'~" .deployment/dist/worker-print-weasy-environment.py

# Inject environment secrets into rabbitmq env file
cp .deployment/rabbitmq.env .deployment/dist/rabbitmq.env
sed -ri "s~RABBITMQ_DEFAULT_USER=.*~RABBITMQ_DEFAULT_USER=${RABBITMQ_USER:-guest}~" .deployment/dist/rabbitmq.env
sed -ri "s~RABBITMQ_DEFAULT_PASS=.*~RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASS:-guest}~" .deployment/dist/rabbitmq.env

echo "Deploying the project to the server..."

# Add the host fingerprint to the known hosts
echo "|1|cRKiI12wEM4OaBRVG2Yd6QDFSVk=|uvdyN6p+CEXNzz9HbhAgFQGwBcQ= ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLADq1uUT0iDbD6rvfJdAmB+M//sIG9pPD9fR7pXA8o4aoKlGeliT3xs+WQdOg3Jb1W1a46XppNLHnRhtCk/jz0=" >> ~/.ssh/known_hosts
rsync -avz -e ssh --delete .deployment/dist/ "${SSH_USERNAME}@${SSH_HOST}:ecamp3"
ssh -T "${SSH_USERNAME}@${SSH_HOST}" <<EOF
  cd ecamp3
  docker system prune -f --volumes
  docker-compose pull && docker-compose down --volumes && docker-compose up -d
EOF

echo "Deployment complete."
