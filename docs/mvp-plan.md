# Plan du MVP

**Objectif :** une partie complète de 6 soirs, jouable sur PC et Android, avec les règles du prototype,
une interface propre et des animations de base.

Les règles et les chiffres sont décrits dans [game-design.md](game-design.md) ; le prototype jouable est dans
[prototype/dernier-kilometre.html](prototype/dernier-kilometre.html).

## Dans le MVP

- Le quartier généré (chantiers, pavés) et les déplacements avec des cartes.
- Le sac complet : gravité, fragiles, chaud/froid, secousses, retombée des plats, zone « à côté du sac ».
- Les propositions de l'appli, le taux d'acceptation et les modificateurs (urgent, groupée, VIP, 5ᵉ étage).
- La note, le portefeuille, le loyer, la récompense gratuite et la boutique.
- Les 4 profils, les 6 événements et les équipements du prototype.
- Sauvegarde et reprise de partie, menu principal, options simples.
- Sons et visuels provisoires mais propres.

## Après le MVP

- Progression entre les parties (déblocages).
- Graphismes et musique définitifs.
- Export iOS (Mac et compte développeur Apple nécessaires).
- Traduction anglaise (le système est en place dès le départ, seul le français est rempli).

## Choix techniques

- Godot 4.7, GDScript typé, rendu « Compatibility » (le plus large côté mobile).
- Code en anglais, jeu en français via `i18n/fr.po`.
- Noyau de règles (`core/`) séparé de l'interface (`ui/`), aléatoire à graine.
- Écran en paysage sur PC, en portrait sur téléphone et tablette ; résolution de base 1280×720, mise à l'échelle
  automatique (agrandie selon la densité de l'écran sur mobile).
- Tests avec un petit lanceur maison (`tests/run_tests.gd`), lançable en ligne de commande.

## Itérations

| # | Contenu | À vérifier | Statut |
|---|---------|------------|--------|
| 0 | Socle : projet Godot, dossiers, tests, traduction, écran d'accueil provisoire | Le projet s'ouvre, les tests passent | Fait |
| 1 | Noyau : état de jeu, fichiers de données, génération du quartier, chemins | Tests : quartier connecté, chemins corrects, même graine = même quartier | Fait |
| 2 | Noyau : le sac (toutes ses règles) | Tests sur chaque règle et ses cas limites | Fait |
| 3 | Noyau : déroulé de partie (cartes, propositions, livraisons, note, loyer, boutique, profils, événements) + bot | Tests + premier rapport d'équilibrage | Fait |
| 4 | Interface jouable | Une partie complète sur PC | Fait |
| 5 | Animations, sons provisoires, tactile, export Android | La partie sur téléphone | Fait |
| 5 bis | Interface « plateau » : le plan plein écran, la main en bas, l'appli, le sac et l'historique en fenêtres, portrait sur téléphone | Une partie sur téléphone et sur PC | Fait |
| 6 | Sauvegarde, menus, options, aide au premier lancement, outils d'équilibrage (voir ci-dessous) | Une version à faire tester | En revue |
| 6 bis | Équilibrage fin à partir des parties de test | Les rapports des parties de test et du bot | À faire |

### Itération 6

- **6a, sauvegarde** : la partie est enregistrée après chaque action, sous la forme de sa graine et de la liste des
  actions du joueur (`core/save/run_save.gd`) ; la charger, c'est rejouer ces actions. Une sauvegarde qui ne redonne
  plus la même partie (règles ou chiffres changés entre deux versions) est refusée et effacée, avec un message.
- **6b, menus et options** : menu principal (continuer, nouvelle partie, comment jouer, options, quitter), menu de
  pause (reprendre, comment jouer, options, menu principal, abandonner), options gardées dans `user://settings.cfg`
  (volume, taille de l'interface, plein écran, bulles d'aide).
- **6c, aide au premier lancement** : « Comment jouer » en six pages avant la première partie ; les bulles d'aide déjà
  vues restent vues d'un lancement à l'autre.
- **6d, outils d'équilibrage** : chaque partie terminée est gardée dans `user://runs` ; `scripts/run_playtests.sh` en
  fait un rapport avec les mêmes tableaux que celui du bot. Version du jeu passée à 0.1.0. L'équilibrage fin lui-même
  demande des parties humaines : il devient l'itération 6 bis.

## Risques

- Le sac sur téléphone (cases petites) : depuis l'interface « plateau », il s'ouvre en fenêtre au centre de l'écran,
  cases d'environ 8 mm ; à confirmer en jouant sur un vrai téléphone.
- L'équilibrage : le bot et son rapport sont là (itération 3, voir [balance-report.md](balance-report.md)). Une passe grossière a été faite le 18/11/2026 ; le réglage fin, avec des parties humaines (rapport `scripts/run_playtests.sh`), est l'itération 6 bis.
- Une sauvegarde ne survit pas à un changement de règles ou de chiffres : pendant les tests, une nouvelle version efface
  la partie en cours (les parties terminées, elles, gardent leurs chiffres pour le rapport).
- Sur Android, les parties gardées sont dans le stockage privé de l'application : on ne peut les récupérer qu'avec `adb`
  sur une version de debug (voir [playtest.md](playtest.md)). Un bouton « envoyer mes parties » pourra venir après le MVP.
- L'envie d'ajouter des choses : toute nouvelle idée va dans « Après le MVP », sauf si elle corrige un vrai problème de jeu.
