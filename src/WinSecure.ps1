[CmdletBinding()]
param(
    [ValidateSet(
        'Menu',
        'Audit',
        'Apply',
        'Restore',
        'DefenderQuickScan',
        'SystemVerify',
        'ListeningPorts',
        'UpdateCheck',
        'Version',
        'SelfTest',
        'Help'
    )]
    [string]$Action = 'Menu',

    [string]$BackupPath,

    [string]$ReportPath,

    [switch]$Yes,

    [switch]$DryRun,

    [switch]$NoColor
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ToolkitName = 'Windows Security & Management Toolkit'
$script:Version = '0.1.0'
$script:RepositoryUrl = 'https://github.com/KBT096/windows-secure-toolkit'
$script:ReleaseApiUrl = 'https://api.github.com/repos/KBT096/windows-secure-toolkit/releases/latest'
$script:ScriptPath = $PSCommandPath
$script:UseColor = -not $NoColor
$script:PreviewOnly = [bool]$DryRun
$script:ChangeResults = @()

try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = $utf8NoBom
    [Console]::OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
}
catch {
    # Non-interactive hosts can reject console encoding changes.
}

function Get-DataRoot {
    if ($env:ProgramData) {
        return (Join-Path $env:ProgramData 'WindowsSecureToolkit')
    }

    return (Join-Path ([System.IO.Path]::GetTempPath()) 'WindowsSecureToolkit')
}

function Get-ReportRoot {
    if ($env:LOCALAPPDATA) {
        return (Join-Path $env:LOCALAPPDATA 'WindowsSecureToolkit\Reports')
    }

    return (Join-Path ([System.IO.Path]::GetTempPath()) 'WindowsSecureToolkit\Reports')
}

function Write-ToolkitMessage {
    param(
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Plan')]
        [string]$Level,

        [string]$Message
    )

    $prefix = switch ($Level) {
        'Success' { '[完成]' }
        'Warning' { '[警告]' }
        'Error' { '[错误]' }
        'Plan' { '[计划]' }
        default { '[信息]' }
    }

    if (-not $script:UseColor) {
        Write-Host "$prefix $Message"
        return
    }

    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Plan' { 'Cyan' }
        default { 'Gray' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)

    Write-Host ''
    if ($script:UseColor) {
        Write-Host ('=' * 64) -ForegroundColor DarkCyan
        Write-Host ('  ' + $Title) -ForegroundColor Cyan
        Write-Host ('=' * 64) -ForegroundColor DarkCyan
    }
    else {
        Write-Host ('=' * 64)
        Write-Host ('  ' + $Title)
        Write-Host ('=' * 64)
    }
}

function Pause-Toolkit {
    if ([Environment]::UserInteractive) {
        Write-Host ''
        [void](Read-Host '按 Enter 键继续')
    }
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Assert-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw '此操作需要管理员权限。请右键“以管理员身份运行”，再重新执行。'
    }
}

function Test-CommandAvailable {
    param([string]$Name)

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Read-Confirmation {
    param(
        [string]$Prompt,
        [switch]$DefaultNo
    )

    if ($Yes) {
        return $true
    }

    $suffix = if ($DefaultNo) { ' [y/N]' } else { ' [Y/n]' }
    $answer = Read-Host ($Prompt + $suffix)

    if ($DefaultNo) {
        return $answer -match '^[Yy]$'
    }

    return -not ($answer -match '^[Nn]$')
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    & $FilePath @Arguments | Out-Host
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$FilePath 执行失败，退出码：$exitCode"
    }
}

function Get-Sha256File {
    param([string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $stream = [System.IO.File]::OpenRead($resolvedPath)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash($stream)
        return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Get-RegistryValueState {
    param(
        [string]$Path,
        [string]$Name
    )

    $state = [ordered]@{
        Path = $Path
        Name = $Name
        KeyExists = $false
        ValueExists = $false
        Kind = $null
        Value = $null
    }

    $key = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $key) {
        return [pscustomobject]$state
    }

    $state.KeyExists = $true
    if ($key.GetValueNames() -contains $Name) {
        $state.ValueExists = $true
        $state.Kind = [string]$key.GetValueKind($Name)
        $state.Value = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
    }

    return [pscustomobject]$state
}

function Set-RegistryDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    if (-not (Test-Path -Path $Path)) {
        [void](New-Item -Path $Path -Force)
    }

    [void](New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force)
}

function Restore-RegistryValueState {
    param([pscustomobject]$State)

    if ([bool]$State.ValueExists) {
        if (-not (Test-Path -Path ([string]$State.Path))) {
            [void](New-Item -Path ([string]$State.Path) -Force)
        }

        $allowedKinds = @('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')
        $kind = [string]$State.Kind
        if ($allowedKinds -notcontains $kind) {
            throw "不支持恢复注册表类型：$kind"
        }

        [void](New-ItemProperty `
            -Path ([string]$State.Path) `
            -Name ([string]$State.Name) `
            -Value $State.Value `
            -PropertyType $kind `
            -Force)
    }
    elseif (Test-Path -Path ([string]$State.Path)) {
        Remove-ItemProperty `
            -Path ([string]$State.Path) `
            -Name ([string]$State.Name) `
            -ErrorAction SilentlyContinue
    }
}

function Get-GuestAccountState {
    $result = [ordered]@{
        Supported = $false
        Name = $null
        Sid = $null
        Enabled = $null
    }

    try {
        $guest = Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' |
            Where-Object { $_.SID -match '-501$' } |
            Select-Object -First 1

        if ($null -ne $guest) {
            $result.Supported = $true
            $result.Name = [string]$guest.Name
            $result.Sid = [string]$guest.SID
            $result.Enabled = -not [bool]$guest.Disabled
        }
    }
    catch {
        # The caller records unsupported checks as unavailable.
    }

    return [pscustomobject]$result
}

function Get-Smb1State {
    $result = [ordered]@{
        Supported = $false
        State = $null
    }

    if (-not (Test-CommandAvailable 'Get-WindowsOptionalFeature')) {
        return [pscustomobject]$result
    }

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
        $result.Supported = $true
        $result.State = [string]$feature.State
    }
    catch {
        # Some Windows editions do not expose this optional feature.
    }

    return [pscustomobject]$result
}

function Get-DefenderPreferenceState {
    $result = [ordered]@{
        Supported = $false
        DisableRealtimeMonitoring = $null
        PUAProtection = $null
        EnableNetworkProtection = $null
    }

    if (-not (Test-CommandAvailable 'Get-MpPreference')) {
        return [pscustomobject]$result
    }

    try {
        $preference = Get-MpPreference
        $result.Supported = $true
        $result.DisableRealtimeMonitoring = [bool]$preference.DisableRealtimeMonitoring
        $result.PUAProtection = [int]$preference.PUAProtection
        $result.EnableNetworkProtection = [int]$preference.EnableNetworkProtection
    }
    catch {
        # Defender can be removed or managed by another security product.
    }

    return [pscustomobject]$result
}

function Get-FirewallState {
    $result = [ordered]@{
        Supported = $false
        Profiles = @()
    }

    if (-not (Test-CommandAvailable 'Get-NetFirewallProfile')) {
        return [pscustomobject]$result
    }

    try {
        $profiles = Get-NetFirewallProfile |
            Select-Object Name, Enabled

        if (@($profiles).Count -gt 0) {
            $result.Supported = $true
            $result.Profiles = @($profiles)
        }
    }
    catch {
        # The audit reports this subsystem as unavailable.
    }

    return [pscustomobject]$result
}

function Get-BaselineSnapshot {
    $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $explorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $terminalServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $rdpTcpPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'

    return [ordered]@{
        Firewall = Get-FirewallState
        Defender = Get-DefenderPreferenceState
        Smb1 = Get-Smb1State
        Guest = Get-GuestAccountState
        Registry = @(
            (Get-RegistryValueState -Path $uacPath -Name 'EnableLUA'),
            (Get-RegistryValueState -Path $uacPath -Name 'ConsentPromptBehaviorAdmin'),
            (Get-RegistryValueState -Path $uacPath -Name 'PromptOnSecureDesktop'),
            (Get-RegistryValueState -Path $explorerPolicyPath -Name 'NoDriveTypeAutoRun'),
            (Get-RegistryValueState -Path $terminalServerPath -Name 'fDenyTSConnections'),
            (Get-RegistryValueState -Path $rdpTcpPath -Name 'UserAuthentication')
        )
    }
}

function New-BaselineBackup {
    Assert-Administrator

    $backupRoot = Join-Path (Get-DataRoot) 'Backups'
    [void](New-Item -ItemType Directory -Path $backupRoot -Force)

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destination = Join-Path $backupRoot $stamp
    $counter = 0
    while (Test-Path -LiteralPath $destination) {
        $counter++
        $destination = Join-Path $backupRoot ("{0}-{1}" -f $stamp, $counter)
    }
    [void](New-Item -ItemType Directory -Path $destination)

    $snapshot = Get-BaselineSnapshot
    $manifest = [ordered]@{
        SchemaVersion = 1
        ToolkitVersion = $script:Version
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName = $env:COMPUTERNAME
        Snapshot = $snapshot
    }

    $manifestPath = Join-Path $destination 'manifest.json'
    $json = $manifest | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)

    try {
        Invoke-NativeCommand -FilePath 'netsh.exe' -Arguments @(
            'advfirewall',
            'export',
            (Join-Path $destination 'firewall-policy.wfw')
        )
    }
    catch {
        Write-ToolkitMessage Warning ('防火墙完整策略导出失败；清单中的配置状态仍已保存。' + $_.Exception.Message)
    }

    $hash = Get-Sha256File -Path $manifestPath
    [System.IO.File]::WriteAllText(
        (Join-Path $destination 'manifest.sha256'),
        ($hash + '  manifest.json' + [Environment]::NewLine),
        $utf8NoBom
    )

    Write-ToolkitMessage Success "已创建配置备份：$destination"
    return $destination
}

function Resolve-BackupManifest {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw '未提供备份路径。'
    }

    $manifestPath = $Path
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $manifestPath = Join-Path $Path 'manifest.json'
    }

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "找不到备份清单：$manifestPath"
    }

    $hashPath = Join-Path (Split-Path -Parent $manifestPath) 'manifest.sha256'
    if (-not (Test-Path -LiteralPath $hashPath -PathType Leaf)) {
        throw "找不到备份清单校验文件：$hashPath"
    }

    $expectedLine = [System.IO.File]::ReadAllText($hashPath).Trim()
    $expectedHash = ($expectedLine -split '\s+')[0]
    if ($expectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw '备份清单校验文件格式无效。'
    }

    $actualHash = Get-Sha256File -Path $manifestPath
    if ($expectedHash -ne $actualHash) {
        throw '备份清单的 SHA-256 校验失败，文件可能已被修改或损坏。'
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-BackupManifest -Manifest $manifest

    return $manifest
}

function Assert-BackupManifest {
    param([pscustomobject]$Manifest)

    $requiredManifestProperties = @(
        'SchemaVersion',
        'ToolkitVersion',
        'CreatedUtc',
        'ComputerName',
        'Snapshot'
    )
    foreach ($propertyName in $requiredManifestProperties) {
        if ($Manifest.PSObject.Properties.Name -notcontains $propertyName) {
            throw "备份清单缺少字段：$propertyName"
        }
    }

    if ([int]$Manifest.SchemaVersion -ne 1) {
        throw "不支持的备份格式版本：$($Manifest.SchemaVersion)"
    }

    try {
        [void][version]([string]$Manifest.ToolkitVersion)
        [void][datetimeoffset]::Parse([string]$Manifest.CreatedUtc)
    }
    catch {
        throw '备份清单中的版本号或时间格式无效。'
    }

    if (
        [string]::IsNullOrWhiteSpace([string]$Manifest.ComputerName) -or
        ([string]$Manifest.ComputerName -ne [string]$env:COMPUTERNAME)
    ) {
        throw "备份属于另一台计算机：$($Manifest.ComputerName)"
    }

    $snapshot = $Manifest.Snapshot
    $requiredSnapshotProperties = @(
        'Firewall',
        'Defender',
        'Smb1',
        'Guest',
        'Registry'
    )
    foreach ($propertyName in $requiredSnapshotProperties) {
        if ($snapshot.PSObject.Properties.Name -notcontains $propertyName) {
            throw "备份快照缺少字段：$propertyName"
        }
    }
    foreach ($componentName in @('Firewall', 'Defender', 'Smb1', 'Guest')) {
        $component = $snapshot.$componentName
        if (
            $component.PSObject.Properties.Name -notcontains 'Supported' -or
            $component.Supported -isnot [bool]
        ) {
            throw "备份组件的 Supported 状态无效：$componentName"
        }
    }

    if ([bool]$snapshot.Firewall.Supported) {
        foreach ($profile in @($snapshot.Firewall.Profiles)) {
            if (
                $profile.PSObject.Properties.Name -notcontains 'Name' -or
                $profile.PSObject.Properties.Name -notcontains 'Enabled' -or
                $profile.Enabled -isnot [bool]
            ) {
                throw '备份中的防火墙配置文件结构无效。'
            }
        }
        $profileNames = @(
            $snapshot.Firewall.Profiles |
                ForEach-Object { ([string]$_.Name).ToLowerInvariant() }
        )
        $expectedProfiles = @('domain', 'private', 'public')
        if (
            $profileNames.Count -ne 3 -or
            @($profileNames | Select-Object -Unique).Count -ne 3
        ) {
            throw '备份中的防火墙配置文件数量或名称无效。'
        }
        foreach ($profileName in $expectedProfiles) {
            if ($profileNames -notcontains $profileName) {
                throw "备份缺少防火墙配置文件：$profileName"
            }
        }
    }

    if ([bool]$snapshot.Defender.Supported) {
        $requiredDefenderProperties = @(
            'DisableRealtimeMonitoring',
            'PUAProtection',
            'EnableNetworkProtection'
        )
        foreach ($propertyName in $requiredDefenderProperties) {
            if ($snapshot.Defender.PSObject.Properties.Name -notcontains $propertyName) {
                throw "备份中的 Defender 状态缺少字段：$propertyName"
            }
        }
        if ($snapshot.Defender.DisableRealtimeMonitoring -isnot [bool]) {
            throw '备份中的 Defender 实时保护状态类型无效。'
        }
        $puaProtection = [int]$snapshot.Defender.PUAProtection
        $networkProtection = [int]$snapshot.Defender.EnableNetworkProtection
        if ($puaProtection -lt 0 -or $puaProtection -gt 2) {
            throw '备份中的 Defender PUAProtection 值无效。'
        }
        if ($networkProtection -lt 0 -or $networkProtection -gt 2) {
            throw '备份中的 Defender EnableNetworkProtection 值无效。'
        }
    }

    if ([bool]$snapshot.Smb1.Supported) {
        $allowedSmbStates = @(
            'Enabled',
            'Disabled',
            'EnablePending',
            'DisablePending',
            'Removed'
        )
        if ($allowedSmbStates -notcontains [string]$snapshot.Smb1.State) {
            throw "备份中的 SMBv1 状态无效：$($snapshot.Smb1.State)"
        }
    }

    if ([bool]$snapshot.Guest.Supported) {
        if (
            $snapshot.Guest.PSObject.Properties.Name -notcontains 'Name' -or
            $snapshot.Guest.PSObject.Properties.Name -notcontains 'Sid' -or
            $snapshot.Guest.PSObject.Properties.Name -notcontains 'Enabled' -or
            $snapshot.Guest.Enabled -isnot [bool]
        ) {
            throw '备份中的 Guest 账户结构无效。'
        }
        if (
            [string]::IsNullOrWhiteSpace([string]$snapshot.Guest.Name) -or
            ([string]$snapshot.Guest.Sid -notmatch '-501$')
        ) {
            throw '备份中的 Guest 账户身份无效。'
        }
    }

    $allowedRegistryTargets = @(
        'hklm:\software\microsoft\windows\currentversion\policies\system|enablelua',
        'hklm:\software\microsoft\windows\currentversion\policies\system|consentpromptbehavioradmin',
        'hklm:\software\microsoft\windows\currentversion\policies\system|promptonsecuredesktop',
        'hklm:\software\microsoft\windows\currentversion\policies\explorer|nodrivetypeautorun',
        'hklm:\system\currentcontrolset\control\terminal server|fdenytsconnections',
        'hklm:\system\currentcontrolset\control\terminal server\winstations\rdp-tcp|userauthentication'
    )
    $observedRegistryTargets = @()
    foreach ($registryState in @($snapshot.Registry)) {
        $requiredRegistryProperties = @(
            'Path',
            'Name',
            'KeyExists',
            'ValueExists',
            'Kind',
            'Value'
        )
        foreach ($propertyName in $requiredRegistryProperties) {
            if ($registryState.PSObject.Properties.Name -notcontains $propertyName) {
                throw "备份注册表状态缺少字段：$propertyName"
            }
        }
        if (
            $registryState.KeyExists -isnot [bool] -or
            $registryState.ValueExists -isnot [bool]
        ) {
            throw '备份中的注册表存在状态类型无效。'
        }

        $target = (
            ([string]$registryState.Path) +
            '|' +
            ([string]$registryState.Name)
        ).ToLowerInvariant()
        if ($allowedRegistryTargets -notcontains $target) {
            throw "备份包含未授权的注册表目标：$target"
        }
        if ($observedRegistryTargets -contains $target) {
            throw "备份包含重复的注册表目标：$target"
        }
        $observedRegistryTargets += $target

        if (
            [bool]$registryState.ValueExists -and
            [string]$registryState.Kind -ne 'DWord'
        ) {
            throw "备份中的注册表值类型无效：$target"
        }
    }

    if ($observedRegistryTargets.Count -ne $allowedRegistryTargets.Count) {
        throw '备份中的受管注册表目标不完整。'
    }
}

function Add-ChangeResult {
    param(
        [string]$Id,
        [string]$Description,
        [ValidateSet('Planned', 'Changed', 'Skipped', 'Failed')]
        [string]$Status,
        [string]$Detail
    )

    $script:ChangeResults += [pscustomobject]@{
        Id = $Id
        Description = $Description
        Status = $Status
        Detail = $Detail
    }
}

function Invoke-BaselineChange {
    param(
        [string]$Id,
        [string]$Description,
        [scriptblock]$Operation,
        [switch]$Skip,
        [string]$SkipReason
    )

    if ($Skip) {
        Add-ChangeResult -Id $Id -Description $Description -Status Skipped -Detail $SkipReason
        Write-ToolkitMessage Warning "$Description：已跳过（$SkipReason）"
        return
    }

    if ($script:PreviewOnly) {
        Add-ChangeResult -Id $Id -Description $Description -Status Planned -Detail '未修改系统'
        Write-ToolkitMessage Plan $Description
        return
    }

    try {
        & $Operation
        Add-ChangeResult -Id $Id -Description $Description -Status Changed -Detail '操作完成'
        Write-ToolkitMessage Success $Description
    }
    catch {
        $detail = $_.Exception.Message
        Add-ChangeResult -Id $Id -Description $Description -Status Failed -Detail $detail
        Write-ToolkitMessage Error "$Description：$detail"
    }
}

function Show-BaselinePlan {
    Write-Section '保守安全基线'
    Write-Host '将检查并处理以下项目：'
    Write-Host '  1. 开启域、专用和公用网络的 Windows 防火墙'
    Write-Host '  2. 开启 Microsoft Defender 实时保护与 PUA 防护'
    Write-Host '  3. 在 Windows 客户端将 Defender 网络保护设为审核模式'
    Write-Host '  4. 开启 UAC，并在安全桌面提示管理员'
    Write-Host '  5. 禁用 SMBv1 可选功能'
    Write-Host '  6. 禁用本地 Guest 账户'
    Write-Host '  7. RDP 已启用时要求网络级别身份验证（NLA）'
    Write-Host '  8. 禁用所有驱动器的 AutoRun'
    Write-Host ''
    Write-ToolkitMessage Warning '防火墙、旧版 SMB 设备和远程桌面策略可能影响现有业务。'
    Write-ToolkitMessage Info 'Windows Server 的网络保护需要按服务器角色单独评估，默认不修改。'
    Write-ToolkitMessage Info '实际应用前会在 ProgramData 下创建带 SHA-256 校验的配置备份。'
    Write-ToolkitMessage Info '脚本不会自动重启计算机。'
}

function Invoke-ApplyBaseline {
    $script:ChangeResults = @()
    Show-BaselinePlan

    if (-not $script:PreviewOnly) {
        Assert-Administrator
        if (-not (Read-Confirmation -Prompt '确认应用以上配置吗？' -DefaultNo)) {
            Write-ToolkitMessage Info '操作已取消，未修改系统。'
            return 5
        }

        [void](New-BaselineBackup)
    }
    else {
        Write-ToolkitMessage Info '当前为预览模式，不要求管理员权限，也不会创建备份。'
    }

    $snapshot = Get-BaselineSnapshot
    $isWindowsServer = $false
    $productTypeKnown = $false
    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
        $isWindowsServer = [int]$operatingSystem.ProductType -ne 1
        $productTypeKnown = $true
    }
    catch {
        # Network protection remains unchanged when the product type is unknown.
    }
    $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $explorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $rdpTcpPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'

    Invoke-BaselineChange `
        -Id 'firewall' `
        -Description '开启全部 Windows 防火墙配置文件' `
        -Skip:(-not [bool]$snapshot.Firewall.Supported) `
        -SkipReason '系统未提供 NetSecurity 防火墙命令' `
        -Operation {
            Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True
        }

    Invoke-BaselineChange `
        -Id 'defender-base' `
        -Description '开启 Defender 实时保护与 PUA 防护' `
        -Skip:(-not [bool]$snapshot.Defender.Supported) `
        -SkipReason 'Defender 不可用或由其他安全产品管理' `
        -Operation {
            Set-MpPreference `
                -DisableRealtimeMonitoring $false `
                -PUAProtection 1
        }

    $networkProtectionSkip = (
        (-not [bool]$snapshot.Defender.Supported) -or
        $isWindowsServer -or
        (-not $productTypeKnown)
    )
    $networkProtectionSkipReason = if (-not $productTypeKnown) {
        '无法确认 Windows 产品类型'
    }
    elseif ($isWindowsServer) {
        'Windows Server 需结合服务器角色和 UDP 负载单独评估'
    }
    else {
        'Defender 不可用或由其他安全产品管理'
    }

    Invoke-BaselineChange `
        -Id 'defender-network' `
        -Description '将 Defender 网络保护设为审核模式（Windows 客户端）' `
        -Skip:$networkProtectionSkip `
        -SkipReason $networkProtectionSkipReason `
        -Operation {
            Set-MpPreference -EnableNetworkProtection 2
        }

    Invoke-BaselineChange `
        -Id 'uac' `
        -Description '启用 UAC 与安全桌面提示' `
        -Operation {
            Set-RegistryDword -Path $uacPath -Name 'EnableLUA' -Value 1
            Set-RegistryDword -Path $uacPath -Name 'ConsentPromptBehaviorAdmin' -Value 5
            Set-RegistryDword -Path $uacPath -Name 'PromptOnSecureDesktop' -Value 1
        }

    $smbSkip = -not [bool]$snapshot.Smb1.Supported
    $smbReason = '当前系统不提供 SMB1Protocol 可选功能'
    if ([bool]$snapshot.Smb1.Supported -and ([string]$snapshot.Smb1.State -eq 'Disabled')) {
        $smbSkip = $true
        $smbReason = 'SMBv1 已禁用'
    }

    Invoke-BaselineChange `
        -Id 'smb1' `
        -Description '禁用 SMBv1 可选功能（不自动重启）' `
        -Skip:$smbSkip `
        -SkipReason $smbReason `
        -Operation {
            Disable-WindowsOptionalFeature `
                -Online `
                -FeatureName SMB1Protocol `
                -NoRestart `
                -ErrorAction Stop | Out-Null
        }

    $guestSkip = -not [bool]$snapshot.Guest.Supported
    $guestReason = '无法识别本地 Guest 账户'
    if ([bool]$snapshot.Guest.Supported -and (-not [bool]$snapshot.Guest.Enabled)) {
        $guestSkip = $true
        $guestReason = 'Guest 账户已禁用'
    }

    $guestName = [string]$snapshot.Guest.Name
    Invoke-BaselineChange `
        -Id 'guest' `
        -Description '禁用本地 Guest 账户' `
        -Skip:$guestSkip `
        -SkipReason $guestReason `
        -Operation {
            Invoke-NativeCommand -FilePath 'net.exe' -Arguments @(
                'user',
                $guestName,
                '/active:no'
            )
        }

    $rdpState = $snapshot.Registry |
        Where-Object { $_.Name -eq 'fDenyTSConnections' } |
        Select-Object -First 1
    $rdpEnabled = (
        $null -ne $rdpState -and
        [bool]$rdpState.ValueExists -and
        [int]$rdpState.Value -eq 0
    )

    Invoke-BaselineChange `
        -Id 'rdp-nla' `
        -Description 'RDP 已启用时要求网络级别身份验证（NLA）' `
        -Skip:(-not $rdpEnabled) `
        -SkipReason 'RDP 未启用，无需修改 NLA' `
        -Operation {
            Set-RegistryDword -Path $rdpTcpPath -Name 'UserAuthentication' -Value 1
        }

    Invoke-BaselineChange `
        -Id 'autorun' `
        -Description '禁用所有驱动器的 AutoRun' `
        -Operation {
            Set-RegistryDword -Path $explorerPolicyPath -Name 'NoDriveTypeAutoRun' -Value 255
        }

    Write-Section '执行结果'
    $script:ChangeResults |
        Format-Table Id, Status, Description -AutoSize |
        Out-Host

    $failedCount = @($script:ChangeResults | Where-Object { $_.Status -eq 'Failed' }).Count
    if ($failedCount -gt 0) {
        Write-ToolkitMessage Error "有 $failedCount 项配置失败。请查看上方错误并使用备份恢复。"
        return 4
    }

    if ($script:PreviewOnly) {
        Write-ToolkitMessage Success '预览完成，系统未被修改。'
    }
    else {
        Write-ToolkitMessage Success '安全基线处理完成。请安排维护窗口重启后再复查审计。'
    }

    return 0
}

function Invoke-RestoreBaseline {
    param([string]$Path)

    Assert-Administrator
    $manifest = Resolve-BackupManifest -Path $Path

    Write-Section '恢复配置'
    Write-Host "备份时间（UTC）：$($manifest.CreatedUtc)"
    Write-Host "目标计算机：$($manifest.ComputerName)"
    Write-ToolkitMessage Warning '恢复会覆盖本工具管理的防火墙开关、Defender、UAC、SMBv1、Guest、RDP NLA 与 AutoRun 状态。'

    if (-not (Read-Confirmation -Prompt '确认恢复该备份吗？' -DefaultNo)) {
        Write-ToolkitMessage Info '恢复已取消。'
        return 5
    }

    $script:ChangeResults = @()
    $snapshot = $manifest.Snapshot

    Invoke-BaselineChange `
        -Id 'restore-firewall' `
        -Description '恢复 Windows 防火墙配置文件开关' `
        -Skip:(-not [bool]$snapshot.Firewall.Supported) `
        -SkipReason '备份中没有可用的防火墙状态' `
        -Operation {
            foreach ($profile in @($snapshot.Firewall.Profiles)) {
                Set-NetFirewallProfile `
                    -Profile ([string]$profile.Name) `
                    -Enabled ([bool]$profile.Enabled)
            }
        }

    Invoke-BaselineChange `
        -Id 'restore-defender' `
        -Description '恢复 Defender 偏好设置' `
        -Skip:(-not [bool]$snapshot.Defender.Supported) `
        -SkipReason '备份中没有可用的 Defender 状态' `
        -Operation {
            Set-MpPreference `
                -DisableRealtimeMonitoring ([bool]$snapshot.Defender.DisableRealtimeMonitoring) `
                -PUAProtection ([int]$snapshot.Defender.PUAProtection) `
                -EnableNetworkProtection ([int]$snapshot.Defender.EnableNetworkProtection)
        }

    $smbRestoreSupported = [bool]$snapshot.Smb1.Supported
    Invoke-BaselineChange `
        -Id 'restore-smb1' `
        -Description '恢复 SMBv1 可选功能状态（不自动重启）' `
        -Skip:(-not $smbRestoreSupported) `
        -SkipReason '备份中没有可用的 SMBv1 状态' `
        -Operation {
            $originalState = [string]$snapshot.Smb1.State
            if ($originalState -match '^Enabled') {
                Enable-WindowsOptionalFeature `
                    -Online `
                    -FeatureName SMB1Protocol `
                    -All `
                    -NoRestart `
                    -ErrorAction Stop | Out-Null
            }
            elseif ($originalState -match '^Disabled') {
                Disable-WindowsOptionalFeature `
                    -Online `
                    -FeatureName SMB1Protocol `
                    -NoRestart `
                    -ErrorAction Stop | Out-Null
            }
            else {
                throw "无法恢复未知的 SMBv1 状态：$originalState"
            }
        }

    $guestRestoreSupported = [bool]$snapshot.Guest.Supported
    Invoke-BaselineChange `
        -Id 'restore-guest' `
        -Description '恢复本地 Guest 账户状态' `
        -Skip:(-not $guestRestoreSupported) `
        -SkipReason '备份中没有可用的 Guest 状态' `
        -Operation {
            $currentGuest = Get-GuestAccountState
            if (
                (-not [bool]$currentGuest.Supported) -or
                ([string]$currentGuest.Sid -ne [string]$snapshot.Guest.Sid)
            ) {
                throw '当前计算机的 Guest SID 与备份不匹配。'
            }

            $activeSwitch = if ([bool]$snapshot.Guest.Enabled) {
                '/active:yes'
            }
            else {
                '/active:no'
            }

            Invoke-NativeCommand -FilePath 'net.exe' -Arguments @(
                'user',
                ([string]$currentGuest.Name),
                $activeSwitch
            )
        }

    Invoke-BaselineChange `
        -Id 'restore-registry' `
        -Description '恢复 UAC、AutoRun、RDP 与 NLA 注册表值' `
        -Operation {
            foreach ($registryState in @($snapshot.Registry)) {
                Restore-RegistryValueState -State $registryState
            }
        }

    Write-Section '恢复结果'
    $script:ChangeResults |
        Format-Table Id, Status, Description -AutoSize |
        Out-Host

    $failedCount = @($script:ChangeResults | Where-Object { $_.Status -eq 'Failed' }).Count
    if ($failedCount -gt 0) {
        Write-ToolkitMessage Error "有 $failedCount 项恢复失败，请保留备份并手动检查。"
        return 4
    }

    Write-ToolkitMessage Success '恢复完成。部分设置需要重启后生效。'
    return 0
}

function New-AuditResult {
    param(
        [string]$Id,
        [string]$Category,
        [ValidateSet('Pass', 'Review', 'Info', 'Unavailable')]
        [string]$Status,
        [string]$Summary,
        [string]$Detail,
        [string]$Recommendation
    )

    return [pscustomobject]@{
        Id = $Id
        Category = $Category
        Status = $Status
        Summary = $Summary
        Detail = $Detail
        Recommendation = $Recommendation
    }
}

function Get-AuditResults {
    $results = @()

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $results += New-AuditResult `
            -Id 'system' `
            -Category '系统' `
            -Status Info `
            -Summary "$($os.Caption) build $($os.BuildNumber)" `
            -Detail "版本 $($os.Version)；最后启动 $($os.LastBootUpTime)" `
            -Recommendation '保持在微软仍支持的 Windows 版本与更新通道。'
    }
    catch {
        $results += New-AuditResult `
            -Id 'system' `
            -Category '系统' `
            -Status Unavailable `
            -Summary '无法读取操作系统信息' `
            -Detail $_.Exception.Message `
            -Recommendation '以本地管理员身份重新运行审计。'
    }

    $adminStatus = if (Test-IsAdministrator) { 'Pass' } else { 'Info' }
    $adminSummary = if (Test-IsAdministrator) {
        '当前进程具有管理员权限'
    }
    else {
        '当前为标准权限；部分检查可能不可用'
    }
    $results += New-AuditResult `
        -Id 'administrator' `
        -Category '权限' `
        -Status $adminStatus `
        -Summary $adminSummary `
        -Detail "当前用户：$env:USERNAME" `
        -Recommendation '日常使用标准账户，仅在变更系统配置时提升权限。'

    $firewall = Get-FirewallState
    if ([bool]$firewall.Supported) {
        $disabledProfiles = @($firewall.Profiles | Where-Object { -not [bool]$_.Enabled })
        if ($disabledProfiles.Count -eq 0) {
            $results += New-AuditResult `
                -Id 'firewall' `
                -Category '网络' `
                -Status Pass `
                -Summary '全部 Windows 防火墙配置文件已开启' `
                -Detail (($firewall.Profiles | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join '; ') `
                -Recommendation '继续按最小开放原则维护入站规则。'
        }
        else {
            $results += New-AuditResult `
                -Id 'firewall' `
                -Category '网络' `
                -Status Review `
                -Summary '存在已关闭的 Windows 防火墙配置文件' `
                -Detail (($disabledProfiles.Name) -join ', ') `
                -Recommendation '确认业务规则后开启全部配置文件。'
        }
    }
    else {
        $results += New-AuditResult `
            -Id 'firewall' `
            -Category '网络' `
            -Status Unavailable `
            -Summary '无法读取 Windows 防火墙状态' `
            -Detail 'NetSecurity 模块不可用或访问被拒绝。' `
            -Recommendation '检查 Windows 防火墙服务与 PowerShell NetSecurity 模块。'
    }

    if (Test-CommandAvailable 'Get-MpComputerStatus') {
        try {
            $defenderStatus = Get-MpComputerStatus
            $healthy = (
                [bool]$defenderStatus.AntivirusEnabled -and
                [bool]$defenderStatus.RealTimeProtectionEnabled
            )
            $status = if ($healthy) { 'Pass' } else { 'Review' }
            $summary = if ($healthy) {
                'Microsoft Defender 防病毒与实时保护已开启'
            }
            else {
                'Microsoft Defender 未处于完整实时保护状态'
            }

            $results += New-AuditResult `
                -Id 'defender' `
                -Category '恶意软件防护' `
                -Status $status `
                -Summary $summary `
                -Detail "Antivirus=$($defenderStatus.AntivirusEnabled); RealTime=$($defenderStatus.RealTimeProtectionEnabled); Signature=$($defenderStatus.AntivirusSignatureLastUpdated)" `
                -Recommendation '确认没有策略、篡改防护或第三方产品导致实时保护关闭。'
        }
        catch {
            $results += New-AuditResult `
                -Id 'defender' `
                -Category '恶意软件防护' `
                -Status Unavailable `
                -Summary '无法读取 Defender 状态' `
                -Detail $_.Exception.Message `
                -Recommendation '确认 Microsoft Defender 服务存在且当前账户有读取权限。'
        }
    }
    else {
        $results += New-AuditResult `
            -Id 'defender' `
            -Category '恶意软件防护' `
            -Status Unavailable `
            -Summary '系统未提供 Microsoft Defender 状态命令' `
            -Detail '可能使用了第三方安全产品或精简系统。' `
            -Recommendation '确认当前系统具备有效且持续更新的防病毒产品。'
    }

    $uac = Get-RegistryValueState `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
        -Name 'EnableLUA'
    $uacEnabled = [bool]$uac.ValueExists -and [int]$uac.Value -eq 1
    $results += New-AuditResult `
        -Id 'uac' `
        -Category '权限' `
        -Status $(if ($uacEnabled) { 'Pass' } else { 'Review' }) `
        -Summary $(if ($uacEnabled) { '用户账户控制（UAC）已开启' } else { '用户账户控制（UAC）未开启或状态未知' }) `
        -Detail "EnableLUA=$($uac.Value)" `
        -Recommendation '启用 UAC，并在安全桌面上确认需要提升权限的操作。'

    $smb1 = Get-Smb1State
    if ([bool]$smb1.Supported) {
        $smbDisabled = [string]$smb1.State -match '^Disabled'
        $results += New-AuditResult `
            -Id 'smb1' `
            -Category '旧协议' `
            -Status $(if ($smbDisabled) { 'Pass' } else { 'Review' }) `
            -Summary $(if ($smbDisabled) { 'SMBv1 已禁用' } else { 'SMBv1 仍可用或等待变更' }) `
            -Detail "FeatureState=$($smb1.State)" `
            -Recommendation '除非必须连接旧设备，否则保持 SMBv1 禁用。'
    }
    else {
        $results += New-AuditResult `
            -Id 'smb1' `
            -Category '旧协议' `
            -Status Unavailable `
            -Summary '无法读取 SMBv1 可选功能状态' `
            -Detail '当前系统不提供该功能或读取权限不足。' `
            -Recommendation '在“启用或关闭 Windows 功能”中人工确认 SMB 1.0/CIFS 状态。'
    }

    $guest = Get-GuestAccountState
    if ([bool]$guest.Supported) {
        $results += New-AuditResult `
            -Id 'guest' `
            -Category '账户' `
            -Status $(if ([bool]$guest.Enabled) { 'Review' } else { 'Pass' }) `
            -Summary $(if ([bool]$guest.Enabled) { '本地 Guest 账户已启用' } else { '本地 Guest 账户已禁用' }) `
            -Detail "Account=$($guest.Name); Enabled=$($guest.Enabled)" `
            -Recommendation '没有明确业务需求时保持 Guest 账户禁用。'
    }
    else {
        $results += New-AuditResult `
            -Id 'guest' `
            -Category '账户' `
            -Status Unavailable `
            -Summary '无法识别本地 Guest 账户' `
            -Detail 'CIM 查询未返回 SID 以 -501 结尾的本地账户。' `
            -Recommendation '在“本地用户和组”中人工检查来宾账户。'
    }

    $rdpEnabledState = Get-RegistryValueState `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
        -Name 'fDenyTSConnections'
    $rdpNlaState = Get-RegistryValueState `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
        -Name 'UserAuthentication'
    $rdpEnabled = (
        [bool]$rdpEnabledState.ValueExists -and
        [int]$rdpEnabledState.Value -eq 0
    )
    if (-not $rdpEnabled) {
        $results += New-AuditResult `
            -Id 'rdp' `
            -Category '远程访问' `
            -Status Info `
            -Summary '远程桌面未启用' `
            -Detail "fDenyTSConnections=$($rdpEnabledState.Value)" `
            -Recommendation '若不需要远程桌面，保持关闭。'
    }
    else {
        $nlaEnabled = [bool]$rdpNlaState.ValueExists -and [int]$rdpNlaState.Value -eq 1
        $results += New-AuditResult `
            -Id 'rdp' `
            -Category '远程访问' `
            -Status $(if ($nlaEnabled) { 'Pass' } else { 'Review' }) `
            -Summary $(if ($nlaEnabled) { '远程桌面已启用且要求 NLA' } else { '远程桌面已启用但未要求 NLA' }) `
            -Detail "UserAuthentication=$($rdpNlaState.Value)" `
            -Recommendation '限制来源地址、使用 NLA，并避免将 3389 直接暴露到互联网。'
    }

    if (Test-CommandAvailable 'Get-BitLockerVolume') {
        try {
            $bitLocker = Get-BitLockerVolume -MountPoint $env:SystemDrive
            $protected = [string]$bitLocker.ProtectionStatus -eq 'On'
            $results += New-AuditResult `
                -Id 'bitlocker' `
                -Category '磁盘' `
                -Status $(if ($protected) { 'Pass' } else { 'Review' }) `
                -Summary $(if ($protected) { '系统卷 BitLocker 保护已开启' } else { '系统卷未处于 BitLocker 保护状态' }) `
                -Detail "VolumeStatus=$($bitLocker.VolumeStatus); ProtectionStatus=$($bitLocker.ProtectionStatus)" `
                -Recommendation '确认恢复密钥已安全备份后启用系统卷加密。'
        }
        catch {
            $results += New-AuditResult `
                -Id 'bitlocker' `
                -Category '磁盘' `
                -Status Unavailable `
                -Summary '无法读取 BitLocker 状态' `
                -Detail $_.Exception.Message `
                -Recommendation '在“管理 BitLocker”中人工确认系统卷状态。'
        }
    }
    else {
        $results += New-AuditResult `
            -Id 'bitlocker' `
            -Category '磁盘' `
            -Status Unavailable `
            -Summary '当前版本未提供 BitLocker PowerShell 命令' `
            -Detail '部分 Windows 家庭版不包含完整 BitLocker 管理模块。' `
            -Recommendation '检查设备加密或系统版本支持情况。'
    }

    if (Test-CommandAvailable 'Confirm-SecureBootUEFI') {
        try {
            $secureBoot = Confirm-SecureBootUEFI
            $results += New-AuditResult `
                -Id 'secure-boot' `
                -Category '启动' `
                -Status $(if ($secureBoot) { 'Pass' } else { 'Review' }) `
                -Summary $(if ($secureBoot) { '安全启动已开启' } else { '安全启动未开启' }) `
                -Detail "SecureBoot=$secureBoot" `
                -Recommendation '硬件和系统兼容时启用 UEFI Secure Boot。'
        }
        catch {
            $results += New-AuditResult `
                -Id 'secure-boot' `
                -Category '启动' `
                -Status Unavailable `
                -Summary '无法确认安全启动状态' `
                -Detail $_.Exception.Message `
                -Recommendation '在 UEFI 固件设置或“系统信息”中人工确认。'
        }
    }

    try {
        $updateService = Get-Service -Name wuauserv
        $disabled = [string]$updateService.StartType -eq 'Disabled'
        $results += New-AuditResult `
            -Id 'windows-update' `
            -Category '更新' `
            -Status $(if ($disabled) { 'Review' } else { 'Pass' }) `
            -Summary $(if ($disabled) { 'Windows Update 服务已被禁用' } else { 'Windows Update 服务未被禁用' }) `
            -Detail "Status=$($updateService.Status); StartType=$($updateService.StartType)" `
            -Recommendation '保持受支持的补丁管理方式，不要永久禁用更新服务。'
    }
    catch {
        $results += New-AuditResult `
            -Id 'windows-update' `
            -Category '更新' `
            -Status Unavailable `
            -Summary '无法读取 Windows Update 服务' `
            -Detail $_.Exception.Message `
            -Recommendation '检查 wuauserv 服务与组织更新策略。'
    }

    $pendingReasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $pendingReasons += 'CBS'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $pendingReasons += 'WindowsUpdate'
    }
    $sessionManager = Get-ItemProperty `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
        -Name 'PendingFileRenameOperations' `
        -ErrorAction SilentlyContinue
    if ($null -ne $sessionManager) {
        $pendingReasons += 'PendingFileRename'
    }

    $results += New-AuditResult `
        -Id 'pending-reboot' `
        -Category '维护' `
        -Status $(if ($pendingReasons.Count -gt 0) { 'Info' } else { 'Pass' }) `
        -Summary $(if ($pendingReasons.Count -gt 0) { '检测到待重启状态' } else { '未检测到常见待重启标记' }) `
        -Detail $(if ($pendingReasons.Count -gt 0) { $pendingReasons -join ', ' } else { 'None' }) `
        -Recommendation '在维护窗口完成重启，并重新运行审计。'

    if (
        (Test-CommandAvailable 'Get-LocalGroup') -and
        (Test-CommandAvailable 'Get-LocalGroupMember')
    ) {
        try {
            $administrators = Get-LocalGroup -SID 'S-1-5-32-544'
            $members = @(Get-LocalGroupMember -Group $administrators.Name)
            $results += New-AuditResult `
                -Id 'local-admins' `
                -Category '账户' `
                -Status Info `
                -Summary "本地 Administrators 组共有 $($members.Count) 个成员" `
                -Detail (($members.Name) -join ', ') `
                -Recommendation '定期移除不再需要的管理员、旧域账户与未知主体。'
        }
        catch {
            $results += New-AuditResult `
                -Id 'local-admins' `
                -Category '账户' `
                -Status Unavailable `
                -Summary '无法列出本地管理员组成员' `
                -Detail $_.Exception.Message `
                -Recommendation '使用“计算机管理”人工检查本地 Administrators 组。'
        }
    }

    if (Test-CommandAvailable 'Get-NetTCPConnection') {
        try {
            $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
            $results += New-AuditResult `
                -Id 'listening-ports' `
                -Category '网络' `
                -Status Info `
                -Summary "检测到 $($listeners.Count) 个 TCP 监听端点" `
                -Detail '运行 win_secure.cmd ports 查看进程与端口明细。' `
                -Recommendation '核对未知监听端口，并从防火墙和应用两侧关闭无用服务。'
        }
        catch {
            $results += New-AuditResult `
                -Id 'listening-ports' `
                -Category '网络' `
                -Status Unavailable `
                -Summary '无法读取 TCP 监听端点' `
                -Detail $_.Exception.Message `
                -Recommendation '以管理员身份运行 netstat -abno 进行复核。'
        }
    }

    return $results
}

function ConvertTo-MarkdownSafe {
    param([object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Resolve-AuditReportPath {
    param([string]$RequestedPath)

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $defaultName = "audit-$($env:COMPUTERNAME)-$stamp.md"

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        $directory = Get-ReportRoot
        [void](New-Item -ItemType Directory -Path $directory -Force)
        return (Join-Path $directory $defaultName)
    }

    if (Test-Path -LiteralPath $RequestedPath -PathType Container) {
        return (Join-Path $RequestedPath $defaultName)
    }

    if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($RequestedPath))) {
        [void](New-Item -ItemType Directory -Path $RequestedPath -Force)
        return (Join-Path $RequestedPath $defaultName)
    }

    $parent = Split-Path -Parent $RequestedPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    return $RequestedPath
}

function Write-AuditReports {
    param(
        [object[]]$Results,
        [string]$RequestedPath
    )

    $markdownPath = Resolve-AuditReportPath -RequestedPath $RequestedPath
    if ([System.IO.Path]::GetExtension($markdownPath) -ne '.md') {
        $markdownPath = [System.IO.Path]::ChangeExtension($markdownPath, '.md')
    }
    $jsonPath = [System.IO.Path]::ChangeExtension($markdownPath, '.json')

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Windows Security Audit Report')
    $lines.Add('')
    $lines.Add("- Generated (UTC): $((Get-Date).ToUniversalTime().ToString('o'))")
    $lines.Add("- Computer: $env:COMPUTERNAME")
    $lines.Add("- Toolkit version: $script:Version")
    $lines.Add("- Administrator: $(Test-IsAdministrator)")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add('| Status | Count |')
    $lines.Add('| --- | ---: |')
    foreach ($status in @('Pass', 'Review', 'Info', 'Unavailable')) {
        $count = @($Results | Where-Object { $_.Status -eq $status }).Count
        $lines.Add("| $status | $count |")
    }

    $lines.Add('')
    $lines.Add('## Results')
    $lines.Add('')
    $lines.Add('| Status | Category | Check | Summary |')
    $lines.Add('| --- | --- | --- | --- |')
    foreach ($result in $Results) {
        $lines.Add(
            "| $(ConvertTo-MarkdownSafe $result.Status) | " +
            "$(ConvertTo-MarkdownSafe $result.Category) | " +
            "$(ConvertTo-MarkdownSafe $result.Id) | " +
            "$(ConvertTo-MarkdownSafe $result.Summary) |"
        )
    }

    foreach ($result in $Results) {
        $lines.Add('')
        $lines.Add("### [$($result.Status)] $($result.Id)")
        $lines.Add('')
        $lines.Add("- Category: $(ConvertTo-MarkdownSafe $result.Category)")
        $lines.Add("- Summary: $(ConvertTo-MarkdownSafe $result.Summary)")
        $lines.Add("- Detail: $(ConvertTo-MarkdownSafe $result.Detail)")
        $lines.Add("- Recommendation: $(ConvertTo-MarkdownSafe $result.Recommendation)")
    }

    $lines.Add('')
    $lines.Add('## Scope')
    $lines.Add('')
    $lines.Add('This report is a local configuration snapshot, not a penetration test, malware verdict, or compliance certification.')

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8NoBom)

    $document = [ordered]@{
        SchemaVersion = 1
        GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName = $env:COMPUTERNAME
        ToolkitVersion = $script:Version
        Administrator = Test-IsAdministrator
        Results = $Results
    }
    [System.IO.File]::WriteAllText(
        $jsonPath,
        ($document | ConvertTo-Json -Depth 8),
        $utf8NoBom
    )

    return [pscustomobject]@{
        Markdown = $markdownPath
        Json = $jsonPath
    }
}

function Invoke-Audit {
    param([string]$RequestedPath)

    Write-Section '只读安全审计'
    Write-ToolkitMessage Info '正在读取本机安全配置，不修改系统设置。'
    $results = @(Get-AuditResults)

    $results |
        Select-Object Status, Category, Id, Summary |
        Format-Table -AutoSize -Wrap |
        Out-Host

    $paths = Write-AuditReports -Results $results -RequestedPath $RequestedPath
    Write-ToolkitMessage Success "Markdown 报告：$($paths.Markdown)"
    Write-ToolkitMessage Success "JSON 报告：$($paths.Json)"

    $reviewCount = @($results | Where-Object { $_.Status -eq 'Review' }).Count
    if ($reviewCount -gt 0) {
        Write-ToolkitMessage Warning "有 $reviewCount 项需要人工复核；这不等同于确认存在漏洞。"
    }

    return 0
}

function Invoke-DefenderQuickScan {
    Assert-Administrator

    if (-not (Test-CommandAvailable 'Start-MpScan')) {
        throw '当前系统未提供 Microsoft Defender 扫描命令。'
    }

    Write-Section 'Microsoft Defender 快速扫描'
    if (-not (Read-Confirmation -Prompt '确认开始快速扫描吗？' -DefaultNo)) {
        Write-ToolkitMessage Info '扫描已取消。'
        return 5
    }

    Start-MpScan -ScanType QuickScan
    Write-ToolkitMessage Success '快速扫描命令已完成。请在 Windows 安全中心查看检测历史。'
    return 0
}

function Invoke-SystemVerify {
    Assert-Administrator

    Write-Section '系统映像与文件只读验证'
    Write-Host '将运行 DISM /ScanHealth 与 SFC /verifyonly；此模式不会自动修复文件。'
    if (-not (Read-Confirmation -Prompt '确认开始验证吗？' -DefaultNo)) {
        Write-ToolkitMessage Info '验证已取消。'
        return 5
    }

    $failed = 0
    try {
        Invoke-NativeCommand -FilePath 'dism.exe' -Arguments @(
            '/Online',
            '/Cleanup-Image',
            '/ScanHealth'
        )
    }
    catch {
        $failed++
        Write-ToolkitMessage Error $_.Exception.Message
    }

    try {
        Invoke-NativeCommand -FilePath 'sfc.exe' -Arguments @('/verifyonly')
    }
    catch {
        $failed++
        Write-ToolkitMessage Error $_.Exception.Message
    }

    if ($failed -gt 0) {
        Write-ToolkitMessage Warning '验证发现错误或命令执行失败；本工具没有自动修复。'
        return 4
    }

    Write-ToolkitMessage Success '系统映像与文件验证完成。'
    return 0
}

function Show-ListeningPorts {
    if (-not (Test-CommandAvailable 'Get-NetTCPConnection')) {
        throw '当前系统未提供 Get-NetTCPConnection。'
    }

    Write-Section 'TCP 监听端口'
    $rows = foreach ($connection in Get-NetTCPConnection -State Listen -ErrorAction Stop) {
        $processName = '<unknown>'
        try {
            $processName = (Get-Process -Id $connection.OwningProcess -ErrorAction Stop).ProcessName
        }
        catch {
            # A process can exit between the socket and process queries.
        }

        [pscustomobject]@{
            Address = $connection.LocalAddress
            Port = $connection.LocalPort
            PID = $connection.OwningProcess
            Process = $processName
        }
    }

    $rows |
        Sort-Object Port, Process |
        Format-Table -AutoSize |
        Out-Host

    Write-ToolkitMessage Info '监听端口并不自动等于对公网开放；还需结合防火墙、路由与云安全组判断。'
    return 0
}

function Invoke-UpdateCheck {
    Write-Section '版本检查'
    Write-ToolkitMessage Info '仅查询 GitHub Release 元数据，不下载或执行远程代码。'

    try {
        $headers = @{
            'User-Agent' = 'windows-secure-toolkit'
            'Accept' = 'application/vnd.github+json'
        }
        $release = Invoke-RestMethod `
            -Uri $script:ReleaseApiUrl `
            -Headers $headers `
            -Method Get

        $remoteText = ([string]$release.tag_name).TrimStart('v')
        $remoteVersion = [version]$remoteText
        $localVersion = [version]$script:Version

        if ($remoteVersion -gt $localVersion) {
            Write-ToolkitMessage Warning "发现新版本 v$remoteVersion；当前版本 v$localVersion。"
            Write-Host "发布页：$($release.html_url)"
        }
        elseif ($remoteVersion -eq $localVersion) {
            Write-ToolkitMessage Success "当前已是最新发布版本 v$localVersion。"
        }
        else {
            Write-ToolkitMessage Info "当前版本 v$localVersion 高于最新公开发布 v$remoteVersion。"
        }

        return 0
    }
    catch {
        Write-ToolkitMessage Error "无法读取 GitHub Release：$($_.Exception.Message)"
        return 4
    }
}

function Show-Help {
    Write-Host "$script:ToolkitName v$script:Version"
    Write-Host ''
    Write-Host '用法：'
    Write-Host '  win_secure.cmd                         打开交互菜单'
    Write-Host '  win_secure.cmd audit [报告路径]        生成只读 Markdown + JSON 审计报告'
    Write-Host '  win_secure.cmd plan                    预览保守基线，不修改系统'
    Write-Host '  win_secure.cmd apply                   备份并交互式应用保守基线'
    Write-Host '  win_secure.cmd restore "备份路径"      校验并恢复本工具管理的设置'
    Write-Host '  win_secure.cmd scan                    运行 Defender 快速扫描'
    Write-Host '  win_secure.cmd verify                  运行 DISM/SFC 只读验证'
    Write-Host '  win_secure.cmd ports                   查看 TCP 监听端口'
    Write-Host '  win_secure.cmd update                  查询 GitHub 最新 Release'
    Write-Host '  win_secure.cmd version                 输出版本'
    Write-Host '  win_secure.cmd self-test               运行无修改自检'
    Write-Host ''
    Write-Host '自动化可直接调用 src\WinSecure.ps1，并使用 -Yes、-DryRun、-ReportPath 等参数。'
    Write-Host "项目：$script:RepositoryUrl"
}

function Invoke-SelfTest {
    $failures = New-Object System.Collections.Generic.List[string]

    try {
        [void][version]$script:Version
    }
    catch {
        $failures.Add('版本号不是有效的 System.Version。')
    }

    if (-not $script:RepositoryUrl.StartsWith('https://')) {
        $failures.Add('仓库 URL 必须使用 HTTPS。')
    }

    if (-not $script:ReleaseApiUrl.StartsWith('https://api.github.com/')) {
        $failures.Add('Release API URL 不符合预期。')
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $script:ScriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if (@($parseErrors).Count -gt 0) {
        foreach ($parseError in $parseErrors) {
            $failures.Add("PowerShell 语法错误：$($parseError.Message)")
        }
    }

    $escaped = ConvertTo-MarkdownSafe 'a|b'
    if ($escaped -ne 'a\|b') {
        $failures.Add('Markdown 转义自检失败。')
    }

    $temporaryBackup = Join-Path ([System.IO.Path]::GetTempPath()) (
        'windows-secure-toolkit-manifest-test-' + [Guid]::NewGuid().ToString('N')
    )
    try {
        [void](New-Item -ItemType Directory -Path $temporaryBackup)
        $testManifestPath = Join-Path $temporaryBackup 'manifest.json'
        $testHashPath = Join-Path $temporaryBackup 'manifest.sha256'
        $emptyRegistryState = {
            param(
                [string]$Path,
                [string]$Name
            )

            return [ordered]@{
                Path = $Path
                Name = $Name
                KeyExists = $false
                ValueExists = $false
                Kind = $null
                Value = $null
            }
        }
        $testRegistry = @(
            (& $emptyRegistryState 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'),
            (& $emptyRegistryState 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin'),
            (& $emptyRegistryState 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop'),
            (& $emptyRegistryState 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'),
            (& $emptyRegistryState 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'),
            (& $emptyRegistryState 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication')
        )
        $testManifest = [ordered]@{
            SchemaVersion = 1
            ToolkitVersion = $script:Version
            CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            ComputerName = $env:COMPUTERNAME
            Snapshot = [ordered]@{
                Firewall = [ordered]@{
                    Supported = $false
                    Profiles = @()
                }
                Defender = [ordered]@{
                    Supported = $false
                    DisableRealtimeMonitoring = $null
                    PUAProtection = $null
                    EnableNetworkProtection = $null
                }
                Smb1 = [ordered]@{
                    Supported = $false
                    State = $null
                }
                Guest = [ordered]@{
                    Supported = $false
                    Name = $null
                    Sid = $null
                    Enabled = $null
                }
                Registry = $testRegistry
            }
        }
        $testEncoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText(
            $testManifestPath,
            ($testManifest | ConvertTo-Json -Depth 8),
            $testEncoding
        )
        $testHash = Get-Sha256File -Path $testManifestPath
        [System.IO.File]::WriteAllText(
            $testHashPath,
            ($testHash + '  manifest.json' + [Environment]::NewLine),
            $testEncoding
        )

        $resolvedManifest = Resolve-BackupManifest -Path $temporaryBackup
        if ([int]$resolvedManifest.SchemaVersion -ne 1) {
            $failures.Add('备份清单解析自检失败。')
        }

        $originalTestRegistryPath = [string]$testManifest.Snapshot.Registry[0].Path
        $testManifest.Snapshot.Registry[0].Path = 'HKLM:\SOFTWARE\UnauthorizedRestoreTarget'
        [System.IO.File]::WriteAllText(
            $testManifestPath,
            ($testManifest | ConvertTo-Json -Depth 8),
            $testEncoding
        )
        $testHash = Get-Sha256File -Path $testManifestPath
        [System.IO.File]::WriteAllText(
            $testHashPath,
            ($testHash + '  manifest.json' + [Environment]::NewLine),
            $testEncoding
        )
        $structureRejected = $false
        try {
            [void](Resolve-BackupManifest -Path $temporaryBackup)
        }
        catch {
            $structureRejected = $true
        }
        if (-not $structureRejected) {
            $failures.Add('备份清单恢复白名单自检失败。')
        }

        $testManifest.Snapshot.Registry[0].Path = $originalTestRegistryPath
        [System.IO.File]::WriteAllText(
            $testManifestPath,
            ($testManifest | ConvertTo-Json -Depth 8),
            $testEncoding
        )
        $testHash = Get-Sha256File -Path $testManifestPath
        [System.IO.File]::WriteAllText(
            $testHashPath,
            ($testHash + '  manifest.json' + [Environment]::NewLine),
            $testEncoding
        )
        [System.IO.File]::AppendAllText($testManifestPath, ' ', $testEncoding)
        $tamperDetected = $false
        try {
            [void](Resolve-BackupManifest -Path $temporaryBackup)
        }
        catch {
            $tamperDetected = $true
        }
        if (-not $tamperDetected) {
            $failures.Add('备份清单篡改检测自检失败。')
        }
    }
    catch {
        $failures.Add("备份清单自检异常：$($_.Exception.Message)")
    }
    finally {
        if (Test-Path -LiteralPath $temporaryBackup) {
            Remove-Item -LiteralPath $temporaryBackup -Recurse -Force
        }
    }

    if ($failures.Count -gt 0) {
        foreach ($failure in $failures) {
            Write-ToolkitMessage Error $failure
        }
        return 4
    }

    Write-ToolkitMessage Success 'WinSecure 核心自检通过。'
    return 0
}

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "$script:ToolkitName v$script:Version"
        Write-Host ('=' * 64)
        Write-Host '  1. 生成只读安全审计报告'
        Write-Host '  2. 预览保守安全基线'
        Write-Host '  3. 备份并应用保守安全基线'
        Write-Host '  4. 从备份恢复设置'
        Write-Host '  5. Microsoft Defender 快速扫描'
        Write-Host '  6. DISM/SFC 系统只读验证'
        Write-Host '  7. 查看 TCP 监听端口'
        Write-Host '  8. 检查项目更新'
        Write-Host '  9. 显示命令帮助'
        Write-Host '  0. 退出'
        Write-Host ''

        $choice = Read-Host '请选择项目 [0-9]'
        try {
            switch ($choice) {
                '1' {
                    [void](Invoke-Audit -RequestedPath $null)
                    Pause-Toolkit
                }
                '2' {
                    $oldPreview = $script:PreviewOnly
                    $script:PreviewOnly = $true
                    [void](Invoke-ApplyBaseline)
                    $script:PreviewOnly = $oldPreview
                    Pause-Toolkit
                }
                '3' {
                    [void](Invoke-ApplyBaseline)
                    Pause-Toolkit
                }
                '4' {
                    $path = Read-Host '请输入备份目录或 manifest.json 路径'
                    [void](Invoke-RestoreBaseline -Path $path)
                    Pause-Toolkit
                }
                '5' {
                    [void](Invoke-DefenderQuickScan)
                    Pause-Toolkit
                }
                '6' {
                    [void](Invoke-SystemVerify)
                    Pause-Toolkit
                }
                '7' {
                    [void](Show-ListeningPorts)
                    Pause-Toolkit
                }
                '8' {
                    [void](Invoke-UpdateCheck)
                    Pause-Toolkit
                }
                '9' {
                    Show-Help
                    Pause-Toolkit
                }
                '0' {
                    Write-ToolkitMessage Info '程序已退出。'
                    return 0
                }
                default {
                    Write-ToolkitMessage Error '输入无效。'
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-ToolkitMessage Error $_.Exception.Message
            Pause-Toolkit
        }
    }
}

$exitCode = 0
try {
    switch ($Action) {
        'Menu' {
            $exitCode = Show-MainMenu
        }
        'Audit' {
            $exitCode = Invoke-Audit -RequestedPath $ReportPath
        }
        'Apply' {
            $exitCode = Invoke-ApplyBaseline
        }
        'Restore' {
            $exitCode = Invoke-RestoreBaseline -Path $BackupPath
        }
        'DefenderQuickScan' {
            $exitCode = Invoke-DefenderQuickScan
        }
        'SystemVerify' {
            $exitCode = Invoke-SystemVerify
        }
        'ListeningPorts' {
            $exitCode = Show-ListeningPorts
        }
        'UpdateCheck' {
            $exitCode = Invoke-UpdateCheck
        }
        'Version' {
            Write-Host $script:Version
            $exitCode = 0
        }
        'SelfTest' {
            $exitCode = Invoke-SelfTest
        }
        'Help' {
            Show-Help
            $exitCode = 0
        }
    }
}
catch {
    Write-ToolkitMessage Error $_.Exception.Message
    $exitCode = 1
}

exit $exitCode
