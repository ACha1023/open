#!/usr/bin/env bash
# 獨立版 nginx 升級腳本：自己上網抓 nginx 原始碼 + nginx-http-flv-module，編譯後換 binary。
# 保留現有 conf，只換 sbin/nginx，含安全檢查與備份/回滾。
# 用法： sudo bash upgrade_nginx_1_29_8.sh
#   可選環境變數： NGX_VER / FLV_VER / FLV_LOCAL
set -euo pipefail

NGX_VER="${NGX_VER:-1.29.8}"
FLV_VER="${FLV_VER:-1.2.11}"
WORK=/tmp/nginxup
PREFIX=/usr/local/nginx
BAK="$PREFIX/sbin/nginx.$(date +%F-%H%M).bak"

# 升級前建議先看現有編譯參數，確認沒有別的模組會被漏掉：
#   /usr/local/nginx/sbin/nginx -V

echo "[0] 準備工作目錄 $WORK"
rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"

echo "[1] 下載 nginx-$NGX_VER 原始碼"
wget -q "http://nginx.org/download/nginx-$NGX_VER.tar.gz"
tar xzf "nginx-$NGX_VER.tar.gz"

if [ -n "${FLV_LOCAL:-}" ]; then
  FLV_DIR="$FLV_LOCAL"
  echo "[2] 使用本機既有 flv 模組：$FLV_DIR"
else
  echo "[2] 下載 nginx-http-flv-module v$FLV_VER"
  wget -qO flv.tar.gz "https://github.com/winshining/nginx-http-flv-module/archive/refs/tags/v$FLV_VER.tar.gz"
  tar xzf flv.tar.gz
  FLV_DIR="$WORK/nginx-http-flv-module-$FLV_VER"
fi

cd "nginx-$NGX_VER"
echo "[3] configure（--add-module=$FLV_DIR --with-http_ssl_module）"
./configure --add-module="$FLV_DIR" --with-http_ssl_module
echo "[4] make"
make -j"$(nproc)"

echo "[5] 安全檢查：用新 binary 測現有設定檔（不過就中止、不換）"
./objs/nginx -p "$PREFIX" -c "$PREFIX/conf/nginx.conf" -t

echo "[6] 備份舊 binary + 換新（conf 不動）"
cp "$PREFIX/sbin/nginx" "$BAK"
install -m 0755 objs/nginx "$PREFIX/sbin/nginx"

echo "[7] 重啟並驗證"
systemctl restart nginx
sleep 1
"$PREFIX/sbin/nginx" -V
systemctl status nginx --no-pager --lines=5 || true
echo "完成：nginx 已升級到 $NGX_VER"
echo "回滾：sudo cp $BAK $PREFIX/sbin/nginx && sudo systemctl restart nginx"
