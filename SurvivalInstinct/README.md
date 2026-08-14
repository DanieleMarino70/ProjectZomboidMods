# Survival Instinct — Mod per Project Zomboid Build 42

Nome interno e ID sono in inglese (`SurvivalInstinct`) perché è la lingua sorgente
della mod; il nome mostrato in gioco resta "Istinto di Sopravvivenza" in italiano,
via `Translate/IT/UI.json`.

Testato su **42.20.2 stable**. Richiede `versionMin=42.20.0`. Non funziona su Build 41.

## Descrizione
Aggiunge il tratto positivo **Istinto di Sopravvivenza** (costa 6 punti).

> "La paura affina i riflessi. Quando gli zombie ti sono addosso,
>  impari a combattere più in fretta."

### Come funziona
Il principio: **il pericolo reale abilita il bonus, l'emozione lo amplifica.**

```
minaccia  = (visibili x1 + inseguitori x2 + addosso x3) / 20   -- 0.0 a 1.0
emozione  = panico x0.7 + stress x0.3                          -- 0.0 a 1.0
intensita = minaccia x (0.5 + 0.5 x emozione)
moltiplicatore = 1.0 + intensita x 1.5                         -- da x1.0 a x2.5
```

Di conseguenza:

| Situazione | Moltiplicatore XP |
|---|---|
| Al sicuro, anche in pieno panico | **×1.0** (nessun bonus) |
| Veterano/Desensibilizzato, 8 zombie all'inseguimento | ×1.60 |
| Personaggio normale, 8 all'inseguimento, panico 3/4 | ×2.00 |
| Veterano/Desensibilizzato, orda 20+ | ×1.75 |
| Personaggio normale, orda 20+, panico pieno | **×2.50** |

Skill influenzate dal moltiplicatore: **Axe, Blunt, SmallBlunt, SmallBlade, LongBlade, Spear**.

In più il tratto concede `XPBoosts = Blunt=1;SmallBlade=1`, cioè **+1 livello iniziale**
in quelle due skill e un rate XP permanente del 75% invece del 50%.

**Sul costo:** 6 punti è il prezzo vanilla di `base:brawler`, che a parità di costo dà
gli stessi 2 boost e nient'altro. Qui il meccanismo dinamico è in aggiunta, quindi il
tratto resta conveniente senza essere regalato.

### Perché funziona anche con Veterano
La professione `base:veteran` concede `base:desensitized`, che rende il personaggio
molto meno soggetto al panico. Un tratto che scala solo sul panico sarebbe stato
6 punti buttati per quella build. Siccome qui il pericolo conta da solo, un Veterano
arriva comunque al 50% del bonus massimo restando lucido.

Per lo stesso motivo il tratto **non** ha `MutuallyExclusiveTraits`: escludere
`base:desensitized` avrebbe tagliato fuori i Veterani, ed escludere `base:cowardly`
non serve, perché panicare al sicuro ora vale zero.

---

## Installazione (manuale)
1. Copia la cartella `SurvivalInstinct` in `C:\Users\<TuoNome>\Zomboid\mods\`
2. Avvia Project Zomboid → **Mods** → attiva "Istinto di Sopravvivenza"
3. Crea una **nuova partita** e seleziona il tratto in creazione personaggio

## Multiplayer
Funziona su dedicated server. La logica è client-side (`media/lua/client/`), mentre la
definizione del tratto (`media/registries.lua` + `media/scripts/`) viene caricata anche
dal server. Va aggiunto a `Mods=` e `WorkshopItems=` nel `.ini` del server.

---

## Struttura dei file
```
SurvivalInstinct/
├── workshop.txt                          ← Descrizione per l'upload Workshop
├── README.md
├── panicXP.png                           ← Sorgente 1024x1024 di poster/icon
├── 42/
│   ├── mod.info
│   ├── poster.png                        ← 256x256
│   ├── icon.png                          ← 64x64
│   └── media/
│       ├── registries.lua                ← Registra il CharacterTrait nel registro B42
│       ├── scripts/
│       │   └── SurvivalInstinct/
│       │       └── traits.txt            ← character_trait_definition
│       ├── ui/Traits/
│       │   └── trait_survivalinstinct.png  ← Icona del tratto, 18x18
│       └── lua/
│           ├── client/
│           │   └── SurvivalInstinct.lua  ← Logica XP dinamica
│           └── shared/Translate/
│               ├── EN/UI.json            ← Lingua sorgente
│               └── IT/UI.json
└── common/                               ← Contenuti condivisi tra version folder
```

### Note tecniche Build 42
- Il tratto va **registrato** in `media/registries.lua` con
  `CharacterTrait.register(...)` e poi definito negli script con
  `character_trait_definition` + campo `CharacterTrait = ...`.
- `mod.info` usa **`versionMin`/`versionMax`**, non `pzversion` (che non esiste).
- Le API usate, verificate sui sorgenti Lua di 42.20.2:
  - `player:hasTrait(CharacterTrait)` — tipizzato, non più stringhe
  - `getMoodles():getMoodleLevel(MoodleType.PANIC)` → 0-4
  - `getStats():get(CharacterStat.STRESS)` → 0.0-1.0
    (attenzione: `CharacterStat.PANIC` è invece su scala **0-100**)
  - `getStats():getNumVisibleZombies() / getNumChasingZombies() / getNumVeryCloseZombies()`
    — campi già mantenuti dal motore, lettura O(1), nessuna iterazione di liste
  - `getXp():addXpMultiplier(perk, mult, minLevel, maxLevel)` — min/max è la finestra
    di **livelli** in cui il moltiplicatore si applica, non un intervallo di tempo

---

## Personalizzazione
In `SurvivalInstinct.lua`, sezione **Costanti di bilanciamento**:

```lua
local XP_BONUS_MIN = 1.0   -- moltiplicatore senza pericolo
local XP_BONUS_MAX = 2.5   -- moltiplicatore a pericolo + panico massimi
local THREAT_CAP   = 20    -- punteggio pesato oltre il quale la minaccia è al 100%
local CALM_SHARE   = 0.5   -- quota di bonus da solo pericolo, senza emozione
```

`CALM_SHARE` è la leva per i Desensibilizzati: a 0.5 arrivano a metà del bonus massimo,
a 1.0 il panico smetterebbe del tutto di contare.

---

## Licenza
MIT. Libera distribuzione, modifica e inclusione in modpack con attribuzione.
