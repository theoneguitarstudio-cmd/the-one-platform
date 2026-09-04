[CmdletBinding(DefaultParameterSetName = "Remote")]
param(
  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [string]$ProjectRef,

  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [string]$ExpectedProjectRef,

  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [ValidateSet("staging", "recovery", "production")]
  [string]$Environment,

  [Parameter(ParameterSetName = "Remote")]
  [switch]$AllowProduction,

  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [switch]$BackupConfirmed,

  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [switch]$OperatorApproved,

  [Parameter(ParameterSetName = "Remote", Mandatory = $true)]
  [switch]$Execute,

  [Parameter(ParameterSetName = "Local", Mandatory = $true)]
  [switch]$LocalValidation,

  [Parameter(ParameterSetName = "Validate", Mandatory = $true)]
  [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCommand) { throw "Node.js executable was not found." }

$arguments = @("scripts/remote-smoke-test-epic5.mjs")
switch ($PSCmdlet.ParameterSetName) {
  "Validate" { $arguments += "--validate-only" }
  "Local" { $arguments += @("--local", "--execute") }
  "Remote" {
    $arguments += @(
      "--execute",
      "--project-ref=$ProjectRef",
      "--expected-project-ref=$ExpectedProjectRef",
      "--environment=$Environment",
      "--backup-confirmed",
      "--operator-approved"
    )
    if ($AllowProduction) { $arguments += "--allow-production" }
  }
}

Push-Location $projectRoot
try {
  & $nodeCommand.Source @arguments
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
