#!/bin/bash -ex
#

source config.cfg
source functions.sh

echocolor "Create DB for CINDER"
sleep 5
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
FLUSH PRIVILEGES;
EOF

echocolor "Create  user, endpoint for CINDER"
sleep 5
openstack user create --password $CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2


openstack endpoint create \
--publicurl http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s \
--internalurl http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s \
--adminurl http://$CON_MGNT_IP:8776/v1/%\(tenant_id\)s \
--region RegionOne \
volume


openstack endpoint create \
--publicurl http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s \
--internalurl http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s \
--adminurl http://$CON_MGNT_IP:8776/v2/%\(tenant_id\)s \
--region RegionOne \
volumev2

#
echocolor "Install CINDER"
sleep 3
apt-get install -y cinder-api cinder-scheduler python-cinderclient \
	lvm2 cinder-volume python-mysqldb  qemu 


pvcreate /dev/vdb
vgcreate cinder-volumes /dev/vdb
sed  -r -i 's#(filter = )(\[ "a/\.\*/" \])#\1["a\/vdb\/", "r/\.\*\/"]#g' \
	/etc/lvm/lvm.conf

cinder_ctl=/etc/cinder/cinder.conf
test -f $cinder_ctl.orig || cp $cinder_ctl $cinder_ctl.orig

## [DEFAULT] section
ops_edit_file $cinder_ctl DEFAULT rpc_backend rabbit
ops_edit_file $cinder_ctl DEFAULT auth_strategy keystone
ops_edit_file $cinder_ctl DEFAULT my_ip $CON_MGNT_IP
ops_edit_file $cinder_ctl DEFAULT verbose True
ops_edit_file $cinder_ctl DEFAULT enabled_backends lvm
ops_edit_file $cinder_ctl DEFAULT glance_host $CON_MGNT_IP
ops_edit_file $cinder_ctl DEFAULT notification_driver messagingv2

## [database] section
ops_edit_file $cinder_ctl \
connection mysql+pymysql://cinder:$CINDER_DBPASS@$CON_MGNT_IP/cinder

## [oslo_messaging_rabbit] section
ops_edit_file $cinder_ctl oslo_messaging_rabbit rabbit_host $CON_MGNT_IP
ops_edit_file $cinder_ctl oslo_messaging_rabbit rabbit_userid openstack
ops_edit_file $cinder_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS

## [keystone_authtoken] section
ops_edit_file $cinder_ctl keystone_authtoken auth_uri http://$CON_MGNT_IP:50000
ops_edit_file $cinder_ctl keystone_authtoken auth_url http://$CON_MGNT_IP:35357
ops_edit_file $cinder_ctl keystone_authtoken auth_plugin password
ops_edit_file $cinder_ctl keystone_authtoken project_domain_id default
ops_edit_file $cinder_ctl keystone_authtoken user_domain_id default
ops_edit_file $cinder_ctl keystone_authtoken project_name service
ops_edit_file $cinder_ctl keystone_authtoken username cinder
ops_edit_file $cinder_ctl keystone_authtoken password $CINDER_PASS

## [oslo_concurrency] section
ops_edit_file $cinder_ctl oslo_concurrency lock_path /var/lib/cinder/tmp

## [lvm] section
ops_edit_file $cinder_ctl lvm \
volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
ops_edit_file $cinder_ctl lvm volume_group cinder-volumes
ops_edit_file $cinder_ctl lvm iscsi_protocol iscsi
ops_edit_file $cinder_ctl lvm iscsi_helper tgtadm


echocolor "Syncing Cinder DB"
sleep 3
su -s /bin/sh -c "cinder-manage db sync" cinder
 
echocolor "Restarting CINDER service"
sleep 3
service tgt restart
service cinder-volume restart
service cinder-api restart
service cinder-scheduler restart

rm -f /var/lib/cinder/cinder.sqlite

echocolor "Finish setting up CINDER"