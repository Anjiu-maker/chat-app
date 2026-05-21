$ErrorActionPreference = 'Stop'

$frontendDir = Join-Path $PSScriptRoot '..\frontend'
$buildDir = Join-Path $frontendDir 'build\web'

$env:Path = "$env:Path;C:\src\flutter\bin"

Push-Location $frontendDir
try {
  flutter build web
  npx serve -s $buildDir -l 5174
} finally {
  Pop-Location
}
