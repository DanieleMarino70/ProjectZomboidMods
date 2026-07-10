# WoW Traits — Project Zomboid Mod
**Build 42.19.0 Compatible**

Aggiunge 14 tratti ispirati alle classi e abilità di World of Warcraft.

---

## 📦 Installazione

1. Copia la cartella `WoWTraits` in:
   ```
   C:\Users\<TuoNome>\Zomboid\mods\
   ```
2. Avvia Project Zomboid
3. Nel menu principale → **Mods** → attiva **WoW Traits**
4. Crea una nuova partita e seleziona i tratti in creazione personaggio

---

## ⚔️ Lista Tratti

I costi seguono la convenzione della Build 42: i tratti positivi **costano** punti.

| Tratto | Classe WoW | Costo | Effetto |
|---|---|---|---|
| **Berserker** | Warrior | 4 | Sotto 30% HP: +30% velocità movimento e attacco |
| **Secondo Respiro** | Warrior | 3 | Sotto 35% HP: rigenera HP lentamente |
| **Muro di Scudi** | Warrior | 3 | Con scudo: -25% danni subiti |
| **Turbine** | Warrior | 3 | 3+ zombie vicini: li fa barcollare (8s cooldown) |
| **Taglia e Affetta** | Rogue | 3 | Colpi consecutivi: +4% velocità attacco per stack (max 5) |
| **Nova di Gelo** | Mage | 3 | 4+ zombie vicini: +50% velocità burst (20s cooldown) |
| **Intelletto Arcano** | Mage | 6 | +2 XP boost su **tutte** le abilità |
| **Immolazione** | Warlock | 3 | Fuoco vicino: rallenta gli zombie nel raggio |
| **Serpente della Morte** | Death Knight | 4 | Kill in mischia: recupera 3 HP |
| **Scudo d'Ossa** | Death Knight | 4 | Dopo 5 kill: -30% danni per 15s |
| **Rilevamento Trappole** | Rogue/Hunter | 2 | +3 XP Furtività/Trappole |
| **Occhio d'Aquila** | Hunter | 2 | +4 XP Mira, +2 XP Ricarica |
| **Carica Ferale** | Druid | 3 | Tasto [F]: burst +80% velocità per 3s (30s cooldown) |
| **Ingegnere** | Goblin Engineer | 3 | XP boost Meccanica/Elettronica/Metallurgia/Falegnameria |

---

## 🎮 Note sui Tratti Attivi

- **Carica Ferale**: premi il tasto **[F]** per attivare il burst di velocità
- **Turbine** e **Nova di Gelo**: si attivano automaticamente quando ci sono abbastanza zombie vicini
- **Immolazione**: funziona in presenza di qualsiasi fonte di fuoco nel raggio d'azione

---

## 🗂️ Struttura File

```
WoWTraits/
└── 42/
    ├── mod.info
    └── media/
        ├── registries.lua                 ← registra i CharacterTrait nel registro B42
        ├── scripts/WoWTraits/traits.txt   ← definizioni character_trait_definition
        └── lua/
            ├── client/WoWTraits_main.lua  ← logica runtime dei tratti
            └── shared/Translate/
                ├── EN/UI.json             ← traduzioni (formato JSON B42)
                └── IT/UI.json
```

---

## 🔧 Compatibilità e Note Tecniche (Build 42.19)

- Testato su Build **42.19.0**
- **Registrazione tratti**: nella B42 i tratti custom vanno prima registrati nel
  registro `character_trait` tramite `media/registries.lua`
  (`CharacterTrait.register("wowtraits:...")`), poi definiti negli script con
  `character_trait_definition` + campo `CharacterTrait = wowtraits:...`.
- **API Lua B42**: `player:hasTrait(CharacterTrait)` (non più stringhe),
  `setMoveSpeed`/`setCombatSpeed` per i buff (Stats:setRunSpeed non esiste più),
  evento `OnWeaponHitCharacter` (non più `OnHitCharacter`),
  `IsoPlayer.getPlayers()` (non più `getActivePlayers()`).
- **Nomi perk B42** negli XPBoosts: `Sneak` (non Sneaking), `Woodwork` (non Carpentry).
- La logica Lua si aggancia a: `OnGameBoot`, `OnPlayerUpdate`,
  `OnWeaponHitCharacter`, `OnZombieDead`, `OnKeyPressed`, `OnPlayerDeath`

---

## 📝 Crediti

Mod creato seguendo le linee guida ufficiali di modding di Indie Stone per Build 42.
Ispirato alle meccaniche di **World of Warcraft** (Blizzard Entertainment).
