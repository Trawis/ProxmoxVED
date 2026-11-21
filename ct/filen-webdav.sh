#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/FilenCloudDienste/filen-webdav

APP="Filen-WebDAV"
var_tags="${var_tags:-cloud;webdav;filen}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
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
    msg_error "No Filen WebDAV Installation Found!"
    exit
  fi

  if check_for_gh_release "filen-webdav" "FilenCloudDienste/filen-webdav"; then
    msg_info "Updating Filen WebDAV"
    cd /opt/filen-webdav
    $STD npm install "@filen/webdav@${CHECK_UPDATE_RELEASE#v}"
    msg_ok "Updated Filen WebDAV"

    msg_info "Restarting Filen WebDAV"
    safe_service_restart filen-webdav
    # Every route requires auth, so a 401 challenge means the server is up.
    [[ "$(curl -s -o /dev/null -w '%{http_code}' --retry 15 --retry-connrefused --retry-delay 1 --max-time 5 http://127.0.0.1:1900/)" == "401" ]]
    cat <<EOF >~/.filen-webdav
${CHECK_UPDATE_RELEASE#v}
EOF
    msg_ok "Restarted Filen WebDAV"
    msg_ok "Updated Successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}Filen-WebDAV setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:1900${CL}"
echo -e "${INFO}${YW}Sign in with your Filen email and password=<your password>; keep it on a trusted network.${CL}"
