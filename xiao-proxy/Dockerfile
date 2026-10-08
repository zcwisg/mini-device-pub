# ============================================
# xiao-proxy Dockerfile
# 使用 node:22-slim（Debian/glibc）基础镜像
# serialport + sqlite3 使用预编译二进制，无需编译
# ============================================

FROM node:22-slim

WORKDIR /app

# 仅安装下载工具和 udev 运行时库（串口通信需要）
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip libudev1 && \
    rm -rf /var/lib/apt/lists/*

# 下载并解压源码
RUN wget -O /tmp/xiao-proxy.zip https://xiao.wisg.site/public/xiao-proxy/xiao-proxy-linux.zip && \
    unzip /tmp/xiao-proxy.zip -d /app && \
    rm /tmp/xiao-proxy.zip

# 安装依赖（预编译二进制自动下载，无需 python/make/g++）
RUN npm install --production && npm cache clean --force

ENV NODE_ENV=production
ENV TZ=Asia/Shanghai

CMD ["node", "server.js"]