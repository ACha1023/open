#!/usr/bin/env bash
# 從原始碼編譯安裝 OpenSSH（portable）：抓官方 tarball、編譯、安裝，
# 並切換到標準常駐 sshd 服務，最後鎖版避免被 apt 降級回舊版。
# 用法： sudo bash install_openssh_10_4p1.sh
#   可選環境變數： SSH_VER
set -euo pipefail

SSH_VER="${SSH_VER:-10.4p1}"
SRC=/usr/local/src

# 1. 裝編譯相依套件
echo "[1] 安裝編譯相依套件"
apt update
apt install -y build-essential zlib1g-dev libssl-dev libpam0g-dev libedit-dev pkg-config

# 2. 下載檔案（別跳過驗證）
echo "[2] 下載 openssh-$SSH_VER 原始碼"
cd "$SRC"
curl -LO "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$SSH_VER.tar.gz"

# 3. 解壓 + configure
echo "[3] 解壓 + configure"
tar xzf "openssh-$SSH_VER.tar.gz"
cd "openssh-$SSH_VER"
./configure \
  --prefix=/usr \
  --sysconfdir=/etc/ssh \
  --with-pam \
  --with-md5-passwords \
  --with-privsep-path=/run/sshd

# 4. 編譯
echo "[4] make"
make -j"$(nproc)"

# 5. 正式安裝
echo "[5] make install + 設定檔語法檢查"
make install
/usr/sbin/sshd -t          # 設定檔語法檢查，必須通過

# 6. 設定 runtime 目錄、切換服務、啟動
echo "[6] 設定 runtime 目錄並切換服務"
# (a) 建 privsep 目錄 + 讓開機自動重建（/run 是 tmpfs，重開機會清空）
mkdir -p /run/sshd && chmod 0755 /run/sshd
echo 'd /run/sshd 0755 root root -' | tee /etc/tmpfiles.d/sshd.conf

# (b) 關掉 socket activation（它佔著 port 22），改用標準常駐 daemon
#     Ubuntu 22.10+/24.04 預設有 ssh.socket；舊版/Debian 沒有的話這行是無害的 no-op
systemctl disable --now ssh.socket || true

# (c) 啟動並設為開機自動起
systemctl enable --now ssh.service
systemctl status ssh.service --no-pager -l   # 要 active (running)

# 7. 擋 apt 之後把它降級回舊版
echo "[7] 鎖住套件版本，避免被 apt 降級"
apt-mark hold openssh-server openssh-client

echo "完成：OpenSSH 已安裝到 $SSH_VER"
