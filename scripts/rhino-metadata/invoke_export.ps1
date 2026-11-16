[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidateRange(5,1800)][int]$TimeoutSeconds = 300
)
. (Join-Path $PSScriptRoot 'bridge.ps1')
Invoke-RhinoBridge -Action metadata -OutputPath $OutputPath -TimeoutSeconds $TimeoutSeconds
exit $script:RhinoBridgeExitCode
