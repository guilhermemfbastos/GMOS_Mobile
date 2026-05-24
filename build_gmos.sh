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

# Cria contêiner com nome fixo para poder copiar os arquivos depois
CONTAINER_NAME="gmos-builder-$$"

docker run --name "$CONTAINER_NAME" --privileged -v "${WORKSPACE_DIR}:/workspace" alpine:latest /bin/sh /workspace/gmos-builder/docker-build.sh

# Copia a ISO gerada para fora do contêiner
echo -e "${GREEN}[DOCKER] Copiando ISO para o ambiente local...${NC}"
docker cp "$CONTAINER_NAME":/workspace/output/gmos-1.0-x86_64.iso "${OUTPUT_DIR}/" 2>/dev/null || {
    echo -e "${RED}[WARNING] Não foi possível copiar a ISO. Verificando arquivos no contêiner...${NC}"
    docker cp "$CONTAINER_NAME":/workspace/output/. "${OUTPUT_DIR}/" 2>/dev/null || true
}

# Remove o contêiner
docker rm "$CONTAINER_NAME" >/dev/null 2>&1

# Verifica se a ISO existe
if [ -f "${OUTPUT_DIR}/gmos-1.0-x86_64.iso" ]; then
    echo -e "${GREEN}[INFO] =================================================================${NC}"
    echo -e "${GREEN}[INFO] GM OS 1.0 COMPILADO COM SUCESSO!${NC}"
    echo -e "${GREEN}[INFO] A sua ISO está localizada na pasta: output/${NC}"
    echo -e "${GREEN}[INFO] =================================================================${NC}"
    ls -lh "${OUTPUT_DIR}/"
else
    echo -e "${RED}[ERROR] A ISO não foi encontrada após a compilação!${NC}"
    echo -e "${RED}[INFO] Verifique os logs acima para mais detalhes.${NC}"
    exit 1
fi
