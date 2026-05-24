#!/bin/bash
# Script para rodar no Codespace (host) e montar a ISO final

echo "[GMOS] =========================================="
echo "[GMOS] Iniciando a geração da ISO Customizada!"
echo "[GMOS] =========================================="

sudo apt-get update
sudo apt-get install -y xorriso squashfs-tools libarchive-tools isolinux

# Monta o disco onde a VM exportou os arquivos
echo "[GMOS] Montando workspace.img localmente..."
sudo mkdir -p /mnt/workspace_host
sudo mount -o loop workspace.img /mnt/workspace_host

if [ ! -d "/mnt/workspace_host/gmos_overlay" ]; then
    echo "[ERRO] gmos_overlay não encontrado no disco virtual. A VM exportou corretamente?"
    sudo umount /mnt/workspace_host
    exit 1
fi

echo "[GMOS] Preparando diretórios de build..."
BUILD_DIR="/tmp/gmos_iso_build"
sudo rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR/extracted_iso

echo "[GMOS] Extraindo ISO base original..."
# Usando bsdtar que lida muito bem com ISOs
bsdtar -xf output/gmos-base.iso -C $BUILD_DIR/extracted_iso/
sudo chmod -R +w $BUILD_DIR/extracted_iso/

echo "[GMOS] Injetando customizações no SquashFS (Appending)..."
# O mksquashfs adiciona/sobrescreve os arquivos no squashfs existente por padrão
sudo mksquashfs /mnt/workspace_host/gmos_overlay $BUILD_DIR/extracted_iso/casper/filesystem.squashfs -e "var/cache" "tmp" "var/log"

echo "[GMOS] Atualizando tamanho do sistema de arquivos..."
sudo su -c "printf \$(sudo du -sx --block-size=1 $BUILD_DIR/extracted_iso/casper/filesystem.squashfs | awk '{print \$1}') > $BUILD_DIR/extracted_iso/casper/filesystem.size"

echo "[GMOS] Gerando novos MD5 sums..."
cd $BUILD_DIR/extracted_iso
sudo rm -f md5sum.txt
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt > /dev/null

echo "[GMOS] Construindo a nova ISO (gmos-custom.iso)..."
cd ../../
sudo xorriso -as mkisofs -r -V "GMOS_CUSTOM" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -o gmos-custom.iso $BUILD_DIR/extracted_iso

echo "[GMOS] Limpando arquivos temporários..."
sudo umount /mnt/workspace_host
sudo rm -rf $BUILD_DIR

echo "[GMOS] =========================================="
echo "[GMOS] SUCESSO! A ISO customizada foi gerada:"
echo "[GMOS] gmos-custom.iso"
echo "[GMOS] =========================================="
