#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[INFO] Iniciando compilação do GM OS 1.0 (SEM DOCKER)...${NC}"

# Detecta o sistema operacional
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
else
    OS_ID="unknown"
fi

# Instala pacotes necessários diretamente no sistema
echo -e "${GREEN}[INFO] Instalando ferramentas de build...${NC}"

if [ "$OS_ID" = "alpine" ]; then
    apk update
    apk add git abuild alpine-conf syslinux xorriso squashfs-tools grub mtools sudo doas bash
    
    # Configura usuário builder
    if ! id -u builder >/dev/null 2>&1; then
        echo -e "${GREEN}[INFO] Criando usuário builder...${NC}"
        adduser -D -g "Builder" builder
        addgroup builder abuild
        echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
        chmod 0440 /etc/sudoers.d/builder

        # Configura chaves
        mkdir -p /var/cache/distfiles
        chgrp abuild /var/cache/distfiles
        chmod g+w /var/cache/distfiles

        su builder -c "abuild-keygen -a -i -n"
    fi
elif [ "$OS_ID" = "debian" ] || [ "$OS_ID" = "ubuntu" ]; then
    echo -e "${GREEN}[INFO] Sistema Debian/Ubuntu detectado. Este script requer Alpine Linux nativo.${NC}"
    echo -e "${YELLOW}[WARN] Para sistemas Debian/Ubuntu, use o script build_gmos.sh com Docker.${NC}"
    exit 1
else
    echo -e "${RED}[ERROR] Sistema operacional não suportado: $OS_ID${NC}"
    echo -e "${RED}[INFO] Use Docker ou execute em Alpine Linux nativo.${NC}"
    exit 1
fi

# Clona aports se não existir
cd /workspace
if [ ! -d "aports" ]; then
    echo -e "${GREEN}[INFO] Clonando repositório aports...${NC}"
    git clone --depth=1 https://gitlab.alpinelinux.org/alpine/aports.git
else
    echo -e "${GREEN}[INFO] Repositório aports já existe.${NC}"
fi

# Copia scripts do GM OS
echo -e "${GREEN}[INFO] Aplicando perfil GM OS...${NC}"
cp /workspace/gmos-builder/mkimg.gmos.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/mkimg.gmos.sh

cp /workspace/gmos-builder/genapkovl-gmos.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/genapkovl-gmos.sh

cp /workspace/gmos-builder/xfce-mint-config.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/xfce-mint-config.sh

# Registra o perfil
echo -e "${GREEN}[INFO] Registrando perfil gmos...${NC}"
if ! grep -q "gmos)" /workspace/aports/scripts/mkimage.sh 2>/dev/null; then
    # Adiciona o perfil gmos ao case statement do mkimage.sh
    # O perfil deve ser inserido DENTRO do case, após a linha 'case "$PROFILE" in'
    sed -i '/^case "\$PROFILE" in/a\
    # GM OS Profile\
    gmos)\
        . "$SCRIPT_DIR/mkimg.gmos.sh"\
        profile_gmos\
        ;;' /workspace/aports/scripts/mkimage.sh
    echo -e "${GREEN}[INFO] Perfil gmos registrado.${NC}"
else
    echo -e "${GREEN}[INFO] Perfil gmos já registrado.${NC}"
fi

# Cria diretório de saída
mkdir -p /workspace/output

# Build da ISO
cd /workspace/aports/scripts
echo -e "${GREEN}[INFO] Gerando ISO do GM OS...${NC}"

REPOS=""
for r in $(cat /etc/apk/repositories); do
    case "$r" in
        http*) REPOS="$REPOS --repository $r" ;;
    esac
done

export MKSQUASHFS_OPTS='-noI -noD -noF -no-fragments'
export APK_OVERLAY_FROM="0"

su builder -c "cd /workspace/aports/scripts && export MKSQUASHFS_OPTS='-noI -noD -noF -no-fragments' && sh mkimage.sh --tag 1.0 --outdir /workspace/output --profile gmos $REPOS"

echo -e "${GREEN}[INFO] =================================================================${NC}"
echo -e "${GREEN}[INFO] GM OS 1.0 COMPILADO COM SUCESSO!${NC}"
echo -e "${GREEN}[INFO] ISO disponível em: output/gmos-1.0-x86_64.iso${NC}"
echo -e "${GREEN}[INFO] =================================================================${NC}"
