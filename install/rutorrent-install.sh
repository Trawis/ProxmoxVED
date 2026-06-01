#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Trawis
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Novik/ruTorrent

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

RUTORRENT_USER="${RUTORRENT_USER:-rutorrent}"
RUTORRENT_PASS="${RUTORRENT_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
RUTORRENT_ENABLE_RPC2="${RUTORRENT_ENABLE_RPC2:-no}"
RUTORRENT_ENABLE_REAL_IP="${RUTORRENT_ENABLE_REAL_IP:-no}"

msg_info "Installing Dependencies"
$STD apt install -y \
  screen \
  rtorrent \
  nginx \
  openssl \
  apache2-utils \
  unrar-free \
  mediainfo \
  ffmpeg \
  python3 \
  python3-cloudscraper \
  python-is-python3 \
  sox
msg_ok "Installed Dependencies"

PHP_FPM="YES" setup_php
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

fetch_and_deploy_gh_release "rutorrent" "Novik/ruTorrent" "tarball" "latest" "/var/www/rutorrent"
[[ -f /var/www/rutorrent/index.html ]] || { msg_error "ruTorrent download failed — check network and GitHub API availability"; exit 1; }
chown -R www-data:www-data /var/www/rutorrent

msg_info "Configuring rTorrent"
mkdir -p /var/lib/rtorrent/{downloads,session,.watch}
cat <<EOF >/var/lib/rtorrent/.rtorrent.rc
directory.default.set = /var/lib/rtorrent/downloads
session.path.set = /var/lib/rtorrent/session
network.scgi.open_local = /run/rtorrent/rtorrent.sock
network.port_range.set = 6881-6881
network.port_random.set = no
pieces.hash.on_completion.set = no
schedule2 = watch_directory,5,5,load.start=/var/lib/rtorrent/.watch/*.torrent
execute.nothrow = chmod,666,/run/rtorrent/rtorrent.sock
EOF

cat <<EOF >/etc/systemd/system/rtorrent.service
[Unit]
Description=rTorrent via screen
After=network.target

[Service]
User=root
Group=root
Type=forking
KillMode=none
RuntimeDirectory=rtorrent
RuntimeDirectoryMode=0755
ExecStart=/usr/bin/screen -d -m -S rtorrent /usr/bin/rtorrent
ExecStop=/usr/bin/bash -c 'screen -S rtorrent -X quit || true'
WorkingDirectory=/var/lib/rtorrent
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Configured rTorrent"

msg_info "Configuring ruTorrent"
cat <<'EOF' >/var/www/rutorrent/conf/config.php
<?php
$topDirectory = '/var/lib/rtorrent/downloads';
$scgi_port = 0;
$scgi_host = "unix:///run/rtorrent/rtorrent.sock";
$XMLRPCMountPoint = "/RPC2";
$pathToExternals = array(
    "php"   => "",
    "curl"  => "",
    "gzip"  => "",
    "id"    => "",
    "stat"  => "",
);
$localhosts = array("127.0.0.1", "localhost");
$tempDirectory = null;
$canUseXSendFile = false;
$locale = "UTF-8";
EOF
chown www-data:www-data /var/www/rutorrent/conf/config.php
msg_ok "Configured ruTorrent"

msg_info "Setting up Authentication"
htpasswd -bc /etc/nginx/.rutorrent_htpasswd "${RUTORRENT_USER}" "${RUTORRENT_PASS}"
chmod 640 /etc/nginx/.rutorrent_htpasswd
chown root:www-data /etc/nginx/.rutorrent_htpasswd
msg_ok "Set up Authentication"

msg_info "Configuring PHP-FPM"
PHP_POOL_DIR="/etc/php/${PHP_VER}/fpm/pool.d"
cat <<EOF >"${PHP_POOL_DIR}/rutorrent.conf"
[rutorrent]
user = www-data
group = www-data
listen = /run/php/rutorrent-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
php_admin_value[upload_max_filesize] = 32M
php_admin_value[post_max_size] = 32M
php_admin_value[error_reporting] = E_ERROR
EOF
rm -f "${PHP_POOL_DIR}/www.conf"
msg_ok "Configured PHP-FPM"

msg_info "Configuring nginx"
RPC2_BLOCK=""
[[ "${RUTORRENT_ENABLE_RPC2}" == "yes" ]] && RPC2_BLOCK="
    location /RPC2 {
        include scgi_params;
        scgi_pass unix:///run/rtorrent/rtorrent.sock;
    }
"
REAL_IP_BLOCK=""
[[ "${RUTORRENT_ENABLE_REAL_IP}" == "yes" ]] && REAL_IP_BLOCK="
    set_real_ip_from 127.0.0.1;
    set_real_ip_from 10.0.0.0/8;
    set_real_ip_from 172.16.0.0/12;
    set_real_ip_from 192.168.0.0/16;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
"
cat <<EOF >/etc/nginx/sites-available/rutorrent
server {
    listen 80;
    server_name _;

    root /var/www/rutorrent;
    index index.html index.php;

    client_max_body_size 32M;

    auth_basic "ruTorrent";
    auth_basic_user_file /etc/nginx/.rutorrent_htpasswd;
${REAL_IP_BLOCK}${RPC2_BLOCK}
    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/rutorrent-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
ln -sf /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
msg_ok "Configured nginx"

msg_info "Starting Services"
systemctl enable -q --now rtorrent

for i in {1..15}; do
  [[ -S /run/rtorrent/rtorrent.sock ]] && break
  sleep 1
done
[[ -S /run/rtorrent/rtorrent.sock ]] \
  || msg_warn "rTorrent socket not found after 15 s — check 'systemctl status rtorrent'"

systemctl restart "php${PHP_VER}-fpm"
systemctl enable -q nginx
systemctl restart nginx
msg_ok "Started Services"

motd_ssh
customize
cleanup_lxc
