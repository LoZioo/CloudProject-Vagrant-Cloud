#!/bin/bash

for image in $(ls -d */ | sed "s/\///g")
do
	./build-and-push-image.sh $image
done
