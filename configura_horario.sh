#!/bin/bash

# Atualiza o sistema e instala o pacote locales
sudo apt update && sudo apt install -y locales

# Configura o fuso horário para São Paulo
sudo timedatectl set-timezone America/Sao_Paulo

# Gera o locale pt_BR.UTF-8
sudo locale-gen pt_BR.UTF-8

# Define o locale pt_BR.UTF-8 como padrão
echo 'LANG=pt_BR.UTF-8' | sudo tee /etc/default/locale
echo 'LC_ALL=pt_BR.UTF-8' | sudo tee -a /etc/default/locale
echo 'LC_TIME=pt_BR.UTF-8' | sudo tee -a /etc/default/locale

# Reconfigura os locales
sudo dpkg-reconfigure -f noninteractive locales

# Reinicia o serviço de tempo para aplicar as mudanças
sudo systemctl restart systemd-timedated

# Exibe as configurações atuais para verificação
echo "Fuso horário configurado para: $(timedatectl show --property=Timezone)"
echo "Locale configurado para: $(locale)"
