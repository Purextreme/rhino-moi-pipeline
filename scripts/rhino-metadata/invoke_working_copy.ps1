[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MetadataPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$OccurrencesPath,
    [ValidateRange(5,1800)][int]$TimeoutSeconds = 300
)
. (Join-Path $PSScriptRoot 'bridge.ps1')
Invoke-RhinoBridge -Action working_copy -OutputPath $OutputPath -MetadataPath $MetadataPath -OccurrencesPath $OccurrencesPath -TimeoutSeconds $TimeoutSeconds
exit $script:RhinoBridgeExitCode
