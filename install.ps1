# Via Studios Kit - installer / repair (3.28.4). Started by install_via_kit.bat (as administrator).
# Downloads the newest release from github.com/waelsamiry/via-kit-releases, checks its SHA-256, installs it into the
# CEP extensions folder, turns on Adobe debug mode (unsigned panel) and gives Users "Modify" on the kit folder, so the
# panel's own Update button never needs admin again. User files are kept (python_path.txt, *.lic, presets you added).
# Works for a new PC and for a PC whose Update button did not finish.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
$RAW = 'https://raw.githubusercontent.com/waelsamiry/via-kit-releases/main/'
$KIT = Join-Path ${env:ProgramFiles(x86)} 'Common Files\Adobe\CEP\extensions\com.welo.tools'
function Say($m, $c) { if ($c) { Write-Host "  $m" -ForegroundColor $c } else { Write-Host "  $m" } }
function Fail($m) { Write-Host ''; Say "X $m" Red; Write-Host ''; exit 1 }

Write-Host ''
Say 'Via Studios Kit - install / update' Cyan
Write-Host ''

# 1 After Effects must be closed
$ae = Get-Process -Name 'AfterFX' -ErrorAction SilentlyContinue
if ($ae) {
  Say 'Save your work and close After Effects - waiting...' Yellow
  while (Get-Process -Name 'AfterFX' -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 2 }
  Start-Sleep -Seconds 2
}

# 2 newest release
Say 'Checking the newest version...'
$j = Invoke-RestMethod -UseBasicParsing -Uri ($RAW + 'latest.json?t=' + [DateTime]::Now.Ticks) -Headers @{ 'Cache-Control' = 'no-cache' }
if (-not $j.version) { Fail 'latest.json has no version' }
$have = ''
$man = Join-Path $KIT 'CSXS\manifest.xml'
if (Test-Path $man) { if ([IO.File]::ReadAllText($man) -match 'ExtensionBundleVersion="([^"]+)"') { $have = $Matches[1] } }
Say ("Installed: " + $(if ($have) { $have } else { 'nothing' }) + "   Newest: " + $j.version)
if (Test-Path (Join-Path $KIT '.git')) {
  Say 'This kit folder is a git clone (developer PC). Installing over it keeps .git but makes the files differ from git.' Yellow
  $a = Read-Host '  Continue anyway? (y/n)'
  if ($a -ne 'y') { exit 0 }
}

# 3 download + verify + unzip
$work = Join-Path $env:TEMP 'via-install'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force $work | Out-Null
$zip = Join-Path $work 'kit.zip'
Say ('Downloading ' + $j.version + '...')
Invoke-WebRequest -UseBasicParsing -Uri ($RAW + $j.file + '?t=' + [DateTime]::Now.Ticks) -OutFile $zip
$sum = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
if ($sum -ne ([string]$j.sha256).ToLower()) { Fail 'the download is damaged (SHA-256 mismatch) - wait 5 minutes and run this again' }
$stage = Join-Path $work 'stage'
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $stage)
if (-not (Test-Path (Join-Path $stage 'CSXS\manifest.xml'))) { Fail 'the package has no CSXS\manifest.xml' }

# 4 backup + copy
if ($have) {
  $bak = Join-Path $env:APPDATA ('Via Studios Kit\backup\' + $have)
  Say ('Backing up ' + $have + '...')
  if (Test-Path $bak) { Remove-Item $bak -Recurse -Force }
  & robocopy $KIT $bak /E /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
}
Say ('Installing ' + $j.version + '...')
& robocopy $stage $KIT /E /XD .git __pycache__ /XF python_path.txt .debug *.lic UPDATE_TEST /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "copy failed (robocopy $LASTEXITCODE)" }
foreach ($r in @($j.remove)) { if ($r -and $r -notmatch '\.\.') { $p = Join-Path $KIT $r; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } } }

# 5 debug mode (unsigned panel) + permissions for the Update button
foreach ($v in 9..13) { & reg add "HKCU\Software\Adobe\CSXS.$v" /v PlayerDebugMode /t REG_SZ /d 1 /f | Out-Null }
& icacls $KIT /grant '*S-1-5-32-545:(OI)(CI)M' /T /Q | Out-Null
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

$now = ''
if ([IO.File]::ReadAllText($man) -match 'ExtensionBundleVersion="([^"]+)"') { $now = $Matches[1] }
Write-Host ''
if ($now -ne $j.version) { Fail ('the kit says ' + $now + ' after copying - send a photo of this window') }
Say ('OK  Via Studios Kit ' + $now + ' is installed.') Green
Say 'Open After Effects: Window > Extensions > Via Studios Kit.'
if (-not $have) {
  Say 'First time on this PC:' Yellow
  Say ' - After Effects: Edit > Preferences > Scripting & Expressions > tick "Allow Scripts to Write Files and Access Network".'
  Say ' - Python + AI libraries (Transcription, Audio, Keyer): run setup_new_pc.bat in the kit folder as administrator.'
}
Write-Host ''
