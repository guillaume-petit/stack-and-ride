# Conception du jeu

Ce document décrit **toutes les règles et tous les chiffres** du jeu, tels qu'ils fonctionnent dans le
prototype jouable (`docs/prototype/dernier-kilometre.html`, à ouvrir dans un navigateur).
C'est la référence pour porter les règles dans `core/` (itérations 1 à 3).

- En cas de doute, **ce document fait foi**. Si le prototype dit autre chose, c'est un écart à signaler.
- Les chiffres sont un **premier jet non équilibré**. Ils seront ajustés avec le bot de simulation (itération 3) :
  il faut donc les mettre dans des données ou des constantes faciles à modifier, jamais en dur au milieu du code.
- Les identifiants entre crochets (`[pizza]`) sont ceux à utiliser dans le code et les fichiers de données.
- Dans le prototype, le jeu s'appelle encore « Dernier Kilomètre » ; le nom retenu est **Stack & Ride**.

## 1. Le concept

Tu es livreur à vélo pour **Grailleo**, une appli de livraison fictive. Une partie dure **6 soirs** de **10 tours**.
Chaque soir, tu acceptes des courses proposées par l'appli, tu traces ton trajet dans le quartier avec des cartes
de déplacement, tu ranges les plats dans un sac en grille sans les abîmer, et tu dois payer ton loyer à la fin de la soirée.

Trois systèmes s'emboîtent :
- **Quoi livrer** : les propositions de l'appli et le taux d'acceptation.
- **Comment se déplacer** : un paquet de cartes à double tranchant.
- **Comment transporter** : un sac avec gravité, plats fragiles, chaud et froid, et secousses.

**Conditions de défaite** : la note passe sous **4,0 étoiles**, ou le loyer ne peut pas être payé.
**Victoire** : terminer le 6ᵉ soir en ayant payé le loyer avec une note d'au moins 4,0.

## 2. Valeurs de départ

| Élément | Valeur |
|---------|--------|
| Note | 5,0 étoiles (bornée entre 0 et 5, arrondie au dixième) |
| Taux d'acceptation | 100 % (borné entre 0 et 100) |
| Portefeuille | 0 € |
| Sac | 4 colonnes × 3 rangées |
| Paquet de départ | 3 × Pédaler, 2 × Pédaler fort, 2 × Feu orange, 1 × Sprint, 1 × Coup de fil, 1 × Café serré |
| Courses en cours au maximum | 4 |
| Soirs / tours par soir | 6 / 10 |

## 3. Le quartier

> **Écart volontaire avec le prototype.** Le prototype utilise une grille de 8 × 8 cases où le livreur traverse
> les maisons et les restaurants. Le jeu utilise à la place un plan de rues entre des pâtés de maisons
> (décision du 17/11/2026). Les chiffres ci-dessous sont un premier jet à rééquilibrer avec le bot.

- Le quartier est une grille de **7 × 6 carrefours** (7 colonnes, 6 rangées), donc **6 × 5 pâtés de maisons**.
  Deux carrefours voisins (gauche, droite, haut, bas) sont reliés par un **tronçon de rue** (71 tronçons en tout).
- Le livreur se tient toujours **sur un carrefour**.
- **Lieux** : chaque lieu est un bâtiment posé dans un coin d'un pâté de maisons, qui donne sur le carrefour de ce coin.
  Être sur ce carrefour, c'est être chez lui. Un carrefour porte **au plus un lieu**.
  - Le **point de départ** `[base]` est au carrefour colonne 3, rangée 3 (en partant de 0). Le livreur y revient au début de chaque soir.
  - **3 restaurants**, de types différents, tirés parmi les 5 types (voir §8), sur des carrefours tirés au hasard ;
  - **12 maisons de clients**, numérotées de 1 à 12, sur des carrefours tirés au hasard ;
  - les autres carrefours n'ont pas de lieu.
- **Rues** : chaque tronçon est tiré au hasard parmi :
  - **7 chantiers** `[work]` : tronçons barrés, infranchissables ;
  - **6 rues pavées** `[pave]` : tronçons franchissables, mais ils secouent le sac (voir §6.6) ;
  - le reste : des rues normales.
- **Contrainte** : tous les carrefours doivent être accessibles depuis le point de départ.
  Si le tirage ne le permet pas, on recommence (200 essais au maximum).
- **Déplacements** : de carrefour en carrefour, le long des rues, **1 pas par tronçon**.
- **Distance** : le plus court chemin en pas (parcours en largeur), sans emprunter les chantiers.
- **Trajet** : le livreur suit un plus court chemin. Entre plusieurs chemins de même longueur, il prend celui qui
  emprunte le moins de rues pavées (décision du 18/11/2026). Pour éviter des pavés au prix de pas en plus, le joueur
  s'arrête en route.

## 4. Un tour de jeu

1. **Début du tour** : la main est complétée à **4 cartes** ; les propositions de l'appli sont complétées (voir §5).
2. Le joueur fait, dans l'ordre qu'il veut :
   - accepter ou refuser des propositions ;
   - jouer des cartes (au plus **2 cartes non gratuites** par tour, 3 avec la Batterie longue durée) ;
   - se déplacer en dépensant ses pas ;
   - prendre un plat au restaurant et le ranger dans le sac ;
   - réorganiser le sac.
3. **Fin du tour** (bouton) :
   - impossible tant qu'un plat est posé « à côté du sac » (voir §6.7) ; un plat en main venant du sac ou du restaurant y est remis automatiquement ;
   - chaque proposition ignorée fait perdre **5 points** de taux d'acceptation, puis les propositions disparaissent ;
   - le délai de chaque course acceptée baisse de 1 ; une course dont le délai passe **sous −2** est annulée par le client
     (voir §7.4) ;
   - les pas non utilisés sont perdus, le compteur de cartes jouées revient à 0 ;
   - si la note est sous 4,0 : défaite ;
   - après le 10ᵉ tour : fin du soir (voir §9).

Les cartes non jouées **restent en main** d'un tour à l'autre.

## 5. Les propositions de l'appli

### 5.1 Nombre de propositions

À chaque début de tour, l'appli complète la liste jusqu'à :
- **2 propositions** les soirs 1 et 2, **3** à partir du soir 3 ;
- **+1** les soirs de pluie et de match.

### 5.2 Contenu d'une proposition

- Un **restaurant** tiré au hasard parmi ceux du quartier.
- **Commande groupée** : probabilité **22 %** (**50 %** un soir de match). Elle contient **2 plats** du même restaurant
  pour **2 clients** ; le second client est tiré parmi les 3 clients libres les plus proches du premier (distance de Manhattan,
  égalités départagées dans l'ordre de lecture). Sinon, 1 plat pour 1 client.
  S'il n'y a pas de second client libre, la proposition devient une commande simple, **sans** le × 1,3 de la paie
  (précision du 18/11/2026 ; le prototype garde le × 1,3).
- Les clients sont tirés parmi ceux qui n'ont ni course en cours ni proposition en attente.
- Chaque plat est tiré dans la liste du restaurant (voir §8 ; un plat présent deux fois dans la liste est deux fois plus probable).
- **Modificateurs** (tirés indépendamment) :
  - **Urgent** : 22 % ;
  - **5ᵉ étage** : 20 % ;
  - **VIP** : 18 %, seulement si le taux d'acceptation est d'au moins 70 % ; avec le Badge Superlivreur, 30 % et sans condition de taux.

### 5.3 Délai et paie, pour chaque plat

Avec `d` = distance du restaurant au client :

- **Délai** (en tours) = `arrondi_sup(d / 3) + 3`
  - Urgent : `max(2, délai − 2)` ;
  - Grève des transports : `+2` ;
  - Canicule, plat froid : `max(2, délai − 1)`.
- **Paie** = `(nombre de cases du plat × 3 + 2 + arrondi_sup(d / 2))`, multipliée par :
  - le multiplicateur d'acceptation `0,6 + 0,4 × taux / 100` ;
  - × 2 si urgent ;
  - × 1,3 si commande groupée ;
  - × 1,3 un soir de pluie ;
  - × 1,5 pour un plat froid un soir de canicule ;
  - puis arrondie à l'entier le plus proche.

### 5.4 Accepter, refuser, ignorer

| Action | Taux d'acceptation | Effet |
|--------|--------------------|-------|
| Accepter | +5 (max 100) | Chaque plat devient une course « à récupérer » au restaurant. Impossible si on dépasse 4 courses en cours. Avec le Sac isotherme pro, chaque course reçoit +1 tour de délai. |
| Refuser | −10 | La proposition disparaît. |
| Ignorer (fin du tour) | −5 par proposition | Elles disparaissent. |

## 6. Le sac

### 6.1 Principe

Le sac est vu **de face** : une grille de colonnes et de rangées, la rangée du bas étant le fond.
Chaque plat a une **forme** (voir §8) que le joueur peut faire pivoter d'un quart de tour avant de la poser.

### 6.2 Poser un plat

Le joueur choisit une **colonne** : le plat est lâché depuis le haut et **tombe** jusqu'à toucher le fond ou un autre plat.

- La colonne d'ancrage est `min(colonne choisie, largeur du sac − largeur de la forme)`.
- Si la forme ne rentre pas en haut de cette colonne : impossible (« plus de place »).
- **Fragile** : la pose est refusée si une case du plat se retrouve **juste au-dessus** d'une case d'un plat fragile.
- **Chaud et froid** : la pose est refusée si une case d'un plat chaud touche (côté par côté, pas en diagonale)
  une case d'un plat froid, et inversement. Les plats ni chauds ni froids n'ont pas de contrainte.
  Le Séparateur isotherme supprime cette règle.

### 6.3 Reprendre un plat

On peut reprendre en main un plat déjà rangé **seulement si aucun autre plat n'est posé dessus**
(aucune case d'un autre plat juste au-dessus d'une de ses cases). Annuler remet le plat exactement à sa place.
Si, entre-temps, un autre plat a quitté le sac et que cette place n'est plus libre, ne repose plus sur rien
ou enfreint une règle de pose, le plat est posé à côté du sac à la place (ajout du 17/11/2026, cas non prévu par le prototype).

### 6.4 Plat calé

Un plat est **calé** s'il a au moins une case bloquée **à gauche** (paroi ou autre plat) **et** au moins une case bloquée
**à droite** (paroi ou autre plat). Les plats non calés sont signalés au joueur.

### 6.5 Secousse

Lors d'une secousse, chaque plat **non calé** et pas encore abîmé devient **abîmé** (une seule fois).
- Avec les Sangles, seuls les plats fragiles peuvent être abîmés.
- La carte Caler le sac annule la **prochaine** secousse du tour (une seule). Si aucune secousse n'a lieu, l'effet se perd en fin de tour.
- Les plats au porte-gobelet et ceux posés à côté du sac ne sont jamais secoués.

### 6.6 Sources de secousse

- Jouer **Sprint** ou **Scooter de prêt** (sauf avec le profil Sprinteur).
- Un déplacement qui emprunte au moins un **tronçon pavé** : **une seule** secousse par déplacement,
  au premier tronçon pavé emprunté. La Fourche suspendue supprime cette source.

### 6.7 Retombée et écrasement

Quand un plat quitte le sac (livraison ou annulation), les plats qui ne reposent plus sur rien **retombent** :
- chaque plat tombe d'un bloc, en gardant sa forme ;
- on traite les plats du plus bas au plus haut, et on recommence jusqu'à ce que plus rien ne bouge ;
- après la chute, tout plat **fragile** sur lequel un autre plat est posé est **écrasé** (il devient abîmé).

### 6.8 À côté du sac

Pour réorganiser, le joueur peut **poser un plat à côté du sac** (venant du sac ou du restaurant), puis le reprendre plus tard.
- Plusieurs plats peuvent être posés à côté.
- Tant qu'un plat est à côté ou en main, **impossible de se déplacer ou de finir le tour**.
- Un plat posé à côté n'est pas livré en passant chez le client.

### 6.9 Porte-gobelet

Avec cet équipement, un **soda** pris au restaurant va directement dans un support à part : il ne prend aucune case
et n'est jamais secoué.

## 7. Les courses et les livraisons

### 7.1 États d'une course

`à récupérer` → (le livreur est au carrefour du restaurant et la prend) → `en main` → `dans le sac` ou `à côté du sac` → livrée.

### 7.2 Livrer

La livraison est **automatique** quand le livreur est au carrefour du client avec la course **dans le sac** :
en arrivant au carrefour, en rangeant le plat sur place ou en jouant une carte sur place.

> **Écart volontaire avec le prototype** (décision du 17/11/2026). On ne livre qu'au carrefour où le trajet **se termine** :
> passer chez un client sans s'y arrêter ne livre pas. Le joueur peut arrêter son trajet chez un client avant d'avoir
> dépensé tous ses pas, mais **toute livraison remet les pas restants à 0** (une carte jouée ensuite redonne des pas).
> Le prototype livrait à chaque carrefour traversé.

**5ᵉ étage** : la livraison demande au moins **1 pas** disponible. Sans pas disponible, elle attend (un message le signale une fois).

### 7.3 Résultat d'une livraison

Les cas sont évalués dans cet ordre :

| Cas | Paie | Note |
|-----|------|------|
| En retard (délai < 0) | `arrondi_sup(paie / 2)`, pas de pourboire | −0,3 (VIP : −0,5) |
| Plat abîmé | paie, pas de pourboire | −0,2 (VIP : −0,5) |
| Parfaite | paie + pourboire + primes | +0,1 (VIP : +0,2) |

- **Pourboire** = délai restant × 2 si VIP × 2 si profil Chouchou.
- **Primes** : +2 € avec le Compteur de primes ; profil Roi du groupé : +3 € × nombre de livraisons parfaites déjà
  faites **dans le même tour**.
- Profil Chouchou : chaque perte de note ci-dessus est aggravée de 0,1.
- Le montant va dans le portefeuille.

### 7.4 Annulation

Quand le délai d'une course passe sous −2 en fin de tour, le client annule : la course disparaît (le plat quitte le sac,
avec retombée), note **−0,5** (Chouchou : −0,6).

## 8. Le contenu

### 8.1 Plats

Formes en coordonnées `(colonne, rangée)`, rangée 0 en haut de la forme.

| Id | Nom | Forme | Cases | Température | Fragile |
|----|-----|-------|-------|-------------|---------|
| `burger` | Menu burger | barre horizontale de 2 | 2 | chaud | non |
| `soda` | Soda | 1 case | 1 | — | oui |
| `pizza` | Pizza | carré 2 × 2 | 4 | chaud | non |
| `sushi` | Plateau sushi | barre horizontale de 3 | 3 | froid | oui |
| `poke` | Poke bowl | barre horizontale de 2 | 2 | froid | non |
| `tacos` | Tacos XL | L : (0,0) (1,0) (0,1) | 3 | chaud | non |
| `glace` | Pot de glace | 1 case | 1 | froid | oui |
| `family` | Menu famille | rectangle 3 × 2 | 6 | chaud | non |

### 8.2 Restaurants

| Id | Nom | Plats proposés (tirage) |
|----|-----|--------------------------|
| `burger` | Smash Corner | burger, burger, soda, family |
| `pizza` | Pizzeria Nonna | pizza, pizza, soda |
| `sushi` | Maki Express | sushi, poke, poke |
| `tacos` | Tacos Loco | tacos, tacos, soda |
| `glacier` | Glacier Polaire | glace, glace, poke |

### 8.3 Cartes

Les cartes **gratuites** ne comptent pas dans la limite de cartes par tour.

| Id | Nom | Pas | Effet |
|----|-----|-----|-------|
| `ped2` | Pédaler | 2 | — |
| `ped3` | Pédaler fort | 3 | — |
| `orange` | Feu orange | 2 | +2 pas si une carte non gratuite a déjà été jouée ce tour |
| `sprint` | Sprint | 5 | Secousse ; ajoute une Fatigue à la défausse |
| `scooter` | Scooter de prêt | 6 | Secousse |
| `wrong` | Contresens | 3 | Les tronçons en chantier sont franchissables jusqu'à la fin du tour ; note −0,1 (sauf Gilet fluo) |
| `kebab` | Pause kebab | 0 | Pioche 3 cartes |
| `call` | Coup de fil | 0 | Toutes les courses en cours gagnent +1 tour de délai |
| `coffee` | Café serré | 0 | **Gratuite.** Pioche 2 cartes |
| `strap` | Caler le sac | 0 | **Gratuite.** La prochaine secousse du tour n'abîme rien |
| `fatigue` | Fatigue | 0 | Ne fait rien. La jouer compte comme une carte du tour et la retire du jeu. Disparaît en fin de soir. |

**Calcul des pas d'une carte** (cartes qui donnent des pas) :
`pas de base` (+2 Feu orange si applicable) (+1 Vélo électrique) (−1 soir de pluie) (−1 profil Mule si au moins 3 plats
dans le sac), avec un **minimum de 1**.

**Paquet** : pioche, défausse et main. Quand la pioche est vide, la défausse est mélangée pour former une nouvelle pioche.
Au début de chaque soir, la pioche est reconstituée à partir du paquet permanent (les Fatigues disparaissent), la main est vidée puis complétée.

### 8.4 Équipements

Achetables en boutique, une seule fois chacun. Ils sont permanents.

| Id | Nom | Effet | Prix |
|----|-----|-------|------|
| `separator` | Séparateur isotherme | Le chaud et le froid peuvent se toucher | 18 € |
| `cupholder` | Porte-gobelet | Les sodas ne prennent pas de place et ne sont jamais secoués | 12 € |
| `straps` | Sangles | Les secousses n'abîment que les plats fragiles | 20 € |
| `shocks` | Fourche suspendue | Les pavés ne secouent plus | 16 € |
| `battery` | Batterie longue durée | 3 cartes par tour au lieu de 2 | 30 € |
| `ebike` | Vélo électrique | +1 pas sur chaque carte qui donne des pas | 28 € |
| `thermos` | Sac isotherme pro | +1 tour de délai sur chaque course acceptée | 16 € |
| `gilet` | Gilet fluo | Le Contresens ne coûte plus d'étoile | 10 € |
| `badge` | Badge Superlivreur | VIP à 30 %, même avec un taux d'acceptation bas | 14 € |
| `bonus` | Compteur de primes | +2 € par livraison parfaite | 18 € |

### 8.5 Autres récompenses

| Id | Nom | Effet | Prix en boutique | Condition |
|----|-----|-------|------------------|-----------|
| `wide` | Sac plus large | +1 colonne | 22 € | largeur < 6 |
| `tall` | Sac plus haut | +1 rangée | 24 € | hauteur < 5 |
| `trim` | Désencombrer | Retire une carte Pédaler du paquet | 8 € | le paquet contient un Pédaler |
| `resto` | Nouveau partenaire | Un restaurant d'un type absent ouvre sur un carrefour sans lieu (pas celui du livreur) | — (récompense gratuite uniquement) | il reste un type absent |

Prix des cartes en boutique : Scooter 12 €, Sprint 8 €, Coup de fil 8 €, Contresens 7 €, Feu orange 7 €, Café serré 7 €,
Pause kebab 6 €, Caler le sac 6 €.

## 9. Fin de soirée

Dans l'ordre :
1. Chaque course acceptée non livrée : note **−0,2**.
2. **Loyer** prélevé dans le portefeuille : **25, 35, 48, 62, 78, 95 €** pour les soirs 1 à 6.
   S'il manque de l'argent : le portefeuille tombe à 0 et c'est la **défaite** (loyer impayé).
3. Si la note est sous 4,0 : **défaite**.
4. Après le 6ᵉ soir : **victoire**.
5. Sinon :
   - **Récompense gratuite** : choix de 1 parmi 3, tirées parmi les cartes, `wide`, `tall`, `trim` et `resto`
     (en respectant les conditions, sans les équipements) ;
   - l'**événement du lendemain** est tiré (jamais « Soir calme ») ;
   - **Boutique** (voir §10) ;
   - début du soir suivant.

Au début de chaque soir : le livreur revient au point de départ, le sac et les courses sont vidés, la pioche est reconstituée,
l'événement s'applique.

## 10. La boutique

Elle propose, avec l'argent du portefeuille :
- **2 équipements** non possédés ;
- **1 amélioration de sac** (`wide` ou `tall`), si possible ;
- **3 cartes** ;
- **Désencombrer**, si possible.

Chaque article ne s'achète qu'une fois par visite. La boutique affiche le loyer du lendemain et l'événement du lendemain,
pour que le joueur arbitre entre acheter et garder de quoi payer.

## 11. Les profils

Choisis en début de partie, pour toute la partie.

| Id | Nom | Avantage | Contrepartie |
|----|-----|----------|--------------|
| `mule` | La mule | Sac de 5 colonnes | −1 pas par carte dès que 3 plats sont dans le sac |
| `sprinter` | Le sprinteur | Ses cartes ne secouent jamais le sac ; un Sprint de plus dans le paquet | Sac de 3 colonnes |
| `darling` | Le chouchou | Pourboires doublés | Chaque problème (retard, plat abîmé, annulation) coûte 0,1 étoile de plus |
| `combo` | Le roi du groupé | +3 € par livraison parfaite déjà faite dans le même tour | — |

## 12. Les événements

Le soir 1 est toujours calme. L'événement des soirs suivants est tiré à la fin du soir précédent et annoncé en boutique.

| Id | Nom | Effet |
|----|-----|-------|
| `calm` | Soir calme | Aucun |
| `rain` | Soir de pluie | +1 proposition par tour, paie × 1,3, −1 pas par carte |
| `match` | Soir de match | +1 proposition par tour, commandes groupées à 50 % |
| `strike` | Grève des transports | +2 tours de délai sur toutes les courses proposées |
| `works` | Nuit de travaux | Les chantiers sont redistribués sur les tronçons normaux (pas les pavés), en gardant le quartier entièrement accessible |
| `heat` | Canicule | Plats froids : paie × 1,5, délai −1 (minimum 2) |

## 13. Points ouverts

- L'équilibrage : loyers, paies, probabilités, prix. Le rapport du bot est dans [balance-report.md](balance-report.md)
  (`scripts/run_sim.sh`). Premiers constats (18/11/2026, 200 parties par profil, bot simple) :
  - **Le loyer ne pèse presque pas** : le bot gagne 107 à 219 € par soir pour des loyers de 25 à 95 €, et finit avec
    240 à 540 €. Moins de 2 % des défaites viennent du loyer. Les paies sont trop hautes ou les loyers trop bas, et la
    boutique devient vite sans arbitrage.
  - **La note décide de tout** : 13 à 51 % de défaites sur la note, souvent dans les premiers soirs.
  - **Le taux d'acceptation s'effondre** (2 à 14 % en fin de partie) : 2 à 4 propositions par tour, −5 pour chacune
    ignorée, +5 seulement pour une acceptée. Impossible de le maintenir sans tout accepter, donc les VIP disparaissent
    et la paie tombe à × 0,6.
  - **Profils déséquilibrés** : le sprinteur gagne 86 % des parties (ses cartes ne secouent jamais), le chouchou 49 %
    (ses pénalités le font perdre tôt, mais il gagne le plus d'argent).
  - **Les pavés sont la première source de plats abîmés** (environ 3 par partie). Depuis, à longueur égale, le trajet
    évite les pavés (§3).
- Les secousses peuvent être très punitives avec un sac de 4 colonnes : à surveiller.
- L'écrasement des fragiles lors de la retombée est peut-être trop sévère (le bot n'en subit presque pas : 0,1 par partie).
- Sur téléphone, la taille des cases du sac (itération 5).
- Le plan de rues (§3) change les distances par rapport au prototype : délais et paies (§5.3) à revérifier avec le bot.
- Idée pour après le MVP : des rues à sens unique, que la carte Contresens permettrait de prendre à l'envers.
- Le prototype ne contient ni sauvegarde, ni progression entre les parties.
