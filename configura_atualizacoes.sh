#!/bin/bash

# Atualizar lista de pacotes e instalar unattended-upgrades
echo "Atualizando lista de pacotes e instalando unattended-upgrades..."
sudo apt-get update
sudo apt-get install -y unattended-upgrades

# Configurar unattended-upgrades
echo "Configurando unattended-upgrades..."
sudo sed -i 's#//\s*\(Unattended-Upgrade::Allowed-Origins.*\)#\1#' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's#//\s*"\${distro_id}:\${distro_codename}-security";#"${distro_id}:${distro_codename}-security";#' /etc/apt/apt.conf.d/50unattended-upgrades

# Configurar auto-upgrades e reinicialização automática
echo "Configurando auto-upgrades e reinicialização automática..."
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade::Automatic-Reboot "true";
APT::Periodic::Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOL

# Verificar configuração
echo "Verificando configuração..."
sudo unattended-upgrade --dry-run --debug

# Habilitar e iniciar o serviço unattended-upgrades
echo "Habilitando e iniciando o serviço unattended-upgrades..."
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades

echo "Configuração completa. Atualizações de segurança automáticas e reinicialização às 2h da manhã estão ativadas."
