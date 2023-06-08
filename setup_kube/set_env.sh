# Eseguire con "source"

if [[ $0 != "-bash" ]] ; then
   echo -e "This script must sourced on the bash"
   exit
fi

. ./set_vars.sh

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
      XHOSTS[$n]=${KHOSTS[$n]}
   done
fi

SSH="ssh -o StrictHostKeyChecking=no -i $KEYFILE -o User=$KUSER"
SCP="scp -o StrictHostKeyChecking=no -i $KEYFILE -o User=$KUSER"

all_nodes ()
{
    if [[ $1 == "" ]]; then
        echo "Usage: all_nodes <command-on-all-nodes>";
        return;
    fi;
    for n in $NODES;
    do
      $SSH ${XHOSTS[$n]} "$*";
    done
}

is_master() {
   local kargs="-l 'node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}'"
   if [[ $1 == "" ]] ; then
      echo "Usage: ${FUNCNAME[0]} <node> (one of $NODES)"
      return 2
   fi
   $SSH ${XHOSTS[$1]} "cd setup_kube; kubectl get nodes $kargs" >& /dev/null
}

get_master() {
   for n in $NODES ; do
      if is_master $n ; then
         echo $n
         return
      fi
   done
}

get_kconfig(){
   local master
   master_node=$(get_master)
   if [[ ! $master_node ]] ; then
      echo No cluster
      return
   fi
   master=${XHOSTS[$master_node]}
   $SCP $master:.kube/config $HOME/.kube/config.$master
   export KUBECONFIG=$HOME/.kube/config.$master
}

all_reset() {
   local master
   local nodes1
   local appendix
   if [[ $1 == "-q" ]] ; then
      appendix=" > /dev/null"
   fi
   master=$(get_master)
   if [[ ! $master ]] ; then
      echo No cluster
      master=none
   fi
   for n in $NODES ; do
      if [[ $n != $master ]] ; then
         nodes1="$nodes1 $n"
         $SSH ${XHOSTS[$n]} "cd setup_kube; sudo ./reset_kube.sh" $appendix &
      fi
   done
   wait
   echo -e "\n${BOLDGREEN}[set_env.sh] nodes$nodes1 in the cluster reset${NC}"
   if [[ $master != none ]] ; then
      $SSH ${XHOSTS[$master]} "cd setup_kube; sudo ./reset_kube.sh" $appendix
      echo -e "\n${BOLDGREEN}[set_env.sh] master $master reset ${NC}"
   fi
}

all_boot() {
   local master
   local nodes1
   local appendix

   unset master
   if ( [[ $1 == "" ]] || [[ $1 == "-q" ]] ) && [[ $THISNODE == none ]] ; then
      echo This host cannot be a k8s master
      echo "Usage: ${FUNCNAME[0]} [-q]             (on the future master)"
      echo "       ${FUNCNAME[0]} master-node [-q] (one of ${NODES})"
      return
   fi
   if [[ $1 != "" ]] && [[ $1 != "-q" ]] ; then
      for n in $NODES ; do
         if [[ $n == $1 ]] ; then
            master=$n
            break
         fi
      done
      if [[ ! $master ]] ; then
         echo -e "${FUNCNAME[0]} was just invoked as \"${FUNCNAME[0]} $1\" but $1 is not one of ${NODES}\n"
         return
      fi
   else
      master=$THISNODE
   fi
   if [[ $1 == "-q" ]] || [[ $2 == "-q" ]] ; then
      appendix=" > /dev/null"
   fi
   $SSH ${XHOSTS[$master]} "cd setup_kube; sudo ./boot_master.sh"
   retVal=$?
   if [ $retVal -ne 0 ]; then
      echo "Failed booting master, will not try to boot workers"
      return $retVal
   fi
   echo -e "\n${BOLDGREEN}[set_env.sh] master $master is up${NC}"
   if [[ $master != $THISNODE ]] ; then
      unset KUBECONFIG
      $SCP ${XHOSTS[$master]}:.kube/config $SETUPDIR/_kube/config.$master
      export KUBECONFIG=$SETUPDIR/_kube/config.$master
   fi
   return # debug
   for n in $NODES ; do
      if [[ $n != $master ]] ; then
         nodes1="$nodes1 $n"
         $SSH ${XHOSTS[$n]} "cd setup_kube; sudo ./boot_worker.sh" $appendix &
      fi
   done
   wait
   echo -e "\n${BOLDGREEN}[set_env.sh] workers nodes$nodes1 in the cluster are up${NC}"
   echo -e "${RED}local kubectl will connect to k8s API on master node $master${NC}"
}

echo -e "\n${RED}[set_env.sh]${NC} Defined bash functions all_boot(), all_nodes() and all_reset()\n"
