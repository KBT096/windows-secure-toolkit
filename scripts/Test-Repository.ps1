[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Checks = 0
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Add-Check {
    param(
        [bool]$Condition,
        [string]$FailureMessage
    )

    $script:Checks++
    if (-not $Condition) {
        $script:Failures.Add($FailureMessage)
    }
}

function Test-Utf8 {
    param([string]$Path)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        [void]$strictUtf8.GetString($bytes)
        return $true
    }
    catch {
        return $false
    }
}

function Test-HasUtf8Bom {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    )
}

function Test-HasOnlyCrLf {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    return -not [regex]::IsMatch($text, '(?<!\r)\n')
}

Write-Host 'Repository validation'
Write-Host "Root: $repositoryRoot"
Write-Host ''

$requiredFiles = @(
    '.editorconfig',
    '.gitattributes',
    '.gitignore',
    'LICENSE',
    'README.md',
    'README.en.md',
    'PROJECT_SUMMARY.md',
    'CHANGELOG.md',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    'SUPPORT.md',
    'win_secure.cmd',
    'win_secure.bat',
    'src\WinSecure.ps1',
    'docs\THREAT_MODEL.md',
    '.github\workflows\ci.yml'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repositoryRoot $relativePath
    Add-Check `
        -Condition (Test-Path -LiteralPath $fullPath -PathType Leaf) `
        -FailureMessage "Missing required file: $relativePath"
}

$batchFiles = Get-ChildItem -Path $repositoryRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.cmd', '.bat') }
foreach ($file in $batchFiles) {
    Add-Check `
        -Condition (Test-Utf8 -Path $file.FullName) `
        -FailureMessage "Batch file is not valid UTF-8: $($file.FullName)"
    Add-Check `
        -Condition (-not (Test-HasUtf8Bom -Path $file.FullName)) `
        -FailureMessage "Batch file must not contain a UTF-8 BOM: $($file.FullName)"
    Add-Check `
        -Condition (Test-HasOnlyCrLf -Path $file.FullName) `
        -FailureMessage "Batch file must use CRLF only: $($file.FullName)"
}

$powerShellFiles = Get-ChildItem -Path $repositoryRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') }
foreach ($file in $powerShellFiles) {
    Add-Check `
        -Condition (Test-Utf8 -Path $file.FullName) `
        -FailureMessage "PowerShell file is not valid UTF-8: $($file.FullName)"
    Add-Check `
        -Condition (Test-HasUtf8Bom -Path $file.FullName) `
        -FailureMessage "Windows PowerShell file must contain a UTF-8 BOM: $($file.FullName)"
    Add-Check `
        -Condition (Test-HasOnlyCrLf -Path $file.FullName) `
        -FailureMessage "PowerShell file must use CRLF only: $($file.FullName)"

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $parseErrorMessages = @(
        $parseErrors | ForEach-Object { $_.Message }
    )
    Add-Check `
        -Condition (@($parseErrors).Count -eq 0) `
        -FailureMessage "PowerShell parse failed: $($file.FullName) $($parseErrorMessages -join '; ')"
}

$codeTextFiles = @(
    (Get-Item -LiteralPath (Join-Path $repositoryRoot 'win_secure.cmd')),
    (Get-Item -LiteralPath (Join-Path $repositoryRoot 'win_secure.bat')),
    (Get-Item -LiteralPath (Join-Path $repositoryRoot 'src\WinSecure.ps1'))
)
$codeText = ($codeTextFiles |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

$forbiddenCodePatterns = @(
    '(?i)invoke-expression',
    '(?i)\biex\b',
    '(?i)downloadstring\s*\(',
    '(?i)(curl|wget|irm|iwr)[^\r\n|]*\|\s*(powershell|pwsh|cmd|bash|sh)'
)
foreach ($pattern in $forbiddenCodePatterns) {
    Add-Check `
        -Condition (-not [regex]::IsMatch($codeText, $pattern)) `
        -FailureMessage "Forbidden code pattern found: $pattern"
}

$readmes = @(
    (Join-Path $repositoryRoot 'README.md'),
    (Join-Path $repositoryRoot 'README.en.md')
)
foreach ($readme in $readmes) {
    if (-not (Test-Path -LiteralPath $readme)) {
        continue
    }

    $content = Get-Content -LiteralPath $readme -Raw
    $matches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')
    foreach ($match in $matches) {
        $target = $match.Groups[1].Value
        if (
            $target -match '^(https?|mailto):' -or
            $target.StartsWith('#')
        ) {
            continue
        }

        $pathOnly = ($target -split '#', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly)) {
            continue
        }

        $resolvedTarget = Join-Path (Split-Path -Parent $readme) $pathOnly
        Add-Check `
            -Condition (Test-Path -LiteralPath $resolvedTarget) `
            -FailureMessage "Broken local README link: $target"
    }
}

$engine = Join-Path $repositoryRoot 'src\WinSecure.ps1'
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -NoLogo `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $engine `
    -Action SelfTest `
    -NoColor
Add-Check `
    -Condition ($LASTEXITCODE -eq 0) `
    -FailureMessage "Windows PowerShell 5.1 self-test failed with exit code $LASTEXITCODE"

$launcher = Join-Path $repositoryRoot 'win_secure.cmd'
& cmd.exe /d /c "`"$launcher`" self-test"
Add-Check `
    -Condition ($LASTEXITCODE -eq 0) `
    -FailureMessage "CMD launcher self-test failed with exit code $LASTEXITCODE"

$versionOutput = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -NoLogo `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $engine `
    -Action Version `
    -NoColor
Add-Check `
    -Condition (($versionOutput | Out-String).Trim() -match '^\d+\.\d+\.\d+$') `
    -FailureMessage 'Version output is not semantic x.y.z.'

& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -NoLogo `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $engine `
    -Action Apply `
    -DryRun `
    -NoColor | Out-Host
Add-Check `
    -Condition ($LASTEXITCODE -eq 0) `
    -FailureMessage "Baseline preview failed with exit code $LASTEXITCODE"

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'windows-secure-toolkit-test-' + [Guid]::NewGuid().ToString('N')
)
[void](New-Item -ItemType Directory -Path $temporaryRoot)
try {
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $engine `
        -Action Audit `
        -ReportPath $temporaryRoot `
        -NoColor | Out-Host
    Add-Check `
        -Condition ($LASTEXITCODE -eq 0) `
        -FailureMessage "Read-only audit smoke test failed with exit code $LASTEXITCODE"

    $markdownReports = @(Get-ChildItem -LiteralPath $temporaryRoot -Filter '*.md')
    $jsonReports = @(Get-ChildItem -LiteralPath $temporaryRoot -Filter '*.json')
    Add-Check `
        -Condition ($markdownReports.Count -eq 1) `
        -FailureMessage 'Audit did not create exactly one Markdown report.'
    Add-Check `
        -Condition ($jsonReports.Count -eq 1) `
        -FailureMessage 'Audit did not create exactly one JSON report.'

    if ($jsonReports.Count -eq 1) {
        $report = Get-Content -LiteralPath $jsonReports[0].FullName -Raw -Encoding UTF8 |
            ConvertFrom-Json
        Add-Check `
            -Condition ([int]$report.SchemaVersion -eq 1) `
            -FailureMessage 'Audit JSON schema version is not 1.'
        Add-Check `
            -Condition (@($report.Results).Count -ge 8) `
            -FailureMessage 'Audit returned fewer checks than expected.'
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Host ''
if ($script:Failures.Count -gt 0) {
    Write-Host "FAILED: $($script:Failures.Count) of $script:Checks checks failed." -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "PASS: $script:Checks checks completed." -ForegroundColor Green
exit 0
