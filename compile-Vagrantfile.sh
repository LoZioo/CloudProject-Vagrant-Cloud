#!/bin/bash
source config.sh

VAGRANTFILE_BASE="Vagrantfile.rb"
VAGRANTFILE="Vagrantfile"

echo "# Auto-generated Vagrantfile from compile-Vagrantfile.sh, Vagrantfile.base and config.sh" > $VAGRANTFILE
echo >> $VAGRANTFILE

echo "# IP addresses." >> $VAGRANTFILE
echo "M_IP = \"$M_IP\"" >> $VAGRANTFILE
echo "W1_IP = \"$W1_IP\"" >> $VAGRANTFILE
echo "W2_IP = \"$W2_IP\"" >> $VAGRANTFILE
echo >> $VAGRANTFILE

cat $VAGRANTFILE_BASE >> $VAGRANTFILE
