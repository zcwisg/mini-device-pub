#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="$(pwd -P)"
ZIP_URL="http://101.201.102.149:9999/down/z75jtoafI7iy.zip"
SERVICE="xiao-proxy.service"

fail() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

[[ "$EUID" -eq 0 ]] || fail "请以 root 权限调用更新脚本。"
for cmd in curl unzip systemctl mktemp cp chmod rm find cat sleep; do
    command -v "$cmd" >/dev/null 2>&1 || fail "缺少必要命令：$cmd"
done
[[ "$(systemctl show "$SERVICE" --property=LoadState --value)" == "loaded" ]] || \
    fail "$SERVICE 未安装或无法加载。"

WORK_DIR="$(mktemp -d /run/xiao-proxy-update.XXXXXXXX)"
trap 'rm -rf -- "$WORK_DIR"' EXIT

PHASE="下载更新包"
printf '%s...\n' "$PHASE"
curl -fsSL --connect-timeout 10 --max-time 300 --retry 2 \
    -o "$WORK_DIR/xiao-proxy.zip" "$ZIP_URL"

PHASE="校验和解压更新包"
printf '%s...\n' "$PHASE"
unzip -tq "$WORK_DIR/xiao-proxy.zip"
unzip -Z1 "$WORK_DIR/xiao-proxy.zip" > "$WORK_DIR/entries.txt"
while IFS= read -r entry; do
    case "$entry" in
        /*|../*|*/../*|*/..|..|*\*)
            fail "更新包包含不安全的路径：$entry"
            ;;
    esac
done < "$WORK_DIR/entries.txt"
unzip -qo "$WORK_DIR/xiao-proxy.zip" -d "$WORK_DIR/unpacked"
[[ -z "$(find "$WORK_DIR/unpacked" -type l -print -quit)" ]] || \
    fail "更新包不能包含符号链接。"

PACKAGE_DIR="$WORK_DIR/unpacked"
if [[ -d "$PACKAGE_DIR/xiao-proxy" ]]; then
    PACKAGE_DIR="$PACKAGE_DIR/xiao-proxy"
fi
for file in xiao-proxy start.sh; do
    [[ -f "$PACKAGE_DIR/$file" && -s "$PACKAGE_DIR/$file" ]] || \
        fail "更新包缺少有效的 $file 文件。"
done

PHASE="设置更新文件权限"
printf '%s...\n' "$PHASE"
chmod -R 777 "$PACKAGE_DIR"

PHASE="覆盖程序文件"
printf '%s...\n' "$PHASE"
cp -a --remove-destination -- "$PACKAGE_DIR/." "$TARGET_DIR/"

PHASE="重启服务"
printf '%s...\n' "$PHASE"
systemctl restart "$SERVICE"
sleep 5
if ! systemctl is-active --quiet "$SERVICE"; then
    systemctl status "$SERVICE" --no-pager || true
    fail "新服务未正常运行，请查看 journalctl -u $SERVICE。"
fi

printf '=== 更新完成，%s 已启动 ===\n' "$SERVICE"
rm -f -- "$TARGET_DIR/update-xiao-proxy.sh"
