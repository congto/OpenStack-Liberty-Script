#!/bin/bash -ex
#

source config.cfg

# Cong cu de sua file cau hinh
apt-get -y install python-pip
pip install https://pypi.python.org/packages/source/c/crudini/crudini-0.7.tar.gz

####################################   
# Ceilomter agent for Compute node #
####################################



echo "Installing Ceilomter agent for Compute node"
sleep 3
apt-get -y install ceilometer-agent-compute

echo "Backup file config of Ceilomter"
sleep 3
fileceilomter=/etc/ceilometer/ceilometer.conf
test -f $fileceilomter.orig || cp $fileceilomter $fileceilomter.orig

echo "Edit file ceilometer"
sleep 3

# Edit [DEFAULT] section 

crudini --set $fileceilomter DEFAULT rpc_backend rabbit
crudini --set $fileceilomter DEFAULT auth_strategy keystone
crudini --set $fileceilomter DEFAULT verbose True


# Edit [slo_messaging_rabbit] section 
crudini --set  $fileceilomter oslo_messaging_rabbit rabbit_host $CON_MGNT_IP
crudini --set $fileceilomter oslo_messaging_rabbit rabbit_userid openstack
crudini --set $fileceilomter oslo_messaging_rabbit rabbit_password $RABBIT_PASS

# Edit [keystone_authtoken] section 
crudini --set $fileceilomter keystone_authtoken auth_uri http://$CON_MGNT_IP:5000
crudini --set $fileceilomter keystone_authtoken auth_url http://$CON_MGNT_IP:35357
crudini --set $fileceilomter keystone_authtoken auth_plugin password
crudini --set $fileceilomter keystone_authtoken project_domain_id default
crudini --set $fileceilomter keystone_authtoken user_domain_id default
crudini --set $fileceilomter keystone_authtoken project_name service
crudini --set $fileceilomter keystone_authtoken username ceilometer
crudini --set $fileceilomter keystone_authtoken password $CEILOMETER_PASS

# Edit [service_credentials] section 
crudini --set $fileceilomter service_credentials os_auth_url http://$CON_MGNT_IP:5000/v2.0
crudini --set $fileceilomter service_credentials os_username ceilometer
crudini --set $fileceilomter service_credentials os_tenant_name service
crudini --set $fileceilomter service_credentials os_password $CEILOMETER_PASS
crudini --set $fileceilomter service_credentials os_endpoint_type internalURL
crudini --set $fileceilomter service_credentials os_region_name RegionOne	

echo "Edit file /etc/nova/nova.conf on Compute node"
sleep 3

# Edit [DEFAULT] section 
filenova=/etc/nova/nova.conf
crudini --set $filenova DEFAULT instance_usage_audit True
crudini --set $filenova DEFAULT instance_usage_audit_period hour
crudini --set $filenova DEFAULT notify_on_state_change vm_and_task_state
crudini --set $filenova DEFAULT notification_driver messagingv2

echo "Restart ceilometer-agent-compute, nova-compute"
sleep 3
service ceilometer-agent-compute restart
service nova-compute restart








