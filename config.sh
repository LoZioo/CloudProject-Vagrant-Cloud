#!/bin/bash

SECRET_KEY="../setup_kube/kube_key.pem"
USER="vagrant"

# IP addresses.
M_IP="192.168.1.71"
W1_IP="192.168.1.72"
W2_IP="192.168.1.73"

# Docker buildx settings.
BUILD_PLATFORMS="linux/amd64"
DOCKERHUB_USER="lozioo"

# Kubernetes cluster (see ./setup_kube/config.sh).
KHOSTS_NETWORK="192.168.1.0/24"

KHOSTS[m]=$M_IP
KHOSTS[w1]=$W1_IP
KHOSTS[w2]=$W2_IP

KUSER=$USER

# Kubernetes infrastructure.
KUBE_SERVICES=$(cd services; ls -d */ | sed "s/\///g")
KUBE_RESOURCES=("deployment" "service")
