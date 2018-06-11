#!/usr/bin/env bash

export http_proxy=
export https_proxy=

export HOST_IP=203.0.113.108
export FLOATING_RANGE="203.0.113.0/24"
export IPV4_ADDRS_SAFE_TO_USE="10.0.0.0/22"
export PUBLIC_NETWORK_GATEWAY="203.0.113.1"
export PUBLIC_INTERFACE=enp0s8
export Q_FLOATING_ALLOCATION_POOL_START="203.0.113.162"
export Q_FLOATING_ALLOCATION_POOL_END="203.0.113.171"
export ADMIN_PASSWORD=secret

if [ ! -z $http_proxy ]
then
# Proxy related settings - apt-get
cat << EOF | sudo tee -a /etc/apt/apt.conf
Acquire::http::Proxy "$http_proxy";
Acquire::https::Proxy "$https_proxy";
EOF
fi

# Steps to install and configure devstack
sudo apt-get update -y
sudo apt-get -y install git vim-gtk libxml2-dev libxslt1-dev libpq-dev python-pip libsqlite3-dev 
sudo apt-get -y build-dep python-mysqldb 
#sudo pip install git-review tox

git config --global user.email "deepak.dt@gmail.com"
git config --global user.name "Deepak Tiwari"
git config --global user.editor "vim"

#sudo groupadd stack
#sudo useradd -g stack -s /bin/bash -d /opt/stack -m stack
echo "vagrant ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/vagrant
#sudo su - vagrant

export WORKSPACE=$PWD

git clone https://github.com/openstack-dev/devstack -b stable/ocata
sudo chown -R vagrant:vagrant $WORKSPACE/devstack

cd $WORKSPACE/devstack

# Replace git.openstack.org with https://github.com/openstack in "GIT_BASE=${GIT_BASE:-git://git.openstack.org}"
sed -i -E "s/(git\:\/\/git.openstack.org)/https\:\/\/git.openstack.org/" $WORKSPACE/devstack/stackrc
sed -i -E "s/(SERVICE_TIMEOUT:-60)/SERVICE_TIMEOUT:-120/" $WORKSPACE/devstack/stackrc

# Prepare local.conf file
cat > $WORKSPACE/devstack/local.conf << EOF
[[local|localrc]]
HOST_IP=$HOST_IP
SERVICE_HOST=$HOST_IP
MYSQL_HOST=$HOST_IP
RABBIT_HOST=$HOST_IP
GLANCE_HOSTPORT=$HOST_IP:9292

## Neutron options
Q_USE_SECGROUP=True
FLOATING_RANGE=$FLOATING_RANGE
IPV4_ADDRS_SAFE_TO_USE=$IPV4_ADDRS_SAFE_TO_USE
Q_FLOATING_ALLOCATION_POOL=start=$Q_FLOATING_ALLOCATION_POOL_START,end=$Q_FLOATING_ALLOCATION_POOL_END
PUBLIC_NETWORK_GATEWAY=$PUBLIC_NETWORK_GATEWAY
PUBLIC_INTERFACE=$PUBLIC_INTERFACE

# Open vSwitch provider networking configuration
Q_USE_PROVIDERNET_FOR_PUBLIC=True
OVS_PHYSICAL_BRIDGE=br-ex
PUBLIC_BRIDGE=br-ex
OVS_BRIDGE_MAPPINGS=public:br-ex

DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

#Enable heat services
enable_service h-eng h-api h-api-cfn h-api-cw

#Enable heat plugin
enable_plugin heat https://git.openstack.org/openstack/heat stable/ocata

# Neutron - Networking Service
# If Neutron is not declared the old good nova-network will be used
ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta,neutron

## Neutron - Load Balancing
ENABLED_SERVICES+=,q-lbaas

## Neutron - VPN as a Service
#ENABLED_SERVICES+=,q-vpn

## Neutron - Firewall as a Service
#ENABLED_SERVICES+=,q-fwaas

# VLAN configuration
Q_PLUGIN=ml2
ENABLE_TENANT_VLANS=True

# GRE tunnel configuration
Q_PLUGIN=ml2
ENABLE_TENANT_TUNNELS=True

# VXLAN tunnel configuration
Q_PLUGIN=ml2
Q_ML2_TENANT_NETWORK_TYPE=vxlan 

#IMAGE_URL_SITE="http://download.fedoraproject.org"
#IMAGE_URL_PATH="/pub/fedora/linux/releases/25/CloudImages/x86_64/images/"
#IMAGE_URL_FILE="Fedora-Cloud-Base-25-1.3.x86_64.qcow2"
IMAGE_URL_SITE="https://cloud-images.ubuntu.com"
IMAGE_URL_PATH="/xenial/current/"
IMAGE_URL_FILE="xenial-server-cloudimg-amd64-disk1.img"
IMAGE_URLS+=","\$IMAGE_URL_SITE\$IMAGE_URL_PATH\$IMAGE_URL_FILE

# Enable Logging
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs

enable_plugin tap-as-a-service https://github.com/openstack/tap-as-a-service stable/ocata
enable_service taas
TAAS_SERVICE_DRIVER=TAAS:TAAS:neutron_taas.services.taas.service_drivers.taas_rpc.TaasRpcDriver:default

EOF

sudo chown -R vagrant:vagrant $WORKSPACE/devstack

FORCE=yes ./stack.sh

# source demo-openrc.sh
# openstack port create --network private --disable-port-security taas-service-port
# openstack server create --flavor m1.nano --image cirros-0.3.4-x86_64-uec --nic port-id=taas-service-port taas_service_vm
# neutron tap-service-create --port taas-service-port --name taas_service
# neutron tap-flow-create --name taas_flow --port 90d0e72c-5f35-4304-a3cc-dcb55f08eb08 --tap-service taas_service --direction both
# neutron tap-service-list
# neutron tap-flow-list
