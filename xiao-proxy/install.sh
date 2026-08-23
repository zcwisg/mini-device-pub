#!/bin/sh
# ============================================
# xiao-proxy 一键部署脚本
# 用法: curl -sSL https://xiao.wisg.cn/install | sh
# ============================================

set -e

# 检查 Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "[错误] 未检测到 Docker，请先安装 Docker。"
    echo "  Ubuntu: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# 下载 docker-compose.yml
echo "[1/3] 下载 docker-compose.yml..."
curl -fsSL https://xiao.wisg.cn/public/xiao-proxy/docker-compose.yml -o /tmp/xiao-proxy-compose.yml

# 停止旧服务
echo "[2/3] 停止旧服务（如有）..."
docker compose -f /tmp/xiao-proxy-compose.yml down 2>/dev/null || true

# 启动
echo "[3/3] 启动服务..."
docker compose -f /tmp/xiao-proxy-compose.yml up -d

# 等待服务就绪
echo "等待服务就绪..."
sleep 10

# 检查状态
if docker ps --format '{{.Names}}' | grep -q '^xiao-proxy$'; then
    IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    echo ""
    echo "========================================="
    echo "  xiao-proxy 部署成功！"
    echo "  Web 面板: http://${IP:-localhost}:3000"
    echo "  查看日志: docker logs -f xiao-proxy"
    echo "  停止服务: docker compose -f /tmp/xiao-proxy-compose.yml down"
    echo "========================================="
else
    echo "[错误] 服务启动失败，查看日志:"
    docker logs xiao-proxy 2>&1 | tail -30
    exit 1
fi