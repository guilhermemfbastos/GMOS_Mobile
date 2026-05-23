#!/bin/bash

echo "[GMOS] Iniciando customização estética do sistema..."

# 1. Baixar o wallpaper customizado da máquina host
curl -o /tmp/gmos_wallpaper.png http://10.0.2.2:8000/gmos_wallpaper.png

# 2. Configurar o tema branco/claro do XFCE
echo "[GMOS] Configurando tema claro..."
xfconf-query -c xsettings -p /Net/ThemeName -s "Mint-Y"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Mint-Y"
xfconf-query -c xfwm4 -p /general/theme -s "Mint-Y"

# 3. Configurar o wallpaper em todas as telas/workspaces ativos
echo "[GMOS] Aplicando novo wallpaper premium..."
for p in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
    xfconf-query -c xfce4-desktop -p "$p" -s "/tmp/gmos_wallpaper.png"
done

# 4. Configurar a barra de tarefas (painel) para ser flutuante e centralizada
echo "[GMOS] Ajustando barra de tarefas flutuante..."
xfconf-query -c xfce4-panel -p /panels/panel-0/length -s 75
xfconf-query -c xfce4-panel -p /panels/panel-0/length-adjust -s false 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/position -s "p=10;x=0;y=0"
xfconf-query -c xfce4-panel -p /panels/panel-0/position-locked -s true

# 5. Arredondar a barra de tarefas com CSS customizado
echo "[GMOS] Aplicando cantos arredondados na barra de tarefas..."
mkdir -p ~/.config/gtk-3.0
cat << 'EOF' > ~/.config/gtk-3.0/gtk.css
/* Arredondar e dar margem na barra de tarefas */
.xfce4-panel {
    border-radius: 16px;
    margin-bottom: 8px;
    border: 1px solid rgba(255, 255, 255, 0.4);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}
EOF

# 6. Recarregar o painel para aplicar as modificações
xfce4-panel -r

echo "[GMOS] Personalização concluída com sucesso!"
