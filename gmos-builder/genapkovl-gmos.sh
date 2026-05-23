#!/bin/sh -e

HOSTNAME="gmos"

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp"/etc/motd <<EOF

  ____  __  __   ___  ____    _    ___  
 / ___||  \/  | / _ \/ ___|  / |  / _ \ 
| |  _ | |\/| || | | \___ \  | | | | | |
| |_| || |  | || |_| |___) | | | | |_| |
 \____||_|  |_| \___/|____/  |_|  \___/ 
                                        
Bem-vindo ao GM OS 1.0 (Alpine Linux Custom)
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF

# Configurar LightDM para login automático do usuário gmos
mkdir -p "$tmp"/etc/lightdm
makefile root:root 0644 "$tmp"/etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=gmos
autologin-user-timeout=0
user-session=xfce
EOF

# Script que roda no boot para criar o usuário gmos, se não existir
mkdir -p "$tmp"/etc/local.d
makefile root:root 0755 "$tmp"/etc/local.d/gmos-setup.start <<EOF
#!/bin/sh
if ! id gmos >/dev/null 2>&1; then
    adduser -D -g "GM OS User" -s /bin/bash gmos
    echo "gmos:gmos" | chpasswd
    addgroup -S autologin 2>/dev/null || true
    addgroup gmos autologin
    addgroup gmos wheel
    addgroup gmos video
    addgroup gmos audio
    addgroup gmos input
    echo "gmos ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/gmos
    chmod 0440 /etc/sudoers.d/gmos
fi
EOF

# Serviços a iniciar
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add udev sysinit
rc_add udev-trigger sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

rc_add networking default
rc_add local default
rc_add dbus default
rc_add lightdm default

tar -c -C "$tmp" etc | gzip -9n > $1
