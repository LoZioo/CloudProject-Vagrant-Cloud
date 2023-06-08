#!/usr/bin/env bash

# v. https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html
# ma piu` sofisticato

if [[ $0 != -bash ]] ; then
   echo -e "You ran this script $(basename $0), but should have sourced it, to define its functions "
   exit
fi

#. ./aws_kcluster_info.sh

# questo script è autonomo, si potrebbe però usare la chiamata sopra e
# eliminare da questo la ricerca delle risorse esistenti
# e, se questo script fa prima il source di aws_kcluster_info.sh, successivo rigo inutile

. ./set_vars.sh

unset XHOSTS
declare -A XHOSTS

if [[ -f xhosts.conf ]] && [[ -s xhosts.conf ]] ; then
. xhosts.conf
else
echo -e "${BOLDRED}Empty or no xhosts.conf${NC}$RED, you'll probably want to run ${NC}${IT}create_nodes$NC"
fi

case "$1" in
-r)

unset VPCID RTIDS SUBNETIDS SGIDS IGIDS INSTIDS RTIDS1 SUBNETIDS1 SGIDS1 IGIDS1
unset KEY REGION RT_SUBNET_ASSOC RUN_NODES KRT_OUT

# Fingerprinting a private/public key without AWS CLI
#ssh-keygen -ef ssh_key.pem -m PEM | openssl rsa -RSAPublicKey_in -outform DER 2> /dev/null | openssl md5 -c | tr -d ' ' | cut -d '=' -f2
#ssh-keygen -f ssh_key.pem.pub -e -m PKCS8 | openssl pkey -pubin -outform DER | openssl md5 -c | tr -d ' ' |  cut -d '=' -f2

if [[ ! -f $KEYFILE ]] ; then
   echo -e "file della chiave privata $KEYFILE ${RED}non presente${NC}" > /dev/stderr
   { [[ $0 == -bash ]] && return || exit; }
else
   KEY=$(basename $KEYFILE .pem)
   echo -e "chiave AWS \"$KEY\""
fi

echo -e "\nDetermining/setting cluster parameters\n"

REGION=$(aws configure get region)
EC2_CONNECT_CIDR=$(curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | \
grep -B2 EC2_INSTANCE_CONNECT | grep -C1 $REGION | grep ip_prefix | tr -cd '0-9./')

echo "Current region is: $REGION"

VPCID=$(aws ec2 describe-vpcs --filters Name=tag-value,Values=kcluster \
   --query 'Vpcs[*].VpcId' --output text \
)
echo -e "found vpc $VPCID, set VPCID to $VPCID"

if [[ "x$VPCID" == "x" ]] ; then

VPCID=$(aws ec2 create-vpc --cidr-block $KHOSTS_NETWORK \
   --tag-specifications 'ResourceType=vpc,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-vpc}]' \
   --query 'Vpc.VpcId' --output text \
) && echo -e "created vpc $VPCID, set VPCID to $VPCID" || { echo  "Failed to create VPC"; { [[ $0 == -bash ]] && return || exit; }; }

fi

# nel determinare SUBNETID si usano 3 filtri (in AND per default), in effetti ne basterebbe uno...
# qui si adotta la programmazione difensiva;
# il filtro Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-subnet significa:
# trova un tag di "Key" qualunque (di fatto "esperimento") e "Value" kcluster e
# un tag di "Key" qualunque (di fatto "Name") e "Value" kcluster-subnet
SUBNETID=$(aws ec2 describe-subnets --filters Name="vpc-id",Values="$VPCID" \
      Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-subnet \
   --query 'Subnets[0].SubnetId' --output text
) && echo -e "found subnet $SUBNETID, set SUBNETID to $SUBNETID" || { echo  "Failed to determine subnet"; { [[ $0 == -bash ]] && return || exit; }; }

if [[ "x$SUBNETID" == "x" ]] || [[ $SUBNETID == None ]] ; then

SUBNETID=$(aws ec2 create-subnet --vpc-id $VPCID --cidr-block $KHOSTS_NETWORK \
   --tag-specifications 'ResourceType=subnet,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-subnet}]' \
   --query 'Subnet.SubnetId' --output text
) && echo "created $SUBNETID, set SUBNETID to $SUBNETID" || { echo  "Failed to create subnet" ; { [[ $0 == -bash ]] && return || exit; }; }

aws ec2 modify-subnet-attribute --subnet-id $SUBNETID --map-public-ip-on-launch || \
   { echo failed to modify subnet attribute map-public-ip-on-launch; { [[ $0 == -bash ]] && return || exit; }; }
fi


# nel determinare IGID si usano 3 filtri (in AND per default), in effetti basterebbe vpc-id...
# qui si adotta la programmazione difensiva;
IGID=$(aws ec2 describe-internet-gateways --filters Name="attachment.vpc-id",Values="$VPCID" \
            Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-igw \
         --query 'InternetGateways[0].InternetGatewayId' --output text
) && echo -e "found internet gateway $IGID, set IGID to $IGID" \
  || { echo  "Failed to determine Internet gateway Id IGID"; { [[ $0 == -bash ]] && return || exit; }; }

if [[ "x$IGID" == "x" ]] || [[ $IGID == None ]] ; then
IGID=$(aws ec2 create-internet-gateway \
   --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-igw}]' \
   --query 'InternetGateway.InternetGatewayId' --output text \
) && echo "created Internet gateway $IGID, set IGID to $IGID" || { echo  "Failed to create Internet gateway" ; { [[ $0 == -bash ]] && return || exit; }; } 

aws ec2 attach-internet-gateway --internet-gateway-id $IGID --vpc-id $VPCID \
&& echo "attached Internet gateway $IGID to $VPCID" \
|| { echo  "Failed to attach Internet gateway $IGID to $VPCID" ; { [[ $0 == -bash ]] && return || exit; }; } 
fi

# Ora occorre una Route Table per la subnet creata, la main r.t. (di default) NON ha rotta
#    per esterno, quindi:
#    o si aggiunge tale rotta alla main r.t. di $VPCID:
#        aws ec2 replace-route-table-association --association-id $MAINRT_ASSOC_ID --route-table-id $RTID
#    o si crea RT con i tag ad hoc (faremo questo)

# ci sono tre casi possibili qui, per le RT di VPCID
# 1. esistono RT con tag, senza associazioni: non dovrebbe capitare, ma le cancelliamo
#    e usciamo e diciamo di riprovare
# 2. non esiste RT con tag: va creata, dotata di rotta e associata e si prosegue
# 3. escluso (1), esiste una RT con tag e associazione con subnet (quindi non main), si procede
#    (dovremmo verificare che abbia la rotta di default, ma lo ignoriamo)

# caso (1), per ora lo ignoriamo
rt_case_1() {
   local KRT_OUT_1
   echo cleaning unassociated RTs/subnets
   KRT_OUT_1=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
      Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-rt \
      --query 'RouteTables[?Associations==`[]`].RouteTableId' --output text
   #  --query 'RouteTables[].[Associations[].[RouteTableAssociationId,RouteTableId],
   #                          Routes[].DestinationCidrBlock,Routes[].GatewayId] | [0]' \
   )  || { echo  "Failed in determining unassociated Route tables";
         { [[ $0 == -bash ]] && return || exit; }; }

   if [[ -n $KRT_OUT_1 ]] ; then
      for rt in $KRT_OUT_1 ; do
         echo -e "found route table $rt non associated to $SUBNETID, deleting both"
         CMD="aws ec2 delete-route-table --route-table-id $rt"
         echo $CMD
         $CMD
         CMD="aws ec2 delete-subnet --subnet-id $SUBNETID"
         echo $CMD
         $CMD
      done
      echo -e "relaunch this script ${BASH_SOURCE[0]}" 
      echo -e "if deleting $RTID or $SUBNETID failed, maybe instances must be deleted (or their networking fixed by hand)"
      return
   fi
}

# casi 2 e 3 per route table

KRT_OUT=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
   Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-rt \
   Name="association.subnet-id",Values="$SUBNETID" --output text
)  || { echo  "Failed in determining associated Route tables";
        { [[ $0 == -bash ]] && return || exit; }; }

RTID=$(echo "$KRT_OUT" | head -1 | cut -f3)
echo -e "found route table $RTID , set RTID to $RTID"

if [[ "x$RTID" == "x" ]] || [[ $RTID == None ]] ; then
# caso 2: crea RT con route di default e associala
   RTID=$(aws ec2 create-route-table --vpc-id $VPCID \
      --tag-specifications 'ResourceType=route-table,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-rt}]' \
      --query 'RouteTable.RouteTableId' --output text \
   ) && echo "Created route table $RTID, set RTID to $RTID" || \
     { echo  "Failed to create route table" ; { [[ $0 == -bash ]] && return || exit; }; }

   aws ec2 create-route --route-table-id $RTID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGID > /dev/null \
   && echo -e "created default (0.0.0.0/0) route to gateway $IGID for table $RTID" \
   || { echo failed to create route to gateway $IGID for table $RTID; { [[ $0 == -bash ]] && return || exit; }; }

   aws ec2 associate-route-table --route-table-id $RTID --subnet-id $SUBNETID > /dev/null \
   && echo associated route-table $RTID to $SUBNETID \
   || {
         echo failed to associate subnet $SUBNETID and route table $RTID;
         rt_case_1
         { [[ $0 == -bash ]] && return || exit; }; }
else
# caso 3: dovrebbe esserci già una RT adatta
   echo -ne "\tassociation: "
   echo "$KRT_OUT" | grep "ASSOCIATIONS[^T]" | cut -f4,5
   echo "$KRT_OUT" | grep ROUTES | cut -f1-3 | sed 's/ROUTES/\troute:/'
fi

# Checking association RT/SUBNET... useless

#RT_SUBNET_ASSOC=$(aws ec2 describe-route-tables --filters Name="route-table-id",Values="$RTID" \
#   Name="association.route-table-id",Values="$RTID" Name="association.subnet-id",Values="$SUBNETID" \
#   --query 'RouteTables[].Associations[?SubnetId==`'$SUBNETID'`]' --output text)
#[[ $RT_SUBNET_ASSOC ]] && echo -e "      $RTID associated to $SUBNETID" || \
#   {
#      echo -e "      $RTID ${RED}not associated to$NC $SUBNETID";
#      echo -e "      try: aws ec2 delete-subnet --subnet-id $SUBNETID";
#      { [[ $0 == -bash ]] && return || exit; };
#   }

# Following for main Route Table... Don't actually need it

#MAINRT_OUT=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" Name="association.main",Values="true" \
#   --query 'RouteTables[].[Associations[].[RouteTableAssociationId,RouteTableId] | [0],
#                           Routes[].DestinationCidrBlock,Routes[].GatewayId] | [0]'    --output text \
##  --query 'RouteTables[].Associations[].[RouteTableAssociationId,RouteTableId]' --output text
##  --query 'RouteTables[?Associations[?Main]].Associations[].[RouteTableAssociationId,RouteTableId]' --output text \
#)
#MAINRT_ID=$(echo "$MAINRT_OUT" | head -1 | cut -f2)
#MAINRT_ASSOC_ID=$(echo "$MAINRT_OUT" | head -1 | cut -f1)
#echo -e " main route table $MAINRT_ID , associated to $VPCID with $MAINRT_ASSOC_ID"
#NROUTES=$(echo "$MAINRT_OUT" | tail -n +3 | wc -w)
#echo -n "      routes: "
#for n in $(seq 1 $NROUTES) ; do
#MAINRT_ROUTE_n=$(echo "$MAINRT_OUT" | tail -n +2 | cut -f $n | tr '\n' ' ' | sed -e 's/ / via /' )
#echo -ne $MAINRT_ROUTE_n ", "
#done
#echo

SGID_OUT=$(aws ec2 describe-security-groups --filters Name=tag-value,Values=kcluster \
      Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-sg \
      --output text) \
|| { echo  "Failed to determine security group "; { [[ $0 == -bash ]] && return || exit; }; }

SGID=$(echo "$SGID_OUT" | grep SECURITYGROUPS | cut -f3)
echo -e "found security group $SGID, set SGID to ${SGID}\n\tthis host has IP ${RED}$MYPUBIP${NC}"

if [[ "x$SGID" == "x" ]] || [[ $SGID == None ]] ; then

SGID=$(aws ec2 create-security-group --group-name SSHAccess \
   --description "Security group for SSH access" \
   --vpc-id $VPCID \
   --tag-specifications 'ResourceType=security-group,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-sg}]' \
   --query 'GroupId' --output text \
) || { echo "Failed to create security group"; { [[ $0 == -bash ]] && return || exit; }; }

echo "created security group $SGID, set SGID to $SGID"

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --protocol tcp --port 22 --cidr $MYPUBIP/32 \
   --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=kcluster-client}]' > /dev/null \
&& echo -e "        opened sg $SGID to $MYPUBIP", port 22 \
|| echo  "Failed to open security group $SGID, port 22 to $MYPUBIP"

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --protocol tcp --port 22 --cidr $EC2_CONNECT_CIDR \
   --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=ec2-connect}]' > /dev/null \
&& echo -e "        opened sg $SGID to $EC2_CONNECT_CIDR", port 22 \
|| echo  "Failed to open security group $SGID, port 22 to $EC2_CONNECT_CIDR"

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --protocol tcp --port 22 --cidr $KHOSTS_NETWORK > /dev/null \
&& echo -e "        opened sg $SGID to $KHOSTS_NETWORK", port 22 \
|| echo  "Failed to open security group $SGID, port 22 to $KHOSTS_NETWORK"

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --ip-permissions IpProtocol=icmp,FromPort=-1,ToPort=-1,\
IpRanges=[{CidrIp=$MYPUBIP/32},{CidrIp=$KHOSTS_NETWORK}] > /dev/null \
&& echo -e "        opened sg $SGID to ping (icmp) from\n        \
        this host ($MYPUBIP) and $KHOSTS_NETWORK"\
|| echo  "Failed to open security group $SGID, port 22 to $KHOSTS_NETWORK"

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --protocol tcp --port 6443 --cidr $KHOSTS_NETWORK > /dev/null \
&& echo -e "        opened sg $SGID to $KHOSTS_NETWORK", port 6443 \
|| echo  "Failed to open security group ${SGID}, port 6443 to $KHOSTS_NETWORK"

SGID_OUT=$(aws ec2 describe-security-groups --filters Name=tag-value,Values=kcluster \
      Name=tag-value,Values=kcluster Name=tag-value,Values=kcluster-sg \
      --output text)

else
   echo -e "\tsecurity group is open to: "
   echo "$SGID_OUT" | grep '^IP' | sed -e 's/^IPP/\tIPP/' -e 's/^IPR/\t   IPR/'
fi

echo "$SGID_OUT" | grep -q -E -e "^IPRANGES[[:blank:]]$MYPUBIP" || \
echo -e "${BOLDRED}Warning:$NC Security group is not open to your IP $RED$MYPUBIP$NC"

echo "$SGID_OUT" | grep -q -E -e "^IPRANGES[[:blank:]]$KHOSTS_NETWORK" || \
echo -e "${BOLDRED}Warning:$NC Security group is not open to host cluster $RED$KHOSTS_NETWORK$NC"

echo "$SGID_OUT" | grep -q -E -e "^IPRANGES[[:blank:]]$EC2_CONNECT_CIDR" || \
echo -e "${BOLDRED}Warning:$NC Security group is not open to AWS EC2 connect service $RED$EC2_CONNECT_CIDR$NC"

echo -ne "\n${RED}Using:\tVPC$NC $VPCID${RED}, subnet $NC$SUBNETID${RED} \n"
echo -e  "\tsecurity group $NC$SGID${RED}, route table $NC$RTID${RED} \n\tinternet gateway $NC$IGID"

echo -e "\n${RED}You have re-read AWS environment vars$NC"
echo -e "\n${RED}Call this script as \". ${BASH_SOURCE[0]}\" to load AWS related functions$NC"
;;

*)

echo "VPCID=\"$VPCID\"  (vpc)"
echo "SUBNETID=\"$SUBNETID\"  (subnet)"
echo "IGID=\"$IGID\"  (internet gateway)"
echo "RTID=\"$RTID\"  (route table)"
echo "SGID=\"$SGID\"   (security group)"

if [[ x$VPCID == x ]] || [[ x$SUBNETID == x ]] || [[ xIGID == x ]] || [[ xIGID == x ]] || [[ xRTID == x ]] || [[ xSGID == x ]] ; then
echo -ne "\n${BOLDRED}Some variable above undefined, run:$NC  "
echo -e ". $IT${BASH_SOURCE[0]} -r$NC"
return
fi

echo XHOSTS[${!XHOSTS[@]}]=[${XHOSTS[@]}]

read_nodes() {
   > xhosts.tsv
   for N in $NODES ; do
      aws ec2 describe-instances \
         --filters Name=tag-value,Values=$N \
         --query 'Reservations[].Instances[?State.Name==`running`].[(Tags[?Value==`'$N'`].Value)[0],PrivateIpAddress,PublicIpAddress,InstanceId] | [] ' \
         --output text | tee -a xhosts.tsv
   done
   awk '{print "s/" $1 ":/" $3 ":/"}' xhosts.tsv > xhosts.sed
   awk '{print "XHOSTS[" $1 "]=" $3 }' xhosts.tsv > xhosts.conf
   XHOSTS=()
   . xhosts.conf
   echo rebuilt XHOSTS: ${XHOSTS[@]}
}

create_nodes() {
   for N in $NODES ; do
      aws ec2 run-instances \
         --image-id ami-09e67e426f25ce0d7  \
         --instance-type t2.medium \
         --key-name $KEY \
         --tag-specifications 'ResourceType=instance,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value='$N'}]' \
         --subnet-id $SUBNETID \
         --security-group-ids $SGID \
         --private-ip-address ${KHOSTS[$N]} \
         --user-data file://aws_1st_boot.sh | \
      grep InstanceId | sed -e 's/^ *"InstanceId": *"\(.*\)",/\1/'
   done
   read_nodes
}

find_nodes() {
   for N in $NODES ; do
      aws ec2 describe-instances \
         --filters Name=tag-value,Values=$N \
         --query 'Reservations[].Instances[?State.Name!=`terminated`].[(Tags[?Value==`'$N'`].Value)[0],PrivateIpAddress,PublicIpAddress,InstanceId,State.Name] | [] ' \
         --output text
   done
}

kssh() {
   [[ ${#XHOSTS[@]} != ${#KHOSTS[@]} ]] && read_nodes
   local host=${XHOSTS[$1]}
   shift
   ssh -o StrictHostKeyChecking=no -i $KEYFILE $KUSER@$host $*
}
complete -F _ssh kssh

kscp() {
   local scp_params
   if [[ ${#XHOSTS[@]} == 0 ]] || [[ ! -f xhosts.tsv ]] ; then
      echo run prep_nodes first
      return
   fi
   scp_params=$(echo $* | sed -f xhosts.sed)
   scp -o StrictHostKeyChecking=no -i $KEYFILE -o User=$KUSER $scp_params
}
complete -o nospace -F _scp kscp

prep_nodes() {
   read_nodes
   RUN_NODES0=$(cut -f 1 xhosts.tsv | tr '\n' ' ' | sed -e 's/^ //' -e 's/ $//')
   RUN_NODES=$(echo $RUN_NODES0 | xargs -n1 | sort -V | xargs)
   echo -e "Nodes on AWS EC2: $RUN_NODES"
   echo -e "Nodes declared in config.sh: $NODES"
   if [[ $RUN_NODES != $NODES ]] ; then
      echo -e "only $RUN_NODES are running, wait for all $NODES to be running"
      return
   fi
   for N in $NODES ; do
      echo -e "\npreparing $N (IP: ${XHOSTS[$N]})"
      if [[ ! ${XHOSTS[$N]} ]] ; then
         echo -e "node $N has no IP, failing" > /dev/stderr
         return
      fi
      scp -i $KEYFILE $KEYFILE $KUSER@${XHOSTS[$N]}:~/.ssh/id_rsa &&
         echo -e "${RED}you can:$NC kssh or kscp to node $N" ||
         echo -e "${RED}node $N ${BOLDRED} unreachable!$NC"
   done
}

echo
echo -e "You may now call, for your ${IT}nodes${NC} (i.e. AWS instances named: $IT$NODES$NC):"
echo -e "- ${IT}create_nodes$NC \n\
- ${IT}read_nodes$NC (find running AWS nodes and reset ${IT}xhosts.*${NC})\n\
- ${IT}find_nodes$NC (find ${BOLD}any$NC nodes in AWS, do not reset ${IT}xhosts.*$NC)\n\
- ${IT}prep_nodes$NC (to check nodes are ready and prepare calls to ${IT}kssh/kscp$NC)\n\
- ${IT}kssh$NC or ${IT}kscp$NC to a node in: ${IT}$NODES$NC"
echo -ne "\n${RED}to re-read AWS environment vars, source this script as:$NC "
echo -e ". $IT${BASH_SOURCE[0]} -r$NC"
echo -ne "${RED}to check/delete AWS environment vars:$NC "
echo -e "$IT./aws_kcluster_info$NC"

;;
esac
