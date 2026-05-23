#!/bin/bash
# ==============================================================================
# Script para emular o GM OS Mobile no GitHub Codespaces usando QEMU e noVNC
# Executa em ambiente Linux nativo (Codespaces) e expõe a porta 6080.
# ==============================================================================

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
log_info "🖥️  INICIANDO EMULADOR NO GITHUB CODESPACES VIA noVNC"
log_info "================================================================="

# 1. Verificar/Instalar dependências
log_info "Verificando dependências (qemu, novnc, websockify)..."
DEPS_TO_INSTALL=""
if ! command -v qemu-system-x86_64 &> /dev/null; then
    DEPS_TO_INSTALL="qemu-system-x86"
fi
if [ ! -d "/usr/share/novnc" ] && [ ! -d "/usr/share/novnc-directory-alt" ]; then
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL novnc"
fi
if ! command -v websockify &> /dev/null; then
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL websockify"
fi

if [ -n "$DEPS_TO_INSTALL" ]; then
    log_info "Instalando dependências ausentes: $DEPS_TO_INSTALL..."
    sudo apt-get update || true
    sudo apt-get install -y $DEPS_TO_INSTALL
else
    log_info "Todas as dependências já estão instaladas."
fi

# 2. Localizar ou baixar a ISO
ISO_PATH=""
if [ -f "output/GM-OS-Mobile.iso" ]; then
    ISO_PATH="output/GM-OS-Mobile.iso"
elif [ -f "GM-OS-Mobile.iso" ]; then
    ISO_PATH="GM-OS-Mobile.iso"
else
    log_warn "Nenhuma ISO local encontrada em 'output/GM-OS-Mobile.iso' ou 'GM-OS-Mobile.iso'."
    mkdir -p output
    ISO_PATH="output/GM-OS-Mobile.iso"
    DOWNLOADED=false

    # Método 1: Usar gh CLI (mais confiável no Codespaces por herdar autenticação)
    if command -v gh &> /dev/null; then
        log_info "Tentando baixar a ISO da última Release via GitHub CLI (gh)..."
        if gh release download latest -p "GM-OS-Mobile.iso" --dir output --clobber; then
            log_info "ISO baixada com sucesso da release do GitHub."
            DOWNLOADED=true
        else
            log_warn "Não foi possível baixar da release com gh. Tentando baixar do último build de sucesso (Actions)..."
            RUN_ID=$(gh run list --workflow "GM OS Mobile ISO Build" --status success --limit 1 --json databaseId --jq '.[0].databaseId' || true)
            if [ -n "$RUN_ID" ]; then
                log_info "Baixando artefato do build de Actions ID: $RUN_ID..."
                if gh run download "$RUN_ID" -n "GM-OS-Mobile-ISO" --dir output --clobber; then
                    log_info "ISO baixada do build com sucesso."
                    DOWNLOADED=true
                fi
            fi
        fi
    fi

    # Método 2: Baixar por link público wget/curl se o método anterior falhar
    if [ "$DOWNLOADED" = false ]; then
        log_info "Tentando baixar via URL pública com wget/curl..."
        RELEASE_URL="https://github.com/guilhermemfbastos/GMOS_Mobile/releases/latest/download/GM-OS-Mobile.iso"
        
        # Baixar usando wget ou curl
        if command -v wget &> /dev/null; then
            if wget -O "$ISO_PATH" "$RELEASE_URL" 2>/dev/null; then
                DOWNLOADED=true
            fi
        else
            if curl -L -o "$ISO_PATH" "$RELEASE_URL" 2>/dev/null; then
                DOWNLOADED=true
            fi
        fi
    fi
fi

# Verificar se a ISO localizada/baixada é válida e se tem um tamanho mínimo aceitável (ex: 100MB)
if [ ! -f "$ISO_PATH" ] || [ $(stat -c%s "$ISO_PATH" 2>/dev/null || echo 0) -lt 104857600 ]; then
    log_error "Erro: O arquivo ISO em '$ISO_PATH' é inválido, inexistente ou incompleto!"
    log_error "Como a trava de compilação está ativa localmente, você deve:"
    log_error "1. Executar a Action 'GM OS Mobile ISO Build' no GitHub para compilar a ISO na nuvem;"
    log_error "2. Ou colocar uma ISO de teste válida em 'output/GM-OS-Mobile.iso' manualmente."
    rm -f "$ISO_PATH" # Remove o arquivo inválido/HTML de erro
    exit 1
fi

log_info "Usando a ISO: $ISO_PATH ($(stat -c%s "$ISO_PATH" 2>/dev/null || echo 0) bytes)"

# 3. Criar disco virtual de 4GB se não existir (para salvar estados/testar instalação)
if [ ! -f "android_disk.qcow2" ]; then
    log_info "Criando disco virtual android_disk.qcow2 de 4GB..."
    qemu-img create -f qcow2 android_disk.qcow2 4G
fi

# 4. Configurar noVNC para carregar vnc.html por padrão
log_info "Configurando páginas do noVNC..."
if [ -f "/usr/share/novnc/vnc.html" ] && [ ! -f "/usr/share/novnc/index.html" ]; then
    sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
fi

# 5. Detectar suporte a KVM
QEMU_ACCEL=""
QEMU_SMP="2"
if [ -w /dev/kvm ]; then
    log_info "Aceleração por hardware KVM disponível!"
    QEMU_ACCEL="-enable-kvm -cpu host"
else
    log_warn "KVM não está disponível (comum em ambientes de containers). Usando emulador de software TCG com CPU de recursos máximos e 1 núcleo (smp 1) para estabilidade."
    QEMU_ACCEL="-accel tcg -cpu max"
    QEMU_SMP="1"
fi

# 6. Finalizar processos antigos se houver
log_info "Limpando instâncias antigas do QEMU ou websockify..."
sudo killall qemu-system-x86_64 websockify 2>/dev/null || true
sleep 1

# 7. Iniciar QEMU
log_info "Iniciando QEMU em background (headless)..."
# -vnc :0 configura o VNC na porta 5900
# -daemonize roda em background
sudo qemu-system-x86_64 \
  -m 2048 \
  -smp $QEMU_SMP \
  $QEMU_ACCEL \
  -boot d \
  -cdrom "$ISO_PATH" \
  -hda android_disk.qcow2 \
  -vga std \
  -usb \
  -device usb-tablet \
  -k en-us \
  -vnc 127.0.0.1:0 \
  -daemonize

# 8. Iniciar websockify para converter VNC (5900) para WebSockets (6080)
log_info "Iniciando websockify na porta 6080..."
# Roda em background
sudo websockify --web /usr/share/novnc 6080 127.0.0.1:5900 &
sleep 2

# 9. Mostrar instruções para o Codespaces
log_info "================================================================="
log_info "🎉 EMULADOR PRONTO!"
log_info "================================================================="
echo -e "Para acessar o Android do GM OS Mobile no seu navegador:"
echo -e "1. Acesse a aba ${CYAN}'Ports'${NC} (Portas) no rodapé do VS Code / Codespaces."
echo -e "2. Localize a porta ${CYAN}6080${NC}."
echo -e "3. Clique no ícone de globo (${CYAN}'Open in Browser'${NC}) ou copie o link encaminhado."
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "   Seu link direto é: https://${CODESPACE_NAME}-6080.app.github.dev/"
fi
echo -e "4. Se o noVNC não conectar sozinho, clique no botão ${GREEN}'Connect'${NC} na tela."
log_info "================================================================="
