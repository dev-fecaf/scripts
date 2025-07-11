#!/bin/bash

wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.2-1_amd64.deb && \
sudo WAZUH_MANAGER='wazuh.unifecaf.edu.br' dpkg -i ./wazuh-agent_4.7.2-1_amd64.deb && \
sudo systemctl daemon-reload && \
sudo systemctl enable wazuh-agent && \
sudo systemctl start wazuh-agent
