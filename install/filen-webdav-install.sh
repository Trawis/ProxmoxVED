#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/FilenCloudDienste/filen-webdav

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

NODE_VERSION="22" setup_nodejs

FILEN_WEBDAV_VERSION=$(get_latest_github_release "FilenCloudDienste/filen-webdav")
msg_info "Installing Filen WebDAV ${FILEN_WEBDAV_VERSION}"
mkdir -p /opt/filen-webdav
cd /opt/filen-webdav
$STD npm install "@filen/webdav@${FILEN_WEBDAV_VERSION}"
msg_ok "Installed Filen WebDAV ${FILEN_WEBDAV_VERSION}"

msg_info "Writing server configuration"
cat <<EOF >/opt/filen-webdav/server.js
const { WebDAVServer } = require("@filen/webdav")

// Omitting "user" enables multi-account proxy mode.
const server = new WebDAVServer({
  hostname: "0.0.0.0",
  port: 1900,
  https: false,
  authMode: "basic",
})

server
  .start()
  .then(() => console.log("Filen WebDAV running on port 1900"))
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
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
[[ "$(curl -s -o /dev/null -w '%{http_code}' --retry 15 --retry-connrefused --retry-delay 1 --max-time 5 http://127.0.0.1:1900/)" == "401" ]]
cat <<EOF >~/.filen-webdav
${FILEN_WEBDAV_VERSION}
EOF
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
