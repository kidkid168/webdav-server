#!/usr/bin/env bash
# 一键部署 WebDAV 服务到当前主机
# 用法：在 VPS 上 root 用户执行
#   curl -fsSL https://raw.githubusercontent.com/kidkid168/webdav-server/claude/determined-hopper-yZ2zH/bootstrap.sh | DOMAIN=webdav.example.com bash
# 或者克隆仓库后：
#   DOMAIN=webdav.example.com ./bootstrap.sh

set -euo pipefail

DOMAIN="${DOMAIN:-}"
WEBDAV_USERNAME="${WEBDAV_USERNAME:-terry}"
INSTALL_DIR="${INSTALL_DIR:-/srv/webdav}"
REPO_URL="${REPO_URL:-https://github.com/kidkid168/webdav-server.git}"
BRANCH="${BRANCH:-claude/determined-hopper-yZ2zH}"

if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: 必须设置 DOMAIN 环境变量，例如：DOMAIN=webdav.example.com $0" >&2
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: 请用 root 执行（或 sudo bash $0）" >&2
  exit 1
fi

echo "==> 1/7 系统信息"
. /etc/os-release
echo "    OS: $PRETTY_NAME"
echo "    Domain: $DOMAIN"
echo "    WebDAV user: $WEBDAV_USERNAME"
echo "    Install dir: $INSTALL_DIR"

echo "==> 2/7 装 Docker（如已装会跳过）"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
else
  echo "    docker 已存在：$(docker --version)"
fi
docker compose version >/dev/null 2>&1 || {
  echo "ERROR: docker compose plugin 不可用" >&2
  exit 1
}

echo "==> 3/7 开 80/443 防火墙端口"
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
fi

echo "==> 4/7 拉代码到 $INSTALL_DIR"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" fetch origin "$BRANCH"
  git -C "$INSTALL_DIR" checkout "$BRANCH"
  git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"

echo "==> 5/7 生成 .env（含随机密码）"
if [[ ! -f .env ]]; then
  PW=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-32)
  cat > .env <<EOF
WEBDAV_USERNAME=$WEBDAV_USERNAME
WEBDAV_PASSWORD=$PW
EOF
  chmod 600 .env
  echo "    新密码已写入 $INSTALL_DIR/.env"
else
  echo "    .env 已存在，保持不变"
fi

echo "==> 6/7 写 Caddyfile"
cat > Caddyfile <<EOF
$DOMAIN {
	reverse_proxy webdav:80
	encode gzip
	log {
		output stdout
		format console
	}
}
EOF

echo "==> 7/7 启动服务"
docker compose pull
docker compose up -d
sleep 3
docker compose ps

echo
echo "===================================================="
echo "部署完成。访问凭证："
echo "  URL:      https://$DOMAIN/"
echo "  用户名:   $(grep WEBDAV_USERNAME .env | cut -d= -f2)"
echo "  密码:     $(grep WEBDAV_PASSWORD .env | cut -d= -f2)"
echo "===================================================="
echo "看证书申请进度： docker compose logs -f caddy"
echo "看 WebDAV 日志：  docker compose logs -f webdav"
