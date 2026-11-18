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

## Organisation

| Dossier | Contenu |
|---------|---------|
| `core/` | Les règles du jeu, sans aucune dépendance à l'affichage |
| `data/` | Le contenu du jeu (plats, cartes, restaurants…) sous forme de fichiers de données |
| `ui/` | Les scènes et l'interface |
| `sim/` | Les simulations sans affichage, pour l'équilibrage |
| `tests/` | Les tests (`test_*.gd`) et leur lanceur |
| `i18n/` | Les textes du jeu (`fr.po`) |
| `docs/` | Le plan du MVP et les notes de conception |

## Licence

[MIT](LICENSE)
