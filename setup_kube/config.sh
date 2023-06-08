### VARIABILI DA CONFIGURARE                         ###
### ATTENZIONE, in "V=DEF" NO SPAZI PRIMA E DOPO "=" ###

# Loading from global config script.
source ../config.sh

# KHOSTS_NETWORK="192.168.0.0/24"

# nomi con cui sono noti in k8s gli host del cluster e loro IP nel cluster
# i nomi non devono essere necessariamente quelli ufficiali
# KHOSTS[m]="192.168.0.11"
# KHOSTS[w1]="192.168.0.12"
# KHOSTS[w2]="192.168.0.13"

# KUSER="vagrant"
# si presume su ognuno degli host del cluster vi sia l'utente $KUSER,
# con home directory con lo stesso nome, che utilizzera` k8s e che,
# $KUSER di ciascun host abbia accesso ssh con chiave agli altri host e
# che dal cliente, rsync permetta di inviare file agli host (v. upload_scripts.sh)

KEYFILE="kube_key.pem"
#KEYFILE=~/.ssh/id_rsa
# to create a keyfile (in this dir) without passphrase and with comment "k8s":
# ssh-keygen -P "" -C "k8s"" -f $KEYFILE

POD_NETWORK_CIDR="10.10.0.0/16"
# blocco di IP allocato per la rete dei Pod

SERVICE_CIDR="172.96.0.0/16"
# blocco CIDR allocato per gli IP "virtuali" dei servizi

CONTAINER_RUNTIME="containerd"
#CONTAINER_RUNTIME="crio"

### FINE VARIABILI DA CONFIGURARE                   ###
