#!/bin/bash
# ==============================================================================
# GM OS Builder - Versão Nativa Debian/Ubuntu
# ==============================================================================
# Este script compila a ISO do GM OS diretamente em sistemas baseados em Debian
# usando live-build, sem necessidade de Docker ou Alpine Linux.
# ==============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
VERSION="1.0"
ISO_NAME="GM_OS_${VERSION}.iso"
BUILD_DIR="$(pwd)/build_area"
OUTPUT_DIR="$(pwd)/output"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Verifica se está rodando como root (necessário para live-build)
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script precisa ser executado como root (sudo). Execute: sudo ./build_gmos.sh"
fi

log_info "Iniciando compilação do GM OS ${VERSION} (Nativo em Debian/Ubuntu)..."

# ------------------------------------------------------------------------------
# 1. Instalação de Dependências
# ------------------------------------------------------------------------------
log_info "Verificando e instalando dependências do sistema..."

DEPS="live-build debootstrap xorriso squashfs-tools genisoimage wget curl"
apt-get update -qq
apt-get install -y $DEPS

log_success "Dependências instaladas."

# ------------------------------------------------------------------------------
# 2. Preparação do Ambiente de Build
# ------------------------------------------------------------------------------
if [ -d "$BUILD_DIR" ]; then
    log_warn "Limpando área de build anterior..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$BUILD_DIR"

# ------------------------------------------------------------------------------
# 3. Configuração do Live-Build
# ------------------------------------------------------------------------------
log_info "Configurando estrutura do live-build..."

# Inicializa o projeto live-build com parâmetros compatíveis
lb config \
    --mode debian \
    --distribution bookworm \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --debian-installer none \
    --memtest none

# Configurações manuais via arquivos de configuração
mkdir -p config/archives
echo "deb http://deb.debian.org/debian/ bookworm main contrib non-free" > config/archives/debian.chroot
echo "deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free" >> config/archives/debian.chroot

# Configurar metadados da ISO
mkdir -p config/includes.chroot
echo "GM OS" > config/includes.chroot/.application_name
echo "Guilherme Bastos" > config/includes.chroot/.publisher

# Configurar bootloaders (GRUB BIOS e EFI)
mkdir -p config/bootloaders
lb config --bootstrap-qemu-arch amd64 --bootloaders "grub-pc grub-efi" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Personalização (Chroot)
# ------------------------------------------------------------------------------
log_info "Personalizando o sistema (instalação de pacotes e configs)..."

# Lista de pacotes básicos para o GM OS
PACKAGES="linux-image-amd64 linux-headers-amd64 grub-pc grub-efi-amd64 systemd-sysv network-manager vim nano wget curl firmware-linux-nonfree"

# Adiciona pacotes à lista de inclusão
echo "$PACKAGES" >> config/package-lists/my.list.chroot

# Script de personalização dentro do chroot
cat << 'EOF' > config/hooks/my-custom.chroot
#!/bin/bash
# Scripts executados DENTRO do chroot durante o build

echo "GM OS - Configurando sistema..."

# Configurar usuário padrão
useradd -m -s /bin/bash -G sudo gmuser
echo "gmuser:gmuser" | chpasswd
echo "gmuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configurar hostname
echo "gmos-mobile" > /etc/hostname

# Mensagem de boas-vindas
cat << 'WELCOME' > /etc/motd
  ____   _   _   ___   _____ 
 / ___| | | | | |_ _| | ____|
| |  _  | |_| |  | |  |  _|  
| |_| | |  _  |  | |  | |___ 
 \____| |_| |_| |___| |_____|
                            
Bem-vindo ao GM OS Mobile v1.0
WELCOME

# Limpeza
apt-get clean
rm -rf /var/cache/apt/archives/*.deb
EOF

chmod +x config/hooks/my-custom.chroot

# ------------------------------------------------------------------------------
# 5. Construção da Imagem
# ------------------------------------------------------------------------------
log_info "Iniciando construção da imagem (isso pode demorar alguns minutos)..."

# Executa o build
lb build 2>&1 | tee "${OUTPUT_DIR}/build.log"

# ------------------------------------------------------------------------------
# 6. Finalização
# ------------------------------------------------------------------------------
if [ -f "live-image-amd64.hybrid.iso" ]; then
    mv "live-image-amd64.hybrid.iso" "${OUTPUT_DIR}/${ISO_NAME}"
    log_success "Build concluído com sucesso!"
    log_info "ISO gerada em: ${OUTPUT_DIR}/${ISO_NAME}"
    log_info "Tamanho: $(du -h "${OUTPUT_DIR}/${ISO_NAME}" | cut -f1)"
else
    log_error "Falha na geração da ISO. Verifique ${OUTPUT_DIR}/build.log para detalhes."
fi

log_info "Processo finalizado."
