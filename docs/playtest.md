# Faire tester le jeu

Version à faire tester : **0.1.0** (itération 6). Le but est de régler les chiffres (itération 6 bis) avec des parties
jouées par des personnes, pas seulement par le bot.

## Avant de lancer les tests

- Exporte la version (PC ou APK, voir le [README](../README.md)) et note son numéro. **À chaque changement de chiffre
  dans `data/`, change la version** (Projet > Paramètres du projet > Application > Config > Version) : le rapport
  peut alors séparer les parties de chaque version.
- Le jeu s'explique tout seul au premier lancement (« Comment jouer », puis les bulles d'aide). Ne donne pas d'autre
  explication aux testeurs : ce qui n'est pas compris est justement à corriger.

## Récupérer les parties

Chaque partie terminée ou abandonnée est un fichier `.json` du dossier `runs` des données du jeu (voir le tableau du
README). Demande ces fichiers aux testeurs, mets ceux de chaque testeur dans un dossier, puis :

```bash
scripts/run_playtests.sh ~/parties-de-lea 0.1.0
```

Le rapport est écrit dans `docs/playtest-report.md`, avec les mêmes tableaux que [balance-report.md](balance-report.md)
(celui du bot) : on peut les comparer ligne à ligne.

Sur Android, les fichiers sont dans le stockage privé de l'application. Avec un APK de debug et le téléphone branché
(débogage USB) :

```bash
adb exec-out run-as org.stackandride.game tar -c -C files runs > runs.tar
```

puis `tar -xf runs.tar` donne le dossier `runs`.

## Ce qu'il faut regarder

Dans le rapport :

- **Victoires par profil** : le bot gagne 51 à 59 % de ses parties. Un humain qui découvre devrait perdre ses
  premières parties, puis gagner de plus en plus souvent. Un profil qui ne gagne jamais (ou toujours) est à revoir.
- **Soir de la fin de partie** : des défaites très tôt (soir 1 ou 2) découragent ; des défaites toutes au soir 6
  rendent les premiers soirs sans enjeu.
- **Gains comparés au loyer** : le loyer doit peser sans étouffer. Si le portefeuille gonfle soir après soir, la
  boutique n'a plus d'intérêt et le loyer non plus.
- **Taux d'acceptation final** : s'il s'effondre, ignorer les propositions coûte trop cher ; s'il reste à 100 %,
  il ne sert à rien.
- **Secousses** : quelle source abîme le plus de plats (pavés, Sprint, Scooter), et les plats écrasés à la retombée.

En regardant jouer (ou en demandant aux testeurs) :

- Ce qui n'a pas été compris (une règle, un bouton, un message). Ce qui a été cherché sans être trouvé.
- Le sac sur téléphone : la taille des cases, le double toucher (voir, puis lâcher).
- Le moment où la partie devient ennuyeuse ou injuste, et pourquoi.
- La durée d'une partie complète.

Les points ouverts de [game-design.md](game-design.md) (§13) sont à confirmer ou à écarter avec ces retours.
