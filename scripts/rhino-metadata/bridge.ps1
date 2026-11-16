# Shared launcher for metadata and Blender occurrence-copy requests.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RhinoBridgeRoot = $PSScriptRoot

function Invoke-RhinoBridge {
    param(
        [ValidateSet('metadata','working_copy')][string]$Action,
        [string]$OutputPath,
        [string]$MetadataPath,
        [string]$OccurrencesPath,
        [int]$TimeoutSeconds = 300,
        [string]$MutexName = 'Local\CodexRhinoMoiPipelineRhino7'
    )
    $script:RhinoBridgeExitCode = 1
    $rhino = $null
    $mutex = $null
    $locked = $false
    $code = 'INVALID_OUTPUT_PATH'
    $requestId = [guid]::NewGuid().ToString('D')
    $evidence = [ordered]@{ok=$false; request_id=$requestId}
    try {
        $output = [IO.Path]::GetFullPath($OutputPath)
        $evidence.output_path = $output
        $targets = @($output)
        if ($Action -eq 'working_copy') {
            $occurrences = [IO.Path]::GetFullPath($OccurrencesPath)
            $targets += $occurrences
            if ($output -eq $occurrences) { throw 'Transport and sidecar must be distinct' }
            $metadataFull = [IO.Path]::GetFullPath($MetadataPath)
            $metadata = Get-Content -LiteralPath $metadataFull -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $metadata.automation.request_id) { throw 'Missing metadata request ID' }
        }
        foreach ($target in $targets) {
            if (Test-Path -LiteralPath $target) { throw 'Output exists; inspect before retry' }
            if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($target)) -PathType Container)) {
                throw 'Output directory must exist'
            }
        }
        # One mutex across both actions and all installs in this Windows session.
        $code = 'BRIDGE_BUSY'
        $mutex = [Threading.Mutex]::new($false, $MutexName)
        try { $locked = $mutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] {
            $locked = $true
            throw 'Previous launcher ended unexpectedly; inspect Rhino and partial outputs before retry'
        }
        if (-not $locked) { throw 'Another Rhino/MoI bridge call is active; inspect it before retry' }
        $code = 'RHINO_NOT_RUNNING'
        $processes = @(Get-Process -Name Rhino -ErrorAction SilentlyContinue)
        if ($processes.Count -eq 0) { throw 'No Rhino instance is running' }
        $code = 'MULTIPLE_RHINO_INSTANCES'
        if ($processes.Count -ne 1) {
            $evidence.process_ids = @($processes | ForEach-Object { $_.Id })
            throw 'Require exactly one running Rhino process'
        }
        $evidence.rhino_process_id = $processes[0].Id
        $code = 'BRIDGE_SETUP_FAILED'
        $directory = Join-Path ([IO.Path]::GetDirectoryName($output)) ('.rhino-moi-bridge\' + $requestId)
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $requestPath = Join-Path $directory 'request.json'
        $responsePath = Join-Path $directory 'response.json'
        $runnerPath = Join-Path $directory 'run.py'
        $evidence.request_path = $requestPath
        $evidence.response_path = $responsePath
        $request = [ordered]@{
            schema_version=1; action=$Action; request_id=$requestId; output_path=$output
            response_path=$responsePath; created_utc=[DateTime]::UtcNow.ToString('o')
        }
        if ($Action -eq 'working_copy') {
            $request.metadata_path = $metadataFull
            $request.metadata_request_id = $metadata.automation.request_id
            $request.occurrences_path = $occurrences
        }
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($requestPath, ($request | ConvertTo-Json -Depth 8), $utf8)
        # Paths are data, encoded as ASCII, never Python/shell source interpolation.
        $dispatcher = Join-Path $script:RhinoBridgeRoot 'bridge_request.py'
        $dispatcher64 = [Convert]::ToBase64String($utf8.GetBytes($dispatcher))
        $request64 = [Convert]::ToBase64String($utf8.GetBytes($requestPath))
        $runner = "import base64, imp`nbridge = imp.load_source('rhino_moi_bridge', base64.b64decode('$dispatcher64').decode('utf-8'))`nbridge.run(base64.b64decode('$request64').decode('utf-8'))`n"
        [IO.File]::WriteAllText($runnerPath, $runner, [Text.Encoding]::ASCII)
        $code = 'COM_AUTOMATION_FAILED'
        $rhino = New-Object -ComObject 'Rhino.Interface.7'
        $accepted = $rhino.RunScript(('_-RunPythonScript ("{0}")' -f $runnerPath.Replace('"','""')), 0)
        $code = 'RHINO_REJECTED_COMMAND'
        if (-not $accepted) { throw 'Rhino rejected RunPythonScript; inspect before retry' }
        $code = 'EXPORT_TIMEOUT'
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (-not (Test-Path -LiteralPath $responsePath) -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 200
        }
        if (-not (Test-Path -LiteralPath $responsePath)) { throw 'Missing response; completion unknown, inspect outputs before retry' }
        $code = 'INVALID_RESPONSE'
        $response = Get-Content -LiteralPath $responsePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($response.request_id -ne $requestId) { throw 'Response request ID mismatch' }
        $code = 'RHINO_EXPORT_FAILED'
        if (-not $response.ok) {
            $evidence.message = $response.message
            $evidence.traceback = $response.traceback
            throw $response.message
        }
        $code = 'OUTPUT_NOT_FOUND'
        foreach ($target in $targets) {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or (Get-Item -LiteralPath $target).Length -eq 0) {
                throw 'Rhino reported success but required output is missing or empty'
            }
        }
        $code = 'INVALID_OUTPUT'
        if ($response.output_path -ne $output) { throw 'Response output path mismatch' }
        if ($Action -eq 'metadata') {
            $data = Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($data.automation.request_id -ne $requestId) { throw 'Metadata request ID mismatch' }
        } else {
            $data = Get-Content -LiteralPath $occurrences -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($data.metadata_request_id -ne $request.metadata_request_id -or $data.transport_path -ne $output) {
                throw 'Occurrence snapshot or transport path mismatch'
            }
        }
        # Keep all original target result fields as well as shared bridge evidence.
        foreach ($property in $response.PSObject.Properties) { $evidence[$property.Name] = $property.Value }
        $evidence.ok = $true
        $script:RhinoBridgeExitCode = 0
    } catch {
        $evidence.ok = $false
        $evidence.error_code = $code
        $evidence.message = $_.Exception.Message
        if (-not $evidence.Contains('traceback')) { $evidence.traceback = $_.ScriptStackTrace }
    } finally {
        if ($null -ne $rhino -and [Runtime.InteropServices.Marshal]::IsComObject($rhino)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($rhino)
        }
        if ($locked) { $mutex.ReleaseMutex() }
        if ($null -ne $mutex) { $mutex.Dispose() }
    }
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $evidence | ConvertTo-Json -Depth 12 -Compress
}
