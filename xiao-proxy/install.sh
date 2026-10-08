#!/bin/sh
# ============================================
# xiao-proxy 一键部署脚本
# 用法: curl -sSL https://xiao.wisg.cn/install | sh
# ============================================

set -e

BASE_URL="https://xiao.wisg.cn/public/xiao-proxy"
INSTALL_DIR="/opt/xiao-proxy"

echo "========================================="
echo "  xiao-proxy 一键部署"
echo "========================================="

# ---- 检查 Docker ----
if ! command -v docker >/dev/null 2>&1; then
    echo "[错误] 未检测到 Docker，请先安装 Docker。"
    echo "  Ubuntu/Debian: curl -fsSL https://get.docker.com | sh"
    echo "  CentOS/RHEL:   yum install -y docker && systemctl start docker"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "[错误] Docker 未运行或当前用户无权限，请执行:"
    echo "  sudo systemctl start docker"
    echo "  sudo usermod -aG docker \$USER  # 然后重新登录"
    exit 1
fi

# ---- 创建安装目录 ----
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ---- 下载部署文件 ----
echo "[1/4] 下载部署文件..."
curl -fsSL "$BASE_URL/docker-compose.yml" -o docker-compose.yml
curl -fsSL "$BASE_URL/Dockerfile"      -o Dockerfile
echo "      文件已下载到 $INSTALL_DIR"

# ---- 停止旧服务 ----
echo "[2/4] 停止旧服务（如有）..."
docker compose down 2>/dev/null && echo "      旧服务已停止" || echo "      无旧服务"

# ---- 清理旧镜像（重新构建） ----
echo "[3/4] 构建镜像（含 native 模块编译，首次约 3-5 分钟）..."
docker compose build --no-cache

# ---- 启动服务 ----
echo "[4/4] 启动服务..."
docker compose up -d

# ---- 等待服务就绪 ----
echo "等待服务就绪..."
sleep 5

# ---- 检查状态 ----
if docker ps --format '{{.Names}}' | grep -q '^xiao-proxy$'; then
    IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    echo ""
    echo "========================================="
    echo "  xiao-proxy 部署成功！"
    echo "  Web 面板: http://${IP:-localhost}:3000"
    echo "========================================="
    echo ""
    echo "常用命令："
    echo "  查看日志: docker compose -f $INSTALL_DIR/docker-compose.yml logs -f"
    echo "  重启服务: docker compose -f $INSTALL_DIR/docker-compose.yml restart"
    echo "  停止服务: docker compose -f $INSTALL_DIR/docker-compose.yml down"
    echo "  更新重装: curl -sSL https://xiao.wisg.cn/install | sh"
    echo ""
else
    echo "[错误] 服务启动失败，最近日志："
    docker compose logs --tail=30 2>/dev/null || docker logs xiao-proxy --tail=30 2>/dev/null
    exit 1
fi