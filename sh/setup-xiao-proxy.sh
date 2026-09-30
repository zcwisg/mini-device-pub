#!/usr/bin/env bash
sudo -H bash -lc '
set -Eeuo pipefail
cd /opt && \
apt update && \
apt-get install -y unzip network-manager && \
curl -L -O https://xiao.wisg.site/public/xiao-proxy/xiao-proxy-linux.zip \
mkdir -p /opt/xiao-proxy && \
unzip -o xiao-proxy-linux.zip -d /opt/xiao-proxy && \
cd /opt/xiao-proxy && \
chmod -R 777 ./ && \
./install.sh && \

# 添加自启动服务
cat > /etc/systemd/system/xiao-proxy.service <<"EOF"
[Unit]
Description=Xiao Proxy - 微设备免流服务
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/xiao-proxy
ExecStart=/opt/xiao-proxy/start.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 刷新服务并确保不会被 mask
systemctl unmask xiao-proxy || true
systemctl daemon-reload
systemctl enable xiao-proxy || true
systemctl start xiao-proxy || true
systemctl status xiao-proxy --no-pager || true
'

exit 0
