# Offline launcher integration with a fake COM object. Never creates Rhino COM.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/rhino-metadata/bridge.ps1')
$testRoot = Join-Path (Join-Path $PSScriptRoot '../../.test-tmp') ('bridge-test-' + [guid]::NewGuid().ToString('N'))
$testRoot = [IO.Path]::GetFullPath($testRoot)
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$testMutex = 'Local\RhinoMoiBridgeTest-' + [guid]::NewGuid().ToString('N')
$script:mode = 'success'
$script:processCount = 1
$script:calls = 0
function Get-Process { param($Name,$ErrorAction) ; for($i=0;$i -lt $script:processCount;$i++){ [pscustomobject]@{Id=123} } }
function New-Object {
    param([string]$ComObject)
    if ($ComObject -ne 'Rhino.Interface.7') { throw 'Unexpected object factory' }
    $script:calls++
    $fake = [pscustomobject]@{}
    $fake | Add-Member ScriptMethod RunScript {
        param($command,$echo)
        $runner = [regex]::Match($command, '\("(.*)"\)').Groups[1].Value
        $matches64 = [regex]::Matches([IO.File]::ReadAllText($runner), "b64decode\('([^']+)'\)")
        $requestPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($matches64[1].Groups[1].Value))
        $request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
        if ($script:mode -eq 'missing_response') { return $true }
        if ($script:mode -eq 'rejected') { return $false }
        if ($script:mode -eq 'malformed') { [IO.File]::WriteAllText($request.response_path, '{'); return $true }
        $response = @{ok=$true;request_id=$request.request_id;output_path=$request.output_path}
        if ($script:mode -eq 'wrong_response_id') { $response.request_id='stale' }
        if ($script:mode -eq 'wrong_output_path') { $response.output_path='wrong' }
        if ($script:mode -eq 'failure') { $response.ok=$false; $response.message='Rhino failure'; $response.traceback='IronPython evidence' }
        if ($script:mode -ne 'missing_output') {
            if ($request.action -eq 'metadata') {
                $id = $request.request_id
                if ($script:mode -eq 'stale_metadata') { $id='stale' }
                @{automation=@{request_id=$id}} | ConvertTo-Json | Set-Content -LiteralPath $request.output_path
            } else {
                [IO.File]::WriteAllText($request.output_path, 'fake transport')
                $id=$request.metadata_request_id
                if ($script:mode -eq 'stale_sidecar') { $id='stale' }
                @{metadata_request_id=$id;transport_path=$request.output_path} | ConvertTo-Json | Set-Content -LiteralPath $request.occurrences_path
                $response.geometry_count=3; $response.source_unchanged=$true
            }
        }
        $response | ConvertTo-Json | Set-Content -LiteralPath $request.response_path
        return $true
    }
    return $fake
}
function Assert-True($condition,$message) { if (-not $condition) { throw $message } }
function Run-Case($mode,$action='metadata') {
    $script:mode=$mode
    $output=Join-Path $testRoot ([guid]::NewGuid().ToString('N')+'.json')
    if ($action -eq 'metadata') {
        $result=Invoke-RhinoBridge -Action metadata -OutputPath $output -TimeoutSeconds 0 -MutexName $testMutex | ConvertFrom-Json
    } else {
        $baseline=Join-Path $testRoot 'baseline.json'
        @{automation=@{request_id='snapshot'}} | ConvertTo-Json | Set-Content -LiteralPath $baseline
        $result=Invoke-RhinoBridge -Action working_copy -MetadataPath $baseline -OutputPath $output -OccurrencesPath ($output+'.sidecar') -TimeoutSeconds 0 -MutexName $testMutex | ConvertFrom-Json
    }
    return $result
}
$holder=$null
try {
    $result=Run-Case 'success'
    Assert-True ($result.ok -and $script:RhinoBridgeExitCode -eq 0) ('Metadata success rejected: '+($result | ConvertTo-Json -Compress))
    $first=$result.request_path
    $result=Run-Case 'success' 'working_copy'
    Assert-True ($result.ok -and $result.geometry_count -eq 3 -and $result.source_unchanged) 'Copy success fields lost'
    Assert-True ($first -ne $result.request_path) 'Request directory reused'
    foreach($case in @(@('missing_response','EXPORT_TIMEOUT'),@('wrong_response_id','INVALID_RESPONSE'),@('malformed','INVALID_RESPONSE'),@('stale_metadata','INVALID_OUTPUT'),@('missing_output','OUTPUT_NOT_FOUND'),@('wrong_output_path','INVALID_OUTPUT'),@('rejected','RHINO_REJECTED_COMMAND'),@('failure','RHINO_EXPORT_FAILED'))) {
        $result=Run-Case $case[0]
        Assert-True (-not $result.ok -and $result.error_code -eq $case[1] -and $script:RhinoBridgeExitCode -ne 0) ('Failed check: '+$case[0])
        if ($case[0] -eq 'failure') { Assert-True ($result.traceback -eq 'IronPython evidence') 'Traceback lost' }
    }
    $result=Run-Case 'stale_sidecar' 'working_copy'
    Assert-True (-not $result.ok -and $result.error_code -eq 'INVALID_OUTPUT') 'Stale sidecar accepted'
    foreach($count in @(0,2)) {
        $script:processCount=$count; $beforeCalls=$script:calls; $result=Run-Case 'success'
        Assert-True (-not $result.ok -and $script:calls -eq $beforeCalls) 'Process guard connected COM'
    }
    $script:processCount=1
    $beforeCalls=$script:calls
    $existing=Join-Path $testRoot 'existing.json'
    [IO.File]::WriteAllText($existing,'original evidence')
    $result=Invoke-RhinoBridge -Action metadata -OutputPath $existing -MutexName $testMutex | ConvertFrom-Json
    Assert-True (-not $result.ok -and $beforeCalls -eq $script:calls -and [IO.File]::ReadAllText($existing) -eq 'original evidence') 'Existing evidence overwritten or COM invoked'
    # Another process holds the real session mutex, proving rejection before COM.
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=Join-Path $PSHOME 'pwsh.exe'
    $command='$m=[Threading.Mutex]::new($false,"Local\CodexRhinoMoiPipelineRhino7"); [void]$m.WaitOne(); [Console]::WriteLine("READY"); [Console]::Out.Flush(); [void][Console]::ReadLine(); $m.ReleaseMutex(); $m.Dispose()'
    $command=$command.Replace('Local\CodexRhinoMoiPipelineRhino7',$testMutex)
    $info.Arguments='-NoProfile -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true
    $holder=[Diagnostics.Process]::Start($info)
    Assert-True ($holder.StandardOutput.ReadLine() -eq 'READY') 'Mutex holder failed'
    $beforeCalls=$script:calls
    $result=Run-Case 'success'
    Assert-True (-not $result.ok -and $result.error_code -eq 'BRIDGE_BUSY' -and $beforeCalls -eq $script:calls) 'Concurrent call reached COM'
    Write-Output 'PASS: 15 launcher scenarios; both actions, fresh requests, malformed/stale/failure evidence, process and real cross-process mutex guards'

} finally {
    if ($null -ne $holder) { $holder.StandardInput.WriteLine('done'); $holder.WaitForExit(); $holder.Dispose() }
    # Retain test evidence under this allowed local test directory for inspection.
    Write-Output ('Evidence: '+$testRoot)
}
