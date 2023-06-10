#!/bin/bash
cat /vagrant/setup_kube/kube_key.pem.pub >> /home/vagrant/.ssh/authorized_keys
cp /vagrant/.inputrc /home/vagrant/
