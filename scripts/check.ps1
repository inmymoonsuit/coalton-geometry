param(
    [ValidateSet(0,1)][int]$Safety = 1,
    [string]$Sbcl = '',
    [string]$Python = '',
    [string]$CacheRoot = '',
    [string]$CoaltonRoot = '',
    [string]$QuicklispRoot = '',
    [ValidateRange(0,1048576)][int]$DynamicSpaceMb = 0
)
$ErrorActionPreference = 'Stop'
$libraryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $libraryRoot 'config.local.psd1'
$config = @{}
if (Test-Path -LiteralPath $configPath) { $config = Import-PowerShellDataFile -LiteralPath $configPath }
foreach ($setting in @('Sbcl','Python','CacheRoot','CoaltonRoot','QuicklispRoot')) {
    if (-not $PSBoundParameters.ContainsKey($setting) -and $config.ContainsKey($setting)) {
        Set-Variable -Name $setting -Value $config[$setting]
    }
}
if (-not $Sbcl) { $Sbcl = 'sbcl' }
if (-not $Python) { $Python = 'python' }
$Sbcl = (Get-Command $Sbcl -CommandType Application -ErrorAction Stop).Source
$Python = (Get-Command $Python -CommandType Application -ErrorAction Stop).Source
if (-not $CoaltonRoot -or -not $QuicklispRoot) {
    throw 'Set CoaltonRoot and QuicklispRoot to the pinned installed dependencies; see docs/setup.md.'
}
$CoaltonRoot = (Resolve-Path -LiteralPath $CoaltonRoot -ErrorAction Stop).Path
$QuicklispRoot = (Resolve-Path -LiteralPath $QuicklispRoot -ErrorAction Stop).Path
if (-not $CacheRoot) { $CacheRoot = Join-Path $libraryRoot 'build/cache' }
$CacheRoot = [System.IO.Path]::GetFullPath($CacheRoot)
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $libraryRoot 'build'))
[System.IO.Directory]::CreateDirectory($buildRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($CacheRoot) | Out-Null
$environment = @{
    XDG_CACHE_HOME = $CacheRoot.Replace('\','/')
    COALTON_ENV = 'release'
    COALTON_GEOMETRY_COALTON_ROOT = $CoaltonRoot.Replace('\','/')
    COALTON_GEOMETRY_QUICKLISP_ROOT = $QuicklispRoot.Replace('\','/')
    COALTON_GEOMETRY_SAFETY = "$Safety"
    COALTON_GEOMETRY_METADATA = (Join-Path $buildRoot 'toolchain-metadata.tsv').Replace('\','/')
}
$previous = @{}
foreach ($name in $environment.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
}
try {
    $toolchainCheck = Join-Path $libraryRoot 'tools/check-toolchain.py'
    & $Python $toolchainCheck --sbcl-root (Split-Path -Parent $Sbcl) --coalton-root $CoaltonRoot --quicklisp-root $QuicklispRoot
    if ($LASTEXITCODE -ne 0) { throw 'Installed toolchain differs from toolchain.lock.json.' }
    # A runtime option must precede the toplevel options. Zero keeps SBCL's own default heap.
    $runtimeOptions = @()
    if ($DynamicSpaceMb -gt 0) { $runtimeOptions = @('--dynamic-space-size', "$DynamicSpaceMb") }
    & $Sbcl @runtimeOptions --noinform --no-sysinit --no-userinit --disable-debugger --script (Join-Path $PSScriptRoot 'check.lisp')
    if ($LASTEXITCODE -ne 0) { throw "The Lisp checks failed with exit code $LASTEXITCODE." }
    & $Python $toolchainCheck --sbcl-root (Split-Path -Parent $Sbcl) --coalton-root $CoaltonRoot --quicklisp-root $QuicklispRoot --metadata $environment.COALTON_GEOMETRY_METADATA
    if ($LASTEXITCODE -ne 0) { throw 'Loaded toolchain differs from the pin.' }
    & $Python $toolchainCheck --selftest (Join-Path $buildRoot 'toolchain-selftest')
    if ($LASTEXITCODE -ne 0) { throw 'Toolchain checker control failed.' }
    Write-Output "CHECK-PASS safety=$Safety"
}
finally {
    foreach ($name in $environment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
