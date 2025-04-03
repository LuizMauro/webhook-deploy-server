#!/bin/bash

REPO=$1
URL=$2
PROJECTS_DIR="/home/ubuntu/projetos"
DOMAIN="$REPO.luizmauro.com"
PORT=$((10000 + $(echo $REPO | cksum | cut -d ' ' -f1) % 1000)) # porta única baseada no nome
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

echo "🌱 Deployando $REPO ($DOMAIN) na porta $PORT..."

mkdir -p $PROJECTS_DIR
cd $PROJECTS_DIR

# Clona ou atualiza
if [ -d "$REPO" ]; then
  cd $REPO && git pull
else
  git clone $URL && cd $REPO
fi

# Docker up
if [ -f "docker-compose.yml" ]; then
  docker-compose down
  PORT=$PORT docker-compose up -d --build
else
  docker stop $REPO || true
  docker rm $REPO || true
  docker build -t $REPO .
  docker run -d --name $REPO -p 127.0.0.1:$PORT:80 $REPO
fi

# Gera nginx config
cat <<EOF > $NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf $NGINX_CONF $NGINX_LINK
nginx -t && systemctl reload nginx

echo "✅ $REPO disponível em http://$DOMAIN"
