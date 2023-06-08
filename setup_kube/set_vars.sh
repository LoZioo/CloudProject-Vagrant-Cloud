# Includere negli altri script con "source"

RED='\033[0;31m'
BOLDRED='\033[0;41;1m'
GREEN='\033[0;32m'
BOLDGREEN='\033[0;42;1m'
NC='\033[0m'
IT='\033[3m'
NOIT='\033[23m'
BIT='\033[0m\033[3m'
NCR='\033[0m\033[0;31m'
BOLD='\033[1m'

BASENAME="-bash"

if [[ $0 != "-bash" ]] ; then
BASENAME=$(basename $0)
fi

if [[ ("$BASENAME" != "upload_scripts.sh")  &&  ("$BASENAME" != "-bash")  && ( "$0" != ./aws_kcluster_* ) ]] ; then
if [ "$EUID" -ne 0 ] ; then
   echo -e "${BOLDRED}Please run as root$NC"
   exit
fi
fi

if [ "$BASENAME" = "upload_scripts.sh" ] ; then
if [ "$EUID" -eq 0 ] ; then
   echo -e "${BOLDRED}Please do not run as root$NC"
   exit
fi
fi

if [ "$0" = "-bash" ] ; then
   echo -e "\n${RED}[$(basename ${BASH_SOURCE[0]})]${NC} sourced on the bash"
fi

unset KHOSTS
declare -A KHOSTS

CRI_RUNTIMES="containerd crio"

. ./config.sh

NODES0="${!KHOSTS[@]}"
NODES=$(echo $NODES0 | xargs -n1 | sort -V | xargs)
# sort -V mette (p. es.) s9 prima di s10
KHOSTIPS0="${KHOSTS[@]}"
KHOSTIPS=$(echo $KHOSTIPS0 | xargs -n1 | sort -V | xargs)

# KNAMES is KHOSTS inverted
unset KNAMES
unset KINDEX
declare -A KNAMES
declare -A KINDEX

build_names_indexes() {
   local i
   i=0
   for N in ${NODES}; do
      IPN=${KHOSTS[$N]}
      KNAMES[$IPN]=$N
      KINDEX[$N]=$i
      let i+=1
   done
}

build_names_indexes

UNIXNAME=$( uname -s )
if [[ "$UNIXNAME" == @(Linux|GNU|GNU/*) ]]; then
MYIPS=$(hostname -I)
elif [[ "$UNIXNAME" =~ "MINGW" ]]; then
MYIPS=$(ipconfig //all | grep -B4 'Default Gateway.*: .' | head -1 | cut -d':' -f2 | tr -dc 0-9.)
else
MYIPS=$(for name in $(/sbin/ifconfig -l) ; do \
   /sbin/ifconfig $name | awk -v name=$name '/inet / {printf "%s ", $2; }'; \
done)
fi

THISNODE=none
THISIP=none
THISINDEX=none
for N in ${NODES}; do
   IPN=${KHOSTS[$N]}
   INDXN=${KINDEX[$N]}
   for A in $MYIPS; do
      if [[ "$IPN" == "$A" ]]; then
         THISNODE=$N
         THISIP=$IPN
         THISINDEX=$INDXN
         break 2
      fi
   done
done

if [[ $OSTYPE == 'darwin'* ]]; then
EGREP="ggrep -E "
FGREP="ggrep -F "
GREP="grep"
else
EGREP="egrep"
FGREP="fgrep"
GREP="grep"
fi

# su ogni host, troviamo l'IP dell'host stesso
#THISIP=$(grep ${THISHOST} /etc/hosts | grep -v 127.0. | cut -f1 -d' ')

SETUPDIR=$(pwd)
if [[ "$UNIXNAME" =~ "MINGW" ]]; then
LOCALIP=$MYIPS
else
LOCALNETINTFC=$(ip route | $FGREP default | cut -d' ' -f5)
LOCALIP=$(ip addr show dev $LOCALNETINTFC | $EGREP '^[[:blank:]]*inet ' | tr -s ' ' | cut -d' ' -f 3)
LOCALIP=${LOCALIP/\/[0-9]*/}
fi
MYPUBIP=$(curl -s https://ipinfo.io/ip)

echo -ne "\n${RED}[$(basename ${BASH_SOURCE[0]})]${NC} "

if [[ "$THISNODE" == "none" ]] ; then
   printf "Questo cliente ($(hostname) - $LOCALIP - $MYPUBIP) non e\` destinato a essere un nodo del cluster composto da:\n[%s]/[%s]\ne definito in ./config.sh)\n" "$NODES" "$KHOSTIPS"
else
   printf "Questo host e\` il nodo %s (IP %s) del cluster definito in $SETUPDIR/config.sh\n" "$THISNODE" "$THISIP"
fi

if [[ $THISNODE != none ]] ; then
   KCOLOR=34
   let KCOLOR+=$THISINDEX
   RED="\033[0;"$KCOLOR"m"
fi

echo -e "\n${RED}[$(basename ${BASH_SOURCE[0]})]${NC} Variabili lette\n"
