#!/bin/bash
# Script executado via chroot dentro do squashfs

echo "[GMOS-CHROOT] Entrando no ambiente isolado (chroot)..."

# 1. Copiando assets visuais
echo "[GMOS-CHROOT] Instalando assets visuais..."
mkdir -p /usr/share/backgrounds/
mkdir -p /usr/share/pixmaps/

if [ -f /tmp/gmos_wallpaper.png ]; then
    cp /tmp/gmos_wallpaper.png /usr/share/backgrounds/gmos_wallpaper.png
fi

if [ -f /tmp/gmos_menu_icon.png ]; then
    cp /tmp/gmos_menu_icon.png /usr/share/pixmaps/gmos_menu_icon.png
fi

# 2. Configurando cantos arredondados padrão para novos usuários
echo "[GMOS-CHROOT] Configurando CSS global do GTK..."
mkdir -p /etc/skel/.config/gtk-3.0
cat << 'EOF' > /etc/skel/.config/gtk-3.0/gtk.css
/* Arredondar e dar margem na barra de tarefas */
.xfce4-panel {
    border-radius: 16px;
    margin-bottom: 8px;
    border: 1px solid rgba(255, 255, 255, 0.4);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}
EOF

# 3. Criando o script de Primeiro Boot para aplicar as configurações XFCE
# Como o XFCE usa o 'xfconf' que requer o servidor gráfico rodando, a melhor forma 
# de alterar é rodar as configs no exato segundo em que o usuário faz login pela primeira vez.
echo "[GMOS-CHROOT] Criando script de auto-configuração no login..."

cat << 'EOF' > /usr/local/bin/gmos-first-boot.sh
#!/bin/bash
# Aguarda o painel iniciar
sleep 2

# Temas e icones
xfconf-query -c xsettings -p /Net/ThemeName -s "Mint-Y" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "Mint-Y" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/theme -s "Mint-Y" 2>/dev/null || true

# Wallpaper
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image); do
    xfconf-query -c xfce4-desktop -p "$p" -s "/usr/share/backgrounds/gmos_wallpaper.png" 2>/dev/null || true
done

# Barra flutuante centralizada
xfconf-query -c xfce4-panel -p /panels/panel-0/length -s 75 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/length-adjust -s false 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/position -s "p=10;x=0;y=0" 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/position-locked -s true 2>/dev/null || true

# Ícone do Whisker Menu
for plugin_path in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E "^/plugins/plugin-[0-9]+$"); do
    plugin_type=$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null)
    if [ "$plugin_type" = "whiskermenu" ]; then
        WHISKER_ID=$(echo "$plugin_path" | grep -oP 'plugin-\K[0-9]+')
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${WHISKER_ID}/button-icon" -s "/usr/share/pixmaps/gmos_menu_icon.png" 2>/dev/null || true
        break
    fi
done

# Desativa este script para não rodar novamente
rm -f ~/.config/autostart/gmos-first-boot.desktop
EOF

chmod +x /usr/local/bin/gmos-first-boot.sh

# Colocando no autostart do sistema
mkdir -p /etc/xdg/autostart
cat << 'EOF' > /etc/xdg/autostart/gmos-first-boot.desktop
[Desktop Entry]
Type=Application
Name=GM OS Setup
Comment=Aplica customizações no primeiro boot
Exec=/usr/local/bin/gmos-first-boot.sh
OnlyShowIn=XFCE;
Terminal=false
Hidden=false
EOF

# 4. Tema do Plymouth (Tela de carregamento)
echo "[GMOS-CHROOT] Configurando Splash Screen (Plymouth)..."
if [ -f /tmp/gmos_boot_splash.png ]; then
    mkdir -p /usr/share/plymouth/themes/gmos
    
    # Copia a imagem principal
    cp /tmp/gmos_boot_splash.png /usr/share/plymouth/themes/gmos/splash.png
    
    # Cria o arquivo de configuração do plymouth
    cat << 'EOF' > /usr/share/plymouth/themes/gmos/gmos.plymouth
[Plymouth Theme]
Name=GMOS
Description=Tema customizado GM OS
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/gmos
ScriptFile=/usr/share/plymouth/themes/gmos/gmos.script
EOF

    # Cria o script de animação básico do Plymouth
    cat << 'EOF' > /usr/share/plymouth/themes/gmos/gmos.script
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

# Fundo branco
Window.SetBackgroundTopColor(1.0, 1.0, 1.0);
Window.SetBackgroundBottomColor(1.0, 1.0, 1.0);

splash_image = Image("splash.png");
resized_image = splash_image.Scale(screen_width, screen_height);
splash_sprite = Sprite(resized_image);
splash_sprite.SetX(0);
splash_sprite.SetY(0);
EOF

    # Define o tema como padrão e atualiza o initramfs
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/gmos/gmos.plymouth 100
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/gmos/gmos.plymouth
    
    # IMPORTANTE: No ambiente chroot do Codespaces precisamos montar /proc, /sys e /dev
    # O build_offline_iso.sh fará o bind antes do chroot, então podemos rodar o update-initramfs direto!
    update-initramfs -u
fi

echo "[GMOS-CHROOT] Customização concluída!"
