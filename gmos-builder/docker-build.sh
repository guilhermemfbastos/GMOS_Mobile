#!/bin/sh
set -e

echo "[DOCKER] Instalando ferramentas de compilação do Alpine..."
apk update
apk add git abuild alpine-conf syslinux xorriso squashfs-tools grub mtools sudo doas bash

# O abuild requer um usuário não-root no grupo abuild
echo "[DOCKER] Configurando usuário construtor..."
adduser -D -g "Builder" builder
addgroup builder abuild
echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
echo 'Defaults env_keep += "MKSQUASHFS_OPTS"' >> /etc/sudoers.d/builder
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

# Copia o script mkimg.gmos.sh para a pasta de scripts
cp /workspace/gmos-builder/mkimg.gmos.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/mkimg.gmos.sh

# Copia o script genapkovl-gmos.sh para a pasta de scripts
cp /workspace/gmos-builder/genapkovl-gmos.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/genapkovl-gmos.sh

# Copia o script xfce-mint-config.sh para ser instalado na ISO
cp /workspace/gmos-builder/xfce-mint-config.sh /workspace/aports/scripts/
chmod +x /workspace/aports/scripts/xfce-mint-config.sh

# Registra o perfil GM OS na lista de perfis disponíveis
echo "[DOCKER] Registrando perfil gmos..."
if ! grep -q "gmos)" /workspace/aports/scripts/mkimage.sh 2>/dev/null; then
    # Adiciona o perfil gmos ao case statement do mkimage.sh
    # O perfil deve ser inserido DENTRO do case, após a linha 'case "$PROFILE" in'
    sed -i '/^case "\$PROFILE" in/a\
    # GM OS Profile\
    gmos)\
        . "$SCRIPT_DIR/mkimg.gmos.sh"\
        profile_gmos\
        ;;' /workspace/aports/scripts/mkimage.sh
    echo "[DOCKER] Perfil gmos adicionado ao mkimage.sh"
else
    echo "[DOCKER] Perfil gmos já está registrado no mkimage.sh"
fi

# Compilando a ISO
cd /workspace/aports/scripts
echo "[DOCKER] Iniciando processo de geração da ISO do GM OS..."
REPOS=""
for r in $(cat /etc/apk/repositories); do
    case "$r" in
        http*) REPOS="$REPOS --repository $r" ;;
    esac
done

# Exporta variáveis necessárias para o build
export MKSQUASHFS_OPTS='-noI -noD -noF -no-fragments'
export APK_OVERLAY_FROM="0"

# Executa o build com o perfil gmos
su builder -c "cd /workspace/aports/scripts && export MKSQUASHFS_OPTS='-noI -noD -noF -no-fragments' && sh mkimage.sh --tag 1.0 --outdir /workspace/output --profile gmos $REPOS"

echo "[DOCKER] Compilação concluída!"
