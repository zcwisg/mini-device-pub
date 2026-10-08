# ============================================
# xiao-proxy Dockerfile（多阶段构建）
# 阶段1: 构建 - 编译 native 模块
# 阶段2: 运行 - 最小镜像，秒启动
# ============================================

# ---- 构建阶段 ----
FROM node:22-alpine AS builder

RUN apk add --no-cache python3 make g++ linux-headers eudev-dev udev unzip wget

WORKDIR /app

# 下载并解压源代码
RUN wget -O /tmp/xiao-proxy.zip https://xiao.wisg.site/public/xiao-proxy/xiao-proxy-linux.zip && \
    unzip /tmp/xiao-proxy.zip -d /app && \
    rm /tmp/xiao-proxy.zip

# 安装依赖（编译 native 模块）
RUN npm install --production && npm cache clean --force

# ---- 运行阶段 ----
FROM node:22-alpine

WORKDIR /app

# 仅复制编译好的产物
COPY --from=builder /app /app

# 运行时不需要编译工具，只需 udev 运行时库（串口通信需要）
RUN apk add --no-cache eudev udev

ENV NODE_ENV=production
ENV TZ=Asia/Shanghai

CMD ["node", "server.js"]