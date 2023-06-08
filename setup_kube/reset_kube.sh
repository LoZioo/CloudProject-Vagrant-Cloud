#!/usr/bin/env bash

reset_cri_daemon() {
   echo -e "${RED}$(basename $0): Stopping/starting $CONTAINER_RUNTIME$NC\n"
   systemctl stop $CONTAINER_RUNTIME
   # I due "rm -rf" seguenti risolvono MSGERR1 (v. definizioni), ma interviene poi MSGERR2
   #rm -rf /var/lib/containerd/*
   #rm -rf /var/run/containerd/*

   echo -e "${RED}$(basename $0): Removing /etc/cni/net.d"
   rm -rf /etc/cni/net.d
   # "rm -rf" sopra è necessario per un reset "completo"" di CNI, come dice "kubeadm reset":
   #    [reset] ... The reset process does not clean CNI configuration... remove /etc/cni/net.d
   # Ma a questo punto si deve rilanciare containerd/crio perche' (forse) il containerd/crio 
   # preesistente considera ancora il precedente stato CNI e non potra` quindi supportare 
   # il nuovo kubelet che partira`, che, infatti, dira` (da systemctl kubelet status):
   #    kubelet[18911]: E0603 08:45:27.530646   18911 kubelet.go:2344]
   #    "Container runtime network not ready" networkReady="NetworkReady=false reason:
   #    NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
   # Rimedio: containerd/crio va riavviato dopo "rm -rf /etc/cni/net.d", cioè dopo
   # l'invocazione di questa funzione, e prima che "kubeadm init" (script boot_master.sh) 
   # e boot_worker.sh (esplicitamente) avviino un nuovo kubelet
   #
   # Inoltre, presumibilmente, questa funzione, che spegne il container engine 
   # $CONTAINER_RUNTIME, dovrebbe essere invocata dopo "kubeadm reset", ma e` accaduto
   # che "kubeadm reset" andasse in stallo e riuscisse a terminare solo dopo 
   # avere spento il container engine...
}

. ./set_vars.sh

# Docker now (should be) unnecessary, maybe harmful
# see https://www.jetstack.io/blog/cri-migration/
echo -e "\n$RED[TASK 1] Stop container runtime (we do not expect docker) $NC"
#systemctl stop docker
#systemctl stop docker.socket

# we stop any "other" container runtime, in case it is on (e.g. if we just changed
# it); the current one should not be stopped until we delete /etc/cni/net.d

for cri in $CRI_RUNTIMES ; do
if [[ $cri != $CONTAINER_RUNTIME ]] ; then
   systemctl stop $cri
fi
done

if [[ ! -f /etc/crictl.yaml ]] || \
   ! { head -1 /etc/crictl.yaml | grep -q  "^# /etc/crictl.$CONTAINER_RUNTIME.yaml"; } ; then
cp /etc/crictl.$CONTAINER_RUNTIME.yaml /etc/crictl.yaml
fi

# Add sysctl settings
echo -e "\n$RED[TASK 2] Check sysctl settings$NC"

sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
echo "if three previous lines do not end in '... = 1', check sysctl setting in install_kube.sh"

# Disable swap
echo -e "\n$RED[TASK 3] Turn off SWAP$NC"
#sed -i '/swap/d' /etc/fstab
swapoff -a

# Reset kubernetes software

echo -e "\n$RED[TASK 4] Reset k8s, remove k8s config files, stop k8s programs$NC"

## v. https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down
## Per un tear-down ordinato, servirebbero, sul master, per ogni worker node:
#kubectl drain <node name> --delete-emptydir-data --force --ignore-daemonsets
#kubectl delete <node name>
## poi, su <node>, "kubeadm reset"
## e, alla fine, "kubeadm reset" sul master
## ma, per i nostri scopi di apprendimento, (forse?) basta un reset "hard", come segue

# "kubeadm reset" su un worker causa alcuni errori legati al pod Sandbox (che dovrebbe 
# stare su ogni nodo con kubelet, lo si puo` vedere con "sudo crictl pods")
# qui si cerca di "gestire" o spiegare questi errori... MSGERR1 e` raro, in effetti

MSGERR1="\n$RED[$THISNODE] Per l'errore: $NC${BOLDRED}Failed to remove containers: failed to stop running pod... \
StopPodSandbox from runtime service failed... rpc error: code = Unknown desc... failed to \
destroy network for sandbox... cni plugin not initialized... stopping the pod sandbox... \
cni plugin not initialized$NC"
URL1="https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/troubleshooting-cni-plugin-related-errors"
URL2='https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/troubleshooting-cni-plugin-related-errors/#failed-to-destroy-network-for-sandbox-error'
MSGERR1="$MSGERR1\n${RED}v.   $NC$IT$URL1$NC\n${RED}v.   $NC$IT$URL2$NC\n${RED}in breve, puoi provare: \n"
MSGERR1="$MSGERR1$NC     ${IT}cp -i containerd-net.conflist /etc/cni/net.d/10-containerd-net.conflist"
MSGERR1="$MSGERR1\n     systemctl restart containerd (?)\n${RED}poi rilancia questo script: $NC$IT$0$RED"
MSGERR1="$MSGERR1\n    oppure altro tentativo:${NC} ${IT}rm -rf /var/{lib,run}/$CONTAINER_RUNTIME$RED$NC"

MSGERR2="\n$RED[$THISNODE] Errore rilevato:${NC} ${BOLDRED}failed to stop running pod... \
StopPodSandbox from runtime service failed... rpc error: code = NotFound desc... \
an error occurred when try to find sandbox... stopping the pod sandbox$NC"
MSGERR2="$MSGERR2\n$NC${RED}Accade perché $NC${IT}kubeadm reset$NC$RED chiede a ${CONTAINER_RUNTIME},"
MSGERR2="${MSGERR2} e specificamente al sandbox pod, \nl'elenco dei pod, attraverso $NC${IT}crictl$NC$RED, ma questi sono già fermi. \n\
Ora, se $NC${IT}/etc/crictl.yaml$NC$RED pone $NC${IT}Debug: false$NC$RED, non succede niente, ma se il debug è \n\
attivato per $NC${IT}crictl$NC$RED, questo restituisce un errore (che logicamente non è tale) \n\
e si propaga, come abbiamo visto qui, a $NC${IT}kubeadm reset$NC"

reset_cri_daemon
# la funzione sopra spegne ìl container engine, v. codice per la ragione  

rm -f /tmp/kubeadm.err
kubeadm reset -f 2> /tmp/kubeadm.err
if [[ -s /tmp/kubeadm.err ]] ; then
echo -e "\n$RED[/tmp/kubeadm.err]${NC}" > /dev/stderr
ERRLINES=$(wc -l /tmp/kubeadm.err | cut -d' ' -f1)
if [[ $ERRLINES -lt 5 ]] ; then
   cat /tmp/kubeadm.err
else
   head -2 /tmp/kubeadm.err > /dev/stderr
   echo -e "$RED[...]${NC}" > /dev/stderr
   tail -n +3 /tmp/kubeadm.err | head -n -2 | $FGREP -m1 --color 'code = NotFound' > /dev/stderr &&
      echo -e "$RED[...]${NC}" > /dev/stderr
   tail -2 /tmp/kubeadm.err > /dev/stderr
fi
echo -e "${RED}[/tmp/kubeadm.err ended]${NC}" > /dev/stderr
fi

$FGREP -q "cni plugin not initialized" /tmp/kubeadm.err && KUBEADMERR=1
$FGREP -q "code = NotFound" /tmp/kubeadm.err && KUBEADMERR=2

if [[ $KUBEADMERR ]] ; then
MSGERR=MSGERR$KUBEADMERR
echo -e ${!MSGERR}
fi

## apparently "kubeadm reset" also stops the kubelet daemon, so following useless
#systemctl stop kubelet

## presumably, "kubeadm reset" needs some configuration files, to undo cleanly, so following
## "rm -rf" are useless, even harmful before I added "sleep 2", because "kubeadm reset"
## is slow to set in and without "sleep 2" would not find the configuration to remove!
#sleep 2
#echo -e "\n${RED}Removing k8s config files$NC"
#rm -rf /etc/kubernetes/*
#rm /etc/kubernetes/pki/ca.crt
# a volte si ritrova il precedente file...
#mkdir -p /etc/kubernetes/manifests
#rm -rf /var/lib/etcd

echo -e "${RED}" >& /dev/stdout
# sometimes an older kubeadm survives...
killall kubeadm >& /dev/stdout
# sometimes an older kubectl hangs...
killall kubectl >& /dev/stdout
echo -e "${NC}" >& /dev/stdout

# following important, otherwise on nodes with a stale config, kubectl will hang
rm -f ~/.kube/config

#reset_cri_daemon
# la funzione sopra spegne ìl container engine, v. commenti nel codice della
# funzione per capire perche' non la si invoca qui  

echo -e "\n$RED[TASK 5] Finalizing$NC"

rm -f /tmp/joincluster.sh /joincluster.sh
systemctl restart $CONTAINER_RUNTIME

lsof -i :10250 && echo -e "\n${BOLDRED}port 10250 busy, maybe should stop microk8s or other k8s implementation?$NC" && exit
pgrep -l kub && echo -e "${RED}WARNING: there are k8s processes$NC\n" || echo -e "${RED}OK: no k8s processes$NC\n"

echo -e "${RED}Ora esegui qui ./boot_master.sh oppure ./boot_worker.sh (deve esserci prima un master)$NC"
