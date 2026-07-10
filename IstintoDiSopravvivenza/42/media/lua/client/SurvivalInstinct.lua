-- ============================================================
--  Istinto di Sopravvivenza — Mod per Project Zomboid B42.19.0
--  Autore: (Danielao)
--  Versione: 1.1.0
--
--  Logica: quando il personaggio è in stato di panico o stress
--  elevato, il moltiplicatore XP delle skill di combattimento
--  viene potenziato proporzionalmente all'intensità del panico.
--
--  NOTE B42 (API verificate su 42.19.0):
--   * Il tratto è registrato in media/registries.lua e definito in
--     media/scripts/IstintoDiSopravvivenza/traits.txt.
--   * HasTrait(stringa) non esiste più: si usa player:hasTrait(CharacterTrait)
--     con l'handle recuperato via CharacterTrait.get(ResourceLocation.of(id)).
--   * Il panico si legge con getMoodles():getMoodleLevel(MoodleType.PANIC)
--     (0-4); lo stress con stats:get(CharacterStat.STRESS) (0.0-1.0).
--   * setXPMultiplier non esiste: si usa
--     getXp():addXpMultiplier(perk, mult, minLevel, maxLevel).
-- ============================================================

IstintoDiSopravvivenza = {}

-- -------------------------------------------------------
-- Costanti di bilanciamento
-- -------------------------------------------------------
local TRAIT_ID       = "istintodisopravvivenza:trait_survivalinstinct"
local XP_BONUS_MIN   = 1.0   -- moltiplicatore base (nessun bonus)
local XP_BONUS_MAX   = 2.5   -- moltiplicatore massimo (panico pieno)
local PANIC_MOODLE_MAX = 4   -- getMoodleLevel restituisce 0-4

-- Skill di combattimento che ricevono il bonus
local COMBAT_SKILLS = {
    Perks.Axe,
    Perks.Blunt,
    Perks.SmallBlade,
    Perks.LongBlade,
    Perks.Spear,
}

-- Handle del tratto, risolto una volta al boot dal registro character_trait
local SurvivalTrait = nil

-- -------------------------------------------------------
-- Stato interno (evita spam ogni tick)
-- -------------------------------------------------------
local lastMultiplier = {}   -- [playerIndex] = currentMultiplier

-- -------------------------------------------------------
-- Funzione: calcola il moltiplicatore XP in base al panico
--   panicRatio  : 0.0-1.0 (dal moodle Panic, livello 0-4)
--   stressLevel : 0.0-1.0 (da stats)
-- -------------------------------------------------------
local function calcMultiplier(panicRatio, stressLevel)
    -- Combina panico (peso 70%) e stress (peso 30%)
    local clampedPanic  = math.max(0, math.min(panicRatio, 1))
    local clampedStress = math.max(0, math.min(stressLevel, 1))
    local combined = clampedPanic * 0.7 + clampedStress * 0.3
    -- Interpolazione lineare tra MIN e MAX
    return math.min(XP_BONUS_MAX, XP_BONUS_MIN + combined * (XP_BONUS_MAX - XP_BONUS_MIN))
end

-- -------------------------------------------------------
-- Applica (o rimuove) il moltiplicatore XP sulle skill.
-- Arrotonda a 2 decimali per evitare riscritture continue
-- dovute a micro-variazioni dello stress.
-- -------------------------------------------------------
local function applyXpMultiplier(player, multiplier)
    multiplier = math.floor(multiplier * 100 + 0.5) / 100
    local idx = player:getPlayerNum()
    if lastMultiplier[idx] == multiplier then return end   -- nessun cambio
    lastMultiplier[idx] = multiplier

    local xp = player:getXp()
    if not xp then return end
    for _, perk in ipairs(COMBAT_SKILLS) do
        xp:addXpMultiplier(perk, multiplier, 1, 10)
    end
end

-- -------------------------------------------------------
-- Hook principale: eseguito ogni aggiornamento del giocatore
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnPlayerUpdate(player)
    if not player or player:isDead() then return end

    -- Controlla che il personaggio abbia il tratto
    if SurvivalTrait == nil or not player:hasTrait(SurvivalTrait) then
        -- Rimuovi eventuali bonus residui se il tratto non c'è più
        local idx = player:getPlayerNum()
        if lastMultiplier[idx] and lastMultiplier[idx] ~= XP_BONUS_MIN then
            applyXpMultiplier(player, XP_BONUS_MIN)
        end
        return
    end

    -- Leggi livello panico dai Moodles (0-4, normalizzato su 0.0-1.0)
    local panicRatio = 0
    local moodles = player:getMoodles()
    if moodles then
        panicRatio = moodles:getMoodleLevel(MoodleType.PANIC) / PANIC_MOODLE_MAX
    end

    -- Leggi livello stress dalle statistiche (0.0-1.0)
    local stressLevel = 0
    local stats = player:getStats()
    if stats then
        stressLevel = stats:get(CharacterStat.STRESS)
    end

    -- Calcola e applica il moltiplicatore
    applyXpMultiplier(player, calcMultiplier(panicRatio, stressLevel))
end

-- -------------------------------------------------------
-- Hook: pulizia alla morte / nuovo personaggio
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnPlayerDeath(player)
    if not player then return end
    lastMultiplier[player:getPlayerNum()] = nil
end

-- -------------------------------------------------------
-- Hook: risolve l'handle del tratto al boot
-- -------------------------------------------------------
function IstintoDiSopravvivenza.OnGameBoot()
    SurvivalTrait = CharacterTrait.get(ResourceLocation.of(TRAIT_ID))
    if SurvivalTrait == nil then
        print("[IstintoDiSopravvivenza] ERRORE: tratto non trovato nel registro: "
            .. TRAIT_ID .. " (registries.lua non eseguito?)")
    elseif getDebug() then
        print("[IstintoDiSopravvivenza] Mod caricato correttamente. Versione 1.1.0")
    end
end

-- -------------------------------------------------------
-- Registrazione degli eventi
-- -------------------------------------------------------
Events.OnGameBoot.Add(IstintoDiSopravvivenza.OnGameBoot)
Events.OnPlayerUpdate.Add(IstintoDiSopravvivenza.OnPlayerUpdate)
Events.OnPlayerDeath.Add(IstintoDiSopravvivenza.OnPlayerDeath)
