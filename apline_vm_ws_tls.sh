#!/bin/bash
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

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
    green "xray文件已存在！"
else
    echo "正在获取xray最新版本号..."
    last_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases?include_prereleases=true | sed -n 29p | tr -d ',"' | awk '{print $2}')
    yellow "xray最新版本号为： $last_version"
    echo "开始下载xray文件..."
    wget https://github.com/XTLS/Xray-core/releases/download/$last_version/Xray-linux-32.zip
    cd /root
    mkdir ./Xray
    unzip -d /root/Xray Xray-linux-32.zip
    rm Xray-linux-32.zip
    cd /root/Xray
    if [[ -f "xray" ]]; then
        green "下载成功！"
    else
        red "下载失败！"
        exit 1
    fi
fi

yellow "开始配置nat内部端口..."
read -p "请选择是否使用cloudflare cdn? 1.是；2.否；other.退出(默认使用cloudflare)：" iscf
[[ -z $iscf ]] && iscf=1
if [[ $iscf == 1 ]]; then
    read -p "请输入cf支持的https端口号(443, 2053, 2083, 2087, 2096, 8443. 默认为443)：" in_port
elif [[ $iscf == 2 ]]; then
    read -p "请输入内部端口号（默认为443）：" in_port
else
    exit 1
fi
sign=false
[[ -z $in_port ]] && in_port=443
until $sign; do
    if ! echo "$in_port" | grep -qE '^[0-9]+$';then
        red "错误：端口号必须是数字!"
        read -p "请重新输入内部端口号：" in_port
        continue
    fi
    if [[ $iscf == 1 && ! $in_port == 443 && ! $in_port == 2053 && ! $in_port == 2083 && ! $in_port == 2087 && ! $in_port == 2096 && ! $in_port == 8443 ]]; then
        red "错误：使用cloudflare加速，端口号必须是[443, 2053, 2083, 2087, 2096, 8443]中任意一个未被占用的端口号!"
        read -p "请重新输入内部端口号：" in_port
        continue
    fi
    if [ "$in_port" -lt 1 ] || [ "$in_port" -gt 65535 ]; then
        red "错误：端口号必须介于1~65525之间!"
        read -p "请重新输入内部端口号：" in_port
        continue
    fi
    if [[ -z $(nc -zv 127.0.0.1 $in_port 2>&1 | grep "open") ]]; then
        green "成功：端口号 $in_port 可用!"
        sign=true
    else
        red "错误：$in_port 已被占用！"
        read -p "请重新输入内部端口号：" in_port
    fi
done
green "nat内部端口配置完成！"

yellow "开始进行端口映射..."
read -p "服务商已提供映射或可通过操作面板完成映射？1.是；2.否; other.退出(默认为2)：" map
[[ -z $map ]] && map=2
if [[ $map == 1 ]]; then
    echo "如服务商已提供映射，可直接进行下一步！"
    echo "如果可通过操作面板完成映射，请稍后移步操作面板完成前面设定的nat内部端口 $in_port 和可用的外部端口的映射！"
elif [[ $map == 2 ]]; then
    read -p "请输入nat的外部访问端口：" out_port
    sign=false
    [[ -z $out_port ]] && out_port=443
    until $sign; do
        if ! echo "$out_port" | grep -qE '^[0-9]+$';then
            red "错误：端口号必须是数字!"
            read -p "请重新输入外部端口号：" out_port
            continue
        fi
        if [[ $out_port == $in_port ]]; then
            red "外部映射端口号不能与内部端口号一样!"
            read -p "请重新输入外部端口号：" out_port
            continue
        fi
        if [ "$out_port" -lt 1 ] || [ "$out_port" -gt 65535 ]; then
            red "错误：端口号必须介于1~65525之间!"
            read -p "请重新输入外部端口号：" out_port
            continue
        fi
        if [[ -z $(nc -zv 127.0.0.1 $out_port 2>&1 | grep "open") ]]; then
            green "成功：端口号 $out_port 可用!"
            sign=true
        else
            red "错误：$out_port 已被占用！"
            read -p "请重新输入nat端口号：" out_port
        fi
    done
    apk add iptables
    iptables -t nat -F PREROUTING
    rm -f /etc/iptables/rules.v4
    iptables -t nat -A PREROUTING -p tcp --dport $out_port -j DNAT --to-destination :$in_port
    iptables-save > /etc/iptables/rules.v4
    chmod +x /etc/init.d/iptables
    if ! rc-update show | grep iptables | grep 'default' > /dev/null;then
        rc-update add iptables default
    fi
else
    exit 1
fi
green "已完成端口映射！"

yellow "开始配置证书..."

while true; do
    read -p "请输入已解析完成的域名：" domain
    if [ ! -z "$domain" ]; then
        break
    fi
done

read -p "请选择：1.已上传证书文件，输入证书路径；2.未上传证书，直接输入证书内容.(默认选择1)： " is_path
[[ -z $is_path ]] && is_path=1
if [[ $is_path == 1 ]]; then
    read -p "请输入.crt结尾的证书绝对路径：" cert
    until [[ -f "$cert" ]]; do
        red "找不到文件！请检查输入路径！"
        read -p "请输入.crt结尾的证书绝对路径：" cert
    done
    read -p "请输入.key结尾的证书绝对路径：" key
    until [[ -f "$key" ]]; do
        red "找不到文件！请检查输入路径！"
        read -p "请输入.key结尾的证书绝对路径：" key
    done
else
    echo "请输入证书内容(输入空行结束)："
    while read line; do
    if [[ "$line" == "" ]]; then
        break
    fi
    cert_txt="$cert_txt$line\n"
    done

    rm -f /root/Xray/domain.crt
    echo -e "$cert_txt" >  /root/Xray/domain.crt
    yellow "证书被保存在：/root/Xray/domain.crt"

    echo "请输入对应的key内容(输入空行结束)："
    while read line; do
    if [[ "$line" == "" ]]; then
        break
    fi
    key_txt="$key_txt$line\n"
    done
    rm -f /root/Xray/domain.key
    echo -e "$key_txt" >  /root/Xray/domain.key
    yellow "证书被保存在：/root/Xray/domain.key"
    cert=/root/Xray/domain.crt
    key=/root/Xray/domain.key
fi
green "证书配置完成！"

read -p "请输入path值(以/开始的字符串，默认为/)：" path
[[ -z $path ]] && path="/"

UUID=$(cat /proc/sys/kernel/random/uuid)
green "UUID: $UUID"

rm -f /root/Xray/config.json
cat << EOF > /root/Xray/config.json
{
    "inbounds": [
    {
        "listen": "0.0.0.0",
        "port": $in_port,
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
                    "id": "$UUID"
                }
            ],
            "disableInsecureEncryption": true
        },
        "sniffing": {
            "destOverride": [
            "http",
            "tls",
            "quic"
            ],
            "enabled": true
        },
        "streamSettings": {
            "network": "ws",
            "security": "tls",
            "sockopt": {
                "acceptProxyProtocol": false,
                "domainStrategy": "AsIs",
                "interface": "",
                "tcpFastOpen": true,
                "tcpKeepAliveIdle": 0,
                "tcpKeepAliveInterval": 0,
                "tcpMaxSeg": 1440,
                "tcpUserTimeout": 10000,
                "tcpcongestion": ""
            },
            "wsSettings": {
                "acceptProxyProtocol": false,
                "path": "$path",
                "headers": {
                    "Host": "$domain"
                }
            },
            "tlsSettings": {
                "allowInsecure": false,
                "alpn": [
                    ""
                ],
                "certificates": [
                    {
                        "ocspStapling": 3600,
                        "certificateFile": "$cert",
                        "keyFile": "$key",
                        "certificate": [
                            ""
                        ],
                        "key": [
                            ""
                        ]
                    }
                ],
                "cipherSuites": "",
                "fingerprint": "random",
                "maxVersion": "1.3",
                "minVersion": "1.0",
                "rejectUnknownSni": false,
                "serverName": "$domain"
            }
        }
    }],
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
green "IP为：$IP"

data='{
  "v": "2",
  "ps": "nat",
  "add": "'$domain'",
  "port": "'$in_port'",
  "id": "'$UUID'",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "'$domain'",
  "path": "'$path'",
  "tls": "tls",
  "sni": "",
  "alpn": "",
  "fp": "random"
}'
base=$(echo $data | base64)
share_link="vmess://$base"
rm -f /root/Xray/share-link.txt
echo ${share_link} > /root/Xray/share-link.txt

rm -f /root/Xray/clash.yaml
cat << EOF > /root/Xray/clash.yaml
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
  - name: nat
    type: vmess
    server: $domain
    port: $in_port
    uuid: $UUID
    alterId: 0
    cipher: auto
    udp: true
    servername: $domain
    network: ws
    ws-path: $path
    ws-headers:
      Host: $domain
    ws-opts:
      path: $path
      headers: { Host: $domain }
    tls: true

proxy-groups:
  - name: 🚀 节点选择
    type: select
    proxies:
      - nat
      - DIRECT

rules:
  - GEOIP,CN,DIRECT,no-resolve
  - MATCH,🚀 节点选择
EOF

yellow "Clash yaml配置文件已保存到：/root/Xray/clash.yaml"
yellow "vmess+ws+tls的分享链接已保存到：/root/Xray/share-link.txt"
echo
green "vmess+ws+tls的分享链接为："
red "$share_link" | tr -d '\n'
echo

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
