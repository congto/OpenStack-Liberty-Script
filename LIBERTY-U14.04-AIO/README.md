# Cài đặt & HDSD OpenStack LIBERTY AIO

### Giới thiệu
- Script cài đặt OpenStack Liberty trên một máy chủ
- Các thành phần cài đặt bao gồm
  - MariaDB, NTP
  - Keystone Version 3
  - Glance
  - Neutron (ML2, OpenvSwitch)
  
### Môi trường cài đặt
- LAB trên Vmware Workstation hoặc máy vật lý, đáp ứng yêu cầu tối thiểu sau:
```sh
 - RAM: 4GB
 - HDD
  - HDD1: 60GB (cài OS và các thành phần của OpenStack)
  - HDD2: 40GB (sử dụng để cài CINDER - cung cấp VOLUME cho OpenStack) - CHÚ Ý: NẾU KHÔNG CÀI CINDER THÌ KHÔNG CẦN Ổ NÀY
 - 02 NIC với thứ tự sau
  - NIC 1:  - eth0 - Management Network
  - NIC 2: - eth1 - External Network
 - CPU hỗ trợ ảo hóa
```

### Các bước thực hiện

#### Chuẩn bị môi trường trên VMware
Thiết lập cấu hình như bên dưới, lưu ý:
- NIC1: Sử dụng Vmnet 1 hoặc hostonly
- NIC2: Sử dụng bridge
- CPU: 2x2, nhớ chọn VT

![Topo-liberty](/images/VMware1.png)

#### Lựa chọn 1:  Thực hiện cài đặt bằng 01 duy nhất.
- Nếu chọn lựa chọn 1 thì sau khi cài xong chuyển qua bước sử dụng dashboard luôn, bỏ qua lựa chọn 2

#### Tải GIT và cấu hình ip động cho các card mạng.
- Cấu hình network bằng đoạn lệnh sau để đảm bảo máy chủ có 02 NIC
```sh

cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

# NIC MGNT
auto eth0
iface eth0 inet dhcp

# NIC EXT
auto eth1
iface eth1 inet dhcp
EOF

```

- Khởi động lại network
```sh
ifdown -a && ifup -a
```

- Kiểm tra lại địa chỉ IP của máy cài OpenStack, đảm bảo có đủ 02 NIC bằng lệnh `landscape-sysinfo`

```sh
root@controller:~# landscape-sysinfo

  System load:  0.93              Users logged in:       1
  Usage of /:   4.0% of 94.11GB   IP address for eth0:   10.10.10.159
  Memory usage: 53%               IP address for eth0  172.16.69.228
  Swap usage:   0%                
```

- Kiểm tra kết nối internet bằng lệnh `ping google.com`
```sh
root@controller:~# ping google.com

PING google.com (203.162.236.211) 56(84) bytes of data.
64 bytes from 203.162.236.211: icmp_seq=1 ttl=57 time=0.877 ms
64 bytes from 203.162.236.211: icmp_seq=2 ttl=57 time=0.786 ms
64 bytes from 203.162.236.211: icmp_seq=3 ttl=57 time=0.781 ms

```
- Cài đặt git với quền root
```sh
su -
apt-get update
apt-get -y install git
```

- Thực thi script để đặt địa chỉ IP tĩnh cho máy cài OpenStack
```sh
git clone https://github.com/congto/OpenStack-Liberty-Script.git

mv /root/OpenStack-Liberty-Script/LIBERTY-U14.04-AIO /root
rm -rf OpenStack-Liberty-Script

cd LIBERTY-U14.04-AIO 
chmod +x *.sh
bash AIO-LIBERTY-1.sh 
```
- Máy sẽ khởi động lại, đăng nhập và thực hiện script tiếp theo
- Thực thi script cài đặt toàn bộ các thành phần còn lại
```sh
bash AIO-LIBERTY-2.sh
```
- Chờ khoảng 30-60 phút để thực hiện tải và cấu hình các dịch vụ sau đó chuyển qua bước tạo network, tạo VM. 
- Kết thúc việc cài đặt OpenStack


#### Lựa chọn 2:  Thực hiện cài đặt theo từng script
#### Tải script và thực thi script
- Tải script
- Sử dụng quyền root để đăng nhập, với Ubuntu 14.04 cần đăng nhập bằng user thường trước, sau đó chuyển qua root bằng lệnh su -

```sh
git clone https://github.com/congto/OpenStack-Liberty-Script.git

mv /root/OpenStack-Liberty-Script/LIBERTY-U14.04-AIO /root
rm -rf OpenStack-Liberty-Script

cd LIBERTY-U14.04-AIO 
chmod +x *.sh
```

##### Thực thi script đặt IP cho các card mạng
- Script sẽ thực hiện tự động việc đặt IP tĩnh cho các card mạng
```sh
bash 0-liberty-aio-ipadd.sh
```

##### Cài đặt các gói NTP, MARIADB, RABBITMQ
- Đăng nhập lại máy chủ với quyền root và thực thi script
```sh
su -
cd LIBERTY-U14.04-AIO 
bash 1-liberty-aio-prepare.sh
```
- Sau khi thực hiện script trên xong, máy chủ sẽ khởi động lại.

##### Cài đặt Keystone
- Thực thi script dưới để cài đặt Keystone
```sh
bash 2-liberty-aio-keystone.sh
```

- Thực thi lệnh dưới để khai báo biến môi trường cho OpenStack
```sh
source admin-openrc.sh
```

- Kiểm tra lại việc cài đặt của Keystone bằng lệnh dưới 
```sh
openstack token issue
```

- Kết quả như dưới là đảm bảo cài đặt Keystone thành công.
```sh
+------------+----------------------------------+
| Field      | Value                            |
+------------+----------------------------------+
| expires    | 2015-11-20T04:36:40.458714Z      |
| id         | afa93ac41b9f432d989cc6f5c235c44f |
| project_id | a863f6011c9f4d748a9af23983284a90 |
| user_id    | 07817eb3060941598fe406312b8aa448 |
+------------+----------------------------------+
```

##### Cài đặt GLANCE
```sh
bash 3-liberty-aio-glance.sh
```

##### Cài đặt NOVA
```
bash 4-liberty-aio-nova.sh
```

##### Cài đặt NEUTRON
- Cài đặt OpenvSwitch và cấu hình lại NIC
```sh
bash 5-liberty-aio-config-ip-neutron.sh
```
- Sau khi thực thi xong script trên, máy chủ sẽ khởi động lại. Đăng nhập với quyền root và tiếp tục thực hiện lệnh dưới để cài NEUTRON

```sh
bash 6-liberty-aio-install-neutron.sh
```

##### Cài đặt Horizon
```
bash 7-liberty-aio-install-horizon.sh
```

## Hướng dẫn sử dụng dashboard để tạo network, VM, tạo các rule.
### Tạo rule cho project admin
- Đăng nhập vào dasboard
![liberty-horizon1.png](/images/liberty-horizon1.png)

- Chọn tab `admin => Access & Security => Manage Rules`
![liberty-horizon2.png](/images/liberty-horizon2.png)

- Chọn tab `Add Rule`
![liberty-horizon3.png](/images/liberty-horizon3.png)

- Mở rule cho phép từ bên ngoài SSH đến máy ảo
![liberty-horizon4.png](/images/liberty-horizon4.png)
- Làm tương tự với rule ICMP để cho phép ping tới máy ảo và các rule còn lại.

### Tạo network
#### Tạo dải external network
- Chọn tab `Admin => Networks => Create Network`
![liberty-net-ext1.png](/images/liberty-net-ext1.png)

- Nhập và chọn các tab như hình dưới.
![liberty-net-ext2.png](/images/liberty-net-ext2.png)

- Click vào mục `ext-net` vừa tạo để khai báo subnet cho dải external.
![liberty-net-ext3.png](/images/liberty-net-ext3.png)

- Chọn tab `Creat Subnet`
![liberty-net-ext4.png](/images/liberty-net-ext4.png)

- Khai báo dải IP của subnet cho dải external 
![liberty-net-ext5.png](/images/liberty-net-ext5.png)

- Khai báo pools và DNS
![liberty-net-ext6.png](/images/liberty-net-ext6.png)

#### Tạo dải internal network
- Lựa chọn các tab lần lượt theo thứ tự `Project admin => Network => Networks => Create Network"
![liberty-net-int1.png](/images/liberty-net-int1.png)

- Khai báo tên cho internal network
![liberty-net-int2.png](/images/liberty-net-int2.png)

- Khai báo subnet cho internal network
![liberty-net-int3.png](/images/liberty-net-int3.png)

- Khai báo dải IP cho Internal network
![liberty-net-int4.png](/images/liberty-net-int4.png)

#### Tạo Router cho project admin
- Lựa chọn theo các tab "Project admin => Routers => Create Router
![liberty-r1.png](/images/liberty-r1.png)

- Tạo tên router và lựa chọn như hình
![liberty-r2.png](/images/liberty-r2.png)

- Gán interface cho router
![liberty-r3.png](/images/liberty-r3.png)

![liberty-r4.png](/images/liberty-r4.png)

![liberty-r5.png](/images/liberty-r5.png)
- Kết thúc các bước tạo exteral network, internal network, router


## Tạo máy ảo (Instance)
- Lựa chọn các tab dưới `Project admin => Instances => Launch Instance`
![liberty-instance1.png](/images/liberty-instance1.png)

![liberty-instance2.png](/images/liberty-instance2.png)

![liberty-instance3.png](/images/liberty-instance3.png)
