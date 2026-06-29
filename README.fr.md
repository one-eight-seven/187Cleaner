# [187] Cleaner

> Vous êtes la seule partie neutre de Los Santos à avoir pénétré dans chaque scène de crime — et le fait que vous soyez encore en vie signifie que vous avez appris exactement quelle vérité dire à qui.

Script de nettoyage clandestin de scènes de crime avec un système de chaleur, deux jauges de réputation et des mécaniques de décision sur les preuves. Les joueurs sont des prestataires anonymes engagés pour éliminer les traces avant l'arrivée de la police.

---

## Aperçu

| Panneau d'évaluation de scène | Décision sur les preuves | Écran de paiement |
|-------------------------------|--------------------------|-------------------|
| Jauge de chaleur en direct, liste de tâches à cocher, minuteur affiché pendant chaque contrat | Choisissez de détruire une preuve pour gagner de la Réputation ou de la garder pour la vendre au receleur, au risque d'être trahi | Écran de style scaleform avec paiement de base, bonus temps/fantôme et total |

---

## Dépendances

| Dépendance | Requise |
|------------|---------|
| `ox_lib` | Oui |
| `oxmysql` | Oui |
| ESX / QBCore / Standalone | L'un des trois |

---

## Installation

1. Placer `187Cleaner` dans `resources/[187]/`
2. Ajouter `ensure 187Cleaner` dans votre `server.cfg`
3. Importer `database.sql` dans votre base de données MySQL
4. Définir `Config.Framework` dans `config.lua` sur `'esx'`, `'qbcore'` ou `'standalone'`
5. Modifier si nécessaire le fichier de pont framework correspondant à votre serveur

---

## Fonctionnalités

- **Système de contrats anonymes** — Les contrats arrivent sous forme de notifications style téléphone toutes les 2 minutes pour les joueurs éligibles ; Accepter (Y) ou Refuser (N) sans bloquer le jeu
- **Interface d'évaluation de scène** — Panneau non-bloquant affichant la liste des tâches, la jauge de chaleur en direct et le minuteur pendant l'intervention
- **Chaîne d'élimination des corps** — Emballer chaque corps sur la scène avec une barre de progression, puis transporter les sacs vers l'un des quatre sites d'élimination (incinérateur, entrepôt de containers, falaise, déchetterie)
- **Nettoyage des surfaces** — Mares de sang, éclats de verre et déversements chimiques sont marqués ; nettoyer chacun avec une animation chronométrée
- **Système de décision sur les preuves** — Chaque élément de preuve déclenche une fenêtre modale de 15 secondes : Détruire pour la Réputation Cleaner ou Garder pour la revente au receleur avec un risque de trahison configurable
- **Système de chaleur** — La chaleur monte toutes les 10 secondes en zone de scène ; les tâches accomplies la réduisent ; atteindre le maximum déclenche une fouille policière ; quitter la zone pendant 90 secondes réduit la chaleur de 40%
- **Complication du témoin** — Chance aléatoire par contrat ; un témoin apparaît près de la scène ; payer (déduit du paiement), signaler au client (sans coût, risque de réputation) ou ignorer (chaleur +30, police plus rapide)
- **Receleur de preuves** — Un contact rotatif achète les preuves conservées à 1,5× la valeur de base ; l'emplacement change chaque jour ; chaque vente comporte un risque de trahison
- **Deux jauges de réputation** — Réputation Cleaner (loyauté envers les clients) et Réputation Receleur (réseau d'informateurs) en tension ; haute Réputation Cleaner débloque les contrats de tier 3
- **Boutique d'équipement** — Trois niveaux d'amélioration au point de contact rotatif : Tier 1 (animations plus rapides), Tier 2 (scanner UV révèle les preuves cachées), Tier 3 (chaleur –40%)
- **Système de bonus chronométrés** — Bonus Temps (+25%) pour terminer avant la fin de la fenêtre ; Bonus Fantôme (+50%) pour terminer en moins de la moitié du temps
- **Statistiques à vie** — `/cleanerstats` affiche contrats, gains, corps, ratios de preuves, meilleur temps, titres et les deux jauges de réputation
- **Commandes admin** — `/cleaner:spawnscene [tier]` génère une scène à votre position ; `/cleaner:resetrep [id]` réinitialise les stats d'un joueur

---

## Fonctionnement

### Cycle de vie d'un contrat

```
Notification de contrat reçue (Y/N, fenêtre 60s)
  ↓ Acceptation
Marqueur de scène affiché → joueur se déplace
  ↓ Zone de scène (~35m de rayon)
Panneau d'évaluation s'ouvre (non-bloquant)
  Tâches :
    ├── Emballer chaque corps (touche E, barre de progression 7s)
    ├── Nettoyer chaque surface (touche E, 3–7s)
    └── Collecter chaque preuve (touche E → modal 15s : Détruire ou Garder)
  Chaleur monte toutes les 10s en zone
  Tâches accomplies réduisent la chaleur
  ↓ Toutes les tâches terminées
Phase élimination → marqueur vers le site
  Joueur conduit jusqu'au site
  Touche E → animation d'élimination 8s + effet de particules
  ↓ Élimination terminée
Écran de paiement → base + multiplicateur → argent accordé
Temps de récupération : Config.ContractCooldown (défaut 600s)
```

### Système de chaleur

- La chaleur commence à 0 à l'acceptation du contrat
- +10 chaleur toutes les `HeatTickRate` secondes (défaut 10s)
- –12 par corps emballé, –8 par surface nettoyée, –5 par preuve collectée
- À 80% : notification d'avertissement
- À 100% : fouille policière, le joueur doit quitter la zone
- 90 secondes après le départ : la chaleur tombe à 60% de sa valeur actuelle

### Réputation

- **Réputation Cleaner** : gagnée en détruisant des preuves (+5 chacune). À 150 → contrats Tier 2. À 500 → contrats Tier 3.
- **Réputation Receleur** : gagnée en vendant des preuves (+3 chacune) et en complétant des contrats.
- Trois trahisons en 24 heures = blacklist de 24h pour le tier concerné.

---

## Configuration

| Clé | Défaut | Description |
|-----|--------|-------------|
| `Config.Framework` | `'esx'` | Pont framework à utiliser |
| `Config.ContractCooldown` | `600` | Secondes entre deux contrats par joueur |
| `Config.PayoutTier` | `{5000, 12000, 25000}` | Paiement de base par tier avant bonus |
| `Config.TimeBonusMultiplier` | `1.25` | Multiplicateur si terminé avant la fin de la fenêtre |
| `Config.GhostBonusMultiplier` | `1.50` | Multiplicateur si terminé en moins de la moitié |
| `Config.UpgradePrices` | `{10000, 28000, 55000}` | Prix par niveau de kit |
| `Config.HeatTickRate` | `10` | Secondes par incrément de chaleur |
| `Config.MaxHeat` | `100` | Seuil de chaleur pour la fouille policière |
| `Config.ContractTimeWindows` | `{480, 720, 1080}` | Fenêtre de temps par tier (secondes) |
| `Config.EvidenceBrokerBonus` | `1.5` | Multiplicateur sur la valeur de revente |
| `Config.RepBetrayalChance` | `0.20` | Probabilité qu'une vente soit retracée |
| `Config.WitnessSpawnChance` | `0.35` | Probabilité d'apparition d'un témoin |
| `Config.WitnessPayoffCost` | `500` | Coût pour faire taire un témoin |
| `Config.BlacklistDuration` | `86400` | Durée du blacklist en secondes |

---

## Commandes & Keybinds

| Commande | Permission | Description |
|----------|------------|-------------|
| `/cleanerregister` | Public | S'enregistrer comme cleaner |
| `/cleanerstats` | Public | Ouvrir le panneau de statistiques |
| `/cleaner:spawnscene [tier]` | `187cleaner.admin` | Générer une scène à votre position |
| `/cleaner:resetrep [id]` | `187cleaner.admin` | Réinitialiser les stats d'un joueur |

**Interactions en jeu :**
- `E` — Emballer corps / Nettoyer surface / Collecter preuve / Éliminer sacs / Ouvrir boutique / Contacter receleur
- `Y` — Accepter un contrat entrant
- `N` — Refuser un contrat entrant

---

## Exports

```lua
-- Retourne la Réputation Cleaner du joueur (entier)
exports['187Cleaner']:GetCleanerRep(src)

-- Retourne la Réputation Receleur du joueur (entier)
exports['187Cleaner']:GetBrokerRep(src)

-- Retourne true si le joueur est enregistré
exports['187Cleaner']:IsRegistered(src)
```

---

## Compatibilité framework

| Framework | Statut |
|-----------|--------|
| ESX | Supporté |
| QBCore | Supporté |
| Standalone | Supporté (portefeuille en mémoire) |

---

**187Scripts** — Scripts FiveM de qualité
