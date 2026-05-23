#!/bin/sh

profile_gmos() {
    title="GM OS"
    desc="GM OS 1.0 Custom Alpine with XFCE Desktop"
    profile_base
    profile_standard
    apks="$apks alpine-base xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus xorg-server xf86-video-modesetting xf86-video-fbdev xf86-video-vesa xf86-input-libinput eudev sudo nano wget curl bash htop font-dejavu shadow mesa-gl mesa-dri-gallium"
    kernel_flavors="lts"
    kernel_cmdline="unionfs_size=512M console=tty0"
    syslinux_serial="0 115200"
    apkovl="genapkovl-gmos.sh"
}
