#!/bin/bash
set -e

TARGET_DIR="/opt/xiao-proxy"
REPO_URL="https://ghproxy.net/https://github.com/zcwisg/xiao-proxy.git"
TEMP_DIR=$(mktemp -d)

echo "=== 升级 xiao-proxy ==="

# 1. 进入目标目录
cd "$TARGET_DIR"

# 2. 删除除了 node 和 node_modules 之外的所有文件和目录
echo "清理旧文件（保留 node 和 node_modules）..."
find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'node' ! -name 'node_modules' -exec rm -rf {} +

# 3. 克隆仓库到临时目录
echo "克隆仓库..."
git clone "$REPO_URL" "$TEMP_DIR"

# 4. 复制文件到 /opt/xiao-proxy（排除 .git 目录）
echo "复制新文件..."
shopt -s dotglob
cp -r "$TEMP_DIR"/* "$TARGET_DIR"/
shopt -u dotglob

# 5. 清理临时目录
rm -rf "$TEMP_DIR"

# 6. 设置权限
echo "设置权限..."
chmod -R 777 "$TARGET_DIR"

echo "=== 升级完成 ==="

# 7. 重启服务
echo "重启 xiao-proxy 服务..."
systemctl restart xiao-proxy

# 8. 查看服务状态
systemctl status xiao-proxy