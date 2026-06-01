# webdav-server

私人 WebDAV 服务，基于 Docker，自动 HTTPS。

栈：`bytemark/webdav`（WebDAV）+ `caddy:2`（反向代理 + Let's Encrypt 自动签发证书）。

## 部署

前置条件：

- 一台 Ubuntu/Debian VPS，开放 80/443
- 一个域名，A 记录已指向 VPS 公网 IP
- 已安装 Docker（含 compose plugin）：`curl -fsSL https://get.docker.com | sh`

步骤：

```bash
git clone <this-repo> /srv/webdav
cd /srv/webdav

# 1. 生成账号密码
cp .env.example .env
sed -i "s|change-me.*|$(openssl rand -base64 24)|" .env
chmod 600 .env

# 2. 配置域名
cp Caddyfile.example Caddyfile
sed -i 's|your.domain.com|实际域名|' Caddyfile

# 3. 启动
docker compose up -d
```

查看密码：`cat .env`

## 验证

```bash
source .env
curl -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" https://your.domain.com/
curl -X PUT -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" --data 'hello' https://your.domain.com/test.txt
curl -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" https://your.domain.com/test.txt
```

客户端挂载：

- macOS Finder：`Cmd+K`，输入 `https://your.domain.com`
- Windows：资源管理器 → 映射网络驱动器
- 第三方：RaiDrive、Cyberduck、Joplin、Obsidian Remotely Save 等

## 日常运维

```bash
docker compose logs -f          # 看日志
docker compose restart          # 重启
docker compose pull && docker compose up -d   # 升级镜像
```

修改密码：编辑 `.env`，然后 `docker compose up -d` 重建容器。

## 目录

```
/srv/webdav/
├── docker-compose.yml
├── Caddyfile               # 真实域名配置（gitignored）
├── .env                    # 账号密码（gitignored）
├── data/                   # 文件实际存储位置（gitignored）
└── caddy/                  # Caddy 证书/缓存（gitignored）
```

## 备份

数据全在 `/srv/webdav/data`，定时 `restic`/`rsync` 这个目录即可。
