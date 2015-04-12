## Raspberry Pi OpenVPN Wireless Access Point
Allows other devices (mobile, tv, laptop) within your home network to connect to this Raspberry Pi and enjoy secured internet access over VPN.

# Pre-requisites
- Rapsberry Pi
- Wireless USB RTL8188CUS Chipset 802.11n Adapter
- Ethernet port to home network
- OpenVPN Provider
- Raspbian installed

# Important Information
You may need to configure the OpenVPN to that of your provider's. For this installation script, we will be using that of [VyprVPN](https://www.goldenfrog.com/vyprvpn).

# Pre-installation Instructions
- You have already loaded Raspbian on your SD Card
- Ensure that your Raspberry Pi is connected to the internet via Ethernet
- In order to allow backup, ensure you already have USB drive attached

# Installation Instructions

1. Download and extract zip file

    $ cd /tmp
    $ wget https://github.com/mosufy/raspberrypi-vpn-hotspot/archive/master.zip
    $ sudo unzip raspberrypi-vpn-hotspot-master.zip

2. Create config.conf from config_sample.conf

    $ cd raspberrypi-vpn-hotspot-master/src/Rpi_Wireless_VPN_Setup/
    $ sudo cp config_sample.conf config.conf

3. Update config.conf accordingly

    $ sudo vim config.conf

4. Run Install script

    $ sudo bash install.sh

5. Reboot and test

    $ sudo reboot

    $ sudo service hostapd status
    $ [ ok ] hostapd is running.

    $ sudo service isc-dhcp-server status
    $ Status of ISC DHCP server: dhcpd is running.

    $ sudo service openvpn status
    $ [ ok ] VPN 'client' is running.

    - Check the outgoing IP for eth0. Make sure it's the VPN one: 
    
        $ curl icanhazip.com

    - Connect into the new WiFI SSID, open http://ipleak.net and check if there are leaking DNS requests

# Sources
The following sources were used to generate this installation script

- http://blog.frd.mn/raspberry-pi-vpn-gateway/
- http://makezine.com/projects/browse-anonymously-with-a-diy-raspberry-pi-vpntor-router/
- https://support.goldenfrog.com/hc/en-us/articles/204088603-OpenVPN