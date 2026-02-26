<#
.SYNOPSIS
    Деплой файлов CS 1.6 сервера на FTP.

.PARAMETER Only
    Деплоить только определённую категорию: plugins, configs, server, scripting, all
    По умолчанию: all

.PARAMETER Env
    Окружение: prod (продакшн) или dev (девелопмент)
    По умолчанию: prod

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -Only plugins
    .\deploy.ps1 -Only configs
    .\deploy.ps1 -Env dev
    .\deploy.ps1 -Env dev -Only plugins
#>
param(
    [string]$Only = "all",
    [ValidateSet("prod","dev")]
    [string]$Env = "prod"
)

# ============================
# НАСТРОЙКИ FTP
# ============================
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

# ============================
# ФУНКЦИИ
# ============================

function Upload-File($localPath, $ftpPath) {
    try {
        $uri = "$FTP_BASE/$ftpPath"
        $req = [System.Net.FtpWebRequest]::Create($uri)
        $req.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $req.UseBinary = $true
        $req.Timeout = 30000

        $fileContent = [System.IO.File]::ReadAllBytes($localPath)
        $req.ContentLength = $fileContent.Length
        $reqStream = $req.GetRequestStream()
        $reqStream.Write($fileContent, 0, $fileContent.Length)
        $reqStream.Close()

        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch {
        Write-Host "    ❌ Ошибка загрузки $ftpPath : $_" -ForegroundColor Red
        return $false
    }
}

function Ensure-FtpDir($ftpDir) {
    try {
        $uri = "$FTP_BASE/$ftpDir"
        $req = [System.Net.FtpWebRequest]::Create($uri)
        $req.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $req.Timeout = 10000
        $resp = $req.GetResponse()
        $resp.Close()
    } catch {
        # 550 = уже существует, игнорируем
    }
}

function Ensure-FtpDirTree($ftpPath) {
    # Создаём все родительские директории по цепочке
    $parts = $ftpPath.TrimEnd("/") -split "/"
    $current = ""
    foreach ($part in $parts) {
        if ($part -eq "") { continue }
        $current = if ($current -eq "") { $part } else { "$current/$part" }
        Ensure-FtpDir $current
    }
}

function Deploy-Folder($localFolder, $ftpFolder, $label) {
    Write-Host "`n📤 $label..." -ForegroundColor Cyan
    $files = Get-ChildItem $localFolder -File -Recurse -ErrorAction SilentlyContinue
    $ok = 0; $fail = 0
    $createdDirs = @{}
    foreach ($f in $files) {
        $relative = $f.FullName.Substring($localFolder.Length).TrimStart("\").Replace("\", "/")
        $ftpPath = "$ftpFolder/$relative"
        # Создаём папку на FTP если ещё не создавали
        $ftpDir = ($ftpPath -split "/")[0..($ftpPath.Split("/").Count - 2)] -join "/"
        if (-not $createdDirs[$ftpDir]) {
            Ensure-FtpDirTree $ftpDir
            $createdDirs[$ftpDir] = $true
        }
        $result = Upload-File $f.FullName $ftpPath
        if ($result) { $ok++; Write-Host "  ✅ $relative" -ForegroundColor Gray }
        else { $fail++ }
    }
    Write-Host "  → $ok загружено, $fail ошибок" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
}

# ============================
# ДЕПЛОЙ
# ============================

Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║    CS 1.6 Server — Deploy to FTP     ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta
$envLabel = if ($Env -eq 'dev') { 'DEV' } else { 'PROD' }
$envColor = if ($Env -eq 'dev') { 'Yellow' } else { 'White' }
Write-Host "  Окружение: [$envLabel] | Сервер: $FTP_HOST | Режим: $Only" -ForegroundColor $envColor
Write-Host ""

$startTime = Get-Date

switch ($Only.ToLower()) {
    "plugins" {
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\plugins" "addons/amxmodx/plugins" "Плагины (.amxx)"
    }
    "configs" {
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\configs" "addons/amxmodx/configs" "Конфиги AMX"
        Deploy-Folder "$LOCAL_ROOT\addons\metamod" "addons/metamod" "Metamod конфиг"
        if (Test-Path "$LOCAL_ROOT\addons\amxmodx\data\lang") {
            Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\data\lang" "addons/amxmodx/data/lang" "Lang файлы"
        }
        if (Test-Path "$LOCAL_ROOT\sprites") {
            Deploy-Folder "$LOCAL_ROOT\sprites" "sprites" "Спрайты"
        }
        if (Test-Path "$LOCAL_ROOT\models") {
            Deploy-Folder "$LOCAL_ROOT\models" "models" "Модели"
        }
    }
    "server" {
        $cfgs = @("server.cfg","game.cfg","game_init.cfg","mapcycle.txt","fastdl.cfg","dproto.cfg","reunion.cfg")
        Write-Host "`n📤 Server configs..." -ForegroundColor Cyan
        $ok = 0
        foreach ($f in $cfgs) {
            $local = "$LOCAL_ROOT\server-configs\$f"
            if (Test-Path $local) {
                if (Upload-File $local $f) { $ok++; Write-Host "  ✅ $f" -ForegroundColor Gray }
            }
        }
        Write-Host "  → $ok файлов загружено" -ForegroundColor Green
    }
    "scripting" {
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\scripting" "addons/amxmodx/scripting" "Исходники (.sma)"
    }
    default {
        # ALL
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\plugins" "addons/amxmodx/plugins" "Плагины (.amxx)"
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\configs" "addons/amxmodx/configs" "Конфиги AMX"
        Deploy-Folder "$LOCAL_ROOT\addons\metamod" "addons/metamod" "Metamod"
        Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\scripting" "addons/amxmodx/scripting" "Исходники (.sma)"
        if (Test-Path "$LOCAL_ROOT\addons\amxmodx\data\lang") {
            Deploy-Folder "$LOCAL_ROOT\addons\amxmodx\data\lang" "addons/amxmodx/data/lang" "Lang файлы"
        }
        if (Test-Path "$LOCAL_ROOT\sprites") {
            Deploy-Folder "$LOCAL_ROOT\sprites" "sprites" "Спрайты"
        }
        if (Test-Path "$LOCAL_ROOT\models") {
            Deploy-Folder "$LOCAL_ROOT\models" "models" "Модели"
        }

        $cfgs = @("server.cfg","game.cfg","game_init.cfg","mapcycle.txt","fastdl.cfg","dproto.cfg","reunion.cfg")
        Write-Host "`n📤 Server configs..." -ForegroundColor Cyan
        $ok = 0
        foreach ($f in $cfgs) {
            $local = "$LOCAL_ROOT\server-configs\$f"
            if (Test-Path $local) {
                if (Upload-File $local $f) { $ok++; Write-Host "  ✅ $f" -ForegroundColor Gray }
            }
        }
        Write-Host "  → $ok файлов загружено" -ForegroundColor Green
    }
}

$elapsed = (Get-Date) - $startTime
Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✅ Deploy завершён!           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
Write-Host "  Время: $([math]::Round($elapsed.TotalSeconds, 1))s" -ForegroundColor White
