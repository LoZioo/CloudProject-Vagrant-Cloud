#!/usr/bin/env bash

export AWS_PAGER=""

. ./set_vars.sh

echo -e "\n${RED}AWS resources with tag ${BOLDRED}esperimento=kcluster$NC"

aws ec2 describe-tags --filters Name=tag-value,Values=kcluster \
   --query 'Tags[*].{Type:ResourceType,Id:ResourceId}' --output text

echo -e "${RED}Should any of the above be deleted (use Web console)?$NC"
read -p "Press [Enter] key to continue..."

VPCID=$(aws ec2 describe-vpcs \
   --filters Name=tag-value,Values=kcluster \
   --query 'Vpcs[*].VpcId' --output text \
) && echo "\nset VPCID=$VPCID" || echo  "\nwill create VPC"

SUBNETID=$(aws ec2 describe-subnets --vpc-id $VPCID --cidr-block 192.168.45.68/28 \
   --filters Name=tag-value,Values=kcluster \
   --query 'Subnet.SubnetId' --output text
)

SUBNETID=$(aws ec2 create-subnet --vpc-id $VPCID --cidr-block 192.168.45.68/28 \
   --tag-specifications 'ResourceType=subnet,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-subnet}]' \
   --query 'Subnet.SubnetId' --output text
)

echo -e "\n${RED}Created VPC $VPCID, subnet $SUBNETID $NC"

aws ec2 modify-subnet-attribute --subnet-id $SUBNETID --map-public-ip-on-launch

SGID=$(aws ec2 create-security-group --group-name SSHAccess \
   --description "Security group for SSH access" \
   --vpc-id $VPCID \
   --tag-specifications 'ResourceType=security-group,Tags=[{Key=esperimento,Value=kcluster},{Key=Name,Value=kcluster-sg}]' \
   --query 'GroupId' --output text \
)

aws ec2 authorize-security-group-ingress --group-id $SGID \
   --protocol tcp --port 22 --cidr 0.0.0.0/0

#aws ec2 describe-instances \
#   --filters Name=tag-value,Values=kmaster \
#   --query 'Reservations[*].Instances[*].PublicIpAddress' --output text
