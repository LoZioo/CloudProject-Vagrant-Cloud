#!/bin/bash

# Check playbook-name parameter.
if [ -n "$1" ]; then
	PLAYBOOK=$1

else
	echo "Usage: $0 playbook-name (without \".yml\")"
	exit 1

fi

cd playbooks
ansible-playbook -i hosts.ini $PLAYBOOK.yml
