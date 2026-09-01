[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$bundledNode = "C:\Users\win\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue

if ($nodeCommand) {
  $nodeExecutable = $nodeCommand.Source
} elseif (Test-Path -LiteralPath $bundledNode) {
  $nodeExecutable = $bundledNode
} else {
  throw "Node.js executable was not found."
}

Push-Location $projectRoot
try {
  & $nodeExecutable "scripts/remote-smoke-test-epic5.mjs"
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
