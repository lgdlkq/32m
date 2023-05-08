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

apk add -f openssl curl iproute2

if [[ -f "./Xray/xray" ]]; then
    green "File already exist！"
else
    echo "Start downloading xray files..."
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.1/Xray-linux-32.zip
    mkdir Xray
    unzip -d ./Xray Xray-linux-32.zip
    rm Xray-linux-32.zip
    cd ./Xray
    if [[ -f "xray" ]]; then
        green "download success！"
    else
        red "download faild！"
        exit 1
    fi
fi

read -p "Set the xray reality port number：" port
until [[ ! -z $port ]] && [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
    if [[ -z $port ]]; then
        red "The port number is empty. Please enter a port number within the given range of TG BOT!"
        read -p "Set the xray reality port number：" port
    elif [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
        echo -e "${RED} $port ${PLAIN} The port is not available, please re-enter the port number！"
        read -p "Set the xray reality port number：" port
    fi
done

UUID=$(./xray uuid)
read -rp "Please enter the domain name for configuration fallback [default: www.microsoft.com]: " dest_server
[[ -z $dest_server ]] && dest_server="www.microsoft.com"
short_id=$(openssl rand -hex 8)
keys=$(./xray x25519)
private_key=$(echo $keys | awk -F " " '{print $3}')
public_key=$(echo $keys | awk -F " " '{print $6}')
green "private_key: $private_key"
green "public_key: $public_key"
green "short_id: $short_id"

rm -f config.json
cat << EOF > config.json
{
  "inbounds": [
      {
          "listen": "0.0.0.0",
          "port": 20801,
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
    "bufferSize": 2048
  }
}
EOF

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
EOF
chmod u+x /etc/init.d/xray
rc-update add xray default
service  xray start
service xray status
IP=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
share_link="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#32M-Reality"
echo ${share_link} > /root/Xray/share-link.txt

cat << EOF > /root/Xray/clash-meta.yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: debug
ipv6: false

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
    - 114.114.114.114

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
  - name: Proxy
    type: select
    proxies:
      - Misaka-Reality

rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF

yellow "Clash Meta configuration file has been saved to /root/sing-box/clash-meta.yaml"
yellow "The following is the sharing link for Xray-Reality, which has been saved to /root/Xray/share-link. txt"
red $share_link

cd /root
