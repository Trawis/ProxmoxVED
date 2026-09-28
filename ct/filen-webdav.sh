#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/FilenCloudDienste/filen-webdav

APP="Filen-WebDAV"
var_tags="${var_tags:-cloud;webdav;filen}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}" # pure Node.js, no native/architecture-specific deps in @filen/sdk or @filen/webdav (re-checked against their current npm dependency trees); not physically run on arm64 hardware
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/filen-webdav ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating Filen WebDAV"
  cd /opt/filen-webdav
  $STD npm install @filen/webdav@latest
  msg_ok "Updated Filen WebDAV"

  msg_info "Restarting Filen WebDAV"
  safe_service_restart filen-webdav
  msg_ok "Restarted Filen WebDAV"
  msg_ok "Updated Successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:1900${CL}"
echo -e "${INFO}${YW}Proxy mode: connect using your Filen email and password as WebDAV credentials.${CL}"
echo -e "${INFO}${YW}Use HTTPS (e.g. a reverse proxy) if this server is reachable outside a trusted LAN — Basic Auth credentials travel in cleartext over plain HTTP.${CL}"
