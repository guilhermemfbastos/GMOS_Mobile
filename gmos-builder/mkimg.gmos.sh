#!/bin/sh

# Este arquivo deve ser copiado para /workspace/aports/scripts/mkimg.gmos.sh
# E o perfil deve ser registrado no /workspace/aports/scripts/profiles

profile_gmos() {
    title="GM OS"
    desc="GM OS 1.0 Custom Alpine with XFCE Desktop (Linux Mint Style)"
    
    # Base profile setup - copia a estrutura do profile standard
    local _arch="${APK_ARCH:-$(apk --print-arch)}"
    local _mirror="${REPO_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable}"
    
    # Pacotes básicos do Alpine
    apks="alpine-base alpine-conf alpine-keys busybox openrc"
    # Kernel e firmware (sem linux-firmware-none para evitar conflitos)
    apks="$apks linux-lts linux-firmware"
    # Ambiente gráfico XFCE com display manager
    apks="$apks xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus xorg-server xorg-xinit xf86-video-modesetting xf86-input-libinput eudev"
    # Utilitários e ferramentas
    apks="$apks sudo nano wget curl bash htop shadow mesa-gl mesa-dri-gallium"
    # Fontes
    apks="$apks ttf-dejavu ttf-freefont ttf-ubuntu-font-family"
    # Temas do Linux Mint para aparência idêntica
    apks="$apks mint-themes mint-y-icons mint-x-icons"
    # Configurações adicionais do XFCE
    apks="$apks xfce4-goodies greybird-themes"
    # Suporte a idiomas e teclado ABNT2
    apks="$apks setxkbmap xkeyboard-config"
    
    kernel_flavors="lts"
    kernel_cmdline="console=tty0 hostname=gmos quiet splash"
    syslinux_serial="0 115200"
    apkovl="genapkovl-gmos.sh"
    
    # Define o nome da ISO
    iso_name="gmos-${version}-${_arch}.iso"
}
