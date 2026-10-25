# Avis Flash Assistance

Client de prise en main à distance d'Avis Flash, basé sur [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.0
(licence AGPL-3.0, conservée). Ce dossier décrit les modifications apportées au code d'origine.

## Modifications

| Fichier | Changement |
|---|---|
| `src/common.rs` | `apply_avisflash_branding()` : nom `AvisFlashAssistance`, serveur `31.207.39.15` + clé publique verrouillés, mises à jour RustDesk désactivées |
| `flutter/lib/common.dart` | Couleurs (or Avis Flash) |
| `flutter/assets/icon.png`, `logo_light.png`, `logo_dark.png` | Logo Avis Flash dans l'interface |
| `flutter/android/app/build.gradle` | Identifiant `fr.avisflash.assistance` |
| `flutter/android/app/src/main/AndroidManifest.xml`, `res/values/*.xml`, `res/mipmap-*/*` | Nom, textes (FR), icônes Android |
| `flutter/android/app/src/main/kotlin/.../MainService.kt`, `BootReceiver.kt` | Libellés de notification |
| `flutter/windows/runner/Runner.rc`, `resources/app_icon.ico`, `res/icon.ico`, `res/tray-icon.ico` | Nom et icônes Windows |
| `.github/workflows/avisflash-build.yml` | Compilation Windows x64 + Android, publiée dans la release `avisflash-1.5.0` |

## Régénérer (nouvelle version de RustDesk)

- `tools/generate-assets.ps1 <dossier>` : toutes les icônes depuis `source/avisflash-mobile-512-v5.png`
- `tools/make-workflow.ps1 <flutter-build.yml> <avisflash-build.yml>` : la recette de compilation

Le nom technique `AvisFlashAssistance` (sans espace) est imposé par RustDesk : il sert de nom
d'exécutable, de service Windows et de schéma de lien (`avisflashassistance://`).
