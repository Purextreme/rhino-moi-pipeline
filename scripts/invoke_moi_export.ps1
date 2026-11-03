[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MoiExe,
    [Parameter(Mandatory)][string]$TransportPath,
    [Parameter(Mandatory)][string]$OccurrencesPath,
    [Parameter(Mandatory)][string]$OutputFbx,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [ValidateRange(0.01, 180.0)][double]$Angle = 3,
    [ValidateSet('ngons', 'quads', 'triangles')][string]$MeshOutput = 'ngons',
    [ValidateRange(0.0, 1000000000.0)][double]$MaxLength = 20,
    [ValidateSet('all', 'curved', 'planes')][string]$MaxLengthApplyTo = 'all',
    [ValidateRange(0.0, 1000000000.0)][double]$MinLength = 0.5,
    [ValidateRange(0.0, 1000000000.0)][double]$AspectRatio = 0,
    [bool]$Weld = $true,
    [ValidateRange(5, 3600)][int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$exe = Get-Item -LiteralPath $MoiExe
$transport = Get-Item -LiteralPath $TransportPath
$sidecar = Get-Item -LiteralPath $OccurrencesPath
$work = Get-Item -LiteralPath $WorkDirectory
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFbx)
if ($exe.Name -ne 'MoI.exe' -or $exe.PSIsContainer -or -not $work.PSIsContainer) {
    throw 'Specify MoI.exe and an existing writable work directory.'
}
if ($transport.Extension -ne '.3dm' -or $transport.Length -le 0 -or $sidecar.Length -le 0) {
    throw 'Specify a validated Rhino 5 transport file and its occurrence sidecar.'
}
if ([IO.Path]::GetExtension($output) -ne '.fbx' -or (Test-Path -LiteralPath $output) -or
        -not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($output))) {
    throw 'Output must be a new .fbx in an existing writable directory.'
}

$manifest = Get-Content -LiteralPath $sidecar.FullName -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.schema_version -ne 2 -or -not $manifest.metadata_request_id -or
        -not $manifest.transport_path -or [IO.Path]::GetFullPath($manifest.transport_path) -ne $transport.FullName) {
    throw 'The occurrence sidecar does not identify this transport file.'
}
[string[]]$tokens = @($manifest.occurrences | ForEach-Object { $_.transport_name })
if ($tokens.Count -eq 0 -or $tokens.Count -ne $manifest.geometry_count) {
    throw 'The occurrence count in the sidecar is inconsistent.'
}
$names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($token in $tokens) {
    if ($token -cnotmatch '^RB_[0-9]+_[0-9a-f]{8}$' -or -not $names.Add($token)) {
        throw "Invalid or duplicate transport token: $token"
    }
}
[Array]::Sort($tokens, [StringComparer]::Ordinal)

$run = Join-Path $work.FullName ('moi-export-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($run)
$state = Join-Path $run 'state.txt'
$partialFbx = Join-Path $run 'mesh.fbx'
$jobPath = Join-Path $run 'export.js'
$culture = [Globalization.CultureInfo]::InvariantCulture
$options = @(
    'NoUI=true'
    "Angle=$($Angle.ToString($culture))"
    "Output=$MeshOutput"
    "MaxLength=$($MaxLength.ToString($culture))"
    "MaxLengthApplyTo=$MaxLengthApplyTo"
    "MinLength=$($MinLength.ToString($culture))"
    "AspectRatio=$($AspectRatio.ToString($culture))"
    "Weld=$($Weld.ToString().ToLowerInvariant())"
    'Display=shadedwithedges'
) -join ';'
$job = @{
    transport = $transport.FullName
    tokens = $tokens
    output = $partialFbx
    state = $state
    options = $options
} | ConvertTo-Json -Depth 4 -Compress -EscapeHandling EscapeNonAscii
$template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'moi_export_job.js') -Raw -Encoding utf8
[IO.File]::WriteAllText($jobPath, "var job = $job;`n$template", [Text.UTF8Encoding]::new($false))
$transportHash = (Get-FileHash -LiteralPath $transport.FullName -Algorithm SHA256).Hash
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $exe.FullName -ArgumentList ('"{0}"' -f $jobPath) -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    throw "MoI completion unknown after timeout (PID $($process.Id)). Inspect $run before retrying."
}
$stage = if (Test-Path -LiteralPath $state -PathType Leaf) {
    (Get-Content -LiteralPath $state -Raw -Encoding utf8).Trim()
} else {
    'missing state'
}
if ($process.ExitCode -ne 0 -or $stage -ne "completed: $($tokens.Count)") {
    throw "MoI export not confirmed (exit $($process.ExitCode), $stage). Inspect $run before retrying."
}

$stream = [IO.File]::OpenRead($partialFbx)
try {
    $bytes = [byte[]]::new(23)
    if ($stream.Read($bytes, 0, $bytes.Length) -ne $bytes.Length -or
            [Text.Encoding]::ASCII.GetString($bytes, 0, 18) -ne 'Kaydara FBX Binary' -or
            $bytes[20] -ne 0 -or $bytes[21] -ne 26 -or $bytes[22] -ne 0 -or $stream.Length -le 27) {
        throw "Expected a binary FBX. Inspect $run before retrying."
    }
} finally {
    $stream.Dispose()
}
if ($transportHash -ne (Get-FileHash -LiteralPath $transport.FullName -Algorithm SHA256).Hash) {
    throw 'Transport changed during the export. Staged FBX was not published.'
}
[IO.File]::Copy($partialFbx, $output, $false)
$watch.Stop()
[pscustomobject]@{
    ok = $true
    metadata_request_id = $manifest.metadata_request_id
    moi_exe = $exe.FullName
    moi_exe_sha256 = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash
    occurrences = $tokens.Count
    meshing_options = $options
    transport_sha256 = $transportHash
    fbx = $output
    fbx_sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    state = $state
    elapsed_seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
}
