#!/bin/bash

echo "======================================================="
echo "   ATIVANDO LOGIN ROOT E AUTENTICAÇÃO POR SENHA SSH"
echo "======================================================="

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "[ERRO] Este script precisa ser executado como ROOT!"
   echo "Use: sudo bash enable-root-ssh.sh"
   exit 1
fi

SSH_CONFIG="/etc/ssh/sshd_config"

echo "[INFO] Fazendo backup de $SSH_CONFIG para $SSH_CONFIG.bak ..."
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

echo "[INFO] Aplicando configurações no sshd_config ..."

# Ativa PermitRootLogin yes
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONFIG
sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONFIG

# Ativa PasswordAuthentication yes
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' $SSH_CONFIG
sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' $SSH_CONFIG

# Garante que UsePAM está ativado
sed -i 's/#UsePAM.*/UsePAM yes/' $SSH_CONFIG

echo "[INFO] Reiniciando o serviço SSH ..."
systemctl restart ssh || systemctl restart sshd

echo "======================================================="
echo "     ✔ ROOT LOGIN ATIVADO COM SUCESSO VIA SSH"
echo "     ✔ SENHA ATIVADA PARA LOGIN SSH"
echo "======================================================="
echo ""
echo "Agora você pode conectar via:"
echo ""
echo "ssh root@IP_DA_MAQUINA -p 22"
echo ""
echo "Se sua VM usa outra porta (ex: 2222):"
echo "ssh root@IP_DA_MAQUINA -p 2222"
echo ""
echo "Backup criado em: $SSH_CONFIG.bak"
echo "======================================================="
