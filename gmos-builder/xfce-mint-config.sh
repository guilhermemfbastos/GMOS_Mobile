#!/bin/sh
# Script de configuração do XFCE com aparência do Linux Mint
# Executado dentro do chroot para configurar o sistema

set -e

echo "[GMOS-MINT] Configurando tema Linux Mint no XFCE..."

# Criar diretórios de configuração
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p /etc/skel/.config/autostart

# Configurar XFCE para usar tema Mint-Y (padrão para novos usuários)
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'XSETTINGS'
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

# Configurar painel do XFCE (estilo Mint - barra inferior)
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position" type="string" value="p=6;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="true"/>
    <property name="size" type="uint" value="30"/>
    <property name="background-style" type="uint" value="0"/>
    <property name="background-color" type="array">
      <value type="uint" value="0"/>
      <value type="uint" value="0"/>
      <value type="uint" value="0"/>
      <value type="uint" value="65535"/>
    </property>
  </property>
</channel>
PANEL

# Configurar desktop do XFCE
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'DESKTOP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="0"/>
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="true"/>
      <property name="show-filesystem" type="bool" value="true"/>
      <property name="show-trash" type="bool" value="true"/>
    </property>
  </property>
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
DESKTOP

# Configurar gerenciador de janelas com botões no estilo Mint (fechar à direita)
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'WM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Mint-Y"/>
    <property name="title_font" type="string" value="Ubuntu Bold 10"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="O|HMC"/>
  </property>
</channel>
WM

echo "[GMOS-MINT] Tema Mint-Y configurado com sucesso!"
