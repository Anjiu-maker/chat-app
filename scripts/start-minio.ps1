$ErrorActionPreference = 'Stop'

$minio = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\MinIO.Server_Microsoft.Winget.Source_8wekyb3d8bbwe\minio.exe'
$dataDir = Join-Path $PSScriptRoot '..\.local\minio-data'

if (-not (Test-Path $minio)) {
  throw "MinIO executable not found: $minio"
}

New-Item -ItemType Directory -Force $dataDir | Out-Null

# Keep these credentials aligned with backend/.env.example for local development.
$env:MINIO_ROOT_USER = 'minioadmin'
$env:MINIO_ROOT_PASSWORD = 'minioadmin'

$listening = Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue
if ($listening) {
  Write-Host 'MinIO is already listening on http://127.0.0.1:9000'
  exit 0
}

Start-Process -FilePath $minio -ArgumentList @(
  'server',
  $dataDir,
  '--address',
  ':9000',
  '--console-address',
  ':9001'
) -WindowStyle Hidden

Write-Host 'MinIO started: API http://127.0.0.1:9000, console http://127.0.0.1:9001'
