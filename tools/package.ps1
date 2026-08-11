param(
  [string]$Version = "2.0.0-rc2",
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$source = Join-Path $repo "MultiDash"
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo "dist\RC2" }
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repo "dist"))
$distPrefix = $distRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if ($output -ne $distRoot -and -not $output.StartsWith($distPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputDirectory must stay inside the repository's dist folder."
}

$files = @(
  "MultiDash.png",
  "audio/armed.wav",
  "audio/beep.wav",
  "audio/disarm.wav",
  "config.lua",
  "i18n.lua",
  "lang/de.lua",
  "lang/es.lua",
  "lang/fr.lua",
  "lang/it.lua",
  "lang/pl.lua",
  "lang/pt.lua",
  "lang/zh_cn.lua",
  "lang/zh_tw.lua",
  "main.lua",
  "models/.gitkeep",
  "storage.lua",
  "summary.lua",
  "widget.lua"
)

$expectedAudio = @{
  "audio/armed.wav" = "C2BB95ED772F4230FAE1674F018CAC1126B8DE5B18525A119752493BE3E1AF47"
  "audio/beep.wav" = "30B14EB691F6E47AD8D3EA2E3E80A3146C3E7EF4F279A636A33D2B70A4C77F55"
  "audio/disarm.wav" = "B3EF33CB3326D35C28860B8DC57F11947A7706775179F1A5262D3E609EC2B365"
}

foreach ($relative in $files) {
  $path = Join-Path $source $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing payload file: $relative" }
}
foreach ($relative in $expectedAudio.Keys) {
  $hash = (Get-FileHash -LiteralPath (Join-Path $source $relative) -Algorithm SHA256).Hash
  if ($hash -ne $expectedAudio[$relative]) { throw "Protected audio changed: $relative" }
}

$stage = [System.IO.Path]::GetFullPath((Join-Path $repo ".package-stage"))
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
$installerStage = Join-Path $stage "installer"
$manualStage = Join-Path $stage "manual\MultiDash"
$sourceStage = Join-Path $stage "source"
New-Item -ItemType Directory -Path $installerStage, $manualStage, $sourceStage, $output -Force | Out-Null

foreach ($relative in $files) {
  foreach ($destination in @($installerStage, $manualStage)) {
    $target = Join-Path $destination $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source $relative) -Destination $target -Force
  }
}

foreach ($item in @(".github", ".gitattributes", ".gitignore", "assets", "LICENSE", "MultiDash", "README.md", "RELEASE_NOTES_RC2.md", "tests", "tools")) {
  Copy-Item -LiteralPath (Join-Path $repo $item) -Destination $sourceStage -Recurse -Force
}

$manifest = [ordered]@{
  manifestVersion = 1
  id = "mdash"
  scriptId = "mdash"
  name = "MultiDash"
  folder = "MultiDash"
  directory = "MultiDash"
  version = $Version
  author = "Steven McCormack"
  description = "MultiDash $Version telemetry dashboard for ETHOS 1.6.6 and newer"
  files = $files
}
$json = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
  (Join-Path $installerStage "ethos_lua_manifest.json"),
  $json,
  (New-Object System.Text.UTF8Encoding($false))
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$installerZip = Join-Path $output "MultiDash_ETHOS_installer.zip"
$manualZip = Join-Path $output "MultiDash_manual_install.zip"
$sourceZip = Join-Path $output "MultiDash_source.zip"
$zipTimestamp = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
function New-ReleaseZip([string]$root, [string]$zipPath) {
  $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName | ForEach-Object {
      $entry = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
      $zipEntry = $archive.CreateEntry($entry, [System.IO.Compression.CompressionLevel]::Optimal)
      $zipEntry.LastWriteTime = $zipTimestamp
      $input = [System.IO.File]::OpenRead($_.FullName)
      $outputStream = $zipEntry.Open()
      try { $input.CopyTo($outputStream) }
      finally { $outputStream.Dispose(); $input.Dispose() }
    }
  } finally {
    $archive.Dispose()
  }
}
New-ReleaseZip $installerStage $installerZip
New-ReleaseZip (Split-Path -Parent $manualStage) $manualZip
New-ReleaseZip $sourceStage $sourceZip

function Assert-ZipEntries([string]$zipPath, [string[]]$expected) {
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    $actual = @($archive.Entries | ForEach-Object { $_.FullName.Replace("\", "/") } | Sort-Object)
    $difference = Compare-Object ($expected | Sort-Object) $actual
    if ($difference) { throw "Unexpected package structure in $zipPath" }
  } finally {
    $archive.Dispose()
  }
}
Assert-ZipEntries $installerZip (@("ethos_lua_manifest.json") + $files)
Assert-ZipEntries $manualZip @($files | ForEach-Object { "MultiDash/$_" })
$sourceEntries = @(Get-ChildItem -LiteralPath $sourceStage -Recurse -File | ForEach-Object {
  $_.FullName.Substring($sourceStage.Length + 1).Replace("\", "/")
})
Assert-ZipEntries $sourceZip $sourceEntries

Remove-Item -LiteralPath $stage -Recurse -Force
Get-Item -LiteralPath $sourceZip, $installerZip, $manualZip
