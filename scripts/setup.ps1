$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Engine = if ($env:MIMINET_ENGINE) { $env:MIMINET_ENGINE } else { 'docker' }
if ($Engine -notin @('docker', 'podman')) { throw "MIMINET_ENGINE must be docker or podman" }
& $Engine info | Out-Null

$withBackend = if ($env:MIMINET_WITH_BACKEND) { $env:MIMINET_WITH_BACKEND } else { '0' }
foreach ($envFile in @((Join-Path $Root 'front/.env'), (Join-Path $Root 'back/.env'))) {
  if (-not (Test-Path $envFile)) {
    $exampleFile = "$envFile.example"
    if (-not (Test-Path $exampleFile)) { throw "Missing $exampleFile" }
    Copy-Item $exampleFile $envFile
    Write-Host "Created $envFile from $exampleFile"
  }
}

& $Engine compose --project-directory (Join-Path $Root 'front') --env-file (Join-Path $Root 'front/.env') -f (Join-Path $Root 'front/docker-compose.yml') up -d --build

if ($withBackend -eq '1') {
  Write-Warning 'The Mininet/OVS backend requires a Linux kernel. Docker Desktop Windows/macOS normally supports frontend-only mode.'
  & $Engine compose --project-directory (Join-Path $Root 'back') -f (Join-Path $Root 'back/docker-compose.yml') --env-file (Join-Path $Root 'back/.env') up -d --build
}
Write-Host 'Miminet frontend started at http://127.0.0.1/'
