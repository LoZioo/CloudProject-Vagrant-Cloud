#!/bin/bash
source config.sh
HOST_INI="./playbooks/hosts.ini"

echo "; Auto-generated hosts.ini from compile-ansible-hosts.sh and config.sh" > $HOST_INI
echo >> $HOST_INI

echo "[master]" >> $HOST_INI
echo "$M_IP" >> $HOST_INI
echo >> $HOST_INI

echo "[workers]" >> $HOST_INI
echo "$W1_IP" >> $HOST_INI
echo "$W2_IP" >> $HOST_INI
echo >> $HOST_INI

echo "[cluster:children]" >> $HOST_INI
echo "master" >> $HOST_INI
echo "workers" >> $HOST_INI
echo >> $HOST_INI

echo "[cluster:vars]" >> $HOST_INI
echo "ansible_ssh_private_key_file=$SECRET_KEY" >> $HOST_INI
echo "ansible_user=$USER" >> $HOST_INI
echo "repo_name=CloudProject-Vagrant-Cloud" >> $HOST_INI
