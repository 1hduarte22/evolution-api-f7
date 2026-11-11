#!/bin/bash
# Script de inicialização (cloud-init) da VM Oracle Always Free para a Evolution do F7 CRM.
# Cole em "Advanced options → Management → Initialization script" ao criar a instância (Ubuntu).
# Gera chaves aleatórias na própria VM, usa um domínio grátis <ip>.sslip.io com HTTPS automático
# e imprime o endereço e a chave no console serial (Console history da instância).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Memória extra (VMs de 1 GB)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

apt-get update
apt-get install -y docker.io docker-compose-v2 curl openssl iptables-persistent || apt-get install -y docker.io docker-compose-plugin curl openssl iptables-persistent
systemctl enable --now docker

# Firewall da imagem Ubuntu da Oracle: libera HTTP e HTTPS
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
netfilter-persistent save || iptables-save > /etc/iptables/rules.v4

mkdir -p /opt/evolution && cd /opt/evolution
if [ ! -f .env ]; then
  IP="$(curl -fsS https://api.ipify.org)"
  echo "EVOLUTION_DOMAIN=${IP//./-}.sslip.io" > .env
  echo "AUTHENTICATION_API_KEY=$(openssl rand -hex 24)" >> .env
  echo "PG_PASSWORD=$(openssl rand -hex 16)" >> .env
  chmod 600 .env
fi
curl -fsSL https://raw.githubusercontent.com/1hduarte22/evolution-api-f7/chore/bump-baileys-7.0.0-rc10/docker-compose.oracle.yaml -o docker-compose.yaml
docker compose --env-file .env up -d

. ./.env
for i in 1 2 3 4 5; do
  echo "F7-EVOLUTION-PRONTA url=https://${EVOLUTION_DOMAIN} chave=${AUTHENTICATION_API_KEY}" | tee /dev/console /dev/ttyS0 || true
  sleep 2
done
