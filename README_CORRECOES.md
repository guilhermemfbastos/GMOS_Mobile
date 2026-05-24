# Correções do GM OS - Interface Linux Mint

## Problemas Identificados e Corrigidos

### 1. Perfil não registrado no mkimage.sh
**Problema:** O perfil `gmos` não estava sendo reconhecido pelo sistema de build do Alpine.

**Solução:** O script `docker-build.sh` agora registra automaticamente o perfil `gmos` no `mkimage.sh` antes de iniciar o build.

### 2. Pacote linux-firmware-none conflitando
**Problema:** O pacote `linux-firmware-none` causava conflitos com drivers de hardware.

**Solução:** Substituído por `linux-firmware` que fornece todos os firmwares necessários.

### 3. Pacotes de vídeo desnecessários
**Problema:** Drivers de vídeo específicos (nouveau, ati, etc.) ocupavam espaço sem necessidade.

**Solução:** Mantido apenas `xf86-video-modesetting` que funciona com a maioria das GPUs modernas.

### 4. Tema Mint-Y não aplicado
**Problema:** Os pacotes `mint-themes`, `mint-y-icons` estavam instalados mas não configurados.

**Solução:** 
- Adicionado script `xfce-mint-config.sh` que configura automaticamente o XFCE
- Configurações salvas em `/etc/skel/` para novos usuários
- Tema Mint-Y aplicado para: GTK, ícones, cursor e gerenciador de janelas

### 5. Fontes e layout estilo Mint
**Problema:** Fontes e alinhamento de botões não correspondiam ao Linux Mint.

**Solução:**
- Fonte Ubuntu 10 configurada como padrão
- Layout de botões "O|HMC" (botões à direita como no Mint)
- DPI configurado para 96

## Pacotes Instalados

### Base do Sistema
- alpine-base, alpine-conf, alpine-keys
- busybox, openrc
- linux-lts, linux-firmware

### Ambiente Gráfico
- xfce4, xfce4-terminal
- lightdm, lightdm-gtk-greeter
- xorg-server, xorg-xinit
- xf86-video-modesetting, xf86-input-libinput
- eudev, dbus

### Temas e Aparência (Linux Mint Style)
- mint-themes (temas GTK)
- mint-y-icons (ícones)
- mint-x-icons (ícones adicionais)
- ttf-ubuntu-font-family (fonte Ubuntu)
- ttf-dejavu, ttf-freefont (fontes extras)
- greybird-themes (tema adicional)

### Utilitários
- sudo, nano, wget, curl, bash, htop
- shadow (gerenciamento de usuários)
- mesa-gl, mesa-dri-gallium (aceleração gráfica)
- setxkbmap, xkeyboard-config (teclado ABNT2)
- xfce4-goodies (extras do XFCE)

## Como Funciona a Customização

1. **Build da ISO:** `bash build_gmos.sh` cria a ISO customizada
2. **Primeiro Boot:** Script `gmos-setup.start` cria usuário e aplica configurações
3. **Tema Mint-Y:** Configurado automaticamente para todos os novos usuários via `/etc/skel/`
4. **Wallpaper:** Copiado para `/usr/share/backgrounds/gmos_wallpaper.png`

## Estrutura de Configuração XFCE

As configurações são salvas em XML no formato XFConf:
- `xsettings.xml` - Tema GTK, ícones, fontes
- `xfce4-panel.xml` - Configuração do painel
- `xfce4-desktop.xml` - Wallpaper e ícones do desktop
- `xfwm4.xml` - Tema do gerenciador de janelas

## Resultado Final

Seu GM OS agora tem:
✅ Interface visual idêntica ao Linux Mint
✅ Tema Mint-Y aplicado automaticamente
✅ Ícones Mint-Y
✅ Fonte Ubuntu
✅ Botões de janela no estilo Mint (fechar à direita)
✅ Wallpaper customizado
✅ Login automático no LightDM
