# Installs Doom in PhotoCraft (Windows), without CraftSpace. In PowerShell:
#
#   irm https://raw.githubusercontent.com/emircesur/doom-in-photocraft/main/install.ps1 | iex
#
# Or save it and run:  .\install.ps1 [-Uninstall] [-Config DIR] [-From DIR]
#   -Uninstall   take it out again
#   -Config DIR  PhotoCraft's settings folder (a portable copy's data folder)
#   -From DIR    use doom-photocraft.wasm and doom-actions.json from DIR
#
# It puts the plug-in in PhotoCraft's additional plug-ins folder (Preferences > Plug-ins; set to
# <settings>\Plug-ins if none is set), adds the "Doom: ..." actions to the Actions panel and binds
# Alt+Shift keys to them (keys you already use are left alone). Close PhotoCraft first.
param([switch]$Uninstall, [string]$Config = "", [string]$From = "")
$ErrorActionPreference = "Stop"

$repo = "emircesur/doom-in-photocraft"
$base = "https://github.com/$repo/releases/latest/download"
if (-not $Config) { $Config = if ($env:PHOTOCRAFT_CONFIG_DIR) { $env:PHOTOCRAFT_CONFIG_DIR } else { Join-Path $env:APPDATA "Photocraft" } }

if (Get-Process -Name "photocraft" -ErrorAction SilentlyContinue) {
    throw "PhotoCraft is open. Close it first (it saves its actions and preferences when it quits)."
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("doom-in-photocraft-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    if (-not $Uninstall) {
        if ($From) {
            Copy-Item (Join-Path $From "doom-photocraft.wasm"), (Join-Path $From "doom-actions.json") $tmp
        } else {
            Write-Host "Downloading Doom in PhotoCraft..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            foreach ($f in "doom-photocraft.wasm", "doom-actions.json", "SHA256SUMS.txt") {
                Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile (Join-Path $tmp $f)
            }
            foreach ($line in Get-Content (Join-Path $tmp "SHA256SUMS.txt")) {
                $sum, $name = $line -split "\s+", 2
                if ($name -in "doom-photocraft.wasm", "doom-actions.json") {
                    $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $name)).Hash.ToLower()
                    if ($actual -ne $sum.ToLower()) { throw "The download doesn't match its checksum; not installing." }
                }
            }
        }
    }

    function Read-Json($path, $default) {
        if (Test-Path $path) { return Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json }
        return $default
    }
    function Write-Json($path, $value) {
        $json = $value | ConvertTo-Json -Depth 64
        [IO.File]::WriteAllText("$path.new", $json + "`n", (New-Object Text.UTF8Encoding $false))
        Move-Item -Force "$path.new" $path
    }
    function Set-Prop($obj, $name, $value) {
        if ($obj.PSObject.Properties[$name]) { $obj.$name = $value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
    }

    New-Item -ItemType Directory -Force (Join-Path $Config "Presets") | Out-Null
    $prefsPath = Join-Path $Config "preferences.json"
    $actionsPath = Join-Path (Join-Path $Config "Presets") "actions.json"
    $prefs = Read-Json $prefsPath ([pscustomobject]@{})
    $list = Read-Json $actionsPath ([pscustomobject]@{ version = 1; actions = @() })
    if ($list.version -ne 1) { throw "PhotoCraft's actions.json is a newer version than this installer knows." }
    $add = if ($Uninstall) { $null } else { Read-Json (Join-Path $tmp "doom-actions.json") $null }
    $names = if ($Uninstall) { @($list.actions | Where-Object { $_.name -like "Doom: *" } | ForEach-Object { $_.name }) } else { @($add.actions | ForEach-Object { $_.name }) }

    if (-not $prefs.PSObject.Properties["plugIns"]) { Set-Prop $prefs "plugIns" ([pscustomobject]@{}) }
    if (-not $prefs.PSObject.Properties["shortcuts"]) { Set-Prop $prefs "shortcuts" ([pscustomobject]@{}) }
    $folder = if ($prefs.plugIns.useAdditionalPluginsFolder -and $prefs.plugIns.additionalPluginsFolder) { $prefs.plugIns.additionalPluginsFolder } else { $null }
    $kept = @($list.actions | Where-Object { $names -notcontains $_.name })
    foreach ($n in $names) { $prefs.shortcuts.PSObject.Properties.Remove("actions.play:$n") }

    if (-not $Uninstall) {
        if (-not $folder) {
            $folder = Join-Path $Config "Plug-ins"
            Set-Prop $prefs.plugIns "useAdditionalPluginsFolder" $true
            Set-Prop $prefs.plugIns "additionalPluginsFolder" $folder
        }
        New-Item -ItemType Directory -Force $folder | Out-Null
        Copy-Item -Force (Join-Path $tmp "doom-photocraft.wasm") (Join-Path $folder "doom-photocraft.wasm")
        Set-Prop $list "actions" @($kept + @($add.actions))
        $taken = @()
        foreach ($p in $add.shortcuts.PSObject.Properties) {
            $id = "actions.play:" + $p.Name
            $used = $prefs.shortcuts.PSObject.Properties | Where-Object { $_.Name -ne $id -and $_.Value -eq $p.Value }
            if ($used) { $taken += $p.Value } else { Set-Prop $prefs.shortcuts $id $p.Value }
        }
        Write-Json $actionsPath $list
        Write-Json $prefsPath $prefs
        $note = if ($taken.Count) { " (keys already used, left alone: " + ($taken -join ", ") + ")" } else { "" }
        Write-Host "Installed: the plug-in is in $folder, and $($names.Count) Doom actions are in the Actions panel$note."
        Write-Host "Start PhotoCraft, make a new 640 x 400 RGB document and press Alt+Shift+W (forward), A/D (turn), F (fire), Space (use)."
    } else {
        if ($folder) { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $folder "doom-photocraft.wasm") }
        Set-Prop $list "actions" $kept
        Write-Json $actionsPath $list
        Write-Json $prefsPath $prefs
        Write-Host "Removed Doom ($($names.Count) actions)."
    }
} finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
}
