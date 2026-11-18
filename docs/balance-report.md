# Rapport d'équilibrage

Généré par `scripts/run_sim.sh 200 1` : ne pas modifier à la main.

- 200 parties par profil, graines 1 à 200 (les mêmes quartiers pour chaque profil).
- Joueur : le bot « raisonnable » de `sim/bot.gd` (une stratégie simple et gourmande, pas optimale).
  Ses résultats donnent des tendances, pas la difficulté ressentie par un humain.

## Résultats par profil

| Profil | Victoires | Défaites (loyer) | Défaites (note) | Bloquées | Taux d'acceptation final |
|---|---|---|---|---|---|
| combo | 59 % | 16 % | 26 % | 0 | 71 % |
| darling | 51 % | 3 % | 47 % | 0 | 76 % |
| mule | 56 % | 17 % | 27 % | 0 | 69 % |
| sprinter | 51 % | 33 % | 16 % | 0 | 67 % |

## Soir où la partie se termine

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 3 % | 6 % | 7 % | 6 % | 7 % | 73 % |
| darling | 4 % | 11 % | 13 % | 8 % | 5 % | 60 % |
| mule | 3 % | 8 % | 6 % | 4 % | 9 % | 73 % |
| sprinter | 3 % | 4 % | 4 % | 7 % | 12 % | 70 % |

## Gains moyens par soir comparés au loyer

Moyenne sur les parties qui ont joué ce soir jusqu'au bout (entre parenthèses : leur nombre).

|  | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| Loyer | 45 € | 60 € | 80 € | 100 € | 120 € | 140 € |
| combo | 94 € (197) | 102 € (187) | 117 € (178) | 128 € (163) | 129 € (151) | 123 € (141) |
| darling | 107 € (193) | 123 € (175) | 151 € (148) | 166 € (132) | 169 € (122) | 172 € (113) |
| mule | 95 € (197) | 100 € (184) | 118 € (172) | 116 € (162) | 117 € (154) | 120 € (139) |
| sprinter | 86 € (198) | 91 € (192) | 104 € (182) | 113 € (169) | 119 € (159) | 120 € (137) |

## Portefeuille moyen après le loyer

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 49 € (197) | 88 € (187) | 111 € (178) | 122 € (163) | 118 € (151) | 101 € (141) |
| darling | 62 € (193) | 116 € (175) | 156 € (148) | 184 € (132) | 199 € (122) | 212 € (113) |
| mule | 50 € (197) | 87 € (184) | 111 € (172) | 111 € (162) | 102 € (154) | 87 € (139) |
| sprinter | 41 € (198) | 72 € (192) | 90 € (182) | 94 € (169) | 89 € (159) | 80 € (137) |

## Note moyenne en fin de soir

| Profil | Soir 1 | Soir 2 | Soir 3 | Soir 4 | Soir 5 | Soir 6 |
|---| --- | --- | --- | --- | --- | --- |
| combo | 4.8 | 4.7 | 4.7 | 4.7 | 4.8 | 4.7 |
| darling | 4.7 | 4.6 | 4.7 | 4.7 | 4.7 | 4.6 |
| mule | 4.8 | 4.7 | 4.7 | 4.7 | 4.7 | 4.7 |
| sprinter | 4.9 | 4.8 | 4.7 | 4.7 | 4.7 | 4.7 |

## Livraisons

| Profil | Livraisons par partie | Parfaites | En retard | Abîmées | Annulations par partie | Non livrées par partie |
|---|---|---|---|---|---|---|
| combo | 43.4 | 83 % | 2 % | 15 % | 0.3 | 2.6 |
| darling | 39.9 | 87 % | 2 % | 12 % | 0.2 | 2.5 |
| mule | 43.0 | 83 % | 2 % | 15 % | 0.3 | 2.6 |
| sprinter | 41.5 | 89 % | 2 % | 9 % | 0.5 | 2.8 |

## Secousses

Par partie : nombre de secousses et de plats abîmés, selon la source.

| Profil | paved | scooter | sprint | Écrasés |
|---|---|---|---|---|
| combo | 9.3 (4.6 abîmés) | 4.3 (0.5 abîmés) | 11.7 (1.9 abîmés) | 0.1 |
| darling | 7.3 (3.1 abîmés) | 5.3 (0.4 abîmés) | 10.9 (1.5 abîmés) | 0.1 |
| mule | 8.7 (4.8 abîmés) | 4.2 (0.5 abîmés) | 11.4 (1.8 abîmés) | 0.1 |
| sprinter | 8.8 (3.9 abîmés) | 0.0 (0.0 abîmés) | 0.0 (0.0 abîmés) | 0.1 |

