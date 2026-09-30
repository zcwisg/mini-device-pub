#!/bin/bash
set -e

echo "=== 优化 xiao-proxy ==="
#关闭系统自动更新
systemctl stop unattended-upgrades && systemctl disable --now unattended-upgrades && systemctl disable apt-daily-upgrade.timer

# 停止 ModemManager
systemctl stop ModemManager && sudo systemctl disable ModemManager && systemctl mask ModemManager

#apt update && apt install -y unzip network-manager
apt update && apt install -y unzip network-manager