#!/bin/bash -ex

# Ham dinh nghia mau cho cac ban tin in ra man hinh
function echocolor() { # $1 = string
    COLOR='\033[01;93m'
    NC='\033[0m'
    printf "${COLOR}$1${NC}\n"
}

# Ham sua file cau hinh cua OpenStack

# 
function ops_edit_file() {
        crudini --set $1 $2 $3 $4 
}
# Cach dung
## Cu phap: 
##			ops_edit_file $bien_duong_dan_file [SECTION] [PARAMETER] [VALUAE]
## Vi du:   
###			filekeystone=/etc/keystone/keystone.conf 
###			ops_edit_file $filekeystone DEFAULT rpc_backend rabbit
