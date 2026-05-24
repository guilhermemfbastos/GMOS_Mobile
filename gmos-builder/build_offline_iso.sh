#!/bin/bash
set -e

echo "[GMOS] =========================================="
echo "[GMOS] Iniciando a construção OFFLINE da ISO Customizada!"
echo "[GMOS] =========================================="

echo "[GMOS] 1. Instalando dependências..."
sudo apt-get update
sudo apt-get install -y xorriso squashfs-tools libarchive-tools isolinux

# Diretório de build
BUILD_DIR="/tmp/gmos_offline_build"
sudo rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR/extracted_iso

BASE_ISO="output/gmos-base.iso"
if [ ! -f "$BASE_ISO" ]; then
    echo "[ERRO] ISO base não encontrada em $BASE_ISO. Execute o run_gmos.sh primeiro para baixá-la."
    exit 1
fi

echo "[GMOS] 2. Extraindo ISO base original..."
bsdtar -xf "$BASE_ISO" -C $BUILD_DIR/extracted_iso/
sudo chmod -R +w $BUILD_DIR/extracted_iso/

echo "[GMOS] 3. Descompactando o sistema de arquivos (Isso pode demorar um pouco)..."
sudo unsquashfs -d $BUILD_DIR/squashfs-root $BUILD_DIR/extracted_iso/casper/filesystem.squashfs

echo "[GMOS] 4. Injetando assets e script de setup..."
sudo cp gmos_wallpaper.png gmos_menu_icon.png gmos_boot_splash.png $BUILD_DIR/squashfs-root/tmp/ 2>/dev/null || true
sudo cp gmos-builder/chroot_setup.sh $BUILD_DIR/squashfs-root/root/
sudo chmod +x $BUILD_DIR/squashfs-root/root/chroot_setup.sh

echo "[GMOS] 5. Montando sistemas de arquivos virtuais para o chroot..."
sudo mount --bind /dev $BUILD_DIR/squashfs-root/dev
sudo mount --bind /proc $BUILD_DIR/squashfs-root/proc
sudo mount --bind /sys $BUILD_DIR/squashfs-root/sys

echo "[GMOS] 6. Executando customização interna via chroot..."
sudo chroot $BUILD_DIR/squashfs-root /bin/bash /root/chroot_setup.sh

echo "[GMOS] 7. Desmontando sistemas de arquivos virtuais e limpando rastros..."
sudo umount $BUILD_DIR/squashfs-root/sys
sudo umount $BUILD_DIR/squashfs-root/proc
sudo umount $BUILD_DIR/squashfs-root/dev
sudo rm -f $BUILD_DIR/squashfs-root/root/chroot_setup.sh

echo "[GMOS] 8. Recompactando o sistema de arquivos (Isso demora alguns minutos)..."
sudo rm -f $BUILD_DIR/extracted_iso/casper/filesystem.squashfs
# Usando a compressão padrão com múltiplos processadores para máxima velocidade
sudo mksquashfs $BUILD_DIR/squashfs-root $BUILD_DIR/extracted_iso/casper/filesystem.squashfs -noappend -b 1048576 -comp zstd || sudo mksquashfs $BUILD_DIR/squashfs-root $BUILD_DIR/extracted_iso/casper/filesystem.squashfs -noappend

echo "[GMOS] 9. Atualizando metadados da ISO..."
sudo su -c "printf \$(sudo du -sx --block-size=1 $BUILD_DIR/squashfs-root | awk '{print \$1}') > $BUILD_DIR/extracted_iso/casper/filesystem.size"

cd $BUILD_DIR/extracted_iso
sudo rm -f md5sum.txt
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt > /dev/null

echo "[GMOS] 10. Construindo a ISO final (gmos-custom.iso)..."
cd ../../
sudo xorriso -as mkisofs -r -V "GMOS_CUSTOM" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -o gmos-custom.iso $BUILD_DIR/extracted_iso

echo "[GMOS] 11. Limpando diretórios de build temporários..."
sudo rm -rf $BUILD_DIR

echo "[GMOS] =========================================="
echo "[GMOS] SUCESSO! A ISO customizada OFFLINE foi gerada:"
echo "[GMOS] gmos-custom.iso"
echo "[GMOS] Para testar: bash run_gmos.sh gmos-custom.iso"
echo "[GMOS] =========================================="
