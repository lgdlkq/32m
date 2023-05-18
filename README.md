# i686架构apline系统节点搭建
## 下述脚本通用命令：
#### 查看运行状态：
```
service xray status
```
#### 启动：
```
service xray start
```
#### 重启：
```
service xray restart
```
#### 停止：
```
service xray stop
```
## xr_install.sh
### 基于xray的vless+reality
#### 执行命令：
```
apk update && wget https://raw.githubusercontent.com/lgdlkq/32m/main/xr_install.sh -O xr_install.sh && ash xr_install.sh
```
#### 完全删除命令：

```
service xray stop
rc-update del xray default
rm -f /etc/init.d/xray
cd /root 
rm -rf ./Xray
```

## apline_vm_ws_tls.sh
### 基于xray的vmess+ws+tls（包含nat端口转发配置，便于将高位端口转发到cf支持的https端口）
#### 前提：
  1. 开始前请在cf中添加域名解析并开启小云朵，ssl选择“完全”；
  2. 在1的基础上依次点击“规则”——>“Origin Rules”——>“创建规则”，填写规则名称，“字段”选择“主机名”，“值”填入前面解析好的域名。“目标端口”选择“重写到”，输入nat小鸡提供的可用高位端口（非ssh端口），最后点击“部署”完成设置；
  3. 此步骤也可在脚本执行完成后配置，注意规则中配置的端口号须保证与nat服务器配置的高位端口一致。

#### 重点说明：
  1. 脚本执行如果nat服务器已完成了端口映射（映射的内部端口为cf支持的https端口），则在脚本执行到“服务商已提供映射或可通过操作面板完成映射？1.是；2.否; other.退出(默认为2)”时输入1；
  2. 如果nat服务器未进行端口映射，但提供了操作面板进行端口映射，则在脚本执行到“服务商已提供映射或可通过操作面板完成映射？1.是；2.否; other.退出(默认为2)”时输入1，并到面板手动配置映射端口；
  3. 否则请默认执行（或输入2），并在接下来输入cloudflare规则配置时的高位端口号。 

#### 完全删除命令：

```
service xray stop
rc-update del xray default
rm -f /etc/init.d/xray
cd /root 
rm -rf ./Xray
iptables -t nat -F PREROUTING
rm -f /etc/iptables/rules.v4
apk del iptables
```

#### 执行命令：

```
apk update && wget https://raw.githubusercontent.com/lgdlkq/32m/main/apline_vm_ws_tls.sh -O apline_vm_ws_tls.sh && ash apline_vm_ws_tls.sh
```

## 其他
写的比较简单，留着给自己做个记录，有时间了再整理整合。
