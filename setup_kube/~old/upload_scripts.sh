#!/usr/bin/env bash

if [[ $1 == -h ]] ; then
   echo "Usage: $0 [-n|--dry-run|-h]"
   exit
fi

. ./set_vars.sh

FILES="!README* *.sh *.yaml *.pem *.pub"

ls _* >& /dev/null && FILES="$FILES _*"
ls *.conflist >& /dev/null && FILES="$FILES *.conflist"
ls *.toml >& /dev/null && FILES="$FILES *.toml"
ls *.yml >& /dev/null && FILES="$FILES *.yml"
ls *.json >& /dev/null && FILES="$FILES *.json"

unset XHOSTIPS
if [[ -f xhosts.conf ]] && [[ -s xhosts.conf ]] ; then
   unset XHOSTS
   declare -A XHOSTS
   . xhosts.conf
   for n in $NODES ; do
      XHOSTIPS="$XHOSTIPS ${XHOSTS[$n]}"
   done
else
   for n in $NODES ; do
      ${XHOSTS[$n]}=${KHOSTS[$n]}
   done
fi

SSH="ssh -o StrictHostKeyChecking=no -i $KEYFILE -o User=$KUSER"

if [[ x$1 == x-n  || x$1 == x--dry-run ]] ; then
   echo -e "\n${BOLDRED}DRY-RUN$NC"
fi

echo -e "\n${RED}Upload degli script sugli host $BOLDRED$NODES$RED con$NC"
if [[ $XHOSTIPS != "" ]] ; then
echo -e "${RED}IP esterni $BOLDRED$XHOSTIPS$RED e "
fi
echo -e "${RED}IP nel cluster $BOLDRED$KHOSTIPS$NC"
echo -e "${RED}(futuri master e worker k8s)$NC"

for n in $NODES ; do
if [[ $XHOSTIPS != "" ]] ; then
   host_ip=${XHOSTS[$n]}
else
   host_ip=${KHOSTS[$n]}
fi
ping -c 1 -W 1 $host_ip &> /dev/null && echo -e "\nhost $host_ip ($n) reachable" \
|| { echo -e "${BOLDRED}host $host_ip unreachable$NC"; exit; }
if [[ $host_ip != $THISIP ]] ; then
   echo -e "${RED}>>> $host_ip ($n) >>>$NC"
   rsync $1 -Ptu -e "ssh -o StrictHostKeyChecking=no -i $KEYFILE -o User=$KUSER " $FILES $host_ip:$(basename $PWD)/ ;
fi
done

echo -e "\n${RED}Su ognuno degli host $BOLDRED$NODES$RED con$NC"
if [[ $XHOSTIPS != "" ]] ; then
echo -e "${RED}IP esterni $BOLDRED$XHOSTIPS$RED e "
fi
echo -e "${RED}IP nel cluster $BOLDRED$KHOSTIPS$NC"
echo -ne "${RED}gli script vi si trovano in $NC"
echo -e "${BOLDRED}/home/$KUSER/$(basename $PWD)$NC$RED"
echo -e "(si presume ${BOLDRED}$KUSER$RED (\$KUSER in config.sh) sia un utente su ogni host e che "
echo -e "${BOLDRED}$KEYFILE${RED} (\$KEYFILE in config.sh) contenga la chiave privata di ciascun host$NC"
