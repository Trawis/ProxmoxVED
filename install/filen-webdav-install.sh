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

FILEN_MODE="${FILEN_MODE:-proxy}"
FILEN_PORT="${FILEN_PORT:-1900}"
FILEN_EMAIL="${FILEN_EMAIL:-}"
FILEN_PASS="${FILEN_PASS:-}"
FILEN_2FA="${FILEN_2FA:-}"

msg_info "Installing Node.js"
$STD curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
$STD apt-get install -y nodejs
msg_ok "Installed Node.js $(node -v)"

msg_info "Installing Filen WebDAV"
mkdir -p /opt/filen-webdav
cd /opt/filen-webdav
$STD npm install @filen/webdav@latest
msg_ok "Installed Filen WebDAV"

msg_info "Writing server configuration"
if [[ "${FILEN_MODE}" == "standalone" ]]; then
  if [[ -n "${FILEN_2FA}" ]]; then
    TFA_LINE="  twoFactorCode: \"${FILEN_2FA}\","
  else
    TFA_LINE=""
  fi

  cat <<EOF >/opt/filen-webdav/server.js
const { WebDAVServer } = require("@filen/webdav")

const server = new WebDAVServer({
  hostname: "0.0.0.0",
  port: ${FILEN_PORT},
  https: false,
  auth: "basic",
  mode: "standalone",
  user: {
    email: "${FILEN_EMAIL}",
    password: "${FILEN_PASS}",
${TFA_LINE}
  },
})

server.start()
  .then(() => console.log("Filen WebDAV running on port ${FILEN_PORT}"))
  .catch((err) => { console.error(err); process.exit(1) })
EOF
else
  cat <<EOF >/opt/filen-webdav/server.js
const { WebDAVServer } = require("@filen/webdav")

// Proxy mode — each WebDAV client authenticates with their own Filen credentials.
const server = new WebDAVServer({
  hostname: "0.0.0.0",
  port: ${FILEN_PORT},
  https: false,
  auth: "basic",
  mode: "proxy",
})

server.start()
  .then(() => console.log("Filen WebDAV running on port ${FILEN_PORT}"))
  .catch((err) => { console.error(err); process.exit(1) })
EOF
fi
chmod 600 /opt/filen-webdav/server.js
msg_ok "Written server.js (mode: ${FILEN_MODE}, port: ${FILEN_PORT})"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/filen-webdav.service
[Unit]
Description=Filen WebDAV Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/filen-webdav
ExecStart=/usr/bin/node /opt/filen-webdav/server.js
Restart=on-failure
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now filen-webdav
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
