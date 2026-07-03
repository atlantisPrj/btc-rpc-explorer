在 Ubuntu 服务器上安装 **Bitcoin（BTC）区块链 RPC 节点**，通常是安装 **Bitcoin Core（bitcoind）**，然后开启 **JSON-RPC 接口**。

下面按生产环境方式介绍（Ubuntu 22.04/24.04 通用）。

---

# 一、服务器要求

先看配置建议：

| 类型  | 最低       | 推荐       |
| --- | -------- | -------- |
| CPU | 2 Core   | 4–8 Core |
| RAM | 4GB      | 8–32GB   |
| SSD | 1TB NVMe | 2TB NVMe |
| 网络  | 100Mbps  | 1Gbps    |

截至 2026 年：

* Bitcoin 全节点区块链数据已经 **700GB+**
* 建议至少 **1TB SSD**
* RPC 查询较多建议 **2TB NVMe**

查看磁盘：

```bash
df -h
```

---

# 二、安装 Bitcoin Core

更新系统：

```bash
sudo apt update
sudo apt upgrade -y
```

安装依赖：

```bash
sudo apt install curl wget unzip jq -y
```

---

## 方法1（推荐）：下载官方预编译版本

去官方发布页：

```text
https://bitcoincore.org/en/download/
```

下载最新版（示例）：

```bash
cd /tmp

wget https://bitcoincore.org/bin/bitcoin-core-29.0/bitcoin-29.0-x86_64-linux-gnu.tar.gz
```

解压：

```bash
tar -xvf bitcoin-29.0-x86_64-linux-gnu.tar.gz
```

安装：

```bash
sudo install -m 0755 -o root -g root -t /usr/local/bin \
bitcoin-29.0/bin/*
```

检查：

```bash
bitcoind --version
```

例如：

```text
Bitcoin Core version v29.0
```

---

# 三、创建节点目录

建立配置目录：

```bash
mkdir -p ~/.bitcoin
```

创建配置文件：

```bash
nano ~/.bitcoin/bitcoin.conf
```

写入：

```ini
server=1

daemon=1

txindex=1

rpcuser=btcuser
rpcpassword=StrongPassword123456

rpcallowip=127.0.0.1

rpcbind=127.0.0.1

rpcport=8332
```

说明：

| 参数           | 作用        |
| ------------ | --------- |
| server=1     | 开启 RPC    |
| daemon=1     | 后台运行      |
| txindex=1    | 全交易索引（推荐） |
| rpcuser      | RPC用户名    |
| rpcpassword  | RPC密码     |
| rpcallowip   | RPC允许IP   |
| rpcport=8332 | RPC端口     |

---

## txindex 很重要

如果要做：

* 区块浏览器
* 钱包服务
* 交易查询
* 自定义链分析

建议：

```ini
txindex=1
```

否则很多 RPC 会失败。

---

# 四、启动节点

启动：

```bash
bitcoind
```

查看状态：

```bash
bitcoin-cli getblockchaininfo
```

输出类似：

```json
{
  "chain": "main",
  "blocks": 912345,
  "headers": 912350,
  "verificationprogress": 0.41
}
```

---

# 五、等待同步

首次同步会比较久。

查看同步：

```bash
bitcoin-cli getblockchaininfo
```

重点看：

```json
"verificationprogress"
```

接近：

```text
1.0
```

表示完成。

---

# 六、开放远程 RPC（可选）

如果你的 Golang/Vue/后端程序需要远程调用。

编辑：

```bash
nano ~/.bitcoin/bitcoin.conf
```

改成：

```ini
rpcbind=0.0.0.0

rpcallowip=0.0.0.0/0
```

或者限制：

```ini
rpcallowip=192.168.1.0/24
```

重启：

```bash
bitcoin-cli stop

bitcoind
```

---

开放防火墙：

RPC 默认端口：

```text
8332
```

Ubuntu：

```bash
sudo ufw allow 8332/tcp
```

查看：

```bash
sudo ufw status
```

---

生产环境不建议直接暴露公网 RPC。

建议：

* Nginx Reverse Proxy
* VPN
* WireGuard
* 内网访问

---

# 七、测试 RPC

测试：

```bash
curl --user btcuser:StrongPassword123456 \
--data-binary '{"jsonrpc":"1.0","id":"1","method":"getblockcount","params":[]}' \
-H 'content-type:text/plain;' \
http://127.0.0.1:8332/
```

返回：

```json
{
  "result":912345,
  "error":null,
  "id":"1"
}
```

---

# 八、作为 systemd 服务运行（推荐）

创建：

```bash
sudo nano /etc/systemd/system/bitcoind.service
```

内容：

```ini
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]

ExecStart=/usr/local/bin/bitcoind \
-conf=/home/ubuntu/.bitcoin/bitcoin.conf \
-datadir=/home/ubuntu/.bitcoin

ExecStop=/usr/local/bin/bitcoin-cli stop

Restart=always

User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
```

替换：

```text
ubuntu
```

为你的用户名。

加载：

```bash
sudo systemctl daemon-reload
```

启动：

```bash
sudo systemctl enable bitcoind
sudo systemctl start bitcoind
```

查看：

```bash
sudo systemctl status bitcoind
```

---

# 九、RPC 常用命令

当前高度：

```bash
bitcoin-cli getblockcount
```

钱包余额：

```bash
bitcoin-cli getbalances
```

区块信息：

```bash
bitcoin-cli getblockchaininfo
```

内存池：

```bash
bitcoin-cli getmempoolinfo
```

交易详情：

```bash
bitcoin-cli getrawtransaction TXID true
```

网络状态：

```bash
bitcoin-cli getnetworkinfo
```

---

# 十、Golang 调用 BTC RPC

如果你用 Go 开发（你之前做过链项目，可能会用到）。

安装库：

```bash
go get github.com/btcsuite/btcd/rpcclient
```

示例：

```go
package main

import (
    "fmt"
    "github.com/btcsuite/btcd/rpcclient"
)

func main() {

    connCfg := &rpcclient.ConnConfig{
        Host:         "127.0.0.1:8332",
        User:         "btcuser",
        Pass:         "StrongPassword123456",
        HTTPPostMode: true,
        DisableTLS:   true,
    }

    client, err := rpcclient.New(connCfg, nil)
    if err != nil {
        panic(err)
    }

    count, _ := client.GetBlockCount()

    fmt.Println(count)
}
```

---

# 十一、快速部署（Pruned 节点）

如果磁盘空间不足。

配置：

```ini
prune=50000
```

50GB 修剪节点。

优点：

* 节省磁盘

缺点：

不能：

* 全历史查询
* getrawtransaction(txindex)

适合：

* 钱包同步
* 轻量节点

---

# 十二、高性能部署建议

如果你要做：

* 交易平台
* BTC钱包
* 区块浏览器
* 高频RPC服务

推荐：

```ini
txindex=1

dbcache=8192

maxconnections=128
```

并使用：

* NVMe SSD
* 32GB RAM
* 10GbE

---

如果你希望，我还可以继续给你做一个 **“Ubuntu 22.04 一键安装 Bitcoin RPC 节点脚本（systemd + 自动配置 + 自动开启 txindex）”**。
如果你的需求是：

* 配置文件：`/.btcdata/.bitcoin/bitcoin.conf`
* 区块链数据目录：`/.btcdata/.bitcoin`
* 使用 `bitcoind` 后台运行
* 可直接启动 / 停止 / 查看日志

下面给你一个完整可运行脚本。

## `btc-node.sh`

```bash
#!/bin/bash

# ==========================
# Bitcoin Core 启动脚本
# Config + Data Dir:
# /.btcdata/.bitcoin
# ==========================

BTC_DIR="/.btcdata/.bitcoin"
CONF_FILE="${BTC_DIR}/bitcoin.conf"

BITCOIND="/usr/local/bin/bitcoind"
BTC_CLI="/usr/local/bin/bitcoin-cli"

case "$1" in

start)

    mkdir -p "$BTC_DIR"

    echo "Starting Bitcoin node..."

    $BITCOIND \
        -daemon \
        -conf="$CONF_FILE" \
        -datadir="$BTC_DIR"

    sleep 3

    echo "Bitcoin node started."

;;

stop)

    echo "Stopping Bitcoin node..."

    $BTC_CLI \
        -conf="$CONF_FILE" \
        -datadir="$BTC_DIR" \
        stop

;;

restart)

    $0 stop

    sleep 5

    $0 start

;;

status)

    $BTC_CLI \
        -conf="$CONF_FILE" \
        -datadir="$BTC_DIR" \
        getblockchaininfo

;;

info)

    $BTC_CLI \
        -conf="$CONF_FILE" \
        -datadir="$BTC_DIR" \
        getnetworkinfo

;;

logs)

    tail -f ${BTC_DIR}/debug.log

;;

*)

echo "Usage:"
echo "  $0 start"
echo "  $0 stop"
echo "  $0 restart"
echo "  $0 status"
echo "  $0 info"
echo "  $0 logs"

exit 1

;;

esac
```

---

## 使用方法

### 1. 保存脚本

例如：

```bash
nano /root/btc-node.sh
```

粘贴内容。

---

### 2. 赋予执行权限

```bash
chmod +x /root/btc-node.sh
```

---

### 3. 创建配置文件

```bash
mkdir -p /.btcdata/.bitcoin

nano /.btcdata/.bitcoin/bitcoin.conf
```

示例配置：

```ini
server=1
daemon=1

txindex=1

rpcuser=btcuser
rpcpassword=StrongPassword123456

rpcbind=127.0.0.1
rpcallowip=127.0.0.1

rpcport=8332

dbcache=4096
maxconnections=64
```

---

### 4. 启动节点

```bash
/root/btc-node.sh start
```

---

### 5. 查看同步状态

```bash
/root/btc-node.sh status
```

或：

```bash
bitcoin-cli \
-conf=/.btcdata/.bitcoin/bitcoin.conf \
-datadir=/.btcdata/.bitcoin \
getblockchaininfo
```

---

### 6. 查看实时日志

```bash
/root/btc-node.sh logs
```

---

### 7. 停止节点

```bash
/root/btc-node.sh stop
```

---

### 8. 重启节点

```bash
/root/btc-node.sh restart
```

---

如果你希望 **开机自动启动**，可以再配一个 systemd 服务：

`/etc/systemd/system/bitcoind.service`

```ini
[Unit]
Description=Bitcoin Core Node
After=network.target

[Service]

Type=forking

ExecStart=/usr/local/bin/bitcoind \
-daemon \
-conf=/.btcdata/.bitcoin/bitcoin.conf \
-datadir=/.btcdata/.bitcoin

ExecStop=/usr/local/bin/bitcoin-cli \
-conf=/.btcdata/.bitcoin/bitcoin.conf \
-datadir=/.btcdata/.bitcoin stop

Restart=always

User=root
Group=root

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

启用：

```bash
sudo systemctl daemon-reload

sudo systemctl enable bitcoind

sudo systemctl start bitcoind
```

查看状态：

```bash
systemctl status bitcoind
```

这样你的 BTC RPC 节点会完全运行在：

```text
配置文件:
 /.btcdata/.bitcoin/bitcoin.conf

区块数据:
 /.btcdata/.bitcoin/blocks/

链状态:
 /.btcdata/.bitcoin/chainstate/

日志:
 /.btcdata/.bitcoin/debug.log
```

适合服务器部署。

