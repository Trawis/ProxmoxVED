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

msg_info "Installing Dependencies"
$STD apt install -y \
  screen \
  rtorrent \
  nginx \
  apache2-utils \
  unrar-free \
  mediainfo \
  python3-cloudscraper \
  python-is-python3
msg_ok "Installed Dependencies"

PHP_FPM="YES" setup_php
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

fetch_and_deploy_gh_release "rutorrent" "Novik/ruTorrent" "tarball" "latest" "/var/www/rutorrent"
[[ -f /var/www/rutorrent/index.html ]] || { msg_error "ruTorrent download failed"; exit 1; }
chown -R www-data:www-data /var/www/rutorrent

msg_info "Configuring rTorrent"
mkdir -p /var/lib/rtorrent/{downloads,session,.watch}
cat <<EOF >/root/.rtorrent.rc
directory.default.set = /var/lib/rtorrent/downloads
session.path.set = /var/lib/rtorrent/session
network.scgi.open_local = /run/rtorrent/rtorrent.sock
network.port_range.set = 50000-50000
network.port_random.set = no
pieces.hash.on_completion.set = no
schedule2 = watch_directory,5,5,load.start=/var/lib/rtorrent/.watch/*.torrent
execute.nothrow = chmod,666,/run/rtorrent/rtorrent.sock
EOF
cat <<EOF >/etc/systemd/system/rtorrent.service
[Unit]
Description=rTorrent
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
TimeoutStartSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now rtorrent
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
RUTORRENT_PASS="${RUTORRENT_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 16)}"
$STD htpasswd -bc /etc/nginx/.rutorrent_htpasswd "rutorrent" "${RUTORRENT_PASS}"
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
php_admin_value[error_reporting] = E_ERROR
EOF
rm -f "${PHP_POOL_DIR}/www.conf"
msg_ok "Configured PHP-FPM"

msg_info "Configuring nginx"
cat <<EOF >/etc/nginx/sites-available/rutorrent
server {
    listen 80;
    server_name _;

    root /var/www/rutorrent;
    index index.html index.php;

    auth_basic "ruTorrent";
    auth_basic_user_file /etc/nginx/.rutorrent_htpasswd;

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
systemctl restart "php${PHP_VER}-fpm"
systemctl restart nginx
for i in {1..20}; do
  [[ -S /run/rtorrent/rtorrent.sock ]] && break
  sleep 1
done
[[ -S /run/rtorrent/rtorrent.sock ]] \
  || msg_warn "rTorrent socket not found after 20 s — check 'systemctl status rtorrent'"
msg_ok "Started Services"

motd_ssh
customize
cleanup_lxc
