#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/Novik/ruTorrent

APP="ruTorrent"
var_tags="${var_tags:-torrent}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified

header_info "$APP"
variables
color
catch_errors

export var_rutorrent_pass="${var_rutorrent_pass:-$(random_password 16)}"

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /var/www/rutorrent ]]; then
    msg_error "No ruTorrent Installation Found!"
    exit
  fi

  if check_for_gh_release "rutorrent" "Novik/ruTorrent"; then
    create_backup /var/www/rutorrent/conf/config.local.php /var/www/rutorrent/conf/plugins.ini

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "rutorrent" "Novik/ruTorrent" "tarball" "latest" "/var/www/rutorrent"

    restore_backup

    PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    msg_info "Restarting Services"
    safe_service_restart "php${PHP_VER}-fpm"
    safe_service_restart nginx
    msg_ok "Restarted Services"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}ruTorrent setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}/${CL}"
echo -e "${INFO}${YW}Login: ${BGN}rutorrent / ${var_rutorrent_pass}${CL}"
