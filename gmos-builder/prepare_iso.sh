#!/bin/bash
# Script executado dentro da VM para exportar as customizações

echo "[GMOS] Iniciando a exportação das customizações para o disco virtual..."

# Encontrar o disco virtual formatado em ext4 (criado no Codespace)
DISK=$(sudo blkid | grep ext4 | cut -d: -f1 | head -n 1)

if [ -z "$DISK" ]; then
    echo "[ERRO] Disco virtual (workspace.img) não encontrado na VM!"
    exit 1
fi

echo "[GMOS] Montando o disco virtual $DISK em /mnt/workspace..."
sudo mkdir -p /mnt/workspace
sudo mount $DISK /mnt/workspace

# Encontrar o diretório onde o Live CD salva as modificações (upperdir do overlayfs)
UPPER_DIR=$(mount | grep overlay | grep -oP 'upperdir=\K[^,]+' | head -n 1)

if [ -z "$UPPER_DIR" ]; then
    # Fallback comum do casper
    if [ -d "/cow" ]; then
        UPPER_DIR="/cow"
    else
        echo "[ERRO] Diretório de modificações (overlay) não encontrado!"
        sudo umount /mnt/workspace
        exit 1
    fi
fi

echo "[GMOS] Diretório de modificações encontrado: $UPPER_DIR"

# Limpar arquivos temporários inúteis para não engordar a ISO
sudo rm -rf $UPPER_DIR/var/cache/apt/archives/* 2>/dev/null || true
sudo rm -rf $UPPER_DIR/tmp/* 2>/dev/null || true
sudo rm -rf $UPPER_DIR/var/log/* 2>/dev/null || true

echo "[GMOS] Copiando customizações para o disco virtual..."
sudo mkdir -p /mnt/workspace/gmos_overlay
# Usar rsync ou cp para copiar preservando as permissões e links
sudo cp -a $UPPER_DIR/* /mnt/workspace/gmos_overlay/ 2>/dev/null || true

echo "[GMOS] Sincronizando dados..."
sudo sync

echo "[GMOS] Desmontando disco..."
sudo umount /mnt/workspace

echo "[GMOS] Exportação concluída! Desligando a VM para o Codespace assumir..."
sudo poweroff
