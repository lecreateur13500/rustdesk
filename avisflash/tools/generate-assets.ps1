# Avis Flash Assistance — génère toutes les icônes du client à partir du logo Avis Flash.
# Usage : powershell -ExecutionPolicy Bypass -File generate-assets.ps1 <dossier overlay>
param([Parameter(Mandatory = $true)][string]$Out)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$src = Join-Path $PSScriptRoot '..\source\avisflash-mobile-512-v5.png'
$base = [Drawing.Bitmap]::FromFile((Resolve-Path $src))

function New-Canvas([int]$w, [int]$h) {
  $b = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'
  $g.PixelOffsetMode = 'HighQuality'; $g.CompositingQuality = 'HighQuality'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([Drawing.Color]::Transparent)
  return @($b, $g)
}

function Save-Png($bmp, [string]$rel) {
  $p = Join-Path $Out $rel
  New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
  $bmp.Save($p, [Drawing.Imaging.ImageFormat]::Png)
}

function Get-Scaled([Drawing.Image]$img, [int]$size, [double]$ratio = 1.0) {
  $b, $g = New-Canvas $size $size
  $s = [int][Math]::Round($size * $ratio); $o = [int](($size - $s) / 2)
  $g.DrawImage($img, $o, $o, $s, $s); $g.Dispose()
  return $b
}

function Get-PngBytes($bmp) {
  $ms = New-Object IO.MemoryStream
  $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
  return , $ms.ToArray()
}

function Save-Ico([Drawing.Image]$img, [int[]]$sizes, [string]$rel) {
  $frames = foreach ($s in $sizes) { $b = Get-Scaled $img $s; , (Get-PngBytes $b); $b.Dispose() }
  $p = Join-Path $Out $rel
  New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
  $fs = [IO.File]::Create($p); $w = New-Object IO.BinaryWriter $fs
  $w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $d = if ($s -ge 256) { 0 } else { $s }
    $w.Write([byte]$d); $w.Write([byte]$d); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32); $w.Write([UInt32]$frames[$i].Length); $w.Write([UInt32]$offset)
    $offset += $frames[$i].Length
  }
  foreach ($f in $frames) { $w.Write($f) }
  $w.Close()
}

# Silhouette blanche des lettres « AF » (icône de notification Android : blanc + transparence).
function Get-Silhouette {
  $crop = New-Object Drawing.Rectangle 80, 120, 360, 270
  $sq = [Math]::Max($crop.Width, $crop.Height) + 40
  $b, $g = New-Canvas $sq $sq; $g.Dispose()
  $ox = [int](($sq - $crop.Width) / 2); $oy = [int](($sq - $crop.Height) / 2)
  for ($x = 0; $x -lt $crop.Width; $x++) {
    for ($y = 0; $y -lt $crop.Height; $y++) {
      $c = $base.GetPixel($crop.X + $x, $crop.Y + $y)
      $m = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
      $a = [Math]::Max(0, [Math]::Min(255, [int](($m - 70) * 255 / 130)))
      if ($a -gt 0) { $b.SetPixel($ox + $x, $oy + $y, [Drawing.Color]::FromArgb($a, 255, 255, 255)) }
    }
  }
  return $b
}

# --- Android : icônes lanceur (classique, rond, adaptative) + notification ---
$android = 'flutter/android/app/src/main/res'
$densities = [ordered]@{ 'mdpi' = 1.0; 'hdpi' = 1.5; 'xhdpi' = 2.0; 'xxhdpi' = 3.0; 'xxxhdpi' = 4.0 }
$silhouette = Get-Silhouette
foreach ($d in $densities.Keys) {
  $k = $densities[$d]
  $legacy = Get-Scaled $base ([int](48 * $k))
  Save-Png $legacy "$android/mipmap-$d/ic_launcher.png"; Save-Png $legacy "$android/mipmap-$d/ic_launcher_round.png"; $legacy.Dispose()
  # Icône adaptative 108 dp : le logo reste dans la zone sûre centrale (66 %).
  $fg = Get-Scaled $base ([int](108 * $k)) 0.66
  Save-Png $fg "$android/mipmap-$d/ic_launcher_foreground.png"; $fg.Dispose()
  $stat = Get-Scaled $silhouette ([int](24 * $k))
  Save-Png $stat "$android/mipmap-$d/ic_stat_logo.png"; $stat.Dispose()
}

# --- Interface (Flutter) : icône + logos clair/sombre (max 300x60, générés en 2x) ---
$icon = Get-Scaled $base 512; Save-Png $icon 'flutter/assets/icon.png'; $icon.Dispose()
foreach ($theme in @(@{ n = 'logo_light.png'; c = [Drawing.Color]::FromArgb(11, 11, 11) }, @{ n = 'logo_dark.png'; c = [Drawing.Color]::White })) {
  $b, $g = New-Canvas 600 120
  $g.DrawImage($base, 0, 4, 112, 112)
  $f1 = New-Object Drawing.Font 'Segoe UI', 40, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $f2 = New-Object Drawing.Font 'Segoe UI', 30, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('Avis Flash', $f1, (New-Object Drawing.SolidBrush $theme.c), 128, 10)
  $g.DrawString('Assistance', $f2, (New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(194, 146, 84))), 130, 62)
  $g.Dispose(); Save-Png $b "flutter/assets/$($theme.n)"; $b.Dispose()
}

# --- Windows : icône de l'exécutable, du packer portable et de la zone de notification ---
Save-Ico $base @(16, 24, 32, 48, 64, 128, 256) 'res/icon.ico'
Save-Ico $base @(16, 24, 32, 48, 64, 128, 256) 'flutter/windows/runner/resources/app_icon.ico'
Save-Ico $base @(16, 20, 24, 32, 48, 64) 'res/tray-icon.ico'

$silhouette.Dispose(); $base.Dispose()
Write-Host "Icônes générées dans $Out"
