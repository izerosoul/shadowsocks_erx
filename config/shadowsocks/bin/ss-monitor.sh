#!/bin/sh
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
LOGFILE=/var/log/shadowsocks_monitor.log
COUNT=`wc -l $LOGFILE|awk '{print $1}'`
#clear log if to many logs
if [ $COUNT -gt 1000 ]; then
        echo '' > $LOGFILE
fi

#check if shadowsocks ok
curl --retry 1 --silent --connect-timeout 3 -I www.google.com > /dev/null
if [ "$?" == "0" ]; then
	echo '['$LOGTIME'] No Problem.' >> $LOGFILE
	exit 0
else
	curl --retry 1 --silent --connect-timeout 3 -I www.baidu.com  > /dev/null
	if [ "$?" == "0" ]; then
		echo '['$LOGTIME'] Problem decteted, restarting shadowsocks.'  >> $LOGFILE
		/etc/init.d/shadowsocks restart
	else
		echo '['$LOGTIME'] Network Problem. Do nothing.'  >> $LOGFILE
	fi
fi