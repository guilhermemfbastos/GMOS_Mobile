#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

log_info "================================================================="
log_info "🖥️  INICIANDO GM OS NO GITHUB CODESPACES VIA noVNC"
log_info "================================================================="

# 1. Dependências
log_info "Verificando dependências (qemu, novnc, websockify)..."
DEPS_TO_INSTALL=""
if ! command -v qemu-system-x86_64 &> /dev/null; then DEPS_TO_INSTALL="qemu-system-x86"; fi
if [ ! -d "/usr/share/novnc" ]; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL novnc"; fi
if ! command -v websockify &> /dev/null; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL websockify"; fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    log_info "Instalando dependências ausentes: $DEPS_TO_INSTALL..."
    sudo apt-get update || true
    sudo apt-get install -y $DEPS_TO_INSTALL
fi

# 2. Localizar ISO
ISO_PATH="output/alpine-gmos-1.0-x86_64.iso"
if [ ! -f "$ISO_PATH" ]; then
    # Talvez a arquitetura mude se for compilado em arm64, vamos ser flexíveis:
    ISO_PATH=$(ls output/alpine-gmos-1.0-*.iso 2>/dev/null | head -n 1 || true)
    
    if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
        log_error "Nenhuma ISO do GM OS encontrada na pasta output/"
        log_error "Por favor, execute 'bash build_gmos.sh' primeiro para compilar o sistema!"
        exit 1
    fi
fi

log_info "Usando a ISO do GM OS: $ISO_PATH"

# 3. Configurar noVNC
if [ -f "/usr/share/novnc/vnc.html" ] && [ ! -f "/usr/share/novnc/index.html" ]; then
    sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
fi

# 4. KVM ou TCG
QEMU_ACCEL="-accel tcg -cpu max"
if [ -w /dev/kvm ]; then
    log_info "Aceleração KVM disponível!"
    QEMU_ACCEL="-enable-kvm -cpu host"
fi

log_info "Limpando instâncias antigas..."
sudo killall qemu-system-x86_64 websockify 2>/dev/null || true
sleep 1

# 5. Iniciar QEMU (GM OS não precisa de tanto disco, apenas a ISO já roda na RAM)
log_info "Iniciando QEMU em background..."
rm -f qemu_boot.log

# Boot direto da ISO
sudo qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  $QEMU_ACCEL \
  -boot d \
  -cdrom "$ISO_PATH" \
  -vga virtio \
  -device usb-tablet \
  -k en-us \
  -vnc 127.0.0.1:0 \
  > qemu_boot.log 2>&1 &

sleep 2
if ! pgrep -f qemu-system-x86_64 > /dev/null; then
    log_error "Erro: O QEMU falhou ao iniciar!"
    cat qemu_boot.log
    exit 1
fi

# 6. Iniciar noVNC bridge
log_info "Iniciando websockify na porta 6080..."
sudo websockify --web /usr/share/novnc 6080 127.0.0.1:5900 &
sleep 2

log_info "================================================================="
log_info "🎉 GM OS PRONTO PARA TESTE!"
log_info "================================================================="
echo -e "Para acessar o sistema:"
echo -e "1. Acesse a aba ${CYAN}'Ports'${NC} (Portas) no rodapé do VS Code / Codespaces."
echo -e "2. Clique no ícone de globo na porta ${CYAN}6080${NC}."
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "   Ou use: https://${CODESPACE_NAME}-6080.app.github.dev/"
fi
log_info "================================================================="
