# ============================================================
#  InstalarTarea.ps1
#  Registra la tarea programada en el Programador de Tareas
#  Ejecutar UNA SOLA VEZ como Administrador
# ============================================================

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Debes ejecutar este script como Administrador."
    Pause
    Exit
}

# ─── PASO 1: Crear carpeta de scripts ────────────────────────
$carpeta = "C:\Scripts"
If (-Not (Test-Path $carpeta)) {
    New-Item -ItemType Directory -Path $carpeta | Out-Null
    Write-Host "[OK] Carpeta creada: $carpeta" -ForegroundColor Green
}

# ─── PASO 2: Copiar scripts a C:\Scripts ─────────────────────
# Ajusta las rutas de origen si los descargaste en otro lugar
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path

$archivos = @("Monitor.ps1", "LimpiezaWindows.ps1")
Foreach ($archivo in $archivos) {
    $src = Join-Path $origen $archivo
    $dst = Join-Path $carpeta $archivo
    If (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "[OK] Copiado: $archivo → $carpeta" -ForegroundColor Green
    } Else {
        Write-Warning "No se encontró $archivo junto a este instalador. Cópialo manualmente a $carpeta"
    }
}

# ─── PASO 3: Crear la tarea programada ───────────────────────
$nombreTarea   = "MonitorSistemaWindows"
$descripcion   = "Monitorea RAM y Disco cada 30 min y limpia si superan el umbral"
$scriptMonitor = "C:\Scripts\Monitor.ps1"
$intervalo     = 30  # minutos entre cada revisión

# Acción: ejecutar PowerShell con el monitor
$accion = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptMonitor`""

# Disparador: repetir cada X minutos indefinidamente
$disparador = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $intervalo) -Once -At (Get-Date)

# Configuración: ejecutar aunque no haya sesión activa, con privilegios
$configuracion = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 60) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -StartWhenAvailable

# Principal: ejecutar como SYSTEM con máximos privilegios
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Registrar la tarea
Register-ScheduledTask `
    -TaskName $nombreTarea `
    -Action $accion `
    -Trigger $disparador `
    -Settings $configuracion `
    -Principal $principal `
    -Description $descripcion `
    -Force | Out-Null

Write-Host "`n============================================" -ForegroundColor Magenta
Write-Host "   TAREA INSTALADA CORRECTAMENTE" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  Nombre  : $nombreTarea" -ForegroundColor White
Write-Host "  Intervalo: cada $intervalo minutos" -ForegroundColor White
Write-Host "  Monitor  : $scriptMonitor" -ForegroundColor White
Write-Host "  Log      : C:\Scripts\monitor_log.txt" -ForegroundColor White
Write-Host "============================================`n" -ForegroundColor Magenta
Write-Host "  Puedes cambiar el intervalo editando esta" -ForegroundColor Yellow
Write-Host "  variable en Monitor.ps1:" -ForegroundColor Yellow
Write-Host "    `$umbralRAM   = 85  (% de RAM)" -ForegroundColor Cyan
Write-Host "    `$umbralDisco = 90  (% de Disco)" -ForegroundColor Cyan
Write-Host ""

Pause
