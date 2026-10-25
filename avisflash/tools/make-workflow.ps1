# Avis Flash Assistance — dérive .github/workflows/avisflash-build.yml de la recette officielle
# flutter-build.yml : Windows x64 + Android uniquement, exécutable renommé, sans MSI, publication
# dans une release « avisflash-<version> » du fork.
# Usage : powershell -ExecutionPolicy Bypass -File make-workflow.ps1 <flutter-build.yml> <sortie.yml>
param(
  [Parameter(Mandatory = $true)][string]$Src,
  [Parameter(Mandatory = $true)][string]$Dst
)
$ErrorActionPreference = 'Stop'

$lines = [IO.File]::ReadAllLines($Src)
$jobsAt = [Array]::IndexOf($lines, 'jobs:')
if ($jobsAt -lt 0) { throw "Ligne 'jobs:' introuvable dans $Src" }

$version = ($lines | Where-Object { $_ -match '^\s+VERSION:\s*"([^"]+)"' } | Select-Object -First 1) -replace '^\s+VERSION:\s*"([^"]+)".*$', '$1'
if (-not $version) { throw 'VERSION introuvable' }

# --- En-tête : déclenchement manuel, release dédiée, droits d'écriture pour publier ---
$head = ($lines[0..$jobsAt] -join "`n")
$head = $head.Replace('name: Build the flutter version of the RustDesk', "name: Avis Flash Assistance (Windows + Android)`n`n# Généré par avisflash/tools/make-workflow.ps1 à partir de flutter-build.yml ($version).")
$head = $head.Replace("on:`n  workflow_call:", "on:`n  workflow_dispatch:")
$head = $head.Replace('default: "nightly"', "default: `"avisflash-$version`"")
$head = $head.Replace("`njobs:", "`npermissions:`n  contents: write`n`njobs:")

# --- Découpage par job (clé à deux espaces d'indentation) ---
$blocks = [ordered]@{}; $cur = $null
for ($i = $jobsAt + 1; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^  ([A-Za-z0-9_-]+):\s*$') { $cur = $Matches[1]; $blocks[$cur] = New-Object Collections.Generic.List[string] }
  if ($cur) { $blocks[$cur].Add($lines[$i]) }
}
$keep = 'generate-bridge', 'build-RustDeskTempTopMostWindow', 'build-for-windows-flutter', 'build-rustdesk-android', 'build-rustdesk-android-universal'
foreach ($k in $keep) { if (-not $blocks.Contains($k)) { throw "Job $k introuvable" } }

function Remove-Step([string]$text, [string]$name) {
  $rx = '(?ms)^      - name: ' + [regex]::Escape($name) + '\s*\n.*?(?=^      - |\z)'
  $new = [regex]::Replace($text, $rx, '')
  if ($new -eq $text) { throw "Étape « $name » introuvable" }
  return $new
}
function Replace-Strict([string]$text, [string]$old, [string]$new) {
  if (-not $text.Contains($old)) { throw "Motif introuvable : $old" }
  return $text.Replace($old, $new)
}

$out = New-Object Collections.Generic.List[string]
foreach ($k in $keep) {
  $t = ($blocks[$k] -join "`n")
  switch ($k) {
    'build-RustDeskTempTopMostWindow' {
      $t = [regex]::Replace($t, '(?s)\n\s+- \{\s*\n\s+target: windows-11-arm,.*?\}', '')
    }
    'build-for-windows-flutter' {
      $t = [regex]::Replace($t, '(?s)\n\s+- \{\s*\n\s+target: aarch64-pc-windows-msvc,.*?\}', '')
      $t = Replace-Strict $t 'runner/Release ./rustdesk' "runner/Release ./rustdesk`n          # Avis Flash : l'exécutable porte le nom de l'application (portable service, mises à jour).`n          mv ./rustdesk/rustdesk.exe ./rustdesk/avisflashassistance.exe"
      $t = Replace-Strict $t '-e ../../rustdesk/rustdesk.exe' '-e ../../rustdesk/avisflashassistance.exe'
      $t = Replace-Strict $t './SignOutput/rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.exe' './SignOutput/avisflash-assistance-${{ env.VERSION }}-${{ matrix.job.arch }}.exe'
      foreach ($s in 'Add MSBuild to PATH', 'Build msi', 'Build pre-built MSI template', 'Upload unsigned msi template') { $t = Remove-Step $t $s }
      $t = Replace-Strict $t "./SignOutput/rustdesk-*.msi`n            ./SignOutput/rustdesk-*.exe" './SignOutput/avisflash-assistance-*.exe'
    }
    { $_ -like 'build-rustdesk-android*' } {
      $t = Replace-Strict $t 'rustdesk-${{ env.VERSION }}' 'avisflash-assistance-${{ env.VERSION }}'
    }
  }
  $out.Add($t.TrimEnd())
  $out.Add('')
}

$yml = ($head + "`n" + ($out -join "`n")).TrimEnd() + "`n"
[IO.File]::WriteAllText($Dst, $yml, (New-Object Text.UTF8Encoding $false))
Write-Host "Workflow écrit : $Dst ($version)"
