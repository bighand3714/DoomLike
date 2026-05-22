param(
	[ValidateSet("windows", "linux", "macos", "android", "web", "all")]
	[string]$Platform = "all"
)

$ErrorActionPreference = "Stop"

# Godot 可执行文件路径 —— 按本地环境修改
$GodotExe = "C:\Godot\Godot_v4.6-stable_win64.exe"
if (-not (Test-Path $GodotExe)) {
	# 尝试常见路径
	$GodotExe = "godot"
}

$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$Presets = @{
	windows = "Windows Desktop"
	linux   = "Linux/X11"
	macos   = "macOS"
	android = "Android"
	web     = "Web"
}

function Export-Platform($Name) {
	$preset = $Presets[$Name]
	Write-Host "=== 导出 $preset ===" -ForegroundColor Cyan
	$args = @("--headless", "--export-release", $preset)
	& $GodotExe @args
	if ($LASTEXITCODE -ne 0) {
		Write-Host "错误: $preset 导出失败 (exit $LASTEXITCODE)" -ForegroundColor Red
	} else {
		Write-Host "完成: $preset" -ForegroundColor Green
	}
}

Push-Location $ProjectRoot
try {
	if ($Platform -eq "all") {
		foreach ($key in $Presets.Keys) {
			Export-Platform $key
		}
	} else {
		Export-Platform $Platform
	}
} finally {
	Pop-Location
}

Write-Host "=== 构建完成 ===" -ForegroundColor Green
