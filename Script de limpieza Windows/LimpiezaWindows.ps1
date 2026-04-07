# ============================================================
#  LimpiezaWindows.ps1
#  Limpieza, temporales y optimización para Windows
#  Ejecutar como Administrador
# ============================================================

# Verificar que se ejecuta como Administrador
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Debes ejecutar este script como Administrador."
    Pause
    Exit
}

$ErrorActionPreference = "SilentlyContinue"

Function Write-Title($texto) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $texto" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
}

Function Write-OK($texto) {
    Write-Host "  [OK] $texto" -ForegroundColor Green
}

Function Write-INFO($texto) {
    Write-Host "  [>>] $texto" -ForegroundColor White
}

# ─────────────────────────────────────────────
# 1. ARCHIVOS TEMPORALES DEL SISTEMA Y USUARIO
# ─────────────────────────────────────────────
Write-Title "Limpiando archivos temporales"

$carpetasTemp = @(
    "$env:TEMP",
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\Prefetch",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
    "$env:APPDATA\Microsoft\Windows\Recent"
)

Foreach ($carpeta in $carpetasTemp) {
    If (Test-Path $carpeta) {
        $antes = (Get-ChildItem $carpeta -Recurse -Force | Measure-Object -Property Length -Sum).Sum
        Remove-Item "$carpeta\*" -Recurse -Force
        $liberado = [math]::Round($antes / 1MB, 2)
        Write-OK "Limpiado: $carpeta ($liberado MB liberados)"
    }
}

# ─────────────────────────────────────────────
# 2. PAPELERA DE RECICLAJE
# ─────────────────────────────────────────────
Write-Title "Vaciando Papelera de Reciclaje"
Clear-RecycleBin -Force -Confirm:$false
Write-OK "Papelera vaciada"

# ─────────────────────────────────────────────
# 3. CACHÉ DE WINDOWS UPDATE
# ─────────────────────────────────────────────
Write-Title "Limpiando caché de Windows Update"
Stop-Service -Name wuauserv -Force
Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service -Name wuauserv
Write-OK "Caché de Windows Update limpiada"

# ─────────────────────────────────────────────
# 4. LIBERADOR DE ESPACIO EN DISCO (cleanmgr)
# ─────────────────────────────────────────────
Write-Title "Ejecutando Liberador de Espacio en Disco"
Write-INFO "Configurando limpieza automática de disco C:..."

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$claves = @(
    "Active Setup Temp Folders",
    "BranchCache",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Memory Dump Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "Service Pack Cleanup",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Upgrade Discarded Files",
    "Windows Defender",
    "Windows Error Reporting Archive Files",
    "Windows Error Reporting Queue Files",
    "Windows Error Reporting System Archive Files",
    "Windows Error Reporting System Queue Files",
    "Windows ESD installation files",
    "Windows Upgrade Log Files"
)

Foreach ($clave in $claves) {
    $fullPath = "$regPath\$clave"
    If (Test-Path $fullPath) {
        Set-ItemProperty -Path $fullPath -Name "StateFlags0001" -Value 2 -Type DWORD
    }
}

Start-Process -FilePath cleanmgr.exe -ArgumentList "/sagerun:1" -Wait
Write-OK "Liberador de espacio ejecutado"

# ─────────────────────────────────────────────
# 5. REPARACIÓN DEL SISTEMA (SFC y DISM)
# ─────────────────────────────────────────────
Write-Title "Verificando integridad del sistema (SFC)"
Write-INFO "Esto puede tardar varios minutos..."
sfc /scannow

Write-Title "Reparando imagen de Windows (DISM)"
Write-INFO "Esto puede tardar varios minutos..."
DISM /Online /Cleanup-Image /RestoreHealth
Write-OK "Verificación y reparación completada"

# ─────────────────────────────────────────────
# 6. OPTIMIZACIÓN Y DESFRAGMENTACIÓN DE DISCO
# ─────────────────────────────────────────────
Write-Title "Optimizando disco C:"
Write-INFO "Detectando tipo de disco (SSD o HDD)..."

$disco = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 }
If ($disco.MediaType -eq "SSD") {
    Write-INFO "Disco SSD detectado — ejecutando TRIM..."
    Optimize-Volume -DriveLetter C -ReTrim -Verbose
    Write-OK "TRIM ejecutado en SSD"
} Else {
    Write-INFO "Disco HDD detectado — ejecutando desfragmentación..."
    Optimize-Volume -DriveLetter C -Defrag -Verbose
    Write-OK "Desfragmentación completada"
}

# ─────────────────────────────────────────────
# 7. LIMPIAR REGISTROS DE EVENTOS DE WINDOWS
# ─────────────────────────────────────────────
Write-Title "Limpiando registros de eventos"
$logs = Get-WinEvent -ListLog * | Where-Object { $_.RecordCount -gt 0 }
Foreach ($log in $logs) {
    Try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
    } Catch {}
}
Write-OK "Registros de eventos limpiados"

# ─────────────────────────────────────────────
# 8. LIMPIAR CACHÉ DE DNS
# ─────────────────────────────────────────────
Write-Title "Limpiando caché de DNS"
ipconfig /flushdns | Out-Null
Write-OK "Caché de DNS limpiada"

# ─────────────────────────────────────────────
# 9. AJUSTAR PLAN DE ENERGÍA A ALTO RENDIMIENTO
# ─────────────────────────────────────────────
Write-Title "Configurando plan de energía: Alto rendimiento"
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
Write-OK "Plan de energía establecido en Alto rendimiento"

# ─────────────────────────────────────────────
# 10. DESHABILITAR PROGRAMAS DE INICIO INNECESARIOS
# ─────────────────────────────────────────────
Write-Title "Revisando programas en el inicio"
Write-INFO "Abriendo Administrador de Tareas > Inicio para revisión manual..."
Start-Process "taskmgr.exe" -ArgumentList "/7"
Write-OK "Revisa la pestaña 'Inicio' en el Administrador de Tareas para deshabilitar lo innecesario"

# ─────────────────────────────────────────────
# RESUMEN FINAL
# ─────────────────────────────────────────────
Write-Host "`n`n"
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   LIMPIEZA Y OPTIMIZACIÓN COMPLETADA   " -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  Se recomienda REINICIAR el equipo ahora." -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Magenta

Pause
