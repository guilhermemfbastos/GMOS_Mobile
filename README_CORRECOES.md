# GM OS - Alpine Linux Customizado

## Problemas Identificados e Correções

### Problema 1: Perfil não registrado no mkimage.sh
**Problema:** O script `mkimg.gmos.sh` definia a função `profile_gmos()`, mas o perfil não estava registrado no script principal `mkimage.sh` do Alpine Linux.

**Solução:** O `docker-build.sh` agora registra automaticamente o perfil `gmos` no `mkimage.sh` usando `sed` para inserir o case statement necessário.

### Problema 2: Chamadas incorretas a funções inexistentes
**Problema:** O `mkimg.gmos.sh` original chamava `profile_base` e `profile_standard`, que não existem no contexto de perfis customizados.

**Solução:** Removidas as chamadas para funções inexistentes. Agora o perfil define diretamente todas as variáveis necessárias (`apks`, `kernel_flavors`, etc.).

### Problema 3: Parâmetro unionfs_size inválido
**Problema:** O parâmetro `unionfs_size=512M` no `kernel_cmdline` não é reconhecido pelo kernel do Alpine.

**Solução:** Removido o parâmetro inválido do `kernel_cmdline`.

### Problema 4: Pacotes de vídeo desnecessários
**Problema:** Pacotes como `xf86-video-fbdev` e `xf86-video-vesa` são obsoletos e podem causar conflitos.

**Solução:** Removidos pacotes desnecessários e adicionados pacotes essenciais como `ttf-dejavu` e `murrine-themes` para melhor aparência.

### Problema 5: Script genapkovl sem feedback
**Problema:** O script `genapkovl-gmos.sh` não fornecia feedback sobre sucesso na criação do overlay.

**Solução:** Adicionada mensagem de confirmação ao final da execução.

## Como Usar

### Build da ISO

```bash
# Executar build completo via Docker
bash build_gmos.sh
```

O processo irá:
1. Clonar o repositório `aports` do Alpine Linux
2. Copiar os scripts customizados do GM OS
3. Registrar o perfil `gmos` no sistema de build
4. Compilar a ISO com todas as personalizações

### Testar a ISO

```bash
# Rodar a ISO em QEMU com noVNC
bash run_gmos.sh output/gmos-1.0-x86_64.iso
```

### Personalizações Incluídas

- **XFCE Desktop Environment** com login automático
- **Tema Mint-Y** (ícones e janelas)
- **Wallpaper customizado** do GM OS
- **Ícone do menu** personalizado
- **Usuário "gmos"** criado automaticamente com senha "gmos"
- **LightDM** configurado para autologin
- **Serviços essenciais** configurados (dbus, networking, etc.)

## Estrutura de Arquivos

```
/workspace/
├── build_gmos.sh              # Script principal de build
├── run_gmos.sh                # Script para testar a ISO
├── gmos-builder/
│   ├── docker-build.sh        # Script executado dentro do Docker
│   ├── mkimg.gmos.sh          # Definição do perfil GM OS
│   ├── genapkovl-gmos.sh      # Geração do overlay de configuração
│   ├── chroot_setup.sh        # Setup pós-instalação (opcional)
│   └── build_offline_iso.sh   # Build offline (avançado)
├── gmos_wallpaper.png         # Wallpaper customizado
├── gmos_menu_icon.png         # Ícone do menu
└── gmos_boot_splash.png       # Splash screen do boot
```

## Requisitos

- Docker instalado e funcionando
- Espaço em disco: ~5GB para build
- Memória RAM: Mínimo 2GB recomendados

## Troubleshooting

### Erro: "Profile gmos not found"
Verifique se o perfil foi registrado corretamente no `mkimage.sh`:
```bash
grep -A 3 "gmos)" /workspace/aports/scripts/mkimage.sh
```

### Erro: "Package not found"
Verifique os repositórios APK no `genapkovl-gmos.sh` e certifique-se de que estão acessíveis.

### Build falha no Docker
Execute manualmente para debug:
```bash
docker run --rm -it --privileged -v "$(pwd):/workspace" alpine:latest /bin/sh
# Dentro do container:
/workspace/gmos-builder/docker-build.sh
```

## Notas Importantes

1. O primeiro build pode demorar (30-60 minutos) devido ao download de pacotes
2. A ISO gerada fica na pasta `output/`
3. Use o script `run_gmos.sh` para testar sem precisar gravar em USB
4. As personalizações visuais são aplicadas via overlay (apkovl) no boot
