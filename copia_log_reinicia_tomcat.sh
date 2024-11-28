#!/bin/bash

# Diretório de destino para os logs
LOG_DIR="/home/victor.silva/logs-tomcat"

# Verifica se o diretório existe, caso contrário, cria
if [ ! -d "$LOG_DIR" ]; then
    echo "Diretório $LOG_DIR não encontrado. Criando..."
    mkdir -p "$LOG_DIR"
    if [ $? -eq 0 ]; then
        echo "Diretório criado com sucesso."
    else
        echo "Erro ao criar o diretório."
        exit 1
    fi
else
    echo "Diretório $LOG_DIR já existe."
fi

# Copia os arquivos de log
echo "Copiando logs do Tomcat para $LOG_DIR..."
cp -f /edusoft/tomcat/logs/* "$LOG_DIR/"
if [ $? -eq 0 ]; then
    echo "Logs copiados com sucesso."
else
    echo "Erro ao copiar os logs."
    exit 1
fi

# Reinicia o serviço do Tomcat
echo "Reiniciando o serviço Tomcat..."
systemctl restart tomcat && sleep 20 && chmod -R 775 /edusoft/tomcat/logs/*
if [ $? -eq 0 ]; then
    echo "Tomcat reiniciado com sucesso."
else
    echo "Erro ao reiniciar o Tomcat."
    exit 1
fi
