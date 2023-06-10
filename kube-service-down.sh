#!/bin/bash
# You can pass -d for a dry run.

source config.sh

set -e
cd infrastructure/build

for resource in "${KUBE_RESOURCES[@]}"
do
	echo "Deleting $resource..."
	if [ "$1" = "-d" ]; then
		echo "Dry run"
	else
		kubectl delete -f $resource.yml
	fi

	echo
done

echo Ok
