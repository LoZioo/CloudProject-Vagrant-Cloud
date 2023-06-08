#!/usr/bin/env bash

usage() {
   echo "Usage: [source] $0 [-s|-d|-h|-c|-D|-v|-V]"
   echo "   -t: veloce, basato solo su tag esperimento=kcluster"
   echo "   -s: usa ricerca semplice delle risorse"
   echo "   -d: ricerca semplice e mostra comandi per cancellare risorse"
   echo "   -c: usa ricerca piu\` complessa (non necessariamente migliore)"
   echo "   -D: effetto (ipotetico) di -c e -d insieme"
   echo "   -v: -s e mostra variabili per AWS"
   echo "   -V: -c e mostra variabili per AWS"
}

if [[ x$1 != x ]] && [[ $1 != -t ]] && [[ $1 != -s ]] && [[ $1 != -d ]] && [[ $1 != -v ]] \
   && [[ $1 != -c ]] && [[ $1 != -D ]] && [[ $1 != -V ]] ; then
   echo "Trova risorse AWS correlate con l'esperimento kcluster"
   usage
   if [[ $0 == "-bash" ]] ; then
      return
   else
      exit
   fi
fi

export AWS_PAGER=""
cd ..
. set_vars.sh
cd - > /dev/null
unset VPCID RTIDS SUBNETIDS SGIDS IGIDS KEYIDS INSTIDS RTIDS1 SUBNETIDS1 SGIDS1 IGIDS1 INSTIDS1

# NB: il filtro sotto significa: trova un tag che ha "Key" qualunque (di fatto
# "esperimento") e "Value" kcluster

if [[ $1 != -t ]] && [[ x$1 != x ]] ; then
VPCID=$(aws ec2 describe-vpcs --filters Name=tag-value,Values=kcluster \
   --query 'Vpcs[*].VpcId' --output text \
)
echo -e "\n${RED}VPC esistenti con tag di ${NC}${IT}Value:kcluster${NOIT}${RED} (da ${NC}${IT}describe-vpcs${NOIT}${RED}): ${NC}"
echo -e "\e[1m$VPCID\e[21m$NC"
fi

only_tags() {
   echo -e "${RED}Risorse AWS con tag di ${NC}${IT}Value:kcluster$NC"

   AWSKRES=$(aws ec2 describe-tags --filters Name=tag-value,Values=kcluster \
      --query 'Tags[*].{Type:ResourceType,Id:ResourceId}' --output text)
   echo "$AWSKRES"
   SGIDS=$(echo "$AWSKRES" | grep security-group | cut -f 1)
   IGIDS=$(echo "$AWSKRES" | grep internet-gateway | cut -f 1)
   RTIDS=$(echo "$AWSKRES" | grep route-table | cut -f 1)
   SUBNETIDS=$(echo "$AWSKRES" | grep subnet | cut -f 1)
   VPCID=$(echo "$AWSKRES" | grep vpc | cut -f 1)
   KEYIDS=$(echo "$AWSKRES" | grep key-pair | cut -f 1)
   INSTIDS=$(echo "$AWSKRES" | grep instance | cut -f 1)
   [[ -s xhosts.tsv ]] && INSTIDS=$(cut -f4 xhosts.tsv | tr '\n' ' ')
}

# simple() cerca con describe-XXX le risorse XXX correlate alla VPC (con o senza tag kcluster)
simple() {
   [[ ! $VPCID ]] && return
   echo -ne "\n${RED}Risorse EC2/VPC AWS ${BIT}xxx${NCR} da ${BIT}describe-xxx${NCR} nella vpc $BIT$VPCID$NCR"
   echo -e  " (escluse RT main e SG default)$NC"

   RTIDS=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
      --query 'RouteTables[?!Associations].RouteTableId' --output text)
   RTIDS="$RTIDS $(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
      --query 'RouteTables[?Associations[?!Main]].RouteTableId' --output text)"
   [[ $RTIDS ]] && echo  "     route tables" $'\t' $RTIDS

   IGIDS=$(aws ec2 describe-internet-gateways --filters Name="attachment.vpc-id",Values="$VPCID" \
      --query 'InternetGateways[].InternetGatewayId' --output text)
   [[ $IGIDS ]] && echo "internet gateways" $'\t' $IGIDS

   SGIDS=$(aws ec2 describe-security-groups --filters Name="vpc-id",Values="$VPCID" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
   [[ $SGIDS ]] && echo "  security groups" $'\t' $SGIDS

   SUBNETIDS=$(aws ec2 describe-subnets --filters Name="vpc-id",Values="$VPCID" \
      --query 'Subnets[].SubnetId' --output text)
   [[ $SUBNETIDS ]] && echo "          subnets" $'\t' $SUBNETIDS

   KEYIDS=$(aws ec2 describe-key-pairs --filters Name=tag-value,Values=kcluster \
               --query 'KeyPairs[].KeyPairId' --output text)
   [[ $KEYIDS ]] && echo "        key pairs" $'\t' $KEYIDS

   INSTIDS=$(aws ec2 describe-instances --filters Name="vpc-id",Values="$VPCID" \
      Name="instance-state-name",Values="running" \
      --query 'Reservations[].Instances[].InstanceId' --output text)
   [[ $INSTIDS ]] && echo "        instances" $'\t' $INSTIDS
}

# Next function is not particularly useful, but maybe faster than simple()!
more_complex() {
   echo -e "\n${RED}Risorse AWS da ${BIT}describe-tags${NCB} con tag di ${BIT}Value:kcluster$NC"

   AWSKRES=$(aws ec2 describe-tags --filters Name=tag-value,Values=kcluster \
      --query 'Tags[*].{Type:ResourceType,Id:ResourceId}' --output text)
   echo "$AWSKRES"
   SGIDS=$(echo "$AWSKRES" | grep security-group | cut -f 1)
   IGIDS=$(echo "$AWSKRES" | grep internet-gateway | cut -f 1)
   RTIDS=$(echo "$AWSKRES" | grep route-table | cut -f 1)
   KEYIDS=$(echo "$AWSKRES" | grep key-pair | cut -f 1)
   SUBNETIDS=$(echo "$AWSKRES" | grep subnet | cut -f 1)
#  INSTIDS=$(echo "$AWSKRES" | grep instance | cut -f 1)
   #VPCID=$(echo "$AWSKRES" | grep vpc | cut -f 1)
   # VPCID determinata in altro modo prima
   [[ ! $VPCID ]] && return

   # ora determiniamo risorse nella VPC, senza il tag kcluster
   # NB: non key-pairs, che sono associate alle VPC (ma solo alle regioni)

   echo -e "\n${RED}Determining main Route table and default security group$NC"
   RT_MAIN=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
      --query 'RouteTables[?Associations[?Main]].RouteTableId' --output text)

   SG_DEFAULT=$(aws ec2 describe-security-groups --filters Name="vpc-id",Values="$VPCID" \
      Name="group-name",Values="default" --query 'SecurityGroups[*].GroupId' --output text)

#  echo -e "\n${RED}Risorse EC2/VPC AWS da ${BIT}describe-...${NCR} nella $VPCID, ma senza il tag ${BOLDRED}Name:esperimento, Value:kcluster$NC: "
#  SELECTOR='?!not_null(Tags[?Key == `esperimento`].Value)'

   echo -e "\n${RED}Risorse EC2/VPC AWS ${BIT}xxx${NCR} da ${BIT}describe-xxx${NCR} nella $BIT$VPCID$NCR, ma "
   echo -ne "senza tag di ${BIT}Value:kcluster$NCR"
   echo -e ", inclusi (se esistenti) \nSG default${BIT} ${SG_DEFAULT} ${NCR}e main RT${BIT} ${RT_MAIN}$NC\n"
   SELECTOR='?!not_null(Tags[?Value == `kcluster`])'

   RTIDS1=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$VPCID" \
      --query "RouteTables[$SELECTOR].RouteTableId" --output text)
   IGIDS1=$(aws ec2 describe-internet-gateways --filters Name="attachment.vpc-id",Values="$VPCID" \
      --query "InternetGateways[$SELECTOR].InternetGatewayId" --output text)
   SGIDS1=$(aws ec2 describe-security-groups --filters Name="vpc-id",Values="$VPCID" \
      --query "SecurityGroups[$SELECTOR].GroupId" --output text)
   SUBNETIDS1=$(aws ec2 describe-subnets --filters Name="vpc-id",Values="$VPCID" \
      --query "Subnets[$SELECTOR].SubnetId" --output text)

   # per le running instances si fa come nel caso simple()
   INSTIDS=$(aws ec2 describe-instances --filters Name="vpc-id",Values="$VPCID" \
      Name="instance-state-name",Values="running" \
      --query 'Reservations[].Instances[].InstanceId' --output text)

   [[ $RTIDS1 ]] && echo "     route tables" $'\t'  $RTIDS1
   [[ $IGIDS1 ]] && echo "internet gateways" $'\t'  $IGIDS1
   [[ $SGIDS1 ]] && echo "  security groups" $'\t' $SGIDS1
   [[ $SUBNETIDS1 ]] && echo "          subnets" $'\t' $SUBNETIDS1
   [[ $INSTIDS ]] && echo "        instances" $'\t' $INSTIDS
}

case $1 in 
   -c | -D | -V ) more_complex ;;
   -s ) simple ;;
   * ) only_tags ;;
esac

if [[ $1 == -d ]] && [[ ! $VPCID ]] ; then
   echo -e "${NC}Nothing to delete (no VPC found)$NC"
   if [[ $0 == -bash ]] ; then
      return
   else
      exit
   fi
fi

if [[ $1 == -d ]] || [[ $1 == -D ]] || [[ $1 == -t ]] || [[ x$1 == x ]] ; then
echo -ne "\n${RED}Per cancellare le risorse elencate sopra \n"
echo -e "(escluse, se presenti e qui di seguito determinate, "
echo -e "RT main \"${BIT}$RT_MAIN${NCR}\" e SG default \"${BIT}$SG_DEFAULT${NCR}\"):$NC"
if [[ x$INSTIDS != x ]] ; then echo "  aws ec2 terminate-instances --instance-ids " $INSTIDS "--output text ; sleep 25" ; fi
for kid in $KEYIDS ; do echo "  aws ec2 delete-key-pair --key-pair-id " $kid ; done
for sid in $SUBNETIDS $SUBNETIDS1 ; do echo "  aws ec2 delete-subnet --subnet-id " $sid ; done
for sg in $SGIDS $SGIDS1 ; do
   [[ $sg != $SG_DEFAULT ]] && echo "  aws ec2 delete-security-group --group-id " $sg ;
done
for ig in $IGIDS $IGIDS1 ; do echo "  aws ec2 detach-internet-gateway --internet-gateway-id " $ig " --vpc-id " $VPCID ; done
for ig in $IGIDS $IGIDS1 ; do echo "  aws ec2 delete-internet-gateway --internet-gateway-id " $ig ; done
for rt in $RTIDS $RTIDS1 ; do
   [[ $rt != $RT_MAIN ]] && echo "  aws ec2 delete-route-table --route-table-id " $rt ; 
done
for vpc in $VPCID ; do echo "  aws ec2 delete-vpc --vpc-id " $vpc ; done
fi

if [[ $1 == -v ]] || [[ $1 == -V ]] ; then
echo
for v in VPCID RTIDS SUBNETIDS SGIDS IGIDS INSTIDS RTIDS1 SUBNETIDS1 SGIDS1 IGIDS1 ; do
   val=${!v}
   [[ $val ]] && echo $v=\"$val\"
done
fi

echo -e "\n${RED}Try also:$NC $IT./aws_kcluster_info -?$NC"

