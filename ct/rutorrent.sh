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

RUTORRENT_PASS="${RUTORRENT_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
export RUTORRENT_PASS

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /var/www/rutorrent ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "rutorrent" "Novik/ruTorrent"; then
    msg_info "Stopping Service"
    systemctl stop nginx
    msg_ok "Stopped Service"

    msg_info "Backing up Configuration"
    cp /var/www/rutorrent/conf/config.php /opt/rutorrent-config.php.bak 2>/dev/null || true
    cp /var/www/rutorrent/conf/plugins.ini /opt/rutorrent-plugins.ini.bak 2>/dev/null || true
    msg_ok "Backed up Configuration"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "rutorrent" "Novik/ruTorrent" "tarball" "latest" "/var/www/rutorrent"

    msg_info "Restoring Configuration"
    [[ -f /opt/rutorrent-config.php.bak ]] && cp /opt/rutorrent-config.php.bak /var/www/rutorrent/conf/config.php
    [[ -f /opt/rutorrent-plugins.ini.bak ]] && cp /opt/rutorrent-plugins.ini.bak /var/www/rutorrent/conf/plugins.ini
    rm -f /opt/rutorrent-config.php.bak /opt/rutorrent-plugins.ini.bak
    chown -R www-data:www-data /var/www/rutorrent
    msg_ok "Restored Configuration"

    msg_info "Starting Service"
    systemctl start nginx
    msg_ok "Started Service"
    msg_ok "Updated ${APP} successfully"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/${CL}"
echo -e "${INFO}${YW} Username: ${BGN}rutorrent${CL}"
echo -e "${INFO}${YW} Password: ${BGN}${RUTORRENT_PASS}${CL}"
