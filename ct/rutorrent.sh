#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Novik/ruTorrent

APP="ruTorrent"
var_tags="${var_tags:-torrent;bittorrent;download}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

RUTORRENT_USER="${RUTORRENT_USER:-rutorrent}"
RUTORRENT_PASS="${RUTORRENT_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
RUTORRENT_ENABLE_RPC2="${RUTORRENT_ENABLE_RPC2:-no}"
RUTORRENT_ENABLE_REAL_IP="${RUTORRENT_ENABLE_REAL_IP:-no}"
RUTORRENT_MAX_UPLOAD_MB="${RUTORRENT_MAX_UPLOAD_MB:-32}"

export RUTORRENT_USER RUTORRENT_PASS RUTORRENT_ENABLE_RPC2 RUTORRENT_ENABLE_REAL_IP RUTORRENT_MAX_UPLOAD_MB

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /var/www/rutorrent ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "rutorrent" "Novik/ruTorrent"; then
    msg_info "Backing up ruTorrent configuration"
    mkdir -p /root/rutorrent_bak
    cp /var/www/rutorrent/conf/config.php /root/rutorrent_bak/config.php 2>/dev/null || true
    cp /var/www/rutorrent/conf/plugins.ini /root/rutorrent_bak/plugins.ini 2>/dev/null || true
    msg_ok "Backed up ruTorrent configuration"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "rutorrent" "Novik/ruTorrent" "tarball" "latest" "/var/www/rutorrent"

    msg_info "Restoring ruTorrent configuration"
    [[ -f /root/rutorrent_bak/config.php ]] && cp /root/rutorrent_bak/config.php /var/www/rutorrent/conf/config.php
    [[ -f /root/rutorrent_bak/plugins.ini ]] && cp /root/rutorrent_bak/plugins.ini /var/www/rutorrent/conf/plugins.ini
    rm -rf /root/rutorrent_bak
    chown -R www-data:www-data /var/www/rutorrent
    msg_ok "Restored ruTorrent configuration"

    msg_ok "Updated ${APP} successfully"
  fi

  cleanup_lxc
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/${CL}"
echo -e "${INFO}${YW} Username: ${BGN}${RUTORRENT_USER}${CL}"
echo -e "${INFO}${YW} Password: ${BGN}${RUTORRENT_PASS}${CL}"
