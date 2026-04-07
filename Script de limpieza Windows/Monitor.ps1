# ============================================================
#  Monitor.ps1
#  Monitorea RAM y Disco — activa limpieza si superan umbral
#  No modificar — es llamado automáticamente por el Scheduler
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# ─── CONFIGURACIÓN DE UMBRALES ───────────────────────────────
$umbralRAM   = 85   # % de RAM usada para activar limpieza
$umbralDisco = 90   # % de Disco usado para activar limpieza

# ─── RUTA DEL SCRIPT DE LIMPIEZA ─────────────────────────────
# ⚠️ Ajusta esta ruta a donde guardaste LimpiezaWindows.ps1
$scriptLimpieza = "C:\Scripts\LimpiezaWindows.ps1"

# ─── LOG ──────────────────────────────────────────────────────
$logPath = "C:\Scripts\monitor_log.txt"

Function Write-Log($mensaje) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "[$timestamp] $mensaje"
}

# ─── MEDIR RAM ────────────────────────────────────────────────
$os        = Get-CimInstance Win32_OperatingSystem
$ramTotal  = $os.TotalVisibleMemorySize
$ramLibre  = $os.FreePhysicalMemory
$ramUsada  = [math]::Round((($ramTotal - $ramLibre) / $ramTotal) * 100, 1)

# ─── MEDIR DISCO C: ───────────────────────────────────────────
$disco      = Get-PSDrive -Name C
$discoTotal = $disco.Used + $disco.Free
$discoUsado = [math]::Round(($disco.Used / $discoTotal) * 100, 1)

# ─── EVALUACIÓN Y ACCIÓN ─────────────────────────────────────
Write-Log "Revisión — RAM: $ramUsada%  |  Disco: $discoUsado%"

$activar = $false
$motivo  = @()

If ($ramUsada -ge $umbralRAM) {
    $motivo  += "RAM al $ramUsada% (umbral: $umbralRAM%)"
    $activar  = $true
}

If ($discoUsado -ge $umbralDisco) {
    $motivo  += "Disco al $discoUsado% (umbral: $umbralDisco%)"
    $activar  = $true
}

If ($activar) {
    $motivoTexto = $motivo -join " | "
    Write-Log "ALERTA: $motivoTexto — Iniciando limpieza..."

    # Mostrar notificación en pantalla
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Se detectó uso alto de recursos:`n$motivoTexto`n`nIniciando limpieza automática...",
        "Monitor del Sistema",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    # Ejecutar limpieza como Administrador
    If (Test-Path $scriptLimpieza) {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptLimpieza`"" -Verb RunAs
        Write-Log "Script de limpieza ejecutado correctamente."
    } Else {
        Write-Log "ERROR: No se encontró el script en $scriptLimpieza"
    }

} Else {
    Write-Log "Sistema en buen estado. No se requiere acción."
}
