# ==============================================================================
# Script para emular o GM OS Mobile localmente usando WSL (QEMU) e noVNC
# Carrega a ISO via streaming diretamente do GitHub (sem download prévio)
# ==============================================================================

$RELEASE_URL = "https://github.com/guilhermemfbastos/GMOS_Mobile/releases/latest/download/GM-OS-Mobile.iso"

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "🖥️  INICIANDO EMULADOR VIA WSL (Windows Subsystem for Linux)"
Write-Host "=================================================================" -ForegroundColor Green

# 1. Verificar se o WSL está disponível
$wslCheck = wsl --list --quiet 2>$null
if ($null -eq $wslCheck) {
    Write-Host "[ERRO] WSL não parece estar instalado ou ativo no sistema." -ForegroundColor Red
    exit 1
}

# 2. Verificar se o QEMU está instalado no WSL
Write-Host "[INFO] Verificando QEMU dentro do WSL..." -ForegroundColor Cyan
$qemuInstalled = wsl which qemu-system-x86_64 2>$null
if ([string]::IsNullOrEmpty($qemuInstalled)) {
    Write-Host "[INFO] Instalar qemu-system-x86 no WSL (pode solicitar sua senha do WSL)..." -ForegroundColor Yellow
    wsl sudo apt-get update
    wsl sudo apt-get install -y qemu-system-x86
}

Write-Host "[INFO] Iniciando QEMU em background no WSL..." -ForegroundColor Cyan
Write-Host "[INFO] Streaming da ISO: $RELEASE_URL" -ForegroundColor Gray

# Executa em background no WSL usando bash -c, nohup e & (envolvido em aspas para o PowerShell não falhar)
wsl bash -c "nohup qemu-system-x86_64 -m 2048 -smp 2 -accel kvm -accel tcg -drive media=cdrom,readonly=on,file.driver=https,file.url=$RELEASE_URL -vga std -vnc 0.0.0.0:0,websocket=6080 > /dev/null 2>&1 &"

Write-Host "[INFO] Aguardando o emulador iniciar as portas..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# 3. Abrir o noVNC no navegador padrão do Windows (localhost se comunica diretamente com o WSL)
Write-Host "[INFO] Abrindo o noVNC no seu navegador..." -ForegroundColor Cyan
Start-Process "https://novnc.com/noVNC/vnc.html?host=localhost&port=6080&autoconnect=true"

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "Caso o navegador não tenha aberto automaticamente, acesse:"
Write-Host "https://novnc.com/noVNC/vnc.html?host=localhost&port=6080&autoconnect=true" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Green
