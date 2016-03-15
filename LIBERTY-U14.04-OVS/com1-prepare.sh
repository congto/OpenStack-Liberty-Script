#!/bin/bash -ex
#

source config.cfg
source functions.sh

apt-get -y install python-pip
pip install https://pypi.python.org/packages/source/c/crudini/crudini-0.7.tar.gz

#

cat << EOF >> /etc/sysctl.conf
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

echocolor "Install python openstack client"
apt-get -y install python-openstackclient

echocolor "Install NTP"

apt-get install ntp -y
apt-get install python-mysqldb -y
#
echocolor "Backup NTP configuration"
sleep 7 
cp /etc/ntp.conf /etc/ntp.conf.bka
rm /etc/ntp.conf
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf
#
sed -i 's/server 0.ubuntu.pool.ntp.org/ \
#server 0.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 1.ubuntu.pool.ntp.org/ \
#server 1.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 2.ubuntu.pool.ntp.org/ \
#server 2.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i 's/server 3.ubuntu.pool.ntp.org/ \
#server 3.ubuntu.pool.ntp.org/g' /etc/ntp.conf

sed -i "s/server ntp.ubuntu.com/server $CON_MGNT_IP iburst/g" /etc/ntp.conf

sleep 5
echocolor "Installl package for NOVA"
apt-get -y install nova-compute 
echo "libguestfs-tools libguestfs/update-appliance boolean true" \
	| debconf-set-selections
apt-get -y install libguestfs-tools sysfsutils guestfsd python-guestfs

#fix loi chen pass tren hypervisor la KVM
update-guestfs-appliance
chmod 0644 /boot/vmlinuz*
usermod -a -G kvm root


echocolor "Configuring in nova.conf"
sleep 5
########
#/* Sao luu truoc khi sua file nova.conf
nova_com=/etc/nova/nova.conf
test -f $nova_com.orig || cp $nova_com $nova_com.orig

## [DEFAULT] Section
ops_edit $nova_com DEFAULT rpc_backend rabbit
ops_edit $nova_com DEFAULT auth_strategy keystone
ops_edit $nova_com DEFAULT my_ip $COM1_MGNT_IP
ops_edit $nova_com DEFAULT network_api_class nova.network.neutronv2.api.API
ops_edit $nova_com DEFAULT security_group_api neutron
ops_edit $nova_com DEFAULT \
	linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
ops_edit $nova_com DEFAULT \
	firewall_driver nova.virt.firewall.NoopFirewallDriver

ops_edit $nova_com DEFAULT enable_instance_password True

## [oslo_messaging_rabbit] section
ops_edit $nova_com oslo_messaging_rabbit rabbit_host $CON_MGNT_IP
ops_edit $nova_com oslo_messaging_rabbit rabbit_userid openstack
ops_edit $nova_com oslo_messaging_rabbit rabbit_password $RABBIT_PASS


## [keystone_authtoken] section
ops_edit $nova_com keystone_authtoken auth_uri http://$CON_MGNT_IP:5000
ops_edit $nova_com keystone_authtoken auth_url http://$CON_MGNT_IP:35357
ops_edit $nova_com keystone_authtoken auth_plugin password
ops_edit $nova_com keystone_authtoken project_domain_id default
ops_edit $nova_com keystone_authtoken user_domain_id default
ops_edit $nova_com keystone_authtoken project_name service
ops_edit $nova_com keystone_authtoken username nova
ops_edit $nova_com keystone_authtoken password $KEYSTONE_PASS

## [vnc] section
ops_edit $nova_com vnc enabled True
ops_edit $nova_com vnc vncserver_listen 0.0.0.0
ops_edit $nova_com vnc vncserver_proxyclient_address \$my_ip
ops_edit $nova_com vnc vncserver_proxyclient_address \$my_ip
ops_edit $nova_com vnc \
	novncproxy_base_url http://$CON_EXT_IP:6080/vnc_auto.html
	
	
## [glance] section
ops_edit $nova_com glance host $CON_MGNT_IP


## [oslo_concurrency] section
ops_edit $nova_com oslo_concurrency lock_path /var/lib/nova/tmp

## [neutron] section
ops_edit $nova_com neutron url http://$CON_MGNT_IP:9696
ops_edit $nova_com neutron auth_url http://$CON_MGNT_IP:35357
ops_edit $nova_com neutron auth_plugin password
ops_edit $nova_com neutron project_domain_id default
ops_edit $nova_com neutron user_domain_id default
ops_edit $nova_com neutron region_name RegionOne
ops_edit $nova_com neutron project_name service
ops_edit $nova_com neutron username neutron
ops_edit $nova_com neutron password $NEUTRON_PASS

## [libvirt] section
ops_edit $nova_com libvirt inject_key True
ops_edit $nova_com libvirt inject_partition -1
ops_edit $nova_com libvirt inject_password True


echo "Restart nova-compute"
sleep 5
service nova-compute restart

# Remove default nova db
rm /var/lib/nova/nova.sqlite

echo "Install openvswitch-agent (neutron) on COMPUTE NODE"
sleep 5

apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent

echo "Config file neutron.conf"
neutron_com=/etc/neutron/neutron.conf
test -f $neutron_com.orig || cp $neutron_com $neutron_com.orig

## [DEFAULT] section
ops_edit $neutron_com DEFAULT core_plugin ml2
ops_edit $neutron_com DEFAULT rpc_backend rabbit
ops_edit $neutron_com DEFAULT auth_strategy keystone
ops_edit $neutron_com DEFAULT verbose True
ops_edit $neutron_com DEFAULT allow_overlapping_ips True
ops_edit $neutron_com DEFAULT service_plugins router

## [keystone_authtoken] section
ops_edit $neutron_com keystone_authtoken auth_uri http://$CON_MGNT_IP:5000
ops_edit $neutron_com keystone_authtoken auth_url http://$CON_MGNT_IP:35357
ops_edit $neutron_com keystone_authtoken auth_plugin password
ops_edit $neutron_com keystone_authtoken project_domain_id default
ops_edit $neutron_com keystone_authtoken user_domain_id default
ops_edit $neutron_com keystone_authtoken project_name service
ops_edit $neutron_com keystone_authtoken username neutron
ops_edit $neutron_com keystone_authtoken password $KEYSTONE_PASS

ops_del $neutron_com keystone_authtoken identity_uri
ops_del $neutron_com keystone_authtoken admin_tenant_name
ops_del $neutron_com keystone_authtoken admin_user
ops_del $neutron_com keystone_authtoken admin_password



## [database] section 
ops_del $neutron_com database connection

## [oslo_messaging_rabbit] section
ops_edit $neutron_com oslo_messaging_rabbit rabbit_host $CON_MGNT_IP
ops_edit $neutron_com oslo_messaging_rabbit rabbit_userid openstack
ops_edit $neutron_com oslo_messaging_rabbit rabbit_password $RABBIT_PASS


echo "############ Configuring ml2_conf.ini ############"
sleep 5
########
ml2_com=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $ml2_com.orig || cp $ml2_com $ml2_com.orig

## [ml2] section
ops_edit $ml2_com ml2 type_drivers flat,vlan,gre,vxlan
ops_edit $ml2_com ml2 tenant_network_types gre
ops_edit $ml2_com ml2 mechanism_drivers openvswitch


## [ml2_type_gre] section
ops_edit $ml2_com ml2_type_gre tunnel_id_ranges 1:1000

## [securitygroup] section 
ops_edit $ml2_com securitygroup enable_security_group True
ops_edit $ml2_com securitygroup enable_ipset True
ops_edit $ml2_com securitygroup \
firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

## [ovs] section
ops_edit $ml2_com ovs local_ip $COM1_MGNT_IP
ops_edit $ml2_com ovs enable_tunneling True

## [agent] section
ops_edit $ml2_com agent tunnel_types gre


echocolor "Reset service nova-compute,openvswitch-agent"
sleep 5
service nova-compute restart
service neutron-plugin-openvswitch-agent restart


