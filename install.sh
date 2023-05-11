#!/bin/bash
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

if [[ -f "/root/Xray/xray" ]]; then
    green "File already exist！"
else
    echo "Start downloading xray files..."
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.1/Xray-linux-32.zip
    cd /root
    mkdir ./Xray
    unzip -d /root/Xray Xray-linux-32.zip
    rm Xray-linux-32.zip
    cd /root/Xray
    if [[ -f "xray" ]]; then
        green "download success！"
    else
        red "download faild！"
        exit 1
    fi
fi

read -p "Set the xray reality port number：" port
until [[ ! -z $port ]] && [[ -z $(netstat -tln | grep ":$port") ]]; do
    if [[ -z $port ]]; then
        red "The port number is empty. Please enter a port number within the given range of TG BOT!"
        read -p "Set the xray reality port number：" port
    elif [[ -z $(netstat -tln | grep ":$port") ]]; then
        echo -e "${RED} $port ${PLAIN} The port is not available, please re-enter the port number！"
        read -p "Set the xray reality port number：" port
    fi
done

UUID=$(cat /proc/sys/kernel/random/uuid)
read -rp "Please enter the domain name for configuration fallback [default: www.microsoft.com]: " dest_server
[[ -z $dest_server ]] && dest_server="www.microsoft.com"
short_id=$(dd bs=4 count=2 if=/dev/urandom | xxd -p -c 8)
keys=$(/root/Xray/xray x25519)
private_key=$(echo $keys | awk -F " " '{print $3}')
public_key=$(echo $keys | awk -F " " '{print $6}')
green "private_key: $private_key"
green "public_key: $public_key"
green "short_id: $short_id"

rm -f /root/Xray/config.json
cat << EOF > /root/Xray/config.json
{
  "inbounds": [
      {
          "listen": "0.0.0.0",
          "port": $port,
          "protocol": "vless",
          "settings": {
              "clients": [
                  {
                      "id": "$UUID",
                      "flow": "xtls-rprx-vision"
                  }
              ],
              "decryption": "none"
          },
          "streamSettings": {
              "network": "tcp",
              "security": "reality",
              "realitySettings": {
                  "show": true,
                  "dest": "$dest_server:443",
                  "xver": 0,
                  "serverNames": [
                      "$dest_server"
                  ],
                  "privateKey": "$private_key",
                  "minClientVer": "",
                  "maxClientVer": "",
                  "maxTimeDiff": 0,
                  "shortIds": [
                  "$short_id"
                  ]
              }
          }
      }
  ],
  "outbounds": [
      {
          "protocol": "freedom",
          "tag": "direct"
      },
      {
          "protocol": "blackhole",
          "tag": "blocked"
      }
  ],
  "policy": {
    "handshake": 4,
    "connIdle": 300,
    "uplinkOnly": 2,
    "downlinkOnly": 5,
    "statsUserUplink": false,
    "statsUserDownlink": false,
    "bufferSize": 1024
  }
}
EOF

IP=$(wget -qO- --no-check-certificate -U Mozilla https://api.ip.sb/geoip | sed -n 's/.*"ip": *"\([^"]*\).*/\1/p')
share_link="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#32M-Reality"
echo ${share_link} > /root/Xray/share-link.txt

cat << EOF > /root/Xray/clash-meta.yaml
port: 7890
socks-port: 7891
allow-lan: true
mode: Rule
log-level: info
external-controller: :9090
dns:
    enable: true
    ipv6: false
    default-nameserver: [223.5.5.5, 119.29.29.29]
    enhanced-mode: fake-ip
    fake-ip-range: 198.18.0.1/16
    use-hosts: true
    nameserver: ['https://doh.pub/dns-query', 'https://dns.alidns.com/dns-query']
    fallback: ['https://doh.dns.sb/dns-query', 'https://dns.cloudflare.com/dns-query', 'https://dns.twnic.tw/dns-query', 'tls://8.8.4.4:853']
    fallback-filter: { geoip: true, ipcidr: [240.0.0.0/4, 0.0.0.0/32] }

proxies:
  - name: 32M-Reality
    type: vless
    server: $IP
    port: $port
    uuid: $UUID
    network: tcp
    tls: true
    udp: true
    xudp: true
    flow: xtls-rprx-vision
    servername: $dest_server
    reality-opts:
      public-key: "$public_key"
      short-id: "$short_id"
    client-fingerprint: chrome

proxy-groups:
  - name: 🚀 节点选择
    type: select
    proxies:
      - 32M-Reality
      - DIRECT

rules:
  - GEOIP,CN,DIRECT,no-resolve
  - MATCH,🚀 节点选择
EOF

yellow "Clash Meta configuration file has been saved to /root/Xray/clash-meta.yaml"
yellow "The following is the sharing link for Xray-Reality, which has been saved to /root/Xray/share-link.txt"
red $share_link

rm -f /etc/init.d/xray
cat << EOF > /etc/init.d/xray
#!/sbin/openrc-run
name="xray"
description="Xray Service"

command="/root/Xray/xray"
pidfile="/run/xray.pid"
command_background="yes"
rc_ulimit="-n 30000"
rc_cgroup_cleanup="yes"

depend() {
    need net
    after net
}

stop() {
   ebegin "Stopping xray"
   start-stop-daemon --stop --name xray
   eend $?
}

EOF

chmod u+x /etc/init.d/xray
if ! rc-update show | grep xray | grep 'default' > /dev/null;then
    rc-update add xray default
fi
service xray restart
service xray status

cd /root
