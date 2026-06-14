# Start the Godot battle server on Windows.
# Edit $GodotExe below if this script cannot find Godot automatically.

param(
    [int]$Port = 7777
)

$GameDir = Split-Path $PSScriptRoot -Parent
$GodotExe = $env:BATTLEFLEET_GODOT_EXE

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.6-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.4-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.6-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.4-stable_win64.exe",
        "C:\Program Files\Godot\Godot_v4.6-stable_win64.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            $GodotExe = $path
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExe) -or -not (Test-Path $GodotExe)) {
    Write-Host "Godot executable not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Option A (easiest): In Godot Editor"
    Write-Host "  1. Open project: $GameDir"
    Write-Host "  2. Open scene: res://scenes/battle/BattleServerMain.tscn"
    Write-Host "  3. Press F6 (Run Current Scene)"
    Write-Host "  4. Look for: [BattleNetwork] Server listening on port $Port"
    Write-Host ""
    Write-Host "Option B: Set your Godot path, then rerun this script:"
    Write-Host '  $env:BATTLEFLEET_GODOT_EXE = "C:\path\to\Godot_v4.6-stable_win64.exe"'
    Write-Host "  .\bin\start-battle-server.ps1"
    Write-Host ""
    Write-Host "Option C: Add Godot to PATH, then use:"
    Write-Host "  godot --path `"$GameDir`" res://scenes/battle/BattleServerMain.tscn -- --battle-server --port $Port"
    exit 1
}

Write-Host "Starting battle server with: $GodotExe" -ForegroundColor Cyan
& $GodotExe --path $GameDir res://scenes/battle/BattleServerMain.tscn -- --battle-server --port $Port
