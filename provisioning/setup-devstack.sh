#!/usr/bin/env bash

export WORKSPACE=$PWD

# Steps to install and configure devstack
sudo apt-get update 
sudo apt-get -y install git vim-gtk libxml2-dev libxslt1-dev libpq-dev python-pip libsqlite3-dev 
sudo apt-get -y build-dep python-mysqldb 
sudo pip install git-review tox 

git clone http://github.com/openstack-dev/devstack -b stable/newton 
cd $WORKSPACE/devstack

git config --global user.email "deepak.dt@gmail.com"
git config --global user.name "Deepak Tiwari"
git config --user.editor "vim"

sudo groupadd stack
sudo useradd -g stack -s /bin/bash -d /opt/stack -m stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo su - stack

# Prepare local.conf file
cat > $WORKSPACE/devstack/local.conf << EOF
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD

#Enable heat services
enable_service h-eng h-api h-api-cfn h-api-cw

#Enable heat plugin
enable_plugin heat https://git.openstack.org/openstack/heat stable/newton

# Neutron - Networking Service
# If Neutron is not declared the old good nova-network will be used
ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta,neutron

## Neutron - Load Balancing
ENABLED_SERVICES+=,q-lbaas

## Neutron - VPN as a Service
ENABLED_SERVICES+=,q-vpn

## Neutron - Firewall as a Service
ENABLED_SERVICES+=,q-fwaas

# VLAN configuration
Q_PLUGIN=ml2
ENABLE_TENANT_VLANS=True

# GRE tunnel configuration
Q_PLUGIN=ml2
ENABLE_TENANT_TUNNELS=True

# VXLAN tunnel configuration
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=vxlan 

IMAGE_URL_SITE="http://download.fedoraproject.org"
IMAGE_URL_PATH="/pub/fedora/linux/releases/25/CloudImages/x86_64/images/"
IMAGE_URL_FILE="Fedora-Cloud-Base-25-1.3.x86_64.qcow2"
IMAGE_URLS+=","\$IMAGE_URL_SITE\$IMAGE_URL_PATH\$IMAGE_URL_FILE

# Enable Logging
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs
EOF

FORCE=yes ./stack
