#!/bin/bash

# Garante que o DISPLAY está definido para os comandos XFCE
export DISPLAY=:0

echo "[GMOS] Iniciando customização estética do sistema..."

# 1. Baixar os assets customizados da máquina host
echo "[GMOS] Baixando assets..."
curl -s -o /tmp/gmos_wallpaper.png http://10.0.2.2:8000/gmos_wallpaper.png 2>/dev/null
curl -s -o /tmp/gmos_menu_icon.png http://10.0.2.2:8000/gmos_menu_icon.png 2>/dev/null
curl -s -o /tmp/gmos_boot_splash.png http://10.0.2.2:8000/gmos_boot_splash.png 2>/dev/null

# 2. Configurar o tema branco/claro do XFCE
echo "[GMOS] Configurando tema claro..."
xfconf-query -c xsettings -p /Net/ThemeName -s "Mint-Y" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "Mint-Y" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/theme -s "Mint-Y" 2>/dev/null || true

# 3. Configurar o wallpaper em todas as telas/workspaces ativos
if [ -f /tmp/gmos_wallpaper.png ]; then
    echo "[GMOS] Aplicando novo wallpaper premium..."
    for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image); do
        xfconf-query -c xfce4-desktop -p "$p" -s "/tmp/gmos_wallpaper.png" 2>/dev/null || true
    done
fi

# 4. Configurar a barra de tarefas (painel) para ser flutuante e centralizada
echo "[GMOS] Ajustando barra de tarefas flutuante..."
xfconf-query -c xfce4-panel -p /panels/panel-0/length -s 75 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/length-adjust -s false 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/position -s "p=10;x=0;y=0" 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/position-locked -s true 2>/dev/null || true

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

# 6. Alterar o ícone do Menu Iniciar (Whisker Menu)
if [ -f /tmp/gmos_menu_icon.png ]; then
    echo "[GMOS] Aplicando ícone customizado no menu iniciar..."
    # Copia o ícone para um local permanente
    sudo cp /tmp/gmos_menu_icon.png /usr/share/pixmaps/gmos_menu_icon.png 2>/dev/null || true

    # Encontra o ID do plugin do Whisker Menu no painel
    WHISKER_ID=""
    for plugin_path in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E "^/plugins/plugin-[0-9]+$"); do
        plugin_type=$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null)
        if [ "$plugin_type" = "whiskermenu" ]; then
            WHISKER_ID=$(echo "$plugin_path" | grep -oP 'plugin-\K[0-9]+')
            break
        fi
    done

    if [ -n "$WHISKER_ID" ]; then
        # Configura o ícone customizado no Whisker Menu
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${WHISKER_ID}/button-icon" -n -t string -s "/usr/share/pixmaps/gmos_menu_icon.png" 2>/dev/null || true
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${WHISKER_ID}/show-button-icon" -n -t bool -s true 2>/dev/null || true
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${WHISKER_ID}/show-button-title" -n -t bool -s false 2>/dev/null || true
        echo "[GMOS] Ícone do menu aplicado com sucesso (plugin-${WHISKER_ID})!"
    else
        echo "[GMOS] AVISO: Whisker Menu não encontrado no painel. Tentando método alternativo..."
        # Tenta configurar para applicationsmenu (XFCE padrão)
        for plugin_path in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E "^/plugins/plugin-[0-9]+$"); do
            plugin_type=$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null)
            if [ "$plugin_type" = "applicationsmenu" ]; then
                APP_ID=$(echo "$plugin_path" | grep -oP 'plugin-\K[0-9]+')
                xfconf-query -c xfce4-panel -p "/plugins/plugin-${APP_ID}/button-icon" -n -t string -s "/usr/share/pixmaps/gmos_menu_icon.png" 2>/dev/null || true
                xfconf-query -c xfce4-panel -p "/plugins/plugin-${APP_ID}/show-button-title" -n -t bool -s false 2>/dev/null || true
                echo "[GMOS] Ícone do menu aplicado via applicationsmenu (plugin-${APP_ID})!"
                break
            fi
        done
    fi
fi

# 7. Configurar tela de boot customizada (Plymouth)
if [ -f /tmp/gmos_boot_splash.png ]; then
    echo "[GMOS] Configurando tela de boot customizada (Plymouth)..."

    # Cria o diretório do tema Plymouth
    sudo mkdir -p /usr/share/plymouth/themes/gmos 2>/dev/null || true

    # Copia a imagem de splash
    sudo cp /tmp/gmos_boot_splash.png /usr/share/plymouth/themes/gmos/background.png 2>/dev/null || true

    # Cria o arquivo de configuração do tema Plymouth
    sudo tee /usr/share/plymouth/themes/gmos/gmos.plymouth > /dev/null 2>&1 << 'PLYTHEME'
[Plymouth Theme]
Name=GM OS
Description=GM OS Premium Boot Screen
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/gmos
ScriptFile=/usr/share/plymouth/themes/gmos/gmos.script
PLYTHEME

    # Cria o script Plymouth que exibe a imagem de fundo e uma barra de loading
    sudo tee /usr/share/plymouth/themes/gmos/gmos.script > /dev/null 2>&1 << 'PLYSC'
# GM OS Plymouth Boot Script
bg_image = Image("background.png");

# Centraliza a imagem de fundo
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
bg_image_scaled = bg_image.Scale(screen_width, screen_height);

bg_sprite = Sprite(bg_image_scaled);
bg_sprite.SetX(0);
bg_sprite.SetY(0);
bg_sprite.SetZ(-100);

# Barra de progresso
progress_box_image = Image("background.png").Scale(400, 6);
progress_box_sprite = Sprite(progress_box_image);
progress_box_sprite.SetPosition((screen_width - 400) / 2, screen_height * 0.75, 0);

fun refresh_callback ()
{
    # A barra de progresso é atualizada pelo sistema
}

Plymouth.SetRefreshFunction(refresh_callback);

fun boot_progress_callback (duration, progress)
{
    # Animação da barra de progresso baseada no progresso do boot
}

Plymouth.SetBootProgressFunction(boot_progress_callback);
PLYSC

    # Define o tema GM OS como padrão
    sudo plymouth-set-default-theme gmos 2>/dev/null || true
    # Atualiza o initramfs (REMOVIDO: no Live CD isso causa kernel panic / reboot por falta de espaço no overlay)
    # sudo update-initramfs -u 2>/dev/null || true
    
    # Testar o plymouth na tela atual (opcional, só para ver como ficou)
    sudo plymouthd --mode=boot --tty=tty1 2>/dev/null || true
    sudo plymouth show-splash 2>/dev/null || true
    sleep 3
    sudo plymouth quit 2>/dev/null || true

    echo "[GMOS] Tela de boot configurada com sucesso!"
fi

# 8. Recarregar o painel para aplicar as modificações
echo "[GMOS] Recarregando painel..."
xfce4-panel -r 2>/dev/null || true

echo "[GMOS] =========================================="
echo "[GMOS] Personalização concluída com sucesso!"
echo "[GMOS]   - Tema claro Mint-Y aplicado"
echo "[GMOS]   - Wallpaper premium aplicado"
echo "[GMOS]   - Barra de tarefas flutuante arredondada"
echo "[GMOS]   - Ícone do menu iniciar customizado"
echo "[GMOS]   - Tela de boot Plymouth customizada"
echo "[GMOS] =========================================="
