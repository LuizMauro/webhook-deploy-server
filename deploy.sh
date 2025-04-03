#!/bin/bash

REPO_NAME=$1
CLONE_URL=$2
PROJECTS_DIR="/home/ubuntu/projetos"
DOMAIN="$REPO_NAME.luizmauro.com"
NGINX_SITES="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Gera uma porta externa baseada no nome do repositório
PORT=$((10000 + $(echo $REPO_NAME | cksum | cut -d ' ' -f1) % 1000))

echo "🌱 Deployando $REPO_NAME ($DOMAIN) na porta $PORT..."

# Cria diretório de projetos se não existir
mkdir -p "$PROJECTS_DIR"
cd "$PROJECTS_DIR"

# Clona ou atualiza o projeto
if [ -d "$REPO_NAME" ]; then
  echo "📥 Atualizando repositório..."
  cd "$REPO_NAME" && git pull
else
  echo "📥 Clonando repositório..."
  git clone "$CLONE_URL"
  cd "$REPO_NAME"
fi

# Para e remove container antigo, se existir
echo "🐳 Subindo container Docker..."
docker stop "$REPO_NAME" 2>/dev/null || true
docker rm "$REPO_NAME" 2>/dev/null || true

# Build e run com a porta correta
docker build -t "$REPO_NAME" .
docker run -d --name "$REPO_NAME" -p 127.0.0.1:$PORT:80 "$REPO_NAME"

# Gera config NGINX
echo "📝 Gerando config do NGINX para $DOMAIN..."

cat <<EOF > "$NGINX_SITES/$DOMAIN"
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Ativa site e recarrega nginx
ln -sf "$NGINX_SITES/$DOMAIN" "$NGINX_ENABLED/$DOMAIN"

echo "🔁 Reload do NGINX..."
nginx -t && systemctl reload nginx

echo "✅ $REPO_NAME disponível em http://$DOMAIN"
