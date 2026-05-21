$ErrorActionPreference = 'Stop'

$backendDir = Join-Path $PSScriptRoot '..\backend'

Push-Location $backendDir
try {
  # Keep the backend on the Node version selected by nvm for this machine.
  nvm use 24.15.0 | Out-Host
  npm run start:dev
} finally {
  Pop-Location
}
