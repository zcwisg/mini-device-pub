#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="$(pwd -P)"
ZIP_URL="http://101.201.102.149:9999/down/z75jtoafI7iy.zip"
SERVICE="xiao-proxy.service"
UPDATE_SERVICE="xiao-proxy-update.service"

fail() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

[[ "$EUID" -eq 0 ]] || fail "请以 root 权限调用更新脚本。"
for cmd in curl unzip systemctl systemd-run mktemp cp chmod rm find readlink cat sleep; do
    command -v "$cmd" >/dev/null 2>&1 || fail "缺少必要命令：$cmd"
done
[[ -f "$TARGET_DIR/xiao-proxy" && -f "$TARGET_DIR/start.sh" ]] || \
    fail "请在程序所在目录运行，当前目录必须包含 xiao-proxy 和 start.sh。"
[[ "$(systemctl show "$SERVICE" --property=LoadState --value)" == "loaded" ]] || \
    fail "$SERVICE 未安装或无法加载。"
SERVICE_DIR="$(systemctl show "$SERVICE" --property=WorkingDirectory --value)"
[[ -n "$SERVICE_DIR" && "$(readlink -f -- "$SERVICE_DIR")" == "$TARGET_DIR" ]] || \
    fail "当前目录与 $SERVICE 的 WorkingDirectory 不一致，拒绝更新。"

# 使用 /run，避免调用方的 PrivateTmp 或退出清理使独立任务无法读取脚本。
WORK_DIR="$(mktemp -d /run/xiao-proxy-update.XXXXXXXX)"
SUBMITTED=0
cleanup_launcher() {
    if [[ "$SUBMITTED" -eq 0 ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}
trap cleanup_launcher EXIT

# 不能仅用 nohup 或 &：停止原服务会杀掉其 cgroup 中的所有子进程。
# 实际更新逻辑复制到临时文件，由独立 systemd 服务执行。
cat > "$WORK_DIR/update.sh" <<'WORKER'
#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="$1"
WORK_DIR="$2"
ZIP_URL="$3"
SERVICE="xiao-proxy.service"
SERVICE_STOPPED=0
PHASE="准备更新"

cleanup() {
    local status=$?
    trap - EXIT
    if [[ "$status" -ne 0 ]]; then
        printf '更新失败，阶段：%s，退出码：%s。\n' "$PHASE" "$status" >&2
        if [[ "$SERVICE_STOPPED" -eq 1 ]]; then
            printf '服务已停止；文件可能尚未完整更新，请检查日志后修复并手动启动。\n' >&2
        fi
    fi
    rm -rf -- "$WORK_DIR" || printf '警告：无法清理临时目录 %s\n' "$WORK_DIR" >&2
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '=== 开始更新 xiao-proxy：%s ===\n' "$TARGET_DIR"
PHASE="下载更新包"
curl -fsSL --connect-timeout 10 --max-time 300 --retry 2 \
    -o "$WORK_DIR/xiao-proxy.zip" "$ZIP_URL"

# 下载和校验期间保留旧服务运行，准备完成后才停服。
PHASE="校验和解压更新包"
unzip -tq "$WORK_DIR/xiao-proxy.zip"
unzip -Z1 "$WORK_DIR/xiao-proxy.zip" > "$WORK_DIR/entries.txt"
while IFS= read -r entry; do
    case "$entry" in
        /*|../*|*/../*|*/..|..|*\*)
            printf '更新包包含不安全的路径：%s\n' "$entry" >&2
            exit 1
            ;;
    esac
done < "$WORK_DIR/entries.txt"
unzip -qo "$WORK_DIR/xiao-proxy.zip" -d "$WORK_DIR/unpacked"
[[ -z "$(find "$WORK_DIR/unpacked" -type l -print -quit)" ]] || {
    printf '更新包不能包含符号链接。\n' >&2
    exit 1
}

PACKAGE_DIR="$WORK_DIR/unpacked"
if [[ -d "$PACKAGE_DIR/xiao-proxy" ]]; then
    PACKAGE_DIR="$PACKAGE_DIR/xiao-proxy"
fi
for file in xiao-proxy start.sh; do
    [[ -f "$PACKAGE_DIR/$file" && -s "$PACKAGE_DIR/$file" ]] || {
        printf '更新包缺少有效的 %s 文件。\n' "$file" >&2
        exit 1
    }
done

PHASE="设置更新文件权限"
chmod -R 777 "$PACKAGE_DIR"

PHASE="停止旧服务"
systemctl stop "$SERVICE"
[[ "$(systemctl show "$SERVICE" --property=ActiveState --value)" == "inactive" ]] || {
    printf '无法确认旧服务已停止，拒绝覆盖文件。\n' >&2
    exit 1
}
SERVICE_STOPPED=1

PHASE="覆盖程序文件"
# 包含隐藏文件，保留更新包未包含的数据；替换文件本身而非写入旧 inode。
cp -a --remove-destination -- "$PACKAGE_DIR/." "$TARGET_DIR/"

PHASE="启动新服务"
systemctl start "$SERVICE"
SERVICE_STOPPED=0
sleep 5
if ! systemctl is-active --quiet "$SERVICE"; then
    systemctl status "$SERVICE" --no-pager || true
    printf '新服务未正常运行，请查看 journalctl -u %s。\n' "$SERVICE" >&2
    exit 1
fi
printf '=== 更新完成，%s 已启动 ===\n' "$SERVICE"
WORKER

# 固定单元名称由 systemd 排他创建，避免并发更新；完成或失败后自动回收。
# --no-block 防止等待 oneshot 完成：原程序必须能及时拿到提交结果。
if ! systemd-run --unit="$UPDATE_SERVICE" --collect --no-block \
    --description="Xiao Proxy 程序更新" \
    --property=Type=oneshot \
    --property=TimeoutStartSec=20min \
    --property=StandardOutput=journal \
    --property=StandardError=journal \
    /bin/bash "$WORK_DIR/update.sh" "$TARGET_DIR" "$WORK_DIR" "$ZIP_URL"; then
    fail "无法提交更新任务，请检查 systemd；若已有更新任务运行，请勿重复调用。"
fi
SUBMITTED=1
printf '更新任务已提交，将由独立服务完成停服、覆盖和重启。\n'

# 等 systemd 创建单元后获取 invocation ID，后续只取本次日志
sleep 0.5
INVOCATION_ID="$(systemctl show "$UPDATE_SERVICE" -p InvocationID --value 2>/dev/null || true)"

printf '等待更新完成...\n'

# 等待服务完成（oneshot 完成 → SubState 变为 dead/exited/failed，--collect 后 show 可能返回空）
while true; do
    STATE="$(systemctl show "$UPDATE_SERVICE" -p SubState --value 2>/dev/null || echo "dead")"
    case "$STATE" in dead|exited|failed) break ;; esac
    sleep 1
done

# 获取退出码
RESULT="$(systemctl show "$UPDATE_SERVICE" -p ExecMainStatus --value 2>/dev/null || echo "unknown")"

# 只输出本次调用的日志
printf '\n========== 更新进度 ==========\n'
if [[ -n "$INVOCATION_ID" && "$INVOCATION_ID" != "0" ]]; then
    journalctl "_SYSTEMD_INVOCATION_ID=$INVOCATION_ID" --no-pager 2>/dev/null || true
else
    journalctl -u "$UPDATE_SERVICE" --no-pager 2>/dev/null || true
fi

if [[ "$RESULT" == "0" ]]; then
    printf '\n========== 更新成功 ==========\n'
else
    printf '\n========== 更新失败（退出码：%s）==========\n' "$RESULT"
fi
