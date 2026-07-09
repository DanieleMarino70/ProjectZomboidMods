-- ============================================================
--  Istinto di Sopravvivenza — Mod per Project Zomboid B42.19.0
--  Autore: (Danielao)
--  Versione: 1.0.0
--
--  Logica: quando il personaggio è in stato di panico o stress
--  elevato, il moltiplicatore XP delle skill di combattimento
--  viene potenziato proporzionalmente all'intensità del panico.
-- ============================================================

IstintoDiSopravvivenza = {}

-- -------------------------------------------------------
-- Costanti di bilanciamento
-- -------------------------------------------------------
local TRAIT_ID       = "trait_SurvivalInstinct"
local XP_BONUS_MIN   = 1.0   -- moltiplicatore base (nessun bonus)
local XP_BONUS_MAX   = 3.0   -- moltiplicatore massimo (panico pieno)
local PANIC_FULL     = 100   -- valore massimo del panico nel gioco

-- Skill di combattimento che ricevono il bonus
local COMBAT_SKILLS = {
    Perks.Axe,
    Perks.Blunt,
    Perks.SmallBlade,
    Perks.LongBlade,
    Perks.Spear,
}

-- -------------------------------------------------------
-- Stato interno (evita spam ogni tick)
-- -------------------------------------------------------
local lastMultiplier = {}   -- [playerIndex] = currentMultiplier

-- -------------------------------------------------------
-- Funzione: calcola il moltiplicatore XP in base al panico
--   panicLevel  : 0–100 (da getMoodles)
--   stressLevel : 0–1   (da getStats)
-- -------------------------------------------------------
local function calcMultiplier(panicLevel, stressLevel)
    -- Combina panico (peso 70%) e stress (peso 30%)
    local combined = (panicLevel / PANIC_FULL) * 0.7 + stressLevel * 0.3
    -- Interpolazione lineare tra MIN e MAX
    return XP_BONUS_MIN + combined * (XP_BONUS_MAX - XP_BONUS_MIN)
end

-- -------------------------------------------------------
-- Applica (o rimuove) il moltiplicatore XP sulle skill
-- -------------------------------------------------------
local function applyXpMultiplier(player, multiplier)
    local idx = player:getPlayerNum()
    if lastMultiplier[idx] == multiplier then return end   -- nessun cambio
    lastMultiplier[idx] = multiplier

    for _, perk in ipairs(COMBAT_SKILLS) do
        player:getXp():setXPMultiplier(perk, multiplier)
    end
end

-- -------------------------------------------------------
-- Hook principale: eseguito ogni aggiornamento del giocatore
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnPlayerUpdate(player)
    -- Controlla che il personaggio abbia il tratto
    if not player:HasTrait(TRAIT_ID) then
        -- Rimuovi eventuali bonus residui se il tratto è stato rimosso
        local idx = player:getPlayerNum()
        if lastMultiplier[idx] and lastMultiplier[idx] ~= XP_BONUS_MIN then
            applyXpMultiplier(player, XP_BONUS_MIN)
        end
        return
    end

    -- Leggi livello panico dai Moodles
    local moodles = player:getMoodles()
    local panicLevel = 0
    if moodles then
        -- getMoodleLevel restituisce 0–4; lo normalizziamo su 0–100
        local panicMoodleLevel = moodles:getMoodleLevel(MoodleType.Panic)
        panicLevel = (panicMoodleLevel / 4) * PANIC_FULL
    end

    -- Leggi livello stress dalle statistiche (0.0–1.0)
    local stressLevel = 0
    local stats = player:getStats()
    if stats then
        stressLevel = stats:getStress()
    end

    -- Calcola e applica il moltiplicatore
    local multiplier = calcMultiplier(panicLevel, stressLevel)
    applyXpMultiplier(player, multiplier)
end

-- -------------------------------------------------------
-- Hook: pulizia alla morte / nuovo personaggio
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnPlayerDeath(player)
    local idx = player:getPlayerNum()
    lastMultiplier[idx] = nil
end

-- -------------------------------------------------------
-- Hook: messaggio di debug all'avvio (solo in debug mode)
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnGameBoot()
    if getDebug() then
        print("[IstintoDiSopravvivenza] Mod caricato correttamente. Versione 1.0.0")
    end
end

-- -------------------------------------------------------
-- Registrazione degli eventi
-- -------------------------------------------------------
Events.OnGameBoot.Add(IstintoDiSopravvivenza.OnGameBoot)
Events.OnPlayerUpdate.Add(IstintoDiSopravvivenza.OnPlayerUpdate)
Events.OnPlayerDeath.Add(IstintoDiSopravvivenza.OnPlayerDeath)
