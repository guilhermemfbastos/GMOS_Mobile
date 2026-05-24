#!/bin/sh
# Script para registrar o perfil GM OS no sistema de build do Alpine Linux

SCRIPT_DIR="$(dirname "$0")"
PROFILES_DIR="$SCRIPT_DIR/profiles"

# Cria diretório de perfis se não existir
mkdir -p "$PROFILES_DIR"

# Copia o script mkimg.gmos.sh para a pasta scripts se ainda não estiver lá
if [ ! -f "$SCRIPT_DIR/mkimg.gmos.sh" ]; then
    echo "[ERROR] mkimg.gmos.sh não encontrado em $SCRIPT_DIR"
    exit 1
fi

# Cria o arquivo de perfil do GM OS
cat > "$PROFILES_DIR/gmos" << 'EOF'
# Perfil GM OS - Alpine Linux Custom com XFCE
profile_name="gmos"
profile_title="GM OS"
profile_desc="GM OS 1.0 - Custom Alpine with XFCE Desktop"
profile_script="mkimg.gmos.sh"
profile_apkovl="genapkovl-gmos.sh"
EOF

echo "[REGISTER] Perfil GM OS registrado com sucesso!"
echo "[REGISTER] Arquivo de perfil: $PROFILES_DIR/gmos"
echo "[REGISTER] Para build, use: mkimage.sh --profile gmos ..."
