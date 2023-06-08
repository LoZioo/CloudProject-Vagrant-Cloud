#!/bin/bash
source config.sh
HOST_INI="./playbooks/hosts.ini"

echo "; Auto-generated hosts.ini from compile-ansible-hosts.sh and config.sh" > $HOST_INI
echo >> $HOST_INI

echo "[blockchain]" >> $HOST_INI
echo "$SERVER_BC_ADDRESS" >> $HOST_INI
echo >> $HOST_INI

echo "[master]" >> $HOST_INI
echo "$SERVER_0_ADDRESS" >> $HOST_INI
echo >> $HOST_INI

echo "[workers]" >> $HOST_INI
echo "$SERVER_1_LOCAL_ADDRESS ansible_port=2222" >> $HOST_INI
echo "$SERVER_2_LOCAL_ADDRESS ansible_port=2222" >> $HOST_INI
echo >> $HOST_INI

echo "[cluster:children]" >> $HOST_INI
echo "master" >> $HOST_INI
echo "workers" >> $HOST_INI
echo >> $HOST_INI

echo "[common:children]" >> $HOST_INI
echo "blockchain" >> $HOST_INI
echo "cluster" >> $HOST_INI
echo >> $HOST_INI

echo "[common:vars]" >> $HOST_INI
echo "ansible_ssh_private_key_file=$SECRET_KEY" >> $HOST_INI
echo "ansible_user=$USER" >> $HOST_INI
