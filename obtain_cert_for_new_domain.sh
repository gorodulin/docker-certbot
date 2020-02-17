#!/bin/bash

if [ ! -f "${BASH_SOURCE%/*}/config" ]; then
  echo "Create config file first! See config.example"
  exit 0
fi

source "${BASH_SOURCE%/*}/config"

# Read domain name and email if not set in config file
if [ -z "$DOMAIN" ]; then
  echo -n "Enter domain name and press [ENTER]: "
  read DOMAIN
fi

if [ -z "$EMAIL" ]; then
  echo -n "Enter your email and press [ENTER]: "
  read EMAIL
fi

echo


# Stop real webserver
"$WEBSERVER_STOP_COMMAND"


# Create docker volume
exe docker volume create --name certbot_temporary_www


# Create nginx config for a dummy website
DUMMYCONF=/tmp/~default.conf
exe cp $ROOT_PATH/resources/default.conf.template $DUMMYCONF
exe sed -i 's/DOMAIN/'$DOMAIN'/' $DUMMYCONF


# Start temporary nginx container that will serve dummy website for the certbot
exe docker run \
  --name $CONTAINER_NAME \
  --detach \
  --rm \
  --volume=$DUMMYCONF:/etc/nginx/conf.d/default.conf \
  --volume=$LETSENCRYPT_FOLDER:/etc/letsencrypt \
  --volume=certbot_temporary_www:/var/www/certbot \
  -p 80:80 \
  nginx:$NGINX_VER-alpine


# Request real cert
certbot_exec () {
  exe docker run \
    -it \
    --rm \
    --env DOMAIN=$DOMAIN \
    --env EMAIL=$EMAIL \
    --env RSA_KEY_SIZE=$RSA_KEY_SIZE \
    --volume=certbot_temporary_www:/var/www/certbot \
    --volume=$ROOT_PATH/resources/request_real_certs:/usr/bin/request_real_certs \
    --volume=$LETSENCRYPT_FOLDER:/etc/letsencrypt \
    --entrypoint="$1" \
    certbot/certbot
   }
certbot_exec "/usr/bin/request_real_certs"


# Stop temporary nginx container
exe docker stop $CONTAINER_NAME


# Remove docker volume
exe docker volume rm certbot_temporary_www


# Cleanup
exe rm $DUMMYCONF

# Start real webserver
"$WEBSERVER_START_COMMAND"


