# Rapport d'équilibrage

Généré par `scripts/run_sim.sh 200 1` : ne pas modifier à la main.

- 200 parties par profil, graines 1 à 200 (les mêmes quartiers pour chaque profil).
- Joueur : le bot « raisonnable » de `sim/bot.gd` (une stratégie simple et gourmande, pas optimale).
  Ses résultats donnent des tendances, pas la difficulté ressentie par un humain.

## Résultats par profil

| Profil | Victoires | Défaites (loyer) | Défaites (note) | Bloquées | Taux d'acceptation final |
|---|---|---|---|---|---|
| combo | 70 % | 2 % | 29 % | 0 | 3 % |
| darling | 49 % | 1 % | 51 % | 0 | 14 % |
| mule | 64 % | 1 % | 36 % | 0 | 7 % |
| sprinter | 86 % | 2 % | 13 % | 0 | 2 % |

## Soir où la partie se termine

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 4 % | 5 % | 6 % | 5 % | 8 % | 75 % |
| darling | 12 % | 18 % | 7 % | 6 % | 5 % | 54 % |
| mule | 5 % | 9 % | 8 % | 4 % | 5 % | 71 % |
| sprinter | 2 % | 2 % | 3 % | 3 % | 3 % | 89 % |

## Gains moyens par soir comparés au loyer

Moyenne sur les parties qui ont joué ce soir jusqu'au bout (entre parenthèses : leur nombre).

|  | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| Loyer | 25 € | 35 € | 48 € | 62 € | 78 € | 95 € |
| combo | 119 € (195) | 135 € (187) | 150 € (175) | 161 € (168) | 168 € (160) | 169 € (143) |
| darling | 140 € (183) | 166 € (144) | 180 € (130) | 205 € (121) | 217 € (113) | 219 € (104) |
| mule | 118 € (194) | 130 € (179) | 143 € (160) | 153 € (153) | 154 € (147) | 154 € (139) |
| sprinter | 107 € (196) | 121 € (193) | 131 € (190) | 140 € (186) | 149 € (183) | 157 € (175) |

## Portefeuille moyen après le loyer

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 94 € (195) | 142 € (187) | 180 € (175) | 224 € (168) | 279 € (160) | 339 € (143) |
| darling | 115 € (183) | 184 € (144) | 244 € (130) | 330 € (121) | 432 € (113) | 538 € (104) |
| mule | 93 € (194) | 137 € (179) | 174 € (160) | 214 € (153) | 250 € (147) | 286 € (139) |
| sprinter | 82 € (196) | 127 € (193) | 153 € (190) | 178 € (186) | 205 € (183) | 238 € (175) |

## Note moyenne en fin de soir

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 4.7 | 4.7 | 4.7 | 4.8 | 4.7 | 4.7 |
| darling | 4.6 | 4.7 | 4.7 | 4.7 | 4.7 | 4.7 |
| mule | 4.7 | 4.7 | 4.7 | 4.8 | 4.7 | 4.7 |
| sprinter | 4.8 | 4.8 | 4.8 | 4.8 | 4.8 | 4.8 |

## Livraisons

| Profil | Livraisons par partie | Parfaites | En retard | Abîmées | Annulations par partie | Non livrées par partie |
|---|---|---|---|---|---|---|
| combo | 47.8 | 89 % | 1 % | 10 % | 0.2 | 3.2 |
| darling | 38.6 | 89 % | 1 % | 10 % | 0.2 | 2.5 |
| mule | 45.7 | 87 % | 2 % | 11 % | 0.2 | 2.7 |
| sprinter | 50.2 | 93 % | 1 % | 6 % | 0.2 | 3.0 |

## Secousses

Par partie : nombre de secousses et de plats abîmés, selon la source.

| Profil | paved | scooter | sprint | Écrasés |
|---|---|---|---|---|
| combo | 12.1 (3.1 abîmés) | 10.8 (0.5 abîmés) | 12.4 (1.3 abîmés) | 0.1 |
| darling | 8.5 (2.3 abîmés) | 9.5 (0.4 abîmés) | 9.6 (1.1 abîmés) | 0.1 |
| mule | 11.2 (3.6 abîmés) | 10.5 (0.7 abîmés) | 11.8 (1.3 abîmés) | 0.0 |
| sprinter | 13.8 (3.1 abîmés) | 0.0 (0.0 abîmés) | 0.0 (0.0 abîmés) | 0.1 |

