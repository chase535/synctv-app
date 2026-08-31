$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageConfigPath = Join-Path (Get-Location) '.dart_tool/package_config.json'
if (-not (Test-Path -LiteralPath $packageConfigPath -PathType Leaf)) {
  throw "Dart package config was not found: $packageConfigPath"
}

$packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw | ConvertFrom-Json
$packageConfigDirectory = Split-Path -Parent (Resolve-Path -LiteralPath $packageConfigPath).Path
$packageConfigDirectory = $packageConfigDirectory.TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$packageConfigBaseUri = [Uri]::new($packageConfigDirectory + [IO.Path]::DirectorySeparatorChar)

function Get-PackageRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $package = @($packageConfig.packages | Where-Object { $_.name -eq $Name })
  if ($package.Count -ne 1) {
    throw "Expected exactly one package named '$Name' in package_config.json; found $($package.Count)."
  }

  $rootUriText = [string]$package[0].rootUri
  $rootUri = [Uri]::new($packageConfigBaseUri, $rootUriText)
  if (-not $rootUri.IsFile) {
    throw "Package '$Name' does not resolve to a local file URI: $rootUri"
  }

  $root = [IO.Path]::GetFullPath($rootUri.LocalPath)
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Package root for '$Name' does not exist: $root"
  }
  return $root
}

function Install-PinnedCMakePatch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageName,

    [Parameter(Mandatory = $true)]
    [Uri]$SourceUrl,

    [Parameter(Mandatory = $true)]
    [string[]]$RequiredMarkers
  )

  $packageRoot = Get-PackageRoot -Name $PackageName
  $destination = Join-Path $packageRoot 'windows\CMakeLists.txt'
  if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw "Windows CMakeLists.txt for '$PackageName' was not found: $destination"
  }

  $temporary = Join-Path $env:RUNNER_TEMP "$PackageName-CMakeLists.txt"
  Invoke-WebRequest -Uri $SourceUrl -OutFile $temporary -UseBasicParsing

  if (-not (Test-Path -LiteralPath $temporary -PathType Leaf) -or (Get-Item -LiteralPath $temporary).Length -eq 0) {
    throw "Pinned CMake patch for '$PackageName' was not downloaded."
  }

  $patchText = Get-Content -LiteralPath $temporary -Raw
  foreach ($marker in $RequiredMarkers) {
    if (-not $patchText.Contains($marker)) {
      throw "Pinned CMake patch for '$PackageName' is missing required marker: $marker"
    }
  }

  Copy-Item -LiteralPath $temporary -Destination $destination -Force
  Write-Host "Patched $PackageName at $destination"
  Write-Host "Source: $SourceUrl"
}

# desktop_webview_window 0.3.0 hardcodes windows/libs/x64/WebView2Loader.dll.lib.
# This immutable SyncTV fork commit selects the architecture-specific loader from
# Microsoft.Web.WebView2 1.0.992.28 instead.
Install-PinnedCMakePatch `
  -PackageName 'desktop_webview_window' `
  -SourceUrl 'https://raw.githubusercontent.com/chase535/flutter-plugins/b3a4930ec2001c945fd8f8d037f4bb5c3b6d58ce/packages/desktop_webview_window/windows/CMakeLists.txt' `
  -RequiredMarkers @(
    'FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64"',
    'set(WEBVIEW2_ARCH "arm64")',
    'set(WEBVIEW2_VERSION "1.0.992.28")'
  )

# media_kit_libs_windows_video 1.0.11 ships x64 ANGLE libraries. This pinned
# upstream ARM64-support commit selects aarch64 libmpv and ARM64 ANGLE assets.
Install-PinnedCMakePatch `
  -PackageName 'media_kit_libs_windows_video' `
  -SourceUrl 'https://raw.githubusercontent.com/talynone/media-kit/3469f4a1e24262db76a8b4cca07116074e3f6eef/libs/windows/media_kit_libs_windows_video/windows/CMakeLists.txt' `
  -RequiredMarkers @(
    'set(LIBMPV_ARCH "aarch64")',
    'mpv-dev-aarch64-20260221-git-534b2d2.7z',
    'ANGLE_WINARM64.7z'
  )
