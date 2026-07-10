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

| Tratto | Classe WoW | Costo | Effetto |
|---|---|---|---|
| **Berserker** | Warrior | -4 | Sotto 30% HP: +30% velocità e attacco |
| **Secondo Respiro** | Warrior | -3 | Sotto 35% HP: rigenera HP lentamente |
| **Muro di Scudi** | Warrior | -3 | Con scudo: -25% danni subiti |
| **Turbine** | Warrior | -3 | 3+ zombie vicini: spinta radiale (8s cooldown) |
| **Taglia e Affetta** | Rogue | -3 | Colpi consecutivi: +4% velocità per stack (max 5) |
| **Nova di Gelo** | Mage | -3 | 4+ zombie vicini: +50% velocità burst (20s cooldown) |
| **Intelletto Arcano** | Mage | -4 | +2% XP su **tutte** le abilità |
| **Immolazione** | Warlock | -3 | Fuoco vicino: rallenta zombie nel raggio del 40% |
| **Serpente della Morte** | Death Knight | -4 | Kill in mischia: recupera 3 HP |
| **Scudo d'Ossa** | Death Knight | -4 | Dopo 5 kill: -30% danni per 15s |
| **Rilevamento Trappole** | Rogue/Hunter | -2 | Raggio visivo +3 tile, +3 XP Sneaking/Trapping |
| **Occhio d'Aquila** | Hunter | -2 | Raggio visivo +5 tile, +4 XP Aiming |
| **Carica Ferala** | Druid | -3 | Tasto [F]: burst +80% velocità per 3s (30s cooldown) |
| **Ingegnere** | Goblin Engineer | -3 | +4 XP Mechanics/Electricity/MetalWelding/Carpentry |

---

## 🎮 Note sui Tratti Attivi

- **Carica Ferala**: premi il tasto **[F]** per attivare il burst di velocità
- **Turbine** e **Nova di Gelo**: si attivano automaticamente quando ci sono abbastanza zombie vicini
- **Immolazione**: funziona in presenza di qualsiasi fonte di fuoco nel raggio d'azione

---

## 🗂️ Struttura File

```
WoWTraits/
├── 42/
│   ├── mod.info
│   └── media/
│       ├── scripts/WoWTraits/traits.txt
│       └── lua/client/
│           ├── WoWTraits_main.lua
│           └── UI/Translate/
│               ├── UI_EN.txt
│               └── UI_IT.txt
└── common/
```

---

## 🔧 Compatibilità e Note Tecniche

- Testato su Build **42.19.0**
- Compatibile con la maggior parte degli altri mod di tratti
- I tratti con XPBoosts multipli (es. Arcane Intellect) si basano sul sistema nativo di Build 42
- La logica Lua si aggancia a: `OnGameBoot`, `OnPlayerUpdate`, `OnHitCharacter`, `OnZombieDead`, `OnKeyPressed`

---

## 📝 Crediti

Mod creato seguendo le linee guida ufficiali di modding di Indie Stone per Build 42.
Ispirato alle meccaniche di **World of Warcraft** (Blizzard Entertainment).
