# Istinto di Sopravvivenza — Mod per Project Zomboid B42.19.0

## Descrizione
Aggiunge il tratto positivo **Istinto di Sopravvivenza** (costa 4 punti).

> "La paura affina i riflessi. Più sei in preda al panico o allo stress,
>  più velocemente impari le abilità di combattimento."

### Come funziona
Il moltiplicatore XP delle skill di combattimento scala dinamicamente:

| Stato del personaggio       | Moltiplicatore XP |
|-----------------------------|-------------------|
| Calmo (panico 0, stress 0)  | ×1.0  (nessun bonus) |
| Stress moderato             | ×1.4 – ×1.7       |
| Panico pieno (100%)         | ×2.5              |

Le skill influenzate sono: **Axe, Blunt, SmallBlade, LongBlade, Spear**.

---

## Installazione (manuale)
1. Copia la cartella `IstintoDiSopravvivenza` in:
   `C:\Users\<TuoNome>\Zomboid\mods\`
2. Avvia Project Zomboid.
3. Dal menu principale → **Mods** → attiva "Istinto di Sopravvivenza".
4. Crea una nuova partita e seleziona il tratto in fase di creazione personaggio.

---

## Struttura dei file
```
IstintoDiSopravvivenza/
├── 42/
│   ├── mod.info
│   └── media/
│       ├── registries.lua              ← Registra il CharacterTrait nel registro B42
│       ├── scripts/
│       │   └── IstintoDiSopravvivenza/
│       │       └── traits.txt          ← Definizione character_trait_definition
│       └── lua/
│           ├── client/
│           │   └── SurvivalInstinct.lua  ← Logica XP dinamica
│           └── shared/Translate/
│               ├── EN/UI.json            ← Testi in inglese (formato JSON B42)
│               └── IT/UI.json            ← Testi in italiano
└── common/                               ← Richiesta da B42 (vuota)
```

### Note tecniche Build 42.19
- Il tratto va **registrato** in `media/registries.lua` con
  `CharacterTrait.register("istintodisopravvivenza:...")` e poi definito negli
  script con `character_trait_definition` + campo `CharacterTrait = ...`.
- API Lua B42: `player:hasTrait(CharacterTrait)` (non più stringhe),
  panico da `getMoodles():getMoodleLevel(MoodleType.PANIC)` (0-4),
  stress da `stats:get(CharacterStat.STRESS)` (0.0-1.0),
  bonus XP con `getXp():addXpMultiplier(perk, mult, minLevel, maxLevel)`.

---

## Bilanciamento
- Il tratto costa **4 punti** (positivo): abbastanza alto da renderlo una scelta reale,
  ma non "gratis" come i tratti sbilanciati citati nelle note di sviluppo.
- Il bonus base è **×1.0**: nessun vantaggio senza panico. Chi gioca "safe" non ne
  beneficia affatto, riducendo il rischio di exploit.
- Il bonus massimo **×2.5** vale solo a panico pieno — uno stato che il giocatore
  vorrà sempre evitare, creando una tensione interessante.

---

## Personalizzazione
In `SurvivalInstinct.lua`, nella sezione **Costanti di bilanciamento**:

```lua
local XP_BONUS_MIN = 1.0   -- moltiplicatore a panico zero
local XP_BONUS_MAX = 2.5   -- moltiplicatore a panico massimo
```

Modifica questi valori per adattare il tratto al tuo stile di gioco.

---

## Licenza
Mod rilasciata sotto licenza MIT. Libera distribuzione e modifica con attribuzione.
