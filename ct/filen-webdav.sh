#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/FilenCloudDienste/filen-webdav

APP="Filen WebDAV"
var_tags="${var_tags:-cloud;webdav;filen}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_nesting="${var_nesting:-0}"
var_fuse="${var_fuse:-no}"
var_tun="${var_tun:-no}"
var_gpu="${var_gpu:-no}"
var_keyctl="${var_keyctl:-0}"
var_mknod="${var_mknod:-0}"
var_protection="${var_protection:-no}"
var_ssh="${var_ssh:-no}"

header_info "$APP"
variables
color
catch_errors

if [[ -z "${FILEN_MODE}" ]]; then
  FILEN_MODE=$(whiptail --radiolist \
    "Select server mode:" 12 55 2 \
    "proxy"      "Proxy — users auth with their own Filen credentials" ON \
    "standalone" "Standalone — single pre-configured Filen account"    OFF \
    --title "Server Mode" 3>&1 1>&2 2>&3) || exit

  if [[ "${FILEN_MODE}" == "standalone" ]]; then
    FILEN_EMAIL=$(whiptail --inputbox \
      "Filen account email:" 8 50 "" \
      --title "Filen Email" 3>&1 1>&2 2>&3) || exit

    FILEN_PASS=$(whiptail --passwordbox \
      "Filen account password:" 8 50 \
      --title "Filen Password" 3>&1 1>&2 2>&3) || exit

    FILEN_2FA=$(whiptail --inputbox \
      "Two-factor code (leave blank if 2FA is disabled):" 8 55 "" \
      --title "2FA Code" 3>&1 1>&2 2>&3) || exit
  fi

  FILEN_PORT=$(whiptail --inputbox \
    "WebDAV listen port:" 8 40 "1900" \
    --title "Port" 3>&1 1>&2 2>&3) || exit
  [[ -z "${FILEN_PORT}" ]] && FILEN_PORT="1900"
fi

FILEN_MODE="${FILEN_MODE:-proxy}"
FILEN_PORT="${FILEN_PORT:-1900}"
FILEN_EMAIL="${FILEN_EMAIL:-}"
FILEN_PASS="${FILEN_PASS:-}"
FILEN_2FA="${FILEN_2FA:-}"

export FILEN_MODE FILEN_PORT FILEN_EMAIL FILEN_PASS FILEN_2FA

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/filen-webdav ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP}"
  cd /opt/filen-webdav
  $STD npm install @filen/webdav@latest
  msg_ok "Updated ${APP}"

  msg_info "Restarting Service"
  systemctl restart filen-webdav
  msg_ok "Service Restarted"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:${FILEN_PORT}${CL}"
