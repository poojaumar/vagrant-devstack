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

export no_proxy=127.0.0.1,$HOST_IP

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

enable_plugin tap-as-a-service-dashboard https://git.openstack.org/openstack/tap-as-a-service-dashboard

EOF

sudo chown -R vagrant:vagrant $WORKSPACE/devstack

FORCE=yes ./stack.sh

#################################
# TaaS usage
#################################

# Prepare local.conf file
cat > $WORKSPACE/demo-openrc.sh << EOF
#!/usr/bin/env bash

# To use an OpenStack cloud you need to authenticate against the Identity
# service named keystone, which returns a **Token** and **Service Catalog**.
# The catalog contains the endpoints for all services the user/tenant has
# access to - such as Compute, Image Service, Identity, Object Storage, Block
# Storage, and Networking (code-named nova, glance, keystone, swift,
# cinder, and neutron).
#
# *NOTE*: Using the 3 *Identity API* does not necessarily mean any other
# OpenStack API is version 3. For example, your cloud provider may implement
# Image API v1.1, Block Storage API v2, and Compute API v2.0. OS_AUTH_URL is
# only for the Identity API served through keystone.
export OS_AUTH_URL=http://203.0.113.108/identity/v3

# With the addition of Keystone we have standardized on the term **project**
# as the entity that owns the resources.
# export OS_PROJECT_ID=e9a7b06d77284831a294a3eb6ed75cf1
export OS_PROJECT_NAME="demo"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "\$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "\$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi

# unset v2.0 items in case set
unset OS_TENANT_ID
unset OS_TENANT_NAME

# In addition to the owning entity (tenant), OpenStack stores the entity
# performing the action as the **user**.
export OS_USERNAME="admin"

# With Keystone you pass the keystone password.
#echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
#read -sr OS_PASSWORD_INPUT
export OS_PASSWORD_INPUT="secret"
export OS_PASSWORD=\$OS_PASSWORD_INPUT

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="RegionOne"
# Don't leave a blank variable, unset it if it was empty
if [ -z "\$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi

export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
EOF


source $WORKSPACE/demo-openrc.sh

#export IMG_PATH="$HOME"
export IMG_NAME="xenial-server-cloudimg-amd64-disk1"
# mkdir -P $IMG_PATH
# wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
# openstack image create "$IMG_NAME"  --file "$IMG_PATH/$IMG_NAME"".img" --disk-format qcow2 --container-format bare --public

echo "-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA3MHSuV4XuMMJZIEnT6y+tc2dVBVIZhh7IkuTFXrVPhhWvrzU
ShysRmx4UkW5OYnGHZVP+Bu2vWJsHKtUnt4dCLTlSIPAoli4F8IZJh/Wb1ow/eVn
hNpR//iwD/UMhWVL/NGoymq6Pk37wqiKqf9CX/P1vvFj9MldJsrcCMtVKRy+qGQ3
rCNefSyA5AlTcpkBu2vlIc5xgXUGllqZ5sGsHlz5xZ10HTHxhsEySZSikkmQnMh4
ZZEravyEUHaf0iXoAlEKqc5h9XVFyd4bpMbXPcSVsqi42VN8wS9F5JWODttEN2zd
VLt0CjIfmQwvcpxg5MtI8fcbj9ZimnHnMw4/1QIDAQABAoIBACJOuPn35oXfQbFt
5Pcb6JOGfeHYYOUE/vXoetZGvaclzy1bWT6fUCKtrtFSZqPLho+IaeIsJG0wQ479
DWyXJjn5KvznBOP2F74ReykSn5e0k5KRuVHLQB0gv/Pq6GQ+xt1mk+3JQmJ2ah7p
ZItg0SbqWhGvoBIlzSU/N4ziVLzLoe1Ee1tGDoRwuQLFHyLvxg7oDBpMhqWysMtf
AriRweXXwZgkNotqDHP+NwryH1KipkTanXyaoxcat90eIfF0VdSqm1rkcfpcXnNR
WN80eeLl1KgEapNvQ1yFiV3hvFI+CqQLu7uLadaOe4QmwOYDeYraWMxhY2TQ1a91
8vwAVq0CgYEA73DwFNxWbOXUrG0u9Lj47P7c0HNVqLwBWWpUo2OrUmMyUfumR9RG
AzQzuZ+heb9NXyyBK+cMQaLVy0SaMtlxM8OoDtDtRIcVE9hHfmnEEr7+zA/Rkubg
8ppKKvg4N8yIhtdic0l0StfMMWEvuAcY3RdPS1IJEklx6xyoTLA6DLcCgYEA7AYa
drfv4vmqSVrS+5Doq8fkY4V1+HJfR5MhyPpdsnFNtTA+o8LJTFn5zWPRrELcmc/E
8KuolmPxXK3oD8gDKxuvsbyVFbg2s7LOYkzZEPi8GMPQ0w45w8q6OkgBFh13Vtjn
zxRsZsDUhdENYMEJ7EFo5Zo+n+3WCgvPOP0NY9MCgYA33MeGdmmLeouFtutvmQAq
esOVtnLTrRk7fT1F6Wj9DbuduPJwa6vx72np8r4/o0wv2jhAv+TyI0Vx6Q14s5Zf
l1RMMJ5KkKFwQdNcQNzH6tuTTFV+ynLM5wZKxCKJkiSAIRwM/aQuGe6/zobNjopU
eq27SuZm58+2JLd3PN4uPQKBgCKnCr+fZdL3QO8gLJXOwrpl0Lxj3dwqPp7tlSpC
x/ro87XEbY3xjUhudWSYYTJfZrAWdx22tjvOVKN8zPN0NDLiD7uSqnjT4QQlHnQE
QGJjgopIRaKXFhgO7aSc6bvre5f+pJocr4WujgVPmh04elJ7kAEV0lf8vU4gSb5e
ONcNAoGAJix/1eiOjBrfS4xfZnoXuWtQVOcrw2p5aH/KKfIw+c+sD72mdxrjmmj0
ETM7YSkCaIlze5Vak3ygiHmsWW6DGnEgVvvsVGeOuYqP7k6GKrB+r0W3FUeCcKzL
GRvZKpTZERkPyT/x1AtWDVJOG8sPHj7Shhe/3u7uqIej9q++tiM=
-----END RSA PRIVATE KEY-----" > ~/.ssh/osh-contrail-key-pair-ubuntu.pem

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcwdK5Xhe4wwlkgSdPrL61zZ1UFUhmGHsiS5MVetU+GFa+vNRKHKxGbHhSRbk5icYdlU/4G7a9Ymwcq1Se3h0ItOVIg8CiWLgXwhkmH9ZvWjD95WeE2lH/+LAP9QyFZUv80ajKaro+TfvCqIqp/0Jf8/W+8WP0yV0mytwIy1UpHL6oZDesI159LIDkCVNymQG7a+UhznGBdQaWWpnmwaweXPnFnXQdMfGGwTJJlKKSSZCcyHhlkStq/IRQdp/SJegCUQqpzmH1dUXJ3hukxtc9xJWyqLjZU3zBL0XklY4O20Q3bN1Uu3QKMh+ZDC9ynGDky0jx9xuP1mKaceczDj/V Generated-by-Nova" >> ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcwdK5Xhe4wwlkgSdPrL61zZ1UFUhmGHsiS5MVetU+GFa+vNRKHKxGbHhSRbk5icYdlU/4G7a9Ymwcq1Se3h0ItOVIg8CiWLgXwhkmH9ZvWjD95WeE2lH/+LAP9QyFZUv80ajKaro+TfvCqIqp/0Jf8/W+8WP0yV0mytwIy1UpHL6oZDesI159LIDkCVNymQG7a+UhznGBdQaWWpnmwaweXPnFnXQdMfGGwTJJlKKSSZCcyHhlkStq/IRQdp/SJegCUQqpzmH1dUXJ3hukxtc9xJWyqLjZU3zBL0XklY4O20Q3bN1Uu3QKMh+ZDC9ynGDky0jx9xuP1mKaceczDj/V Generated-by-Nova" >> ~/dt967u_public_key.pub
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/dt967u_public_key.pub
chmod 600 ~/.ssh/osh-contrail-key-pair-ubuntu.pem
eval $(ssh-agent -s)
ssh-add ~/.ssh/osh-contrail-key-pair-ubuntu.pem

read -p "Proceed with Openstack commands? Press y to continue or n to abort [y/n] : " yn
case $yn in
    [Nn]* ) echo "Aborting...."; exit;;
esac

openstack keypair create --public-key ~/dt967u_public_key.pub dt967u_public_key
openstack floating ip create public
#openstack security group rule create --proto icmp default
#openstack security group rule create --proto tcp --dst-port 22 default

openstack port create --network private --fixed-ip subnet=private-subnet,ip-address=10.0.0.9 --enable left-vm-port
openstack port create --network private --fixed-ip subnet=private-subnet,ip-address=10.0.0.18 --enable right-vm-port
openstack port create --network private --disable-port-security --fixed-ip subnet=private-subnet,ip-address=10.0.0.27 taas-service-port

openstack server create --flavor m1.nano --image cirros-0.3.4-x86_64-uec --nic port-id=left-vm-port left_vm
openstack server create --flavor m1.nano --image cirros-0.3.4-x86_64-uec --nic port-id=right-vm-port right_vm
openstack server create --flavor m1.small --image $IMG_NAME --nic port-id=taas-service-port --key-name dt967u_public_key taas_service_vm

neutron tap-service-create --port taas-service-port --name taas_service
neutron tap-flow-create --name taas_flow --port left-vm-port --tap-service taas_service --direction both
neutron tap-service-list
neutron tap-flow-list
