
shadowsocks for EdgeRouter X

安装:
1.修改/config/shadowsocks/conf/shadowsocks.json配置内容
2.把除Readme外的所有文件复制到对应目录结构
3./etc/dnsmasq.conf中添加一条自己ISP的DNS或者公共DNS
server=114.114.114.114
3.chmod添加可执行权限并启动
chmod +x /etc/init.d/shadowsocks
chmod +x /etc/init.d/chinadns
/etc/init.d/shadowsocks start
/etc/init.d/chinadns start

注意:
1.国内外流量自动分流，通过ipset对国内IP进行白名单，不翻墙访问，只有国外流量会走shadowsocks通道翻墙
2.只能对TCP流量翻墙，UDP只有DNS可以通过ss-tunnel翻墙
3.1080端口可以作为socks5翻墙代理使用
4.文件存放在/config目录是因为这个目录备份配置的时候会被一起备份，并且系统升级也不会删除

启动后进程如下(假设ISP DNS设置为114.114.114.114):
/config/shadowsocks/bin/ss-local -u -l 1080 -c /config/shadowsocks/conf/shadowsocks.json -f /var/run/ss-local.pid
/config/shadowsocks/bin/ss-tunnel -u -c /config/shadowsocks/conf/shadowsocks.json -l 5302 -L 8.8.8.8:53 -f /var/run/ss-tunnel.pid
/config/shadowsocks/bin/ss-redir -u -l 1081 -c /config/shadowsocks/conf/shadowsocks.json -f /var/run/ss-redir.pid
/config/shadowsocks/bin/chinadns /var/run/chinadns.pid -p 5301 -s 114.114.114.114,127.0.0.1:5302 -c /config/shadowsocks/conf/chinadns_chnroute.txt

DNS解析过程
chinadns    必须配置至少一个国内DNS，一个国外DNS
dnsmasq  ->    chinadns    (国外IP)->    ss-tunnel   -> ss-server -> dns-server:ok
			   (国内IP)->    114.114.114.114:ok
