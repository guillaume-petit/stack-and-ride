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
- Écran en paysage, résolution de base 1280×720, mise à l'échelle automatique.
- Tests avec un petit lanceur maison (`tests/run_tests.gd`), lançable en ligne de commande.

## Itérations

| # | Contenu | À vérifier | Statut |
|---|---------|------------|--------|
| 0 | Socle : projet Godot, dossiers, tests, traduction, écran d'accueil provisoire | Le projet s'ouvre, les tests passent | Fait |
| 1 | Noyau : état de jeu, fichiers de données, génération du quartier, chemins | Tests : quartier connecté, chemins corrects, même graine = même quartier | Fait |
| 2 | Noyau : le sac (toutes ses règles) | Tests sur chaque règle et ses cas limites | Fait |
| 3 | Noyau : déroulé de partie (cartes, propositions, livraisons, note, loyer, boutique, profils, événements) + bot | Tests + premier rapport d'équilibrage | Fait |
| 4 | Interface jouable | Une partie complète sur PC | En revue |
| 5 | Animations, sons provisoires, tactile, export Android | La partie sur téléphone | À faire |
| 6 | Sauvegarde, menus, options, aide au premier lancement, équilibrage | Une version à faire tester | À faire |

## Risques

- Le sac sur téléphone (cases petites) : traité à l'itération 5.
- L'équilibrage : le bot et son rapport sont là (itération 3, voir [balance-report.md](balance-report.md)). Une passe grossière a été faite le 18/11/2026 ; le réglage fin, avec des parties humaines, reste pour l'itération 6.
- L'envie d'ajouter des choses : toute nouvelle idée va dans « Après le MVP », sauf si elle corrige un vrai problème de jeu.
