#!/bin/bash
# ==============================================================================
# Script de Remasterização do Android-x86 para GM OS Mobile
# Desenvolvido por Antigravity (Google DeepMind Team)
# ==============================================================================
# Este script deve ser executado em um ambiente Linux (Ubuntu-latest/Debian)
# com privilégios de root (sudo) e requer as seguintes dependências instaladas:
# squashfs-tools, xorriso, p7zip-full, e2fsprogs, wget
# ==============================================================================

set -e # Interrompe a execução caso algum comando falhe

# Cores para logs formatados no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

log_info "Iniciando processo de cirurgia e remasterização da ISO GM OS Mobile..."

# 1. Validação de Privilégios de Execução
if [ "$EUID" -ne 0 ]; then
    log_error "Este script realiza montagem de partições e manipulação de permissões de sistema."
    log_error "Por favor, execute-o utilizando sudo: 'sudo ./remaster.sh'"
    exit 1
fi

# 2. Definição de Variáveis e Ambientes
WORKSPACE_DIR="$(pwd)"
ORIGINAL_ISO_URL="https://downloads.sourceforge.net/project/android-x86/Release%209.0/android-x86-9.0-r2.iso"
ORIGINAL_ISO_NAME="android-x86-9.0-r2.iso"
CUSTOM_ISO_NAME="GM-OS-Mobile.iso"

# Diretórios temporários de compilação
BUILD_DIR="${WORKSPACE_DIR}/build_workspace"
ISO_EXTRACT="${BUILD_DIR}/iso_extract"
SFS_EXTRACT="${BUILD_DIR}/sfs_extract"
SYSTEM_MOUNT="${BUILD_DIR}/system_mount"
OUTPUT_DIR="${WORKSPACE_DIR}/output"

# Limpar workspace anterior se houver
log_info "Limpando ambiente de builds anteriores..."
rm -rf "${BUILD_DIR}"
mkdir -p "${ISO_EXTRACT}"
mkdir -p "${SYSTEM_MOUNT}"
mkdir -p "${OUTPUT_DIR}"

# 3. Download da Imagem Android-x86 de Referência (se não houver localmente)
if [ ! -f "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" ]; then
    log_info "Fazendo download da ISO oficial do Android-x86 (9.0 Pie Stable)..."
    wget -L -O "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" "${ORIGINAL_ISO_URL}"
else
    log_info "ISO original de referência encontrada localmente no diretório root."
fi

# 4. Extração da ISO
log_info "Extraindo o sistema de arquivos da ISO..."
7z x "${WORKSPACE_DIR}/${ORIGINAL_ISO_NAME}" -o"${ISO_EXTRACT}" -y > /dev/null

# 5. Extração e Redimensionamento do SquashFS (system.sfs)
if [ -f "${ISO_EXTRACT}/system.sfs" ]; then
    log_info "Encontrado 'system.sfs'. Extraindo SquashFS para obter o 'system.img'..."
    unsquashfs -d "${SFS_EXTRACT}" "${ISO_EXTRACT}/system.sfs"
    SYSTEM_IMG="${SFS_EXTRACT}/system.img"
elif [ -f "${ISO_EXTRACT}/system.img" ]; then
    log_info "Encontrado 'system.img' diretamente na raiz da ISO..."
    SYSTEM_IMG="${ISO_EXTRACT}/system.img"
else
    log_error "Erro estrutural: Nenhum arquivo system.sfs ou system.img foi encontrado na ISO."
    exit 1
fi

if [ ! -f "${SYSTEM_IMG}" ]; then
    log_error "Erro: O arquivo de imagem de sistema (system.img) não pôde ser extraído."
    exit 1
fi

# Aumentar o tamanho do system.img para que caibam os novos GApps e Launcher (+500MB)
log_info "Redimensionando system.img para adicionar espaço de armazenamento (+500 MB)..."
dd if=/dev/zero bs=1M count=500 >> "${SYSTEM_IMG}"
log_info "Verificando consistência da imagem do sistema..."
e2fsck -f -y "${SYSTEM_IMG}"
log_info "Expandindo o sistema de arquivos ext4 interno..."
resize2fs "${SYSTEM_IMG}"

# 6. Montagem em Loopback para Edição R/W
log_info "Montando 'system.img' em modo Leitura/Escrita..."
mount -o loop,rw "${SYSTEM_IMG}" "${SYSTEM_MOUNT}"

# 7. Injeção do Nosso Launcher Customizado (GM UI)
log_info "Injetando a GM UI (Launcher Customizado)..."
LAUNCHER_SOURCE="${WORKSPACE_DIR}/app/build/outputs/apk/release/app-release-unsigned.apk"
if [ ! -f "${LAUNCHER_SOURCE}" ]; then
    # Procura na pasta root se não foi gerado pelo Gradle na mesma workflow
    LAUNCHER_SOURCE="${WORKSPACE_DIR}/GM_UI.apk"
fi

if [ -f "${LAUNCHER_SOURCE}" ]; then
    mkdir -p "${SYSTEM_MOUNT}/system/priv-app/GM_UI"
    cp "${LAUNCHER_SOURCE}" "${SYSTEM_MOUNT}/system/priv-app/GM_UI/GM_UI.apk"
    
    # Ajuste de Permissões: arquivos de sistema precisam de root e chmod 644
    chmod 644 "${SYSTEM_MOUNT}/system/priv-app/GM_UI/GM_UI.apk"
    chown -R 0:0 "${SYSTEM_MOUNT}/system/priv-app/GM_UI"
    log_info "GM UI Launcher injetado e configurado com sucesso."
else
    log_warn "Aviso: Nenhum launcher APK ('GM_UI.apk') encontrado no root ou na pasta de build."
    log_warn "O sistema iniciará sem alterações de interface."
fi

# 8. Injeção dos Serviços do Google (GApps)
log_info "Verificando presença de arquivos GApps para injeção..."
GAPPS_DIR="${WORKSPACE_DIR}/gapps"

if [ -d "${GAPPS_DIR}" ] && [ "$(ls -A "${GAPPS_DIR}")" ]; then
    log_info "Injetando pacotes Google Play Store e Play Services..."
    
    # Cria os diretórios correspondentes no system
    mkdir -p "${SYSTEM_MOUNT}/system/priv-app/GoogleServicesFramework"
    mkdir -p "${SYSTEM_MOUNT}/system/priv-app/PrebuiltGmsCore"
    mkdir -p "${SYSTEM_MOUNT}/system/priv-app/Phonesky"
    mkdir -p "${SYSTEM_MOUNT}/system/priv-app/GoogleLoginService"

    # Copia os APKs obrigatórios
    [ -f "${GAPPS_DIR}/GoogleServicesFramework.apk" ] && cp "${GAPPS_DIR}/GoogleServicesFramework.apk" "${SYSTEM_MOUNT}/system/priv-app/GoogleServicesFramework/"
    [ -f "${GAPPS_DIR}/PrebuiltGmsCore.apk" ] && cp "${GAPPS_DIR}/PrebuiltGmsCore.apk" "${SYSTEM_MOUNT}/system/priv-app/PrebuiltGmsCore/"
    [ -f "${GAPPS_DIR}/Phonesky.apk" ] && cp "${GAPPS_DIR}/Phonesky.apk" "${SYSTEM_MOUNT}/system/priv-app/Phonesky/"
    [ -f "${GAPPS_DIR}/GoogleLoginService.apk" ] && cp "${GAPPS_DIR}/GoogleLoginService.apk" "${SYSTEM_MOUNT}/system/priv-app/GoogleLoginService/"

    # Injeção crítica da Whitelist de permissões privilegiadas
    log_info "Gravando whitelist de permissões privilegiadas (privapp-permissions-google.xml)..."
    cp "${WORKSPACE_DIR}/scripts/privapp-permissions-google.xml" "${SYSTEM_MOUNT}/system/etc/permissions/"
    chmod 644 "${SYSTEM_MOUNT}/system/etc/permissions/privapp-permissions-google.xml"
    chown 0:0 "${SYSTEM_MOUNT}/system/etc/permissions/privapp-permissions-google.xml"

    # Ajuste de Permissões Recursivas nos Apps do Google
    chmod 644 "${SYSTEM_MOUNT}/system/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk"
    chmod 644 "${SYSTEM_MOUNT}/system/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk"
    chmod 644 "${SYSTEM_MOUNT}/system/priv-app/Phonesky/Phonesky.apk"
    chmod 644 "${SYSTEM_MOUNT}/system/priv-app/GoogleLoginService/GoogleLoginService.apk"
    
    chown -R 0:0 "${SYSTEM_MOUNT}/system/priv-app/GoogleServicesFramework"
    chown -R 0:0 "${SYSTEM_MOUNT}/system/priv-app/PrebuiltGmsCore"
    chown -R 0:0 "${SYSTEM_MOUNT}/system/priv-app/Phonesky"
    chown -R 0:0 "${SYSTEM_MOUNT}/system/priv-app/GoogleLoginService"

    log_info "Serviços Google injetados com sucesso e permissões estruturadas."
else
    log_warn "Diretório de GApps vazio ou ausente em '${GAPPS_DIR}'."
    log_warn "A ISO será gerada sem o ecossistema Google Play pré-instalado."
fi

# 9. Remoção do Launcher Padrão do Android-x86
log_info "Removendo os launchers nativos para inicialização direta do GM UI..."
# Deleta pacotes nativos para que não seja exibido o diálogo "Selecionar um launcher"
rm -rf "${SYSTEM_MOUNT}/system/app/Launcher3"
rm -rf "${SYSTEM_MOUNT}/system/priv-app/Launcher3"
rm -rf "${SYSTEM_MOUNT}/system/app/Taskbar"
rm -rf "${SYSTEM_MOUNT}/system/priv-app/Taskbar"

# 10. Desmontar a Partição e Validar a Gravação
log_info "Salvando alterações e desmontando a imagem do sistema..."
sync
umount "${SYSTEM_MOUNT}"
e2fsck -f -y "${SYSTEM_IMG}"

# 11. Recompressão do SquashFS (system.sfs)
log_info "Recompactando a imagem do sistema em formato SquashFS com compressão XZ..."
TEMP_SFS_DIR="${BUILD_DIR}/sfs_temp"
mkdir -p "${TEMP_SFS_DIR}"
mv "${SYSTEM_IMG}" "${TEMP_SFS_DIR}/system.img"

# Deleta o original da árvore de compilação da ISO
rm -f "${ISO_EXTRACT}/system.sfs"

# Cria o arquivo system.sfs compactado
mksquashfs "${TEMP_SFS_DIR}" "${ISO_EXTRACT}/system.sfs" -comp xz -b 1024K

# 12. Otimizações de Parâmetros de Boot da ISO
log_info "Ajustando configurações de boot para desativar segurança SELinux e estabilizar GApps..."
# androidboot.selinux=permissive é crítico, pois apps e serviços adicionados manualmente
# não possuem os contextos corretos no arquivo file_contexts.bin gerado na compilação do Android.
ISOLINUX_CFG="${ISO_EXTRACT}/isolinux/isolinux.cfg"
if [ -f "${ISOLINUX_CFG}" ]; then
    sed -i 's/androidboot.hardware=android_x86/androidboot.hardware=android_x86 androidboot.selinux=permissive/g' "${ISOLINUX_CFG}"
fi

GRUB_CFG="${ISO_EXTRACT}/boot/grub/grub.cfg"
if [ -f "${GRUB_CFG}" ]; then
    sed -i 's/androidboot.hardware=android_x86/androidboot.hardware=android_x86 androidboot.selinux=permissive/g' "${GRUB_CFG}"
fi

# 13. Empacotamento Híbrido da ISO Final (Compatível com UEFI e Legacy BIOS)
log_info "Montando e criando a nova ISO híbrida bootável via xorriso..."
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

# Limpeza final dos arquivos temporários
rm -rf "${BUILD_DIR}"

log_info "================================================================================"
log_info "PROCESSO CONCLUÍDO COM SUCESSO!"
log_info "ISO Remasterizada: ${OUTPUT_DIR}/${CUSTOM_ISO_NAME}"
log_info "================================================================================"
