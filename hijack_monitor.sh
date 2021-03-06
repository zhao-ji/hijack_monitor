#!/bin/sh
# utf8

# 每日定时任务 追踪最新解封和被封域名

export LC_MESSAGES=C
IGNORE_PATTERN='appspot\|wordpress\|proxy\|youtube\|vpn\|tunnel\|somee\|tumblr'

ALEXA_DOWNLOAD_URL="http://s3.amazonaws.com/alexa-static/top-1m.csv.zip"
TODAY_RECORD="log/$(date +%y_%m_%d_record)"
TODAY_VICTIM="log/$(date +%y_%m_%d_victim)"
TODAY_DIFF="log/$(date +%y_%m_%d_diff)"
YESTERDAY_RECORD="log/$(date -d yesterday +%y_%m_%d_record)"

# 从alexa下载每日更新的全球前1M域名
pushd /home/nightwish/hijack_monitor
wget $ALEXA_DOWNLOAD_URL -O top1m.zip 2> /dev/null
rm top-1m.csv
unzip top1m.zip
touch $TODAY_RECORD $TODAY_VICTIM # $TODAY_DIFF

# 打开监控 关注假域名的返回
(sudo TODAY_RECORD=$TODAY_RECORD TODAY_VICTIM=$TODAY_VICTIM python -c '
from os import environ
import logging
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

from scapy.all import sniff
from scapy.all import IP, UDP, DNS, DNSRR

def store(pkg):
    if pkg.haslayer(UDP) and pkg.haslayer(DNS):
        if pkg[IP].src == "23.252.105.45":
            # print pkg[DNSRR].rrname, pkg[DNSRR].rdata
            v.write(pkg[DNSRR].rdata+"\n")
            r.write(pkg[DNSRR].rrname.rstrip(".")+"\n")

with open(environ["TODAY_RECORD"], "a") as r, open(environ["TODAY_VICTIM"], "a") as v:
    sniff(store=0, filter="src host 23.252.105.45 and udp port 53", prn=store)
' &> /dev/null) &

# 向不存在的DNS服务器查询
cut -d, -f2 top-1m.csv | sudo python -c '
from sys import stdin
import logging
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

from scapy.all import send
from scapy.all import IP, UDP, DNS, DNSQR

for line in stdin:
    dns_query = IP(dst="23.252.105.45")/UDP(dport=53)/DNS(
        rd=1, qd=DNSQR(qname=line.strip()))
    send([dns_query, dns_query, dns_query])
' &> /dev/null

# 休息三分钟后杀掉上个后台任务
# http://stackoverflow.com/questions/1624691/linux-kill-background-task
sleep 2m
sudo kill $!

# 生成差异文件 不包括appspot.com和wordpress.com和一些代理和视频敏感词
{ \
	echo '今日新增'; \
	comm -13 <(sort -u $YESTERDAY_RECORD) <(sort -u $TODAY_RECORD) \
		|grep -v $IGNORE_PATTERN; \
	echo -e '\n\n\n今日消失'; \
	comm -23 <(sort -u $YESTERDAY_RECORD) <(sort -u $TODAY_RECORD) \
		|grep -v $IGNORE_PATTERN; \
} > $TODAY_DIFF

cat $TODAY_DIFF | mail -s "$(date +%y_%m_%d_hijack_diff)" "me@minganci.org"

git add .
git commit -m "add: $(date +%y_%m_%d_hijack_diff)"
git push origin master

popd
