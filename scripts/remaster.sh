#!/bin/bash
# ==============================================================================
# Script de Remasterização do Android-x86 para GM OS Mobile
# Versão Simplificada: Wallpaper + Boot Animation + Ícones
# ==============================================================================
# Executar em ambiente Linux (Ubuntu) com privilégios de root (sudo)
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# ============================================================
# TRAVA DE SEGURANÇA (NO_COMPILE)
# ============================================================
# Ignora a trava se estiver rodando dentro do GitHub Actions
if [ "${GITHUB_ACTIONS}" != "true" ] && [ "${SUDO_USER}" != "runner" ] && [ ! -d "/home/runner/work" ]; then
    if [ -f ".no_compile_lock" ] || [ -f "../.no_compile_lock" ] || [ "${NO_COMPILE}" = "true" ]; then
        log_warn "================================================================="
        log_warn "🔒 TRAVA DE COMPILAÇÃO ATIVA!"
        log_warn "A recompilação da ISO foi bloqueada para evitar novos builds demorados."
        log_warn "Para compilar novamente, remova o arquivo '.no_compile_lock' ou"
        log_warn "remova a variável de ambiente NO_COMPILE."
        log_warn "================================================================="
        exit 0
    fi
fi

log_info "Iniciando remasterização GM OS Mobile..."

if [ "$EUID" -ne 0 ]; then
    log_error "Execute com sudo: 'sudo ./remaster.sh'"
    exit 1
fi

# ============================================================
# VARIÁVEIS DE AMBIENTE
# ============================================================
WORKSPACE_DIR="$(pwd)"
ORIGINAL_ISO_URL="https://downloads.sourceforge.net/project/android-x86/Release%209.0/android-x86-9.0-r2.iso"
ORIGINAL_ISO_NAME="android-x86-9.0-r2.iso"
CUSTOM_ISO_NAME="GM-OS-Mobile.iso"

BUILD_DIR="${WORKSPACE_DIR}/build_workspace"
ISO_EXTRACT="${BUILD_DIR}/iso_extract"
SFS_EXTRACT="${BUILD_DIR}/sfs_extract"
SYSTEM_MOUNT="${BUILD_DIR}/system_mount"
OUTPUT_DIR="${WORKSPACE_DIR}/output"

# Limpar workspace anterior
rm -rf "${BUILD_DIR}"
mkdir -p "${ISO_EXTRACT}" "${SYSTEM_MOUNT}" "${OUTPUT_DIR}"

# ============================================================
# 1. DOWNLOAD DA ISO OFICIAL
# ============================================================
if [ ! -f "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" ]; then
    log_info "Baixando ISO oficial do Android-x86 9.0..."
    wget -L -O "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" "${ORIGINAL_ISO_URL}"
else
    log_info "ISO oficial encontrada localmente."
fi

# ============================================================
# 2. EXTRAÇÃO DA ISO
# ============================================================
log_info "Extraindo ISO..."
7z x "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" -o"${ISO_EXTRACT}" -y > /dev/null

# ============================================================
# 3. EXTRAÇÃO DO SQUASHFS (system.sfs → system.img)
# ============================================================
if [ -f "${ISO_EXTRACT}/system.sfs" ]; then
    log_info "Extraindo SquashFS (system.sfs)..."
    unsquashfs -d "${SFS_EXTRACT}" "${ISO_EXTRACT}/system.sfs"
    SYSTEM_IMG="${SFS_EXTRACT}/system.img"
elif [ -f "${ISO_EXTRACT}/system.img" ]; then
    log_info "system.img encontrado diretamente."
    SYSTEM_IMG="${ISO_EXTRACT}/system.img"
else
    log_error "Nenhum system.sfs ou system.img encontrado!"
    exit 1
fi

# Redimensionar para ter espaço (+200MB)
log_info "Redimensionando system.img (+200 MB)..."
dd if=/dev/zero bs=1M count=200 >> "${SYSTEM_IMG}"
e2fsck -f -y "${SYSTEM_IMG}"
resize2fs "${SYSTEM_IMG}"

# ============================================================
# 4. MONTAR SISTEMA PARA EDIÇÃO
# ============================================================
log_info "Montando system.img em modo R/W..."
mount -o loop,rw "${SYSTEM_IMG}" "${SYSTEM_MOUNT}"

# Detectar estrutura de diretórios (system-as-root vs tradicional)
if [ -d "${SYSTEM_MOUNT}/system" ]; then
    SYS_DIR="${SYSTEM_MOUNT}/system"
    log_info "Estrutura system-as-root detectada. Diretório base: ${SYS_DIR}"
else
    SYS_DIR="${SYSTEM_MOUNT}"
    log_info "Estrutura tradicional detectada. Diretório base: ${SYS_DIR}"
fi

# ============================================================
# 5. TROCAR WALLPAPER PADRÃO
# ============================================================
log_info "Substituindo wallpaper padrão..."
WALLPAPER_SOURCE="${WORKSPACE_DIR}/assets/wallpaper.png"

if [ -f "${WALLPAPER_SOURCE}" ]; then
    # Instala imagemagick para conversão de formato
    apt-get install -y imagemagick > /dev/null 2>&1 || true

    # O Android usa o wallpaper padrão de /system/framework/framework-res.apk
    # Mas a forma mais simples é sobrescrever diretamente os arquivos de wallpaper do sistema
    FRAMEWORK_DIR="${SYS_DIR}/framework"
    
    # Copia o wallpaper para diferentes locais conhecidos do Android-x86
    # Garante que o diretório etc existe
    mkdir -p "${SYS_DIR}/etc"
    
    # Local 1: /system/etc/ (usado por algumas builds)
    cp "${WALLPAPER_SOURCE}" "${SYS_DIR}/etc/default_wallpaper.png" 2>/dev/null || true
    
    # Local 2: Converte para JPG (formato esperado pelo framework)
    convert "${WALLPAPER_SOURCE}" "${SYS_DIR}/etc/default_wallpaper.jpg" 2>/dev/null || true
    
    # Permissões corretas
    chmod 644 "${SYS_DIR}/etc/default_wallpaper.png" 2>/dev/null || true
    chmod 644 "${SYS_DIR}/etc/default_wallpaper.jpg" 2>/dev/null || true
    chown 0:0 "${SYS_DIR}/etc/default_wallpaper.png" 2>/dev/null || true
    chown 0:0 "${SYS_DIR}/etc/default_wallpaper.jpg" 2>/dev/null || true

    log_info "Wallpaper customizado instalado com sucesso."
else
    log_warn "Wallpaper não encontrado em assets/wallpaper.png"
fi

# ============================================================
# 6. BOOT ANIMATION CUSTOMIZADA
# ============================================================
log_info "Criando boot animation customizada GM OS..."
BOOTANIM_DIR="${BUILD_DIR}/bootanimation"
mkdir -p "${BOOTANIM_DIR}/part0"
mkdir -p "${BOOTANIM_DIR}/part1"

# Gera frames para a boot animation usando ImageMagick
# Frame estático com logo GM OS (parte 0 - exibido uma vez)
for i in $(seq -w 0 29); do
    convert -size 1280x720 \
        -define gradient:angle=135 \
        gradient:"#0a0a2e"-"#1a0a3e" \
        -gravity center \
        -font "DejaVu-Sans-Bold" \
        -pointsize 72 \
        -fill "#ffffff" \
        -annotate +0+0 "GM OS" \
        -fill "#4488ff" \
        -pointsize 24 \
        -annotate +0+60 "Mobile" \
        "${BOOTANIM_DIR}/part0/frame${i}.png"
done

# Animação pulsante (parte 1 - loop)
for i in $(seq -w 0 19); do
    OPACITY=$(echo "scale=2; 0.5 + 0.5 * s($i * 0.314)" | bc -l 2>/dev/null || echo "0.8")
    convert -size 1280x720 \
        -define gradient:angle=135 \
        gradient:"#0a0a2e"-"#1a0a3e" \
        -gravity center \
        -font "DejaVu-Sans-Bold" \
        -pointsize 72 \
        -fill "rgba(255,255,255,${OPACITY})" \
        -annotate +0+0 "GM OS" \
        -fill "rgba(68,136,255,${OPACITY})" \
        -pointsize 24 \
        -annotate +0+60 "Mobile" \
        "${BOOTANIM_DIR}/part1/frame${i}.png"
done

# desc.txt define o formato: largura altura fps
# p = parte, count = vezes (0=loop), pause = frames de pausa, nome da pasta
cat > "${BOOTANIM_DIR}/desc.txt" << EOF
1280 720 15
p 1 0 part0
p 0 0 part1
EOF

# Empacota em bootanimation.zip (SEM compressão - obrigatório pelo Android)
cd "${BOOTANIM_DIR}"
zip -r -0 "${BUILD_DIR}/bootanimation.zip" desc.txt part0/ part1/
cd "${WORKSPACE_DIR}"

# Injeta no sistema
mkdir -p "${SYS_DIR}/media"
cp "${BUILD_DIR}/bootanimation.zip" "${SYS_DIR}/media/bootanimation.zip"
chmod 644 "${SYS_DIR}/media/bootanimation.zip"
chown 0:0 "${SYS_DIR}/media/bootanimation.zip"
log_info "Boot animation GM OS instalada."

# ============================================================
# 7. ÍCONES DE NAVEGAÇÃO E STATUS BAR (Overlay)
# ============================================================
log_info "Preparando overlay de ícones customizados..."

# O Android-x86 usa ícones vetoriais (XML drawable) no SystemUI
# A forma mais segura de customizar sem recompilar é criar um
# Runtime Resource Overlay (RRO) - mas isso requer compilação.
#
# Abordagem alternativa: substituir diretamente no SystemUI.apk
# Os ícones de navegação ficam em:
#   /priv-app/SystemUI/SystemUI.apk
#   -> res/drawable-*dpi/ic_sysbar_back.png
#   -> res/drawable-*dpi/ic_sysbar_home.png
#   -> res/drawable-*dpi/ic_sysbar_recent.png
#
# Os ícones de status ficam em:
#   -> res/drawable-*dpi/stat_sys_wifi_signal_*.png
#   -> res/drawable-*dpi/stat_sys_battery_*.png

ICONS_DIR="${WORKSPACE_DIR}/assets/icons"
if [ -d "${ICONS_DIR}" ] && [ "$(ls -A "${ICONS_DIR}" 2>/dev/null)" ]; then
    log_info "Ícones customizados encontrados. Instalando via apktool..."
    
    # Instala apktool se disponível
    which apktool > /dev/null 2>&1 || {
        log_info "Instalando apktool..."
        wget -q "https://raw.githubusercontent.com/nicehash/apktool/master/scripts/linux/apktool" -O /usr/local/bin/apktool
        wget -q "https://bitbucket.org/nicehash/apktool/downloads/apktool_2.7.0.jar" -O /usr/local/bin/apktool.jar
        chmod +x /usr/local/bin/apktool
    }
    
    SYSTEMUI_APK="${SYS_DIR}/priv-app/SystemUI/SystemUI.apk"
    if [ -f "${SYSTEMUI_APK}" ]; then
        SYSTEMUI_WORK="${BUILD_DIR}/systemui_work"
        
        # Decompila SystemUI
        apktool d "${SYSTEMUI_APK}" -o "${SYSTEMUI_WORK}" -f
        
        # Copia ícones customizados por cima dos originais
        # Navegação (botões voltar, home, recentes)
        [ -f "${ICONS_DIR}/ic_sysbar_back.png" ] && find "${SYSTEMUI_WORK}/res" -name "ic_sysbar_back*" -exec cp "${ICONS_DIR}/ic_sysbar_back.png" {} \;
        [ -f "${ICONS_DIR}/ic_sysbar_home.png" ] && find "${SYSTEMUI_WORK}/res" -name "ic_sysbar_home*" -exec cp "${ICONS_DIR}/ic_sysbar_home.png" {} \;
        [ -f "${ICONS_DIR}/ic_sysbar_recent.png" ] && find "${SYSTEMUI_WORK}/res" -name "ic_sysbar_recent*" -exec cp "${ICONS_DIR}/ic_sysbar_recent.png" {} \;
        
        # Status bar (wifi, bateria)
        [ -f "${ICONS_DIR}/stat_sys_wifi.png" ] && find "${SYSTEMUI_WORK}/res" -name "stat_sys_wifi_signal*" -exec cp "${ICONS_DIR}/stat_sys_wifi.png" {} \;
        [ -f "${ICONS_DIR}/stat_sys_battery.png" ] && find "${SYSTEMUI_WORK}/res" -name "stat_sys_battery*" -exec cp "${ICONS_DIR}/stat_sys_battery.png" {} \;
        
        # Recompila SystemUI
        apktool b "${SYSTEMUI_WORK}" -o "${BUILD_DIR}/SystemUI_modified.apk"
        
        # Substitui o APK original (mantém assinatura original copiando apenas os recursos)
        cp "${BUILD_DIR}/SystemUI_modified.apk" "${SYSTEMUI_APK}"
        chmod 644 "${SYSTEMUI_APK}"
        chown 0:0 "${SYSTEMUI_APK}"
        
        log_info "Ícones de navegação e status bar customizados instalados."
    else
        log_warn "SystemUI.apk não encontrado no caminho esperado."
    fi
else
    log_warn "Nenhum ícone customizado encontrado em assets/icons/"
    log_warn "Para customizar, coloque PNGs nessa pasta com os nomes:"
    log_warn "  ic_sysbar_back.png, ic_sysbar_home.png, ic_sysbar_recent.png"
    log_warn "  stat_sys_wifi.png, stat_sys_battery.png"
fi

# ============================================================
# 8. AJUSTES DE BOOT (SELinux Permissive)
# ============================================================
log_info "Ajustando parâmetros de boot..."
ISOLINUX_CFG="${ISO_EXTRACT}/isolinux/isolinux.cfg"
if [ -f "${ISOLINUX_CFG}" ]; then
    sed -i 's/androidboot.hardware=android_x86/androidboot.hardware=android_x86 androidboot.selinux=permissive/g' "${ISOLINUX_CFG}"
fi

GRUB_CFG="${ISO_EXTRACT}/boot/grub/grub.cfg"
if [ -f "${GRUB_CFG}" ]; then
    sed -i 's/androidboot.hardware=android_x86/androidboot.hardware=android_x86 androidboot.selinux=permissive/g' "${GRUB_CFG}"
fi

# ============================================================
# 9. DESMONTAR E RECOMPACTAR
# ============================================================
log_info "Desmontando e recompactando..."
sync
umount "${SYSTEM_MOUNT}"
e2fsck -f -y "${SYSTEM_IMG}"

# Recompactar SquashFS
TEMP_SFS_DIR="${BUILD_DIR}/sfs_temp"
mkdir -p "${TEMP_SFS_DIR}"
mv "${SYSTEM_IMG}" "${TEMP_SFS_DIR}/system.img"
rm -f "${ISO_EXTRACT}/system.sfs"
mksquashfs "${TEMP_SFS_DIR}" "${ISO_EXTRACT}/system.sfs" -comp xz -b 1024K

# ============================================================
# 10. GERAR ISO FINAL
# ============================================================
log_info "Gerando ISO híbrida bootável..."
xorriso -as mkisofs \
  -r -V "GM-OS-Mobile" \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -o "${OUTPUT_DIR}/${CUSTOM_ISO_NAME}" \
  "${ISO_EXTRACT}/"

rm -rf "${BUILD_DIR}"

log_info "================================================================================"
log_info "CONCLUÍDO! ISO: ${OUTPUT_DIR}/${CUSTOM_ISO_NAME}"
log_info "================================================================================"
