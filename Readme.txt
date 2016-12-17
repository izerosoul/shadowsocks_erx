
shadowsocks for EdgeRouter X

安装:
1.下载shadowsocks_erx-master.zip并解压
2.用winscp把解压所有文件copy到/tmp目录，然后执行: sudo bash install.sh
3.根据提示输入shadowsocks配置信息，一般只需要输入服务器地址、端口、密码，其它选项可以直接回车使用默认选项。

注意:
1.国内外流量自动分流，通过ipset对国内IP进行白名单，国内IP不会翻墙访问，只有国外流量会走shadowsocks通道翻墙
2.只能对TCP流量翻墙，UDP只有DNS可以通过ss-tunnel翻墙
3.1080端口可以作为socks5翻墙代理使用
4.文件存放在/config目录是因为这个目录备份配置的时候会被一起备份，并且系统升级也不会删除
5.EdgeRouter X EdgeOS v1.8.5,v1.9.0测试通过

启动后进程如下(假设ISP DNS设置为114.114.114.114):
/config/shadowsocks/bin/ss-local -u -l 1080 -c /config/shadowsocks/conf/shadowsocks.json -f /var/run/ss-local.pid
/config/shadowsocks/bin/ss-tunnel -u -c /config/shadowsocks/conf/shadowsocks.json -l 5302 -L 8.8.8.8:53 -f /var/run/ss-tunnel.pid
/config/shadowsocks/bin/ss-redir -u -l 1081 -c /config/shadowsocks/conf/shadowsocks.json -f /var/run/ss-redir.pid
/config/shadowsocks/bin/chinadns /var/run/chinadns.pid -p 5301 -s 114.114.114.114,127.0.0.1:5302 -c /config/shadowsocks/conf/chinadns_chnroute.txt

DNS解析过程
chinadns    必须配置至少一个国内DNS，一个国外DNS
dnsmasq  ->    chinadns    (国外IP)->    ss-tunnel   -> ss-server -> dns-server:ok
			   (国内IP)->    114.114.114.114:ok

