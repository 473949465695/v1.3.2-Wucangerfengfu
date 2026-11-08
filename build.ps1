$ErrorActionPreference = 'Stop'

# aapt2/zipalign are native binaries that open arguments through the ANSI code
# page. The workspace lives under a non-ASCII path, so any absolute path handed
# to them fails with ENOENT. Everything therefore runs from the project
# directory with strictly relative, ASCII-only paths.
Set-Location $PSScriptRoot

# Android SDK: $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, .\.android-sdk, ..\.android-sdk.
# aapt2 and zipalign are native programs that receive their arguments through the
# ANSI code page, so on Windows the SDK path must stay ASCII-only.
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk -and (Test-Path '.android-sdk')) { $sdk = '.android-sdk' }
if (-not $sdk -and (Test-Path '..\.android-sdk')) { $sdk = '..\.android-sdk' }
if (-not $sdk) {
    throw 'Android SDK not found. Point $env:ANDROID_HOME at a folder containing build-tools\34.0.0 and platforms\android-34.'
}

$bt   = Join-Path $sdk 'build-tools\34.0.0'
$ajar = Join-Path $sdk 'platforms\android-34\android.jar'

$aapt2        = Join-Path $bt 'aapt2.exe'
$zipalign     = Join-Path $bt 'zipalign.exe'
$d8jar        = Join-Path $bt 'lib\d8.jar'
$apksignerJar = Join-Path $bt 'lib\apksigner.jar'

$javacExe = (Get-Command javac).Source
$jdk      = Split-Path (Split-Path $javacExe -Parent) -Parent
$javaExe  = Join-Path $jdk 'bin\java.exe'
$keytool  = Join-Path $jdk 'bin\keytool.exe'

foreach ($p in @($aapt2, $zipalign, $d8jar, $apksignerJar, $ajar, $javaExe, $keytool)) {
    if (-not (Test-Path $p)) { throw "missing tool: $p" }
}
Write-Host "jdk = $jdk"

if (Test-Path 'build') { Remove-Item 'build' -Recurse -Force }
foreach ($d in 'gen', 'classes', 'dex') {
    New-Item -ItemType Directory -Force -Path (Join-Path 'build' $d) | Out-Null
}

Write-Host '== 1/6  aapt2 compile =='
& $aapt2 compile --dir 'app\res' -o 'build\res.zip'
if ($LASTEXITCODE -ne 0) { throw 'aapt2 compile failed' }

Write-Host '== 2/6  aapt2 link =='
& $aapt2 link -o 'build\base.apk' -I $ajar --manifest 'app\AndroidManifest.xml' `
    'build\res.zip' -A 'app\assets' --java 'build\gen'
if ($LASTEXITCODE -ne 0) { throw 'aapt2 link failed' }

Write-Host '== 3/6  javac =='
# javac/d8 are JVMs: they take UTF-16 command lines, so absolute paths are safe.
$srcs  = @()
$srcs += (Get-ChildItem (Join-Path 'build' 'gen') -Recurse -Filter *.java -File).FullName
$srcs += (Get-ChildItem 'app\src' -Recurse -Filter *.java -File).FullName
Write-Host ("java sources: " + $srcs.Count)
& $javacExe -source 8 -target 8 -encoding UTF-8 -nowarn -cp $ajar -d 'build\classes' $srcs
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }

Write-Host '== 4/6  d8 (dex) =='
$classFiles = (Get-ChildItem 'build\classes' -Recurse -Filter *.class -File).FullName
& $javaExe -cp $d8jar com.android.tools.r8.D8 --min-api 21 --lib $ajar --output 'build\dex' $classFiles
if ($LASTEXITCODE -ne 0) { throw 'd8 failed' }

Write-Host '== 5/6  pack classes.dex + fix asset separators + zipalign =='
Copy-Item 'build\base.apk' 'build\unaligned.apk' -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open((Join-Path (Get-Location) 'build\unaligned.apk'), 'Update')
try {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, (Join-Path (Get-Location) 'build\dex\classes.dex'), 'classes.dex',
        [System.IO.Compression.CompressionLevel]::Optimal)

    # aapt2 walks app\assets with the native separator, so nested assets come out
    # as "assets/fonts\wcf-serif-400.otf". AssetManager opens them with '/', so
    # file:///android_asset/fonts/x.otf would 404 and the font would silently
    # fall back. Rewrite those entry names before aligning and signing.
    $bad = @($zip.Entries | Where-Object { $_.FullName.Contains('\') })
    foreach ($e in $bad) {
        $fixed  = $e.FullName.Replace('\', '/')
        $src    = $e.Open()
        $target = $zip.CreateEntry($fixed, [System.IO.Compression.CompressionLevel]::Optimal)
        $dst    = $target.Open()
        $src.CopyTo($dst)
        $dst.Dispose()
        $src.Dispose()
        $e.Delete()
        Write-Host "  renamed asset: $($e.FullName) -> $fixed"
    }
} finally {
    $zip.Dispose()
}
if ($bad.Count -eq 0) { Write-Host '  asset separators already clean' }
& $zipalign -f -p 4 'build\unaligned.apk' 'build\aligned.apk'
if ($LASTEXITCODE -ne 0) { throw 'zipalign failed' }

Write-Host '== 6/6  sign =='
if (-not (Test-Path 'debug.keystore')) {
    & $keytool -genkeypair -keystore 'debug.keystore' -storepass android -keypass android `
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 `
        -dname 'CN=Android Debug,O=Android,C=US' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }
    Write-Host 'generated debug.keystore'
}

if (Test-Path 'wucangerfengfu.apk') { Remove-Item 'wucangerfengfu.apk' -Force }
& $javaExe -jar $apksignerJar sign --ks 'debug.keystore' --ks-pass pass:android `
    --key-pass pass:android --ks-key-alias androiddebugkey `
    --out 'wucangerfengfu.apk' 'build\aligned.apk'
if ($LASTEXITCODE -ne 0) { throw 'apksigner sign failed' }

Write-Host ''
Write-Host '== verify =='
& $javaExe -jar $apksignerJar verify --print-certs 'wucangerfengfu.apk'
& $aapt2 dump badging 'wucangerfengfu.apk' | Select-Object -First 12

""
"APK : " + (Join-Path (Get-Location) 'wucangerfengfu.apk')
"SIZE: " + [math]::Round((Get-Item 'wucangerfengfu.apk').Length / 1MB, 2) + " MB"
