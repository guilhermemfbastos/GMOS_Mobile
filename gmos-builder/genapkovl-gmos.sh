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
Interface baseada no Linux Mint
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
greeter-session=lightdm-gtk-greeter
EOF

# Configurar GTK para usar tema Mint-Y por padrão
mkdir -p "$tmp"/etc/gtk-3.0
makefile root:root 0644 "$tmp"/etc/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=Mint-Y
gtk-icon-theme-name=Mint-Y
gtk-font-name=Ubuntu 10
EOF

# Script que roda no boot para criar o usuário gmos e aplicar tema Mint
mkdir -p "$tmp"/etc/local.d
makefile root:root 0755 "$tmp"/etc/local.d/gmos-setup.start << 'SETUPSCRIPT'
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

# Copiar wallpaper para local padrão
if [ -f /usr/share/backgrounds/gmos_wallpaper.png ]; then
    mkdir -p /usr/share/backgrounds
    # Wallpaper já deve estar instalada pelos pacotes
fi

# Aplicar tema Mint-Y automaticamente para o usuário gmos
if [ -d /home/gmos ]; then
    mkdir -p /home/gmos/.config/xfce4/xfconf/xfce-perchannel-xml

    # Configurar XFCE para usar tema Mint-Y
    cat > /home/gmos/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<XSETTINGS
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Mint-Y"/>
    <property name="IconThemeName" type="string" value="Mint-Y"/>
    <property name="CursorThemeName" type="string" value="Mint-Y"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Ubuntu 10"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="96"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
XSETTINGS

    # Configurar gerenciador de janelas com tema Mint-Y
    cat > /home/gmos/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<XFWM4
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Mint-Y"/>
    <property name="title_font" type="string" value="Ubuntu Bold 10"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="O|HMC"/>
  </property>
</channel>
XFWM4

    # Configurar desktop com wallpaper customizado
    cat > /home/gmos/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<XFDESK
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/gmos_wallpaper.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFDESK

    chown -R gmos:gmos /home/gmos/.config
fi

# Executar script de configuração do Mint
if [ -x /usr/local/bin/xfce-mint-config.sh ]; then
    /usr/local/bin/xfce-mint-config.sh
fi
SETUPSCRIPT

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
