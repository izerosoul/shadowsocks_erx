#!/bin/bash
echo Attention: make sure you have change /config/shadowsocks/conf/shadowsocks.json
#copy files
cp -f ./etc/init.d/* /etc/init.d/
cp -rf ./config/shadowsocks /config
chmod +x /etc/init.d/shadowsocks
chmod +x /etc/init.d/chinadns
chmod +x /config/shadowsocks/bin/*

#change dnsmasq config
echo log-facility=/var/log/dnsmasq.log >> /etc/dnsmasq.conf
echo cache-size=1000 >> /etc/dnsmasq.conf
echo no-resolv >> /etc/dnsmasq.conf
echo server=114.114.114.114 >> /etc/dnsmasq.conf

#add auto start
sed -i "s/^exit 0//" /etc/rc.local
echo /etc/init.d/chinadns start >> /etc/rc.local
echo /etc/init.d/shadowsocks start >> /etc/rc.local
echo exit 0 >> /etc/rc.local

#start service
/etc/init.d/shadowsocks start
/etc/init.d/chinadns start
