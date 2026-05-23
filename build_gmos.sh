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

echo -e "${GREEN}[INFO] Executando contêiner de compilação...${NC}"

# Permite que o container execute o script de build interno
chmod +x "${WORKSPACE_DIR}/gmos-builder/docker-build.sh"

docker run --rm --privileged -v "${WORKSPACE_DIR}:/workspace" alpine:latest /bin/sh /workspace/gmos-builder/docker-build.sh

echo -e "${GREEN}[INFO] =================================================================${NC}"
echo -e "${GREEN}[INFO] GM OS 1.0 COMPILADO COM SUCESSO!${NC}"
echo -e "${GREEN}[INFO] A sua ISO está localizada na pasta: output/${NC}"
echo -e "${GREEN}[INFO] =================================================================${NC}"
