-- ============================================================
--  Survival Instinct (Istinto di Sopravvivenza)
--  Mod per Project Zomboid Build 42
--  Autore: Danielao
--  Versione: 1.2.0
--  Licenza: MIT
--
--  Logica: il bonus XP di combattimento esiste SOLO quando c'e'
--  pericolo reale (zombie nelle vicinanze). Panico e stress
--  amplificano il bonus, ma non lo generano da soli: panicare al
--  sicuro non vale niente.
--
--  NOTE B42 (API verificate sui sorgenti Lua di 42.20.2):
--   * Il tratto e' registrato in media/registries.lua e definito in
--     media/scripts/SurvivalInstinct/traits.txt.
--   * player:hasTrait(CharacterTrait) e' tipizzato: l'handle si
--     recupera con CharacterTrait.get(ResourceLocation.of(id)).
--   * Panico: getMoodles():getMoodleLevel(MoodleType.PANIC) -> 0-4.
--     ATTENZIONE: CharacterStat.PANIC e' invece su scala 0-100
--     (vedi forageSystem.lua:1803), quindi NON usare quello qui.
--   * Stress: getStats():get(CharacterStat.STRESS) -> 0.0-1.0.
--   * Minaccia: getNumVisibleZombies()/getNumChasingZombies()/
--     getNumVeryCloseZombies() sono campi gia' mantenuti dal motore
--     (classe zombie.characters.Stats). Leggerli e' O(1): non
--     iterano nessuna lista. Il vanilla li chiama a ogni tick in
--     SadisticMusicDirector.lua. NON usare getCell():getZombieList().
--   * Bonus XP: getXp():addXpMultiplier(perk, mult, minLevel, maxLevel)
--     dove min/max e' la finestra di LIVELLI in cui il moltiplicatore
--     si applica (vedi ISReadABook.lua:115).
-- ============================================================

SurvivalInstinct = {}

-- -------------------------------------------------------
-- Costanti di bilanciamento
-- -------------------------------------------------------
-- Deve restare identico a media/registries.lua e al blocco in
-- media/scripts/SurvivalInstinct/traits.txt.
local TRAIT_ID     = "survivalinstinct:trait_survivalinstinct"

local XP_BONUS_MIN = 1.0    -- moltiplicatore senza pericolo (nessun bonus)
local XP_BONUS_MAX = 2.5    -- moltiplicatore a pericolo + panico massimi
local XP_NEUTRAL   = 1.0    -- moltiplicatore neutro (rimozione del bonus)

local PANIC_MOODLE_MAX = 4  -- getMoodleLevel restituisce 0-4

-- Soglia di minaccia: oltre questo punteggio pesato la minaccia e' al 100%.
-- Riferimento vanilla: SadisticMusicDirector considera >10 zombie come
-- tensione massima. 20 pesati corrispondono a ~7 zombie che ti inseguono.
local THREAT_CAP   = 20
local W_VISIBLE    = 1      -- zombie visibile
local W_CHASING    = 2      -- zombie che ti insegue
local W_VERY_CLOSE = 3      -- zombie addosso

-- Quota di bonus garantita dal solo pericolo, senza alcuna emozione.
-- 0.5 = un Desensitized (quindi anche un Veterano) arriva al 50% del
-- bonus massimo restando perfettamente calmo.
local CALM_SHARE = 0.5

-- Ricalcola ogni N chiamate di OnPlayerUpdate invece che a ogni frame.
local UPDATE_INTERVAL = 30

-- Skill di combattimento che ricevono il moltiplicatore dinamico.
-- Popolata in OnGameBoot, NON qui: durante il caricamento dei file Lua
-- non e' garantito che Perks sia gia' popolato, e una tabella con un nil
-- dentro farebbe fermare ipairs al primo buco senza alcun errore.
local COMBAT_SKILLS = {}

-- Handle del tratto, risolto una volta al boot dal registro character_trait
local SurvivalTrait = nil

-- -------------------------------------------------------
-- Stato interno (evita riscritture inutili)
-- -------------------------------------------------------
local lastMultiplier = {}   -- [playerNum] = ultimo moltiplicatore calcolato
local tickCounter    = {}   -- [playerNum] = contatore di throttling

-- [playerNum][i] = valore che ABBIAMO scritto sul perk COMBAT_SKILLS[i].
-- Serve a distinguere "il moltiplicatore attuale e' nostro" da "l'ha messo
-- qualcun altro": la mappa dei moltiplicatori ha una sola entry per perk,
-- quindi scrivere alla cieca schiaccerebbe il valore altrui. nil = abbiamo
-- ceduto il posto a un valore piu' alto di un'altra fonte.
local myWritten = {}

-- Tolleranza nel confronto float fra quello che abbiamo scritto e quello
-- che rileggiamo dal motore.
local EPSILON = 0.001

local function clamp01(v)
    if v == nil then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- -------------------------------------------------------
-- Minaccia: 0.0-1.0 in base agli zombie intorno al giocatore.
-- Vedi nota in testa: i tre contatori sono campi gia' pronti, questa
-- funzione non itera nulla e non alloca.
-- -------------------------------------------------------
local function getThreatRatio(stats)
    if not stats then return 0 end
    local threat = stats:getNumVisibleZombies()   * W_VISIBLE
                 + stats:getNumChasingZombies()   * W_CHASING
                 + stats:getNumVeryCloseZombies() * W_VERY_CLOSE
    return clamp01(threat / THREAT_CAP)
end

-- -------------------------------------------------------
-- Moltiplicatore XP.
--   Il pericolo reale ABILITA il bonus, l'emozione lo AMPLIFICA.
--   Nessuno zombie intorno => nessun bonus, per chiunque.
--   panicRatio  : 0.0-1.0 (dal moodle Panic, livello 0-4)
--   stressLevel : 0.0-1.0 (da CharacterStat.STRESS)
--   threatRatio : 0.0-1.0 (da getThreatRatio)
-- -------------------------------------------------------
local function calcMultiplier(panicRatio, stressLevel, threatRatio)
    local emotional = clamp01(panicRatio) * 0.7 + clamp01(stressLevel) * 0.3
    local intensity = threatRatio * (CALM_SHARE + (1 - CALM_SHARE) * emotional)
    return XP_BONUS_MIN + intensity * (XP_BONUS_MAX - XP_BONUS_MIN)
end

-- -------------------------------------------------------
-- Applica (o azzera) il moltiplicatore XP sulle skill.
-- Arrotonda a 2 decimali per evitare riscritture continue dovute a
-- micro-variazioni dello stress.
--
-- Regola "alzo, mai abbasso" (stessa guardia del vanilla in
-- ISReadABook.lua:114): il motore tiene UN SOLO moltiplicatore per perk,
-- quindi se un'altra fonte ne ha impostato uno piu' alto non lo tocchiamo.
-- Il nostro valore invece possiamo alzarlo e abbassarlo liberamente, ed e'
-- per questo che teniamo traccia di cosa abbiamo scritto: senza, dopo la
-- prima scrittura non riusciremmo mai piu' a far scendere il moltiplicatore
-- quando il pericolo passa.
-- -------------------------------------------------------
local function applyXpMultiplier(player, multiplier)
    multiplier = math.floor(multiplier * 100 + 0.5) / 100

    local idx = player:getPlayerNum()
    if lastMultiplier[idx] == multiplier then return end   -- nessun cambio
    lastMultiplier[idx] = multiplier

    local xp = player:getXp()
    if not xp then return end

    local mine = myWritten[idx]
    if not mine then
        mine = {}
        myWritten[idx] = mine
    end

    for i, perk in ipairs(COMBAT_SKILLS) do
        local current = xp:getMultiplier(perk)
        local ours    = mine[i]
        local isOurs  = ours ~= nil and math.abs(current - ours) < EPSILON

        if isOurs or multiplier > current then
            -- minLevel 0: il bonus deve valere anche a skill 0, altrimenti il
            -- tratto sarebbe inerte proprio nella fase iniziale di partita.
            xp:addXpMultiplier(perk, multiplier, 0, 10)
            mine[i] = multiplier
        else
            -- Un'altra fonte ha un moltiplicatore piu' alto: le lasciamo il
            -- posto e ci ripresentiamo quando il nostro lo supera.
            mine[i] = nil
        end
    end

    if getDebug() then
        print("[SurvivalInstinct] moltiplicatore XP: x" .. multiplier)
    end
end

-- -------------------------------------------------------
-- Hook principale: eseguito ad ogni aggiornamento del giocatore
-- -------------------------------------------------------
function SurvivalInstinct.OnPlayerUpdate(player)
    if not player or player:isDead() then return end
    if #COMBAT_SKILLS == 0 then return end   -- boot fallito: non fare nulla

    local idx = player:getPlayerNum()

    -- Senza il tratto: azzera un eventuale bonus residuo ed esci.
    if SurvivalTrait == nil or not player:hasTrait(SurvivalTrait) then
        if lastMultiplier[idx] and lastMultiplier[idx] ~= XP_NEUTRAL then
            applyXpMultiplier(player, XP_NEUTRAL)
        end
        return
    end

    -- Throttling: i conteggi zombie cambiano di continuo, non serve
    -- ricalcolare a ogni frame.
    local t = (tickCounter[idx] or 0) + 1
    if t < UPDATE_INTERVAL then
        tickCounter[idx] = t
        return
    end
    tickCounter[idx] = 0

    local stats = player:getStats()

    -- Pericolo reale intorno al giocatore
    local threatRatio = getThreatRatio(stats)

    -- Livello di panico dai Moodles (0-4, normalizzato su 0.0-1.0)
    local panicRatio = 0
    local moodles = player:getMoodles()
    if moodles then
        panicRatio = moodles:getMoodleLevel(MoodleType.PANIC) / PANIC_MOODLE_MAX
    end

    -- Livello di stress dalle statistiche (0.0-1.0)
    local stressLevel = 0
    if stats then
        stressLevel = stats:get(CharacterStat.STRESS)
    end

    applyXpMultiplier(player, calcMultiplier(panicRatio, stressLevel, threatRatio))
end

-- -------------------------------------------------------
-- Hook: pulizia alla morte / nuovo personaggio
-- -------------------------------------------------------
function SurvivalInstinct.OnPlayerDeath(player)
    if not player then return end
    local idx = player:getPlayerNum()
    lastMultiplier[idx] = nil
    tickCounter[idx]    = nil
    myWritten[idx]      = nil
end

-- -------------------------------------------------------
-- Hook: risolve l'handle del tratto e la lista dei perk al boot
-- -------------------------------------------------------
function SurvivalInstinct.OnGameBoot()
    SurvivalTrait = CharacterTrait.get(ResourceLocation.of(TRAIT_ID))
    if SurvivalTrait == nil then
        print("[SurvivalInstinct] ERRORE: tratto non trovato nel registro: "
            .. TRAIT_ID .. " (registries.lua non eseguito?)")
    end

    -- Perks va letto qui, a boot avvenuto: vedi nota su COMBAT_SKILLS.
    -- Ogni perk mancante viene segnalato invece di sparire in silenzio.
    COMBAT_SKILLS = {}
    local wanted = {
        { perk = Perks.Axe,        name = "Axe" },
        { perk = Perks.Blunt,      name = "Blunt" },
        { perk = Perks.SmallBlunt, name = "SmallBlunt" },
        { perk = Perks.SmallBlade, name = "SmallBlade" },
        { perk = Perks.LongBlade,  name = "LongBlade" },
        { perk = Perks.Spear,      name = "Spear" },
    }
    for _, entry in ipairs(wanted) do
        if entry.perk then
            table.insert(COMBAT_SKILLS, entry.perk)
        else
            print("[SurvivalInstinct] ERRORE: perk non disponibile: " .. entry.name)
        end
    end

    if getDebug() then
        print("[SurvivalInstinct] caricato (v1.2.0), "
            .. #COMBAT_SKILLS .. " skill di combattimento agganciate.")
    end
end

-- -------------------------------------------------------
-- Registrazione degli eventi
-- -------------------------------------------------------
Events.OnGameBoot.Add(SurvivalInstinct.OnGameBoot)
Events.OnPlayerUpdate.Add(SurvivalInstinct.OnPlayerUpdate)
Events.OnPlayerDeath.Add(SurvivalInstinct.OnPlayerDeath)
