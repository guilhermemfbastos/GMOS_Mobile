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
log_info "🖥️  INICIANDO GM OS (MINT XFCE EDITION) NO GITHUB CODESPACES"
log_info "================================================================="

# 1. Dependências
log_info "Verificando dependências (qemu, novnc, websockify, wget, pip)..."
DEPS_TO_INSTALL=""
if ! command -v qemu-system-x86_64 &> /dev/null; then DEPS_TO_INSTALL="qemu-system-x86"; fi
if [ ! -d "/usr/share/novnc" ]; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL novnc"; fi
if ! command -v websockify &> /dev/null; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL websockify"; fi
if ! command -v wget &> /dev/null; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"; fi
if ! command -v pip3 &> /dev/null; then DEPS_TO_INSTALL="$DEPS_TO_INSTALL python3-pip"; fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    log_info "Instalando dependências de sistema ausentes: $DEPS_TO_INSTALL..."
    sudo apt-get update || true
    sudo apt-get install -y $DEPS_TO_INSTALL
fi

# Instala vncdotool para automatizar cliques/teclado no VNC
if ! python3 -c "import vncdotool" &>/dev/null; then
    log_info "Instalando vncdotool para automação estritamente visual..."
    pip3 install vncdotool || pip3 install vncdotool --break-system-packages || true
fi

# 2. Localizar ou baixar a ISO base
ISO_DIR="output"
mkdir -p "$ISO_DIR"
ISO_PATH="${1:-${ISO_DIR}/gmos-base.iso}"

if [ ! -f "$ISO_PATH" ]; then
    log_info "A ISO base do GM OS (Linux Mint XFCE) não foi encontrada."
    log_info "Iniciando download automático (cerca de 2.3 GB, muito rápido no Codespaces)..."
    ISO_URL="https://mirrors.kernel.org/linuxmint/stable/21.3/linuxmint-21.3-xfce-64bit.iso"
    
    # Baixa com barra de progresso
    wget -O "$ISO_PATH" "$ISO_URL" || {
        log_error "Falha ao baixar a ISO de: $ISO_URL"
        exit 1
    }
    log_info "Download concluído com sucesso!"
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
# Fecha qualquer servidor Python rodando na porta 8000
sudo kill -9 $(sudo lsof -t -i:8000) 2>/dev/null || true
sleep 1

# 5. Iniciar Servidor HTTP temporário para servir os arquivos de customização (wallpaper + script)
log_info "Iniciando servidor HTTP temporário na porta 8000..."
python3 -m http.server 8000 &
HTTP_SERVER_PID=$!

# 6. Preparar disco virtual para geração da ISO
if [ ! -f workspace.img ]; then
    log_info "Criando disco virtual de 8GB para extração da ISO..."
    qemu-img create -f raw workspace.img 8G
    mkfs.ext4 -F workspace.img
fi

# 7. Iniciar QEMU
log_info "Iniciando QEMU em background..."
rm -f qemu_boot.log

qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  $QEMU_ACCEL \
  -boot d \
  -cdrom "$ISO_PATH" \
  -vga std \
  -usb \
  -device usb-tablet \
  -k en-us \
  -drive file=workspace.img,format=raw \
  -vnc 127.0.0.1:0,share=force-shared \
  > qemu_boot.log 2>&1 &

sleep 2
if ! pgrep -f qemu-system-x86_64 > /dev/null; then
    log_error "Erro: O QEMU falhou ao iniciar!"
    cat qemu_boot.log
    kill $HTTP_SERVER_PID 2>/dev/null || true
    exit 1
fi

# 7. Iniciar noVNC bridge
log_info "Iniciando websockify na porta 6080..."
websockify --web /usr/share/novnc 6080 127.0.0.1:5900 &
sleep 2

# 8. Iniciar automação de customização após o boot
(
    log_info "Aguardando 35 segundos para o boot carregar antes de aplicar as modificações visuais..."
    sleep 35
    log_info "Aplicando personalizações visuais automaticamente (Wallpaper, Dock flutuante, tema claro)..."
    python3 gmos-builder/automate.py || log_warn "A automação de customização falhou. Você pode rodar manualmente abrindo o terminal no noVNC e digitando: curl -s http://10.0.2.2:8000/gmos-builder/customize.sh | bash"
    
    # Encerra o servidor HTTP temporário após concluir a customização
    kill $HTTP_SERVER_PID 2>/dev/null || true
) &

log_info "================================================================="
log_info "🎉 GM OS (LINUX MINT XFCE) PRONTO PARA TESTE!"
log_info "================================================================="
echo -e "Para acessar o sistema:"
echo -e "1. Acesse a aba ${CYAN}'Ports'${NC} (Portas) no rodapé do VS Code / Codespaces."
echo -e "2. Clique no ícone de globo na porta ${CYAN}6080${NC}."
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "   Ou use: https://${CODESPACE_NAME}-6080.app.github.dev/"
fi
log_info "================================================================="
log_info "Nota: Em 35 segundos, as modificações de estilo (wallpaper, barra de tarefas arredondada flutuante e tema claro) serão aplicadas automaticamente!"
log_info "================================================================="
