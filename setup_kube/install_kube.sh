#!/usr/bin/env bash

. ./set_vars.sh

echo -e "$RED[TASK 1] Update /etc/hosts file$NC"

# Update /etc/hosts file

for N in ${NODES}; do
  HOSTIP=${KHOSTS[$N]//./\\.}
  NN="[[:space:]]+$N([[:space:]]+|$)"
  HOSTLINE="^$HOSTIP"
  if ! grep -E -q -e "$HOSTLINE$NN" /etc/hosts ; then
# if ! host $N 127.0.0.53 >/dev/null ; then
    printf "%s\t%s\t# inserted by %s\n" ${KHOSTS[$N]} $N $0 >> /etc/hosts
  else
    printf "${RED}%s (${KHOSTS[$N]}) in /etc/hosts${NC}\n" $N
#   printf "${RED}% at lines:${NC}\n"
#   grep -E -nT -e "$NN" /etc/hosts
  fi
done

echo -e "$RED[TASK 2] Installing utilities$NC"
apt-get clean
apt-get update
apt-get install -y ca-certificates apt-transport-https curl gnupg lsb-release rdate rsync rdate procps

# clocks must be correct
cat >/etc/cron.daily/rdate-hwclock.sh<<EOF
#!/bin/sh
rdate -s time.ien.it
hwclock --systohc
EOF
/etc/cron.daily/rdate-hwclock.sh

echo -e "${RED}Installing Docker now unnecessary\n$NC"

# echo -e "$RED[TASK 2] Docker container engine should be installed and enabled$NC"
# # Qui si presume lo sia, ma con il driver di default, quindi
# # si installa  il driver overlay2, raccomandato per kubernetes
# cat > /etc/docker/daemon.json <<EOF
# {
#   "exec-opts": ["native.cgroupdriver=systemd"],
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "100m"
#   },
#   "storage-driver": "overlay2"
# }
# EOF
# mkdir -p /etc/systemd/system/docker.service.d
# # Restart Docker (dopo la prima volta non dovrebbe servire)
# systemctl daemon-reload
# systemctl restart docker

# Con sysctl cambia in /proc/sys i setting necessari per
# consentire ai Pod sull'host di comunicare tra loro,
# almeno in certe condizioni (non so se ci riguardino, ma...)

# see https://www.jetstack.io/blog/cri-migration/

# Next necessary after Docker was abandoned by k8s
echo -e "$RED[TASK 3] Installing containerd$NC"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y containerd.io || \
  { echo -e "${RED} Could not install containerd, exiting$NC" ; exit; } 

sed -i -e "s+10.10.0.0/16+$POD_NETWORK_CIDR+" containerd-net.conflist

# Il .deb containerd.io installato qui sopra contiene runc, ma non i plugin CNI
# che sono in kubernetes-cni.deb (richiesto dagli altri pacchetti k8s)

# il pacchetto .deb containerd.io ha un problema nel suo /etc/containerd/config.toml 
# perche' disattiva il plugin cri (CRI e` l'interfaccia standard tra k8s e il container runtime)
#sed -i 's/^disabled_plugins *= *\["cri"\]/#disabled_plugins = \["cri"\]/' /etc/containerd/config.toml
# pero` disattivo la riga sopra perche' /etc/containerd/config.toml pare comunque insufficiente

# quindi la correzione sotto, per il config.toml nel .deb, è insufficiente
#
#if ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
#cat >>/etc/containerd/config.toml<<EOF
#[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#SystemdCgroup = true
# above because for cgroup kubeadm defaults to systemd which is recommended
#EOF
#fi

# Alla fine, quindi, genero /etc/containerd/config.toml di default e lo correggo:
containerd config default > /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/' -i /etc/containerd/config.toml
# DA VERIFICARE NEL TEMPO SE SUFFICIENTE
#sed -e 's/systemd_cgroup = false/systemd_cgroup = true/' -i /etc/containerd/config.toml
#La riga sopra parrebbe ragionevole, ma in effetti causa problemi!

echo -e "$RED[TASK 4] Install CRI-O container runtime$NC"

OS="x$(lsb_release -i | cut -f2)_$(lsb_release -r | cut -f2)"
VERSION=1.24
PATH1="devel:/kubic:/libcontainers:/stable"
echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] \
https://download.opensuse.org/repositories/${PATH1}/$OS/ /" \
> /etc/apt/sources.list.d/${PATH1///}.list

PATH2="devel:/kubic:/libcontainers:/stable:/cri-o:"
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] \
https://download.opensuse.org/repositories/$PATH2/$VERSION/$OS/ /" \
> /etc/apt/sources.list.d/${PATH2///}$VERSION.list

mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

apt-get install libseccomp cri-o cri-o-runc

echo -e "$RED[TASK 4] Installing container runtime monitor crictl$NC"

gen_crictl_conf() {
cat >/etc/crictl.$1.yaml<<EOF
# /etc/crictl.$1.yaml
runtime-endpoint: unix:///var/run/$1/$1.sock
image-endpoint: unix:///var/run/$1/$1.sock
timeout: 10
debug: false    # true causa errori (non gravi) in "kubeadm reset"
EOF
}

for cri in $CRI_RUNTIMES ; do
  gen_crictl_conf $cri
done

head -1 /etc/crictl.yaml | grep "^# $CONTAINER_RUNTIME"

echo -e "$RED[TASK 5] Add sysctl settings$NC"
if ! grep -q net.bridge.bridge-nf-call-ip6tables /etc/sysctl.d/kubernetes.conf; then
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
EOF
fi

if ! grep -q net.bridge.bridge-nf-call-iptables /etc/sysctl.d/kubernetes.conf; then
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-iptables = 1
EOF
fi

if ! grep -q net.ipv4.ip_forward /etc/sysctl.d/kubernetes.conf; then
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
EOF
fi

# ma i sysctl precedenti sono attivi solo se c'è il modulo br_netfilter
modprobe overlay
modprobe br_netfilter
# i modprobe servono all'installazione, poi, a ogni boot vale br_nf_kube.conf
cat >>/etc/modules-load.d/br_nf_kube.conf<<EOF
overlay
br_netfilter
EOF

sysctl --system
# precedente serve all'installazione, non al boot

# Add keys for k8s (from Google) and k8s sources list into the sources.list.d directory
echo -e "$RED[TASK 6] Add keys and the k8s sources list$NC"

# La chiave deve essere in formato binario e non testuale (si fa con gpg --dearmor)
# curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/kubernetes-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
| tee /etc/apt/sources.list.d/kubernetes.list
ls -ltr /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes
echo -e "$RED[TASK 7] Install Kubernetes kubeadm, kubelet and kubectl$NC"
apt-get update && apt-get install -y kubelet kubeadm kubectl || \
  { echo -e "${RED} Could not install k8s, exiting$NC" ; exit; }
# dovrebbe installare anche kubernetes-cni (per le reti virtuali)
apt-mark hold kubelet kubeadm kubectl kubernetes-cni
# above excludes k8s from upgrades, because special attention is needed
# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
kubeadm completion bash > /etc/bash_completion.d/kubeadm
kubectl completion bash > /etc/bash_completion.d/kubectl
crictl completion bash > /etc/bash_completion.d/crictl
# Install a k8s user (now unnecessary)
#echo -e "$RED[TASK 7] Install user $JUSER$NC"
#useradd -m $JUSER && (echo -e "kubeadmin\nkubeadmin" | passwd $JUSER) || echo "(this failure is ok)"

echo -e "$RED[TASK 8] Adding $KEYFILE.pub to authorized_keys$NC"
cat $KEYFILE.pub >> /home/$KUSER/.ssh/authorized_keys

echo -e "$RED[TASK 9] Install more utilities${NC}"
#apt-get install -y sshpass
# ho eliminato sshpass da boot_worker.sh

echo -e "${RED}Preparing to boot a cluster: reset_kube.sh${NC}"
./reset_kube.sh
