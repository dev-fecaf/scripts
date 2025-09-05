#!/bin/bash
set -e

echo "=== Removendo versões antigas do Docker ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

echo "=== Atualizando pacotes ==="
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

echo "=== Adicionando chave GPG da Docker ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "=== Adicionando repositório oficial da Docker ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Instalando Docker Engine, CLI e Compose ==="
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Adicionando usuário '$USER' ao grupo docker ==="
sudo usermod -aG docker $USER

echo "=== Testando instalação ==="
docker --version || echo "Docker não disponível ainda, faça logout/login."
docker compose version || echo "Docker Compose não disponível ainda."

echo "=== Instalação concluída! 🚀 ==="
echo "👉 Saia da sessão (logout/login) ou rode 'newgrp docker' para usar Docker sem sudo."
