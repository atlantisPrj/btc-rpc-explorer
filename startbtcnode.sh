#!/bin/bash

# ==========================
# Bitcoin Core 启动脚本
# Config + Data Dir:
# /.btcdata/.bitcoin
# ==========================

BTC_DIR="/.btcdata/.bitcoin"
CONF_FILE="${BTC_DIR}/bitcoin.conf"

BITCOIND="/.btcdata/bin/bitcoind"
BTC_CLI="/.btcdata/bin/bitcoin-cli"

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
