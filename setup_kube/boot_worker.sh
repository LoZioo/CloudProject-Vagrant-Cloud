#!/usr/bin/env bash

. ./set_vars.sh

echo -e "\n$RED[Worker $THISNODE] Restart kubelet$NC\n"

systemctl is-active kubelet --quiet || systemctl restart kubelet

echo -e "$RED[Worker $THISNODE] Remove old joincluster.sh script$NC\n"

rm /joincluster.sh /tmp/joincluster.sh

##sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kmaster.example.com:/joincluster.sh /joincluster.sh 2>/dev/null
#sshpass -p "kubeadmin" scp -o StrictHostKeyChecking=no kmaster:/joincluster.sh /joincluster.sh

#for n in $NODES ; do
#sshpass -p $KPASS rsync -Ptu --ignore-missing-args -e "ssh -o StrictHostKeyChecking=no" $KUSER@$n:/tmp/joincluster.sh /joincluster.sh
##sshpass -p "kubeadmin" scp -p -o StrictHostKeyChecking=no $KUSER@$n:/tmp/joincluster.sh /joincluster.sh ;
#done

echo -e "$RED[Worker] Get newest joincluster.sh script from other nodes$NC"

for srv in $KHOSTIPS ; do
if [[ $srv != $THISIP ]]; then
su - $KUSER -c "rsync -Ptu --ignore-missing-args -e 'ssh -i $(pwd)/$KEYFILE -o StrictHostKeyChecking=no' $KUSER@$srv:/tmp/joincluster.sh /tmp/joincluster.sh"
fi
done
cp -puf /tmp/joincluster.sh /joincluster.sh

# Join worker nodes to the Kubernetes cluster
echo -e "\n$RED[Worker $THISNODE] Joining node to Kubernetes Cluster$NC"

if [ ! -r /joincluster.sh ]; then
   echo -e "${RED}no file /joincluster.sh, exiting" 
   exit
fi
sed -e 's/$/--node-name '$THISNODE'/' -i /joincluster.sh
bash /joincluster.sh
if [ $? -ne 0 ] ; then
   echo -e "${RED}error running /joincluster.sh, exiting$NC\n"
   exit
fi

MASTER=$(cut -d' ' -f3 /joincluster.sh | cut -d':' -f1)

echo -e "${RED}Il worker $THISNODE si e\` unito al cluster$NC"
echo -e "${RED}kubeadm partito su $THISNODE con configurazione 'kubectl -n kube-system get configmaps kubeadm-config -o yaml'$NC"
echo -e "${RED}kubelet partito su $THISNODE con configurazioni /var/lib/kubelet/config.yaml /var/lib/kubelet/kubeadm-flags.env$NC"
echo
echo -e "${RED}Adesso, da qualunque nodo, opera da utente $KUSER (${BOLDRED}NON da super-user)$NC"
echo -e "${RED}e sull'host master (${KNAMES[$MASTER]}, con IP $MASTER) prova:$NC  kubectl get nodes"
