#!/usr/bin/env bash

. ./set_vars.sh

# Initialize Kubernetes
echo -e "\n$RED[Master] Initialize Kubernetes Cluster and kubelet$NC"

systemctl restart $CONTAINER_RUNTIME
# precedente non dovrebbe servire dopo reset_kube.sh

#kubeadm config images pull
KADMOPTS="--node-name $THISNODE"
KADMOPTS="$KADMOPTS --apiserver-advertise-address=$THISIP"
KADMOPTS="$KADMOPTS --pod-network-cidr=$POD_NETWORK_CIDR"
KADMOPTS="$KADMOPTS --service-cidr=$SERVICE_CIDR"
rm -f /tmp/kadmfail
echo executing kubeadm init $KADMOPTS
(kubeadm init $KADMOPTS 2>&1 || touch /tmp/kadmfail) | tee -a /root/kubeinit.log
# kubeadm inizializza il control-plane e (importante!) genera la configurazione
# (in /etc/kubernetes/kubelet.conf) per il daemon kubelet che poi avvia
if [ -f /tmp/kadmfail ] ; then
   echo -e "\n${RED}Failed to start kubeadm (port 10250, etc. in use? some kubelet running?)$NC"
   lsof -i :10250 | tail -1
   echo -e "${RED}check ${BOLDRED}/root/kubeinit.log$NC${RED} ... exiting$NC"
   exit 2
fi

echo -e "\n$RED[Master] Will now carry out the above instructions for you$NC"

# Copy Kube admin config
echo -e "\n$RED[Master] Copy kube admin config to common user's .kube directory$NC"
mkdir -p /home/$KUSER/.kube
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /home/$KUSER/.kube/config
cp /etc/kubernetes/admin.conf /root/.kube/config
chown -R $KUSER:$KUSER /home/$KUSER/.kube

# Generate Cluster join command
echo -e "\n$RED[Master] Generate and save cluster join command to /joincluster.sh$NC"
kubeadm token create --print-join-command > /joincluster.sh
echo cat /joincluster.sh
cat /joincluster.sh

# NB: il token ha una scadenza e va rigenerato se il master diventa "vecchio"
cp /joincluster.sh /tmp
chmod a+r /tmp/joincluster.sh

# Deploy (SDN) network (can also be done after nodes have joined, until then nodes will be NotReady)
echo -e "\n$RED[Master] Deploy Calico network (can be done after nodes have joined," 
echo -e "   until then nodes will be NotReady)$NC"

#su - $KUSER -c "kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml"
# precedente prende il manifest di calico dalla rete
# ultimo manifest funzionante: v. 3.23, scaricare con:
#wget https://docs.projectcalico.org/v3.23/manifests/calico.yaml
# ultima versione sempre:
#wget https://docs.projectcalico.org/manifests/calico.yaml

sed -e "/ *- name: CALICO_IPV4POOL_CIDR/ {
N;s|\([[:space:]]*value:[[:space:]]*\)\"\([0-9.]*\/[[:digit:]][[:digit:]]\)\"|\1\"$POD_NETWORK_CIDR\"|
}" -e 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/' \
-e "s+#   value: \"$POD_NETWORK_CIDR\"+  value: \"$POD_NETWORK_CIDR\"+" \
calico.yaml > calico-${POD_NETWORK_CIDR/\//_}.yaml
# Nello yaml ottenuto via sed il numero di spazi e` fondamentale!

chown $KUSER:$KUSER calico-${POD_NETWORK_CIDR/\//_}.yaml

#su - $KUSER -c "kubectl apply -f $SETUPDIR/calico-${POD_NETWORK_CIDR/\//_}.yaml"
# may run as root, because now kubectl has config file unser root
kubectl apply -f $SETUPDIR/calico-${POD_NETWORK_CIDR/\//_}.yaml

#su - $KUSER -c "kubectl apply -f $SETUPDIR/calico.yaml"
#su - $KUSER -c "kubectl apply -f $SETUPDIR/flannel.yml"

echo -e "$RED[Master $THISNODE] k8s cluster up, Rete dei nodi $KHOSTS_NETWORK$NC"
echo -e "$RED[Master] Rete dei POD:$NC ${POD_NETWORK_CIDR}," "${RED}Rete dei servizi:$NC ${SERVICE_CIDR}\n"
echo -e "$RED[Master] Adesso opera come user \"$KUSER\" (${BOLDRED}NON da super-user$NC)"
echo -e "$RED         su questo host, e prova:$NC kubectl get nodes\n"
echo -e "$RED[Master] Inoltre, entra come root sui worker nodes, ${NC}cd $(pwd)$RED, poi segui !README$NC\n"
