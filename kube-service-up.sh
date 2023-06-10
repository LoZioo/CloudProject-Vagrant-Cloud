#!/bin/bash
# You can pass -d for a dry run.

source config.sh

set -e
cd infrastructure

for service in "${KUBE_SERVICES[@]}"
do
	for resource in "${KUBE_RESOURCES[@]}"
	do
		full_name="$service-$resource"

		echo "Creating $full_name..."
		if [ "$1" = "-d" ]; then
			echo "Dry run"
		else
			kubectl apply -f $full_name.yml
		fi

		echo
	done
done

echo Ok
