#!/usr/bin/env bash

#CONFIGF=/etc/kubernetes/admin.conf
#per leggere precedente file serve sudo

CONFIGF=$HOME/.kube/config
CONFIGFNEW=$HOME/.kube/config.3
FILES3="ca.crt client.crt client.key"
KUBE_CONF_DIR=$HOME/.kube
mkdir -p $KUBE_CONF_DIR

if [[ $1 != create ]] && [[ $1 != clean ]] ; then
    echo "Usage: $0 create|clean"
    echo "Purpose:  assuming $CONFIGF is a valid configuration file, create"
    echo "          a valid equivalent configuration file $CONFIGF, which"
    echo "          has no explicit certificate or key data, but refers to three "
    echo "          certificate/key files ca.crt, client.crt, client.key; these will"
    echo "          also be created in $KUBE_CONF_DIR"
    exit
fi

if [[ ! -f $CONFIGF ]] ; then
    echo "$CONFIGF absent, cannot run, maybe change CONFIGF?"
    exit
fi

if [[ $1 == clean ]] ; then
for f in $FILES3 ; do
    rm -f $KUBE_CONF_DIR/$f
done
rm -f $CONFIGFNEW
ls $KUBE_CONF_DIR
exit
fi

echo -e "extracting certs/key and creating $FILES3 in $KUBE_CONF_DIR \n"

KEY=certificate-authority-data ; grep $KEY $CONFIGF | sed -e 's/\s*'$KEY':\s*//' | base64 -d > $KUBE_CONF_DIR/ca.crt
echo -n 'fatto: '; ls $KUBE_CONF_DIR/ca.crt
KEY=client-certificate-data ; grep $KEY $CONFIGF | sed -e 's/\s*'$KEY':\s*//' | base64 -d > $KUBE_CONF_DIR/client.crt
echo -n 'fatto: '; ls $KUBE_CONF_DIR/client.crt
KEY=client-key-data ; grep $KEY $CONFIGF | sed -e 's/\s*'$KEY':\s*//' | base64 -d > $KUBE_CONF_DIR/client.key
echo -n 'fatto: '; ls  $KUBE_CONF_DIR/client.key

# Oppure (ma presuppone che k8s abbia gia` una configurazione o "kubectl config view --minify" non funzionerebbe)

#kubectl config view --minify --raw --output 'jsonpath={..user.client-certificate-data}' | base64 -d > $KUBE_CONF_DIR/client.crt
#kubectl config view --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' | base64 -d > $KUBE_CONF_DIR/ca.crt
#kubectl config view --minify --raw --output 'jsonpath={..user.client-key-data}' | base64 -d > $KUBE_CONF_DIR/client.key

echo -e "\nwriting $CONFIGFNEW\n"

# Per kubectl config view  basta che esista ~/.kube/config
kubectl config view  --output yaml |\
sed -e 's=certificate-authority-data: DATA+OMITTED=certificate-authority: '$KUBE_CONF_DIR'/ca.crt=' \
    -e 's=client-certificate-data: REDACTED=client-certificate: '$KUBE_CONF_DIR'/client.crt=' \
    -e 's=client-key-data: REDACTED=client-key: '$KUBE_CONF_DIR'/client.key=' > $CONFIGFNEW

echo "Ora puoi usare:  kubectl --kubeconfig $CONFIGFNEW ... 
in cui dovrebbero esserci gia' le righe:

- cluster:
    certificate-authority: $KUBE_CONF_DIR/ca.crt
- name: kubernetes-admin
    user:
     client-certificate: $KUBE_CONF_DIR/client.crt
     client-key: $KUBE_CONF_DIR/client.key
"
