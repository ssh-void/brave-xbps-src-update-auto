#!/usr/bin/env sh

USERNAME=$(logname)
doas xbps-install -Syu git base-devel xtools-minimal python3
printf "#====================================================================================#\n"
cd /opt/ || exit
doas git clone --depth=1 https://github.com/void-linux/void-packages.git
doas chown -R "$USERNAME":"$USERNAME" void-packages
#git clean -fd && git reset --hard && git pull
printf "#====================================================================================#\n"
cd /opt/void-packages || exit
./xbps-src binary-bootstrap # xbps-src cannot be used as root

cat << 'EOF' > etc/conf
XBPS_ALLOW_RESTRICTED=yes
XBPS_CHROOT_CMD=uchroot
XBPS_CHROOT_CMD_ARGS=-t
XBPS_CFLAGS="-march=native -O3 -pipe"
XBPS_CXXFLAGS="${XBPS_CFLAGS}"
EOF

doas usermod -a -G xbuilder void
printf "#====================================================================================#\n"
cd /opt/void-packages && ./xbps-src -A x86_64 -j "$(nproc)" -f pkg torbrowser-launcher && xi -Syuf torbrowser-launcher
#exemple
#./xbps-src pkg google-chrome && xi google-chrome
#./xbps-src pkg discord && xi discord
./xbps-src bootstrap-update && ./xbps-src update-sys
./xbps-src clean-repocache
#delete .xbps .... clean
