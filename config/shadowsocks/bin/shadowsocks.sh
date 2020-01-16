#! /bin/sh
### BEGIN INIT INFO
# Provides:          shadowsocks
# Required-Start:    $syslog $time $remote_fs
# Required-Stop:     $syslog $time $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start shadowsocks daemon
### END INIT INFO

PATH=/bin:/usr/bin:/sbin:/usr/sbin
DAEMON_SS_LOCAL=/config/shadowsocks/bin/ss-local
DAEMON_SS_REDIR=/config/shadowsocks/bin/ss-redir
DAEMON_PDNSD=/config/shadowsocks/bin/pdnsd
DAEMON_CHINADNS=/config/shadowsocks/bin/chinadns

#/config/shadowsocks/bin/pdnsd -c /config/shadowsocks/conf/pdnsd.conf
#Change ISPDNS to your ISP dns or public dns, like 1.2.4.8, 114.114.114.114
ISPDNS=114.114.114.114

#This source ip range will not go through shadowsocks, uncomment if you want to use it
#BYPASS_RANGE=192.168.123.0/24
#BYPASS_RANGES=(192.168.100.1 192.168.100.2)

#Make sure your shadowsocks config file is correct!
SSCONFIG=/config/shadowsocks/conf/shadowsocks.json
PDNSD_CONFIG=/config/shadowsocks/conf/pdnsd.conf

#Check ChinaDNS readme page on github to know how to generate latest chnroute.txt
CHNROUTE=/config/shadowsocks/conf/chnroute.txt

PIDFILE_SS_LOCAL=/var/run/ss-local.pid
PIDFILE_SS_REDIR=/var/run/ss-redir.pid
PIDFILE_PDNSD=/var/run/pdnsd.pid
PIDFILE_CHINADNS=/var/run/chinadns.pid

test -x $DAEMON_SS_LOCAL || exit 0
test -x $DAEMON_SS_REDIR || exit 0
test -x $DAEMON_PDNSD || exit 0
test -x $DAEMON_CHINADNS || exit 0

. /lib/lsb/init-functions

#Test if network ready (pppoe)
test_network() {
	curl --retry 1 --silent --connect-timeout 2 -I www.baidu.com  > /dev/null
	if [ "$?" != "0" ]; then
		echo 'network not ready, wait for 5 seconds ...'
		sleep 5
	fi
}

get_server_ip() {
	ss_server_host=`grep -o "\"server\"\s*:\s*\"\?[-0-9a-zA-Z.]\+\"\?" $SSCONFIG|sed -e 's/"//g'|awk -F':' '{print $2}'|sed -e 's/\s//g'`
	if [ -z $ss_server_host ];then
	  echo "Error : ss_server_host is empty"
	  exit 0
	fi

	#test if domain or ip
	if echo $ss_server_host | grep -q '^[^0-9]'; then
	  #echo "ss_server_host : $ss_server_host"
	  ss_server_ip=`getent hosts $ss_server_host | awk '{ print $1 }'`
	else
	  ss_server_ip=$ss_server_host
	fi

	if [ -z "$ss_server_ip" ];then
	  echo "Error : ss_server_ip is empty"
	  exit 0
	fi
}

gen_iplist() {
	cat <<-EOF
		0.0.0.0/8
		10.0.0.0/8
		100.64.0.0/10
		127.0.0.0/8
		169.254.0.0/16
		172.16.0.0/12
		192.168.0.0/16
		224.0.0.0/4
		240.0.0.0/4
		255.255.255.255
		110.232.176.0/22
		$ss_server_ip
		$(cat ${CHNROUTE:=/dev/null} 2>/dev/null)
EOF
}

rules_add() {
	ipset -! -R <<-EOF || return 1
		create ss_ipset_bypass hash:net
		$(gen_iplist | sed -e "s/^/add ss_ipset_bypass /")
EOF
	iptables -t nat -N SHADOWSOCKS && \
	iptables -t nat -A SHADOWSOCKS -m set --match-set ss_ipset_bypass dst -j RETURN && \
	iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports 1081 && \
	iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS && \
	iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
	if [ "$BYPASS_RANGE" ]; then
		iptables -t nat -I SHADOWSOCKS -s $BYPASS_RANGE -j RETURN
	fi
	if [ "$BYPASS_RANGES" ]; then
		for i in "${BYPASS_RANGES[@]}"
		do
			iptables -t nat -I SHADOWSOCKS -s ${i} -j RETURN
		done
	fi
	return $?
}

rules_flush() {
	iptables -t nat -F SHADOWSOCKS
	iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS
	iptables -t nat -D OUTPUT -p tcp -j SHADOWSOCKS
	iptables -t nat -X SHADOWSOCKS
	ipset -X ss_ipset_bypass
	return $?
}

case "$1" in
  start)
	test_network
	get_server_ip
	#echo "ss_server_ip:$ss_server_ip"
	log_daemon_msg "Starting ss-local" "ss-local"
	start-stop-daemon -S -p $PIDFILE_SS_LOCAL --oknodo --startas $DAEMON_SS_LOCAL -- -u -l 1080 -c $SSCONFIG -f $PIDFILE_SS_LOCAL
	log_end_msg $?

	log_daemon_msg "Starting ss-redir" "ss-redir"
	start-stop-daemon -S -p $PIDFILE_SS_REDIR --oknodo --startas $DAEMON_SS_REDIR -- -u -l 1081 -c $SSCONFIG -f $PIDFILE_SS_REDIR
	log_end_msg $?

	log_daemon_msg "Starting pdnsd" "pdnsd"
	start-stop-daemon -S -p $PIDFILE_PDNSD --oknodo --startas $DAEMON_PDNSD -- -c $PDNSD_CONFIG -d -p $PIDFILE_PDNSD
	log_end_msg $?

	log_daemon_msg "Starting chinadns" "chinadns"
	start-stop-daemon -S -p $PIDFILE_CHINADNS --oknodo -b -m $PIDFILE_CHINADNS --startas $DAEMON_CHINADNS -- -p 5301 -s $ISPDNS,127.0.0.1:5302 -c $CHNROUTE
	log_end_msg $?

	log_daemon_msg "Adding iptables rules, ss_server_ip" `for i in $ss_server_ip; do p=$p$i","; done; echo ${p%,}`
	rules_add
	log_end_msg $?

	log_daemon_msg "Change dns config"
	sed -i s/server=$ISPDNS/server=127.0.0.1#5301/ /etc/dnsmasq.conf
	[ 0 == `grep "^server" /etc/dnsmasq.conf|wc -l` ] && echo server=127.0.0.1#5301 >> /etc/dnsmasq.conf
	[ 0 == `grep "^no-resolv" /etc/dnsmasq.conf|wc -l` ] && echo no-resolv >> /etc/dnsmasq.conf
	systemctl restart dnsmasq
	log_end_msg $?


    ;;
  stop)
	log_daemon_msg "Stopping ss-local" "ss-local"
	start-stop-daemon -K -p $PIDFILE_SS_LOCAL --oknodo
	log_end_msg $?
	log_daemon_msg "Stopping ss-redir" "ss-redir"
	start-stop-daemon -K -p $PIDFILE_SS_REDIR --oknodo
	log_end_msg $?
	log_daemon_msg "Stopping pdnsd" "pdnsd"
	start-stop-daemon -K -p $PIDFILE_PDNSD --oknodo
	log_end_msg $?
	log_daemon_msg "Stopping chinadns" "chinadns"
	start-stop-daemon -K -p $PIDFILE_CHINADNS --oknodo
	log_end_msg $?
	log_daemon_msg "Deleteing iptables rules" "rules_flush"
	rules_flush
	log_end_msg $?
	log_daemon_msg "Change dns config"
	sed -i s/server=127.0.0.1#5301/server=$ISPDNS/ /etc/dnsmasq.conf
	[ 0 == `grep "^server" /etc/dnsmasq.conf|wc -l` ] && echo server=$ISPDNS >> /etc/dnsmasq.conf
	systemctl restart dnsmasq
	log_end_msg $?
    ;;
  force-reload|restart)
    $0 stop
    $0 start
    ;;
  status)
    status_of_proc -p $PIDFILE_SS_REDIR $DAEMON_SS_REDIR ss-redir
    status_of_proc -p $PIDFILE_SS_LOCAL $DAEMON_SS_LOCAL ss-local
    status_of_proc -p $PIDFILE_PDNSD $DAEMON_PDNSD pdnsd
    status_of_proc -p $PIDFILE_CHINADNS $DAEMON_CHINADNS chinadns
    ;;
  *)

	echo "Usage: systemctl {start|stop|status}"
    exit 1
    ;;
esac

exit 0
