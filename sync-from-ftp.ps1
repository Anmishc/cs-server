<#
.SYNOPSIS
    Синхронизация файлов с FTP сервера (скачивает актуальные версии).
    Запускай когда хочешь подтянуть изменения, сделанные напрямую на сервере.

.PARAMETER Env
    Окружение: prod (продакшн) или dev (девелопмент)
    По умолчанию: prod

.EXAMPLE
    .\sync-from-ftp.ps1
    .\sync-from-ftp.ps1 -Env dev
#>
param(
    [ValidateSet("prod","dev")]
    [string]$Env = "prod"
)

if ($Env -eq "dev") {
    $FTP_HOST = "91.211.118.156"
    $FTP_PORT = 21
    $FTP_USER = "s37144"
    $FTP_PASS = "290001"
} else {
    $FTP_HOST = "91.211.118.77"
    $FTP_PORT = 21
    $FTP_USER = "s37112"
    $FTP_PASS = "109218"
}
$FTP_BASE = "ftp://${FTP_HOST}:${FTP_PORT}"
$LOCAL_ROOT = $PSScriptRoot

function Download-FtpFile($ftpPath, $localPath) {
    try {
        $req = [System.Net.FtpWebRequest]::Create("$FTP_BASE/$ftpPath")
        $req.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $req.Timeout = 30000; $req.UseBinary = $true
        $resp = $req.GetResponse(); $stream = $resp.GetResponseStream()
        $localDir = Split-Path $localPath -Parent
        if (-not (Test-Path $localDir)) { New-Item -ItemType Directory -Force -Path $localDir | Out-Null }
        $fileStream = [System.IO.File]::Create($localPath)
        $stream.CopyTo($fileStream); $fileStream.Close(); $stream.Close(); $resp.Close()
        return $true
    } catch { return $false }
}

function Get-FtpFileList($path) {
    try {
        $req = [System.Net.FtpWebRequest]::Create("$FTP_BASE/$path")
        $req.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory; $req.Timeout = 15000
        $resp = $req.GetResponse(); $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $data = $reader.ReadToEnd(); $reader.Close(); $resp.Close()
        return $data.Trim().Split("`n") | ForEach-Object {
            ($_.Trim() -replace "`r","" -split "/")[-1]
        } | Where-Object { $_ -ne "" }
    } catch { return @() }
}

function Sync-Dir($ftpDir, $localDir, $label) {
    Write-Host "`n📥 $label..." -ForegroundColor Cyan
    $files = Get-FtpFileList $ftpDir; $ok = 0; $skip = 0
    foreach ($f in $files) {
        if ($f -match "\.(exe|dll|so|mmdb)$" -or $f -eq "amxxpc") { continue }
        $localPath = "$localDir\$f"
        $result = Download-FtpFile "$ftpDir/$f" $localPath
        if ($result) { $ok++; Write-Host "  ✅ $f" -ForegroundColor Gray } else { $skip++ }
    }
    Write-Host "  → $ok файлов синхронизировано" -ForegroundColor Green
}

Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    CS 1.6 — Sync from FTP Server     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
$envLabel = if ($Env -eq 'dev') { 'DEV' } else { 'PROD' }
$envColor = if ($Env -eq 'dev') { 'Yellow' } else { 'White' }
Write-Host "  Окружение: [$envLabel] | Сервер: $FTP_HOST" -ForegroundColor $envColor
$startTime = Get-Date

Sync-Dir "addons/amxmodx/plugins"           "$LOCAL_ROOT\addons\amxmodx\plugins"           "Плагины (.amxx)"
Sync-Dir "addons/amxmodx/scripting"          "$LOCAL_ROOT\addons\amxmodx\scripting"          "Исходники (.sma)"
Sync-Dir "addons/amxmodx/scripting/include"  "$LOCAL_ROOT\addons\amxmodx\scripting\include"  "Include файлы"
Sync-Dir "addons/amxmodx/configs"            "$LOCAL_ROOT\addons\amxmodx\configs"            "Конфиги AMX"
Sync-Dir "addons/amxmodx/configs/plugins"    "$LOCAL_ROOT\addons\amxmodx\configs\plugins"    "Конфиги плагинов"
Sync-Dir "addons/amxmodx/configs/mode"       "$LOCAL_ROOT\addons\amxmodx\configs\mode"       "Конфиги режимов"
Sync-Dir "addons/amxmodx/configs/rt_configs" "$LOCAL_ROOT\addons\amxmodx\configs\rt_configs" "RT конфиги"
Sync-Dir "addons/amxmodx/configs/aes"        "$LOCAL_ROOT\addons\amxmodx\configs\aes"        "AES конфиги"
Sync-Dir "addons/metamod"                    "$LOCAL_ROOT\addons\metamod"                    "Metamod"
Sync-Dir "addons/amxmodx/data"               "$LOCAL_ROOT\addons\amxmodx\data"               "Data файлы"
Sync-Dir "addons/amxmodx/data/lang"          "$LOCAL_ROOT\addons\amxmodx\data\lang"          "Lang файлы"
Sync-Dir "sprites"                           "$LOCAL_ROOT\sprites"                           "Спрайты (корень)"
Sync-Dir "sprites/mode"                      "$LOCAL_ROOT\sprites\mode"                      "Спрайты режимов"
Sync-Dir "sprites/reapi_healthnade"          "$LOCAL_ROOT\sprites\reapi_healthnade"          "Спрайты healthnade"
Sync-Dir "models/reapi_healthnade"            "$LOCAL_ROOT\models\reapi_healthnade"            "Модели healthnade"
Sync-Dir "models/vipwhitelion"               "$LOCAL_ROOT\models\vipwhitelion"               "Модели VIP White Lion"
Sync-Dir "models/vipwildstyle"               "$LOCAL_ROOT\models\vipwildstyle"               "Модели VIP Wild Style"
Sync-Dir "models/vipdarksnake"               "$LOCAL_ROOT\models\vipdarksnake"               "Модели VIP Dark Snake"
Sync-Dir "models/vipmurder"                  "$LOCAL_ROOT\models\vipmurder"                  "Модели VIP Murder"
Sync-Dir "models/viphyperbeast"              "$LOCAL_ROOT\models\viphyperbeast"              "Модели VIP Hyperbeast"
Sync-Dir "models/premiumrageseries"          "$LOCAL_ROOT\models\premiumrageseries"          "Модели Premium Rage"
Sync-Dir "models/platinumstickers"           "$LOCAL_ROOT\models\platinumstickers"           "Модели Platinum Stickers"
Sync-Dir "models/platinumcosmo"              "$LOCAL_ROOT\models\platinumcosmo"              "Модели Platinum Cosmo"
Sync-Dir "models/platinumnightwish"          "$LOCAL_ROOT\models\platinumnightwish"          "Модели Platinum Nightwish"

# Server configs
Write-Host "`n📥 Server configs..." -ForegroundColor Cyan
$cfgs = @("server.cfg","game.cfg","game_init.cfg","mapcycle.txt","fastdl.cfg","dproto.cfg","reunion.cfg")
$ok = 0
foreach ($f in $cfgs) {
    if (Download-FtpFile $f "$LOCAL_ROOT\server-configs\$f") { $ok++; Write-Host "  ✅ $f" -ForegroundColor Gray }
}
Write-Host "  → $ok файлов синхронизировано" -ForegroundColor Green

$elapsed = (Get-Date) - $startTime
Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║      ✅ Синхронизация завершена!      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
Write-Host "  Время: $([math]::Round($elapsed.TotalSeconds, 1))s" -ForegroundColor White
