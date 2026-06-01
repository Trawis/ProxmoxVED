#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/FilenCloudDienste/filen-webdav

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

NODE_VERSION="20" setup_nodejs

msg_info "Installing Filen WebDAV"
mkdir -p /opt/filen-webdav
cd /opt/filen-webdav
$STD npm install @filen/webdav@latest
msg_ok "Installed Filen WebDAV"

msg_info "Writing server configuration"
cat <<EOF >/opt/filen-webdav/server.js
const { WebDAVServer } = require("@filen/webdav")

// Proxy mode — each WebDAV client authenticates with their own Filen credentials.
const server = new WebDAVServer({
  hostname: "0.0.0.0",
  port: 1900,
  https: false,
  auth: "basic",
  mode: "proxy",
})

server.start()
  .then(() => console.log("Filen WebDAV running on port 1900"))
  .catch((err) => { console.error(err); process.exit(1) })
EOF
msg_ok "Written server.js"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/filen-webdav.service
[Unit]
Description=Filen WebDAV Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/filen-webdav
ExecStart=/usr/bin/node /opt/filen-webdav/server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now filen-webdav
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
