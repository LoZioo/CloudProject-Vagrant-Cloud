#!/bin/bash

set -e
cd playbooks

playbooks=("sync" "common" "boot-master" "boot-workers")

for playbook in "${playbooks[@]}"
do
	echo "Running $playbook..."
	ansible-playbook -i hosts.ini $playbook.yml
done
