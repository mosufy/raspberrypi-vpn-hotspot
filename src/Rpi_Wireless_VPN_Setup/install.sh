#!/bin/sh -ex
#title				:Rpi_Wireless_VPN_Setup/install.sh
#description		:This script will make your Rpi a Wireless VPN Hotspot
#url				:https://github.com/mosufy/raspberrypi-vpn-hotspot
#author 			:mosufy
#date 				:20150412
#version			:0.1.0
#usage				:sudo bash install.sh

# Raspberry Pi OpenVPN Wireless Access Point Installation Script
#
# Make this Raspberry Pi as a Wireless Router to
# allow other devices within the same network to
# connect and route all traffic via a secured
# OpenVPN Service (VyprVPN).
#
# This installation assumes the following:
# - You have a Rapsberry Pi and you want to use it as a VPN gateway
# - The gateway should be accessable within a dedicated VPN-only WiFi SSID
# - The Pi is connected via Ethernet to your home network
# - The WiFi stick is a RTL8188CUS 802.11n WLAN Adapter
# - You are using https://www.goldenfrog.com/vyprvpn as VPN Provider
# - You are using OpenVPN as VPN Client
# - You have already installed Raspbian
#
# At end of installation and reboot, test services
# - sudo service hostapd status [OK]
# - sudo service isc-dhcp-server status [OK]
# - sudo service openvpn status [OK]
# - curl icanhazip.com [Should show VPN IP]
# - open http://ipleak.net on browser to check for leaking DNS requests
#
# Sources
# - http://blog.frd.mn/raspberry-pi-vpn-gateway/
# - http://makezine.com/projects/browse-anonymously-with-a-diy-raspberry-pi-vpntor-router/
# - https://support.goldenfrog.com/hc/en-us/articles/204088603-OpenVPN
#

if [ ! -f /tmp/Rpi_Wireless_VPN_Setup/config.conf ]; then
	echo "No config file available: Create config.conf from config_sample.conf"
	exit 1
fi

. /tmp/Rpi_Wireless_VPN_Setup/config.conf
echo "Loaded installation config file"

if [ ${BACKUP} = true ]; then
	echo "Backup set to true. Attempting backup of img"

	if [ /dev/sda1 ]; then
		if [ ${BACKUP_MEDIA_FILESYSTEMTYPE} = 'ntfs' ]; then
			echo "HDD File System Type of NTFS detected. Installing ntfs-3g"
			apt-get install ntfs-3g -y
		
			echo "Mounting external HDD for backup creation"
			mkdir -p /mnt/ext
			sudo chown pi:pi /mnt/ext
			mount -t ntfs-3g -o uid=pi,gid=pi /dev/sda1 /mnt/ext
		else
			echo "Mounting external HDD for backup creation"
			mkdir -p /mnt/ext
			sudo chown pi:pi /mnt/ext
			mount -t vfat -o uid=pi,gid=pi /dev/sda1 /mnt/ext
		fi

		if [ ! -f /mnt/ext/backups ]; then
			echo "Creating backups directory on HDD"
			mkdir /mnt/ext/backups
		fi

		apt-get install pv -y
		echo "Installed pv (Pipe Viewer) to monitor installation progress"

		echo "Creating backup image"
		dd if=/dev/mmcblk0p2 >/dev/null | pv /dev/mmcblk0p2 | md5sum | dd of=/mnt/ext/backups/$(date +%Y%m%d%H%M%S)_pre-install-rpi-wireless-vpn.img bs=1M >/dev/null
		#dd if=/dev/mmcblk0p2 2&gt;/dev/null | pv -tpreb -s {ENTER_SIZE} | dd of=/mnt/ext/backups/$(date +%Y%m%d%H%M%S)_pre-install-rpi-wireless-vpn.img bs=1M 2&gt;/dev/null
		echo "Backup image ${DATETIME}_pre-install-rpi-wireless-vpn.img created successfully on HDD/backups"
	else
		echo "Not creating backup img. No external drive plugged in"
	fi
fi

apt-get update && sudo apt-get upgrade -y
echo "Updated Raspberyy Pi"

apt-get install hostapd isc-dhcp-server -y
echo "Installed hostapd (to create access point) and isc-dhcp-server (to act as DHCP Server)"

cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
echo "Created backup for /etc/dhcp/dhcpd.conf"

sed -i -e 's/option domain-name "example.org";/#option domain-name "example.org";/' /etc/dhcp/dhcpd.conf
sed -i -e 's/option domain-name-servers ns1.example.org, ns2.example.org;/#option domain-name-servers ns1.example.org, ns2.example.org;/' /etc/dhcp/dhcpd.conf
sed -i -e "s/#authoritative;/authoritative;/" /etc/dhcp/dhcpd.conf

# Adding subnet configuration
cat >> /etc/dhcp/dhcpd.conf <<EOF 

subnet ${AP_SUBNET} netmask 255.255.255.0 {
	range ${AP_RANGEMIN} ${AP_RANGEMAX};
	option broadcast-address ${AP_BROADCAST};
	option routers ${AP_ROUTERIP};
	default-lease-time 600;
	max-lease-time 7200;
	option domain-name "local";
	option domain-name-servers 8.8.8.8, 8.8.8.4;
}
EOF
echo "Updated /etc/dhcp/dhcpd.conf"

sed -i -e 's/INTERFACES=""/INTERFACES="wlan0"/' /etc/default/isc-dhcp-server
echo "Updated /etc/default/isc-dhcp-server to use wlan0 as Interfaces"

mv /etc/network/interfaces /etc/network/interfaces.bak
echo "Created backup of /etc/network/interfaces"

cat <<EOF > /etc/network/interfaces
auto lo

iface lo inet loopback
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
	address ${AP_ROUTERIP}
	netmask 255.255.255.0
EOF
echo "Created new file /etc/network/interfaces"

ifconfig wlan0 ${AP_ROUTERIP}
echo "Static IP for wlan0 interface set"

cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
driver=rtl871xdrv
ssid=${WIFI_SSID}
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${WIFI_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
echo "Created /etc/hostapd/hostapd.conf (hostapd configuration)"

sed -i -e 's;#DAEMON_CONF="";DAEMON_CONF="/etc/hostapd/hostapd.conf";' /etc/default/hostapd
echo "Updated /etc/default/hostapd to load correct file"

echo "Downloading custom hostapd driver package for RTL8188CUS 802.11n WLAN Adapter"

# Download the archive
cd /tmp/Rpi_Wireless_VPN_Setup
wget "https://github.com/HoraceWeebler/rtl8188cus/archive/master.zip"

# Extract the archive
unzip master.zip

# Extract custom hostapd
cd rtl8188cus-master/wpa_supplicant_hostapd
tar -xvf wpa_supplicant_hostapd-0.8_rtw_r7475.20130812.tar.gz

# Compile custom hostapd
cd wpa_supplicant_hostapd-0.8_rtw_r7475.20130812/hostapd
make && sudo make install

# Move and adjust permissions
mv hostapd /usr/sbin/hostapd
chown root:root /usr/sbin/hostapd
chmod 755 /usr/sbin/hostapd

echo "Custom hostapd for RTL8188CUS updated"

apt-get install dnsmasq -y
echo "Installed dnsmasq"

cat <<EOF > /etc/dnsmasq.d/dnsmasq.custom.conf
interface=wlan0
dhcp-range=wlan,${AP_RANGEMIN},${AP_RANGEMAX},2h
dhcp-option=3,${AP_ROUTERIP}
dhcp-option=6,${AP_ROUTERIP}
dhcp-authoritative # force clients to grab a new IP
EOF
echo "Added custom dnsmasq config dnsmasq.custom.conf"

cat <<EOF > /etc/resolv.conf
nameserver 192.168.1.1
nameserver 8.8.8.8
nameserver 8.8.8.4
EOF
echo "Used Google Public DNS"

echo "Restarting network interface"
ifdown wlan0
ifup wlan0

apt-get install openvpn -y
echo "Installed OpenVPN"

wget -O /etc/openvpn/ca.vyprvpn.com.crt https://www.goldenfrog.com/downloads/ca.vyprvpn.com.crt
echo "Installed VyprVPN CA Certificate"

cat <<EOF > /etc/openvpn/auth.txt
${VPN_USERNAME}
${VPN_PASSWORD}
EOF
echo "Created /etc/openvpn/auth.txt for VyprVPN credentials"

cat <<EOF > /etc/openvpn/client.conf
client # client mode
dev tun
proto udp
remote ${VPN_GATEWAY} ${VPN_PORT}
resolv-retry 30 # reconnect when disconnected
nobind
persist-key
persist-tun
ca /etc/openvpn/ca.vyprvpn.com.crt
ns-cert-type server
comp-lzo
auth-user-pass auth.txt
script-security 3
keepalive 5 30
verb 1
log-append /var/log/openvpn-client.log
EOF
echo "Created /etc/openvpn/client.conf config file"

echo "Starting ntp service and set service at boot"
service ntp start
update-rc.d ntp enable

echo "Starting OpenVPN client"
service openvpn start

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
echo "Enabled packet routing"

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE -m comment --comment "Use VPN IP for eth0"
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE -m comment --comment "Use VPN IP for tun0"
iptables -A FORWARD -s ${AP_SUBNET}/24 -i wlan0 -o eth0 -m conntrack --ctstate NEW -j REJECT -m comment --comment "Block traffic from clients to eth0"
iptables -A FORWARD -s ${AP_SUBNET}/24 -i wlan0 -o tun0 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "Allow only traffic from clients to tun0"
echo "iptables rules to forward masquarade/forward traffic set"

echo "Saving iptables rules for next reboot"
iptables-save > /etc/iptables.ipv4.nat

echo "
up iptables-restore < /etc/iptables.ipv4.nat" >> /etc/network/interfaces
echo "Added task to load iptables rules as soon as network interfaces are loaded"

service isc-dhcp-server start
update-rc.d isc-dhcp-server enable
echo "service isc-dhcp-server started and added to start on boot"

service hostapd start
update-rc.d hostapd enable
echo "service hostapd started and added to start on boot"

service dnsmasq start
update-rc.d dnsmasq enable
echo "service dnsmasq started and added to start on boot"

update-rc.d openvpn enable
echo "service openvpn start on boot"

echo "Installation completed. Run sudo reboot now to continue"

exit 0