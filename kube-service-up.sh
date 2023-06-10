#!/bin/bash
# You can pass -d for a dry run.

source config.sh

set -e
cd infrastructure
mkdir -p build

for resource in "${KUBE_RESOURCES[@]}"
do
	echo "Compiling $resource..."
	cat $resource.yml | sed "$KUBE_REGEXP" > build/$resource.yml

	echo "Creating $resource..."
	if [ "$1" = "-d" ]; then
		echo "Dry run"
	else
		kubectl apply -f build/$resource.yml
	fi

	echo
done

echo Ok
