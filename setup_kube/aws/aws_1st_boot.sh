#!/bin/bash

# could be a (fragment) of a user file for booting AWS instances

cat > /etc/skel/.inputrc<<EOF
set bell-style none
set bell-style visible
set completion-ignore-case on
set show-all-if-ambiguous on
"\e[A": history-search-backward
"\e[B": history-search-forward
EOF
cp /etc/skel/.inputrc /root
cp /etc/skel/.inputrc /home/ubuntu
chown ubuntu:ubuntu /home/ubuntu/.inputrc
sudo chmod -x /etc/update-motd.d/*

##apt-get clean
##apt-get check
#apt update
#apt upgrade -y
