#!/bin/bash
set -e

TARGET_DIR="/opt/xiao-proxy"
ZIP_URL="https://cdn.jsdelivr.net/gh/zcwisg/mini-device-pub/xiao-proxy/update/xiao-proxy-code.zip"
TEMP_DIR=$(mktemp -d)

echo "=== 升级 xiao-proxy ==="

# 1. 下载更新包
echo "下载更新包..."
curl -fsSL -o "$TEMP_DIR/xiao-proxy-code.zip" "$ZIP_URL"

# 2. 解压覆盖到目标目录
echo "解压并覆盖文件..."
unzip -qo "$TEMP_DIR/xiao-proxy-code.zip" -d "$TARGET_DIR"

# 3. 清理临时目录
rm -rf "$TEMP_DIR"

# 4. 设置权限
echo "设置权限..."
chmod -R 777 "$TARGET_DIR"

# 5. 安装依赖
echo "安装依赖..."
cd "$TARGET_DIR"
./install.sh

echo "=== 升级完成 ==="

# 5. 重启服务
echo "重启 xiao-proxy 服务..."
systemctl restart xiao-proxy

# 6. 查看服务状态
systemctl status xiao-proxy