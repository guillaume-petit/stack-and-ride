# Stack & Ride

Roguelite de livraison à vélo, façon jeu de plateau. Chaque soir, choisis tes courses dans l'appli,
trace ton trajet avec des cartes, cale les plats dans ton sac sans rien abîmer… et paie ton loyer.

> Projet en cours. Voir le [plan du MVP](docs/mvp-plan.md) pour l'avancement.

## Prérequis

- [Godot 4.7](https://godotengine.org/download) (version standard, pas la version .NET).

## Ouvrir le projet

1. Lance Godot, clique sur **Importer** et choisis le fichier `project.godot` de ce dossier.
2. Appuie sur **F5** pour lancer le jeu.

Au premier lancement, Godot crée un dossier `.godot/` (cache local, ignoré par Git).

## Jouer

Tout se fait à la souris (ou au doigt, voir plus bas) ; une ligne d'aide dit quoi faire ensuite.

- **Propositions** (au milieu) : survole-en une pour voir le restaurant et les clients sur le plan, puis **Accepter**.
- **Cartes** (en bas à gauche) : clique une carte pour gagner des pas (2 cartes par tour, les gratuites ne comptent pas).
- **Plan** : clique un carrefour surligné ; le trajet s'affiche au survol. On livre le client chez qui le trajet s'arrête.
- **Restaurant** : **Prendre le plat** dans la liste des courses, puis clique une colonne du sac pour l'y lâcher.
  `R` fait pivoter le plat, `Échap` annule. Clique un plat rangé pour le reprendre.
- **Fin du tour** quand tu as fini. Entre deux soirs : bilan, récompense gratuite, puis boutique.

Un bouton grisé ou un compteur de la barre du haut s'explique quand on clique dessus.

### Sur téléphone

L'interface s'agrandit selon la densité de l'écran et passe en mise en page compacte : le plan à gauche, et à droite
un onglet par panneau (**Cartes**, **Appli**, **Courses**, **Sac**, **Fil**) ; le jeu ouvre tout seul l'onglet dont
l'action suivante a besoin. Sans survol possible, on touche deux fois : un premier toucher sur un carrefour montre le
trajet, un second y va ; même chose pour une colonne du sac. Le bouton Retour d'Android repose le plat en main ou ouvre
le menu.

Pour essayer la version téléphone sur ordinateur, ajoute des options après `--` :

```bash
godot --path . -- --ui-scale=1.6 --touch
```

`--ui-scale=X` agrandit l'interface X fois, `--compact` force la mise en page compacte, `--touch` fait agir la souris
comme un doigt.

Les écrans `ui/debug/city_debug.tscn` et `ui/debug/bag_debug.tscn` (F6 dans l'éditeur) restent là pour tester
un quartier ou les règles du sac à la main.

## Lancer les tests

Les tests vérifient les règles du jeu sans ouvrir l'éditeur.

Sous Linux ou macOS :

```bash
scripts/run_tests.sh
```

Sous Windows (PowerShell) :

```powershell
scripts\run_tests.ps1
```

Les scripts cherchent Godot dans le PATH (y compris sous son nom d'origine, `Godot_v4.x-stable_...`), puis dans les dossiers Téléchargements, Bureau et `~/Godot`.
Sinon, indique le chemin de l'exécutable. **Sous Windows, utilise `Godot_v4.x-stable_win64_console.exe`** :
l'autre version n'affiche rien dans le terminal.

```bash
GODOT=/chemin/vers/Godot scripts/run_tests.sh
```

```powershell
$env:GODOT = "C:\chemin\vers\Godot_v4.7.2-stable_win64_console.exe"; scripts\run_tests.ps1
```

Pour ne lancer qu'une partie des tests, ajoute un filtre sur le nom du fichier : `scripts/run_tests.sh rng`.

## Lancer la simulation d'équilibrage

Un bot joue des parties complètes avec chaque profil et écrit le rapport `docs/balance-report.md`
(200 parties par profil par défaut, environ une minute) :

```bash
scripts/run_sim.sh
```

```powershell
scripts\run_sim.ps1
```

On peut choisir le nombre de parties par profil et la première graine : `scripts/run_sim.sh 50 1000`.
Avec les mêmes paramètres, le rapport est toujours identique : relance-le après avoir changé un chiffre
dans `data/` pour comparer.

## Exporter sur Android

Le préréglage d'export « Android » est dans `export_presets.cfg` (APK pour les téléphones 64 bits, sans les tests ni
les outils). À faire une fois sur ton ordinateur :

1. Installe [Android Studio](https://developer.android.com/studio) (le plus simple pour avoir le SDK Android), puis
   dans son *SDK Manager* coche **Android SDK Platform-Tools**, **Android SDK Build-Tools** et
   **Android SDK Command-line Tools**.
2. Installe un JDK 17 (par exemple [Temurin 17](https://adoptium.net/temurin/releases/?version=17)).
3. Dans Godot : **Éditeur > Gérer les modèles d'export > Télécharger et installer**.
4. Dans Godot : **Éditeur > Paramètres de l'éditeur > Export > Android** : indique le dossier du SDK Android
   (sous Windows, en général `C:\Users\<toi>\AppData\Local\Android\Sdk`) et celui du JDK. Godot crée tout seul
   une clé de debug pour signer l'APK.

Ensuite, deux façons de lancer le jeu sur ton téléphone :

- **Câble USB** : active les *Options pour les développeurs* et le *Débogage USB* du téléphone, branche-le, puis
  clique l'icône Android en haut à droite de l'éditeur (déploiement en un clic).
- **Fichier APK** : **Projet > Exporter… > Android > Exporter le projet** (décoche « Exporter en mode debug » seulement
  pour une version à publier), copie `build/stack-and-ride.apk` sur le téléphone et ouvre-le (il faut autoriser
  l'installation d'applications de sources inconnues).

En ligne de commande (le dossier `build/` doit exister, il est ignoré par Git) :
`godot --headless --path . --export-debug "Android" build/stack-and-ride.apk`.
Une version à publier sur le Play Store demandera sa propre clé (keystore) : elle ne doit jamais être commitée
(voir `.gitignore`).

## Sons

Les sons sont provisoires : `scripts/make_sounds.sh` (ou `scripts\make_sounds.ps1`) les synthétise dans
`assets/sounds/`. Pour remplacer un son, écrase son fichier `.wav` (même nom).

## Organisation

| Dossier | Contenu |
|---------|---------|
| `core/` | Les règles du jeu, sans aucune dépendance à l'affichage |
| `data/` | Le contenu du jeu (plats, cartes, restaurants…) sous forme de fichiers de données |
| `assets/` | Les sons (et plus tard les images) |
| `ui/` | Les scènes et l'interface |
| `sim/` | Les simulations sans affichage, pour l'équilibrage |
| `tests/` | Les tests (`test_*.gd`) et leur lanceur |
| `i18n/` | Les textes du jeu (`fr.po`) |
| `docs/` | Le plan du MVP et les notes de conception |

## Licence

[MIT](LICENSE)
