#!/bin/sh

# Este arquivo deve ser copiado para /workspace/aports/scripts/mkimg.gmos.sh
# E o perfil deve ser registrado no /workspace/aports/scripts/profiles

profile_gmos() {
    title="GM OS"
    desc="GM OS 1.0 Custom Alpine with XFCE Desktop"
    
    # Base profile setup - copia a estrutura do profile standard
    local _arch="${APK_ARCH:-$(apk --print-arch)}"
    local _mirror="${REPO_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable}"
    
    apks="alpine-base alpine-conf alpine-keys busybox openrc"
    apks="$apks linux-lts linux-firmware-none"
    apks="$apks xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus xorg-server xf86-video-modesetting xf86-input-libinput eudev"
    apks="$apks sudo nano wget curl bash htop font-dejavu shadow mesa-gl mesa-dri-gallium"
    apks="$apks ttf-dejavu gtk-engines murrine-themes"
    
    kernel_flavors="lts"
    kernel_cmdline="console=tty0 hostname=gmos"
    syslinux_serial="0 115200"
    apkovl="genapkovl-gmos.sh"
    
    # Define o nome da ISO
    iso_name="gmos-${version}-${_arch}.iso"
}
