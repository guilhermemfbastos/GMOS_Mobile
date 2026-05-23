#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[INFO] Iniciando compilação do GM OS 1.0 (Baseado no Alpine Linux)...${NC}"

# Verifica Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] O Docker é necessário para compilar a ISO de forma segura.${NC}"
    exit 1
fi

WORKSPACE_DIR="$(pwd)"
OUTPUT_DIR="${WORKSPACE_DIR}/output"
mkdir -p "${OUTPUT_DIR}"

echo -e "${GREEN}[INFO] Configurando contêiner de compilação...${NC}"

# Inicia o container com privilégios para criar os dispositivos loop necessários pela montagem de ISO
docker run --rm --privileged -v "${WORKSPACE_DIR}:/workspace" alpine:latest /bin/sh -c '
    set -e
    echo "[DOCKER] Instalando ferramentas de compilação do Alpine..."
    apk update
    apk add git abuild alpine-conf syslinux xorriso squashfs-tools grub mtools sudo doas
    
    # O abuild requer um usuário não-root no grupo abuild
    echo "[DOCKER] Configurando usuário construtor..."
    adduser -D -g "Builder" builder
    addgroup builder abuild
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    echo "Defaults env_keep += \"MKSQUASHFS_OPTS\"" >> /etc/sudoers.d/builder
    chmod 0440 /etc/sudoers.d/builder
    
    # Configurar doas (preferido pelo Alpine)
    mkdir -p /etc/doas.d
    echo "permit nopass keepenv :abuild" > /etc/doas.d/builder.conf
    echo "permit nopass keepenv builder" >> /etc/doas.d/builder.conf
    
    # Configurando chaves de assinatura do apk
    mkdir -p /var/cache/distfiles
    chgrp abuild /var/cache/distfiles
    chmod g+w /var/cache/distfiles
    
    su builder -c "abuild-keygen -a -i -n"
    
    # Clonando a base oficial (aports) do Alpine Linux (apenas os scripts necessários)
    cd /workspace
    if [ ! -d "aports" ]; then
        echo "[DOCKER] Clonando aports do Alpine Linux..."
        git clone --depth=1 https://gitlab.alpinelinux.org/alpine/aports.git
    else
        echo "[DOCKER] Repositório aports já existe."
    fi
    
    # Instalando os scripts personalizados do GM OS
    echo "[DOCKER] Aplicando o perfil GM OS..."
    cp /workspace/gmos-builder/mkimg.gmos.sh /workspace/aports/scripts/
    cp /workspace/gmos-builder/genapkovl-gmos.sh /workspace/aports/scripts/
    chmod +x /workspace/aports/scripts/genapkovl-gmos.sh
    
    # Compilando a ISO
    cd /workspace/aports/scripts
    echo "[DOCKER] Iniciando processo de geração da ISO do GM OS..."
    REPOS=""
    for r in $(cat /etc/apk/repositories); do
        case "$r" in
            http*) REPOS="$REPOS --repository $r" ;;
        esac
    done
    su builder -c "export MKSQUASHFS_OPTS=\"-noI -noD -noF -no-fragments\"; sh mkimage.sh --tag 1.0 --outdir /workspace/output --profile gmos $REPOS"
    
    echo "[DOCKER] Compilação concluída!"
'

echo -e "${GREEN}[INFO] =================================================================${NC}"
echo -e "${GREEN}[INFO] GM OS 1.0 COMPILADO COM SUCESSO!${NC}"
echo -e "${GREEN}[INFO] A sua ISO está localizada na pasta: output/${NC}"
echo -e "${GREEN}[INFO] =================================================================${NC}"
