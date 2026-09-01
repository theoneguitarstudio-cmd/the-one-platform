param(
  [string]$AppBaseUrl = "http://127.0.0.1:3103"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$fallbackNode = "C:\Users\宏偉\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.22_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v22.23.2-win-x64\node.exe"
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue

if ($nodeCommand) {
  $nodeExecutable = $nodeCommand.Source
} elseif (Test-Path -LiteralPath $fallbackNode) {
  $nodeExecutable = $fallbackNode
} else {
  throw "Node.js executable was not found."
}

Push-Location $projectRoot
try {
  & $nodeExecutable "scripts/remote-smoke-test-epic3.mjs" "--app-base-url=$AppBaseUrl"
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
