# ============================================
# xiao-proxy Dockerfile（多阶段构建）
# 构建阶段：有编译工具兜底，优先用预编译二进制
# 运行阶段：最小依赖，秒启动
# ============================================

# ---- 构建阶段 ----
FROM node:20-slim AS builder

WORKDIR /app

# 安装构建工具和下载工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget unzip \
        python3 make g++ libudev-dev && \
    rm -rf /var/lib/apt/lists/*

# 下载并解压源码
RUN wget -O /tmp/xiao-proxy.zip https://xiao.wisg.site/public/xiao-proxy/xiao-proxy-linux.zip && \
    unzip /tmp/xiao-proxy.zip -d /app && \
    rm /tmp/xiao-proxy.zip

# 安装依赖（优先下载预编译二进制，若无则从源码编译）
RUN npm install --production && npm cache clean --force

# ---- 运行阶段 ----
FROM node:20-slim

WORKDIR /app

# 仅复制编译好的产物
COPY --from=builder /app /app

# 仅安装运行时库（串口通信需要 libudev）
RUN apt-get update && \
    apt-get install -y --no-install-recommends libudev1 && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
ENV TZ=Asia/Shanghai

CMD ["node", "server.js"]