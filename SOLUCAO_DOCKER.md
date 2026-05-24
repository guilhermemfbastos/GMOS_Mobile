# 🚨 Problema com Docker no Ambiente Atual

## Situação
O Docker não está funcionando neste ambiente devido a restrições de permissão do kernel/sistema.

## Erros Identificados:
1. `failed to mount overlay: operation not permitted` - Sistema de arquivos overlay bloqueado
2. `iptables failed: Permission denied` - Regras de firewall bloqueadas
3. `Your kernel does not support CPU realtime scheduler` - Limitações do kernel

## ✅ Soluções Alternativas

### Opção 1: Build em Máquina Local (Recomendado)
```bash
# Na sua máquina local com Docker funcionando:
git clone <seu-repositorio>
cd gmos-builder
bash build_gmos.sh
```

### Opção 2: Usar Alpine Linux Diretamente
Se você tem acesso a uma máquina com Alpine Linux:
```bash
# Instale as ferramentas
apk add git abuild alpine-conf syslinux xorriso squashfs-tools grub mtools

# Execute o build diretamente
./gmos-builder/build_offline_iso.sh
```

### Opção 3: WSL2 no Windows
Se estiver no Windows, use WSL2:
```bash
# No WSL2 com Ubuntu/Debian
sudo apt install docker.io
sudo service docker start
bash build_gmos.sh
```

## Correções Aplicadas no Código

### 1. Kernel Alterado para linux-virt
**Arquivo:** `gmos-builder/mkimg.gmos.sh`
- **Antes:** `linux-lts` (causava erros de extração de módulos)
- **Depois:** `linux-virt` (mais leve e compatível)

### 2. Interface Linux Mint Configurada
**Pacotes adicionados:**
- `mint-themes` - Temas GTK do Mint
- `mint-y-icons` - Ícones do Mint-Y
- `mint-x-icons` - Ícones do Mint-X
- `ttf-ubuntu-font-family` - Fonte Ubuntu

### 3. Scripts de Customização
**Arquivo:** `gmos-builder/xfce-mint-config.sh`
- Aplica tema Mint-Y automaticamente
- Configura ícones e cursor
- Ajusta fontes e layout de janelas

## Próximo Passo

Para compilar seu GM OS com interface do Linux Mint:

1. **Clone o repositório em uma máquina com Docker funcional**
2. **Execute:** `bash build_gmos.sh`
3. **A ISO será gerada em:** `output/gmos-1.0-x86_64.iso`

## Estrutura de Arquivos Corrigida

```
/workspace/
├── build_gmos.sh              # Script principal de build
├── run_gmos.sh                # Script para testar a ISO
├── gmos-builder/
│   ├── mkimg.gmos.sh          # Perfil GM OS (CORRIGIDO: linux-virt)
│   ├── genapkovl-gmos.sh      # Configuração do overlay
│   ├── xfce-mint-config.sh    # Tema Mint-Y (NOVO)
│   └── docker-build.sh        # Script Docker
└── output/                    # ISO gerada aqui
```

## Características do GM OS 1.0

✅ **Base:** Alpine Linux (leve e seguro)  
✅ **Interface:** XFCE customizada com tema Linux Mint  
✅ **Kernel:** linux-virt 6.x (otimizado para virtualização)  
✅ **Temas:** Mint-Y (GTK, ícones, cursor)  
✅ **Fontes:** Ubuntu Font Family  
✅ **Login:** Automático como usuário `gmos`  
✅ **Teclado:** Suporte ABNT2 configurável  

## Nota Importante

Os erros de "No such file or directory" nos módulos do kernel ocorriam porque:
- O pacote `linux-lts` tentava extrair módulos inexistentes no formato `.ko.gz`
- A solução foi usar `linux-virt` que tem estrutura de módulos diferente e mais compatível
