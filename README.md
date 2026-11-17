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

Si la commande `godot` n'est pas dans ton PATH, indique le chemin de l'exécutable :

```bash
GODOT=/chemin/vers/Godot scripts/run_tests.sh
```

```powershell
$env:GODOT = "C:\chemin\vers\Godot.exe"; scripts\run_tests.ps1
```

Pour ne lancer qu'une partie des tests, ajoute un filtre sur le nom du fichier : `scripts/run_tests.sh rng`.

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
