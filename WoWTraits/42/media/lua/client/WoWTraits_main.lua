-- =============================================================================
-- WOW TRAITS MOD - Main Script
-- Build 42.19.0 Compatible
-- 14 tratti ispirati a World of Warcraft
--
-- NOTE B42 (API verificate su 42.19.0):
--  * I tratti custom sono registrati in media/registries.lua e definiti in
--    media/scripts/WoWTraits/traits.txt.
--  * HasTrait(stringa) non esiste più: si usa player:hasTrait(CharacterTrait),
--    con l'handle recuperato via CharacterTrait.get(ResourceLocation.of(id)).
--  * Stats:get/setRunSpeed non esistono più: i buff di movimento usano
--    IsoPlayer setMoveSpeed, quelli di attacco setCombatSpeed.
--  * L'evento OnHitCharacter non esiste: si usa OnWeaponHitCharacter.
--  * Il rallentamento degli zombie usa setWalkType("slow1..3") +
--    setSpeedTypeFromWalkType(); la spinta di Turbine usa setStaggerBack.
-- =============================================================================

WoWTraits = {}

-- =============================================================================
-- COSTANTI DI CONFIGURAZIONE
-- =============================================================================
local CFG = {
    -- Velocità di movimento base di IsoPlayer (campo moveSpeed, default 0.06)
    DEFAULT_MOVE_SPEED        = 0.06,

    -- Berserker
    BERSERKER_HP_THRESHOLD    = 0.30,   -- 30% HP
    BERSERKER_SPEED_BONUS     = 0.30,   -- +30% velocità movimento
    BERSERKER_ATTACK_BONUS    = 0.30,   -- +30% velocità di attacco

    -- Second Wind
    SECONDWIND_HP_THRESHOLD   = 0.35,   -- 35% HP
    SECONDWIND_REGEN_AMOUNT   = 0.002,  -- HP regen per tick

    -- Shield Wall
    SHIELDWALL_DMG_REDUCTION  = 0.25,   -- 25% riduzione danni

    -- Whirlwind
    WHIRLWIND_ZOMBIE_COUNT    = 3,      -- Zombie minimi per attivare
    WHIRLWIND_RADIUS          = 1.5,    -- Raggio in tile
    WHIRLWIND_COOLDOWN        = 8000,   -- ms cooldown

    -- Slice & Dice
    SLICEANDDICE_MAX_STACKS   = 5,      -- Massimo stack
    SLICEANDDICE_WINDOW       = 3000,   -- ms finestra combo
    SLICEANDDICE_SPEED_BONUS  = 0.04,   -- +4% velocità attacco per stack

    -- Frost Nova
    FROSTNOVA_ZOMBIE_TRIGGER  = 4,      -- Zombie minimi
    FROSTNOVA_RADIUS          = 3.0,    -- Raggio rilevamento
    FROSTNOVA_SPEED_BONUS     = 0.50,   -- +50% velocità burst
    FROSTNOVA_DURATION        = 4000,   -- ms durata
    FROSTNOVA_COOLDOWN        = 20000,  -- ms cooldown

    -- Immolation
    IMMOLATION_RADIUS         = 4.0,    -- Raggio fuoco
    IMMOLATION_SLOW_MS        = 1500,   -- ms di rallentamento (rinfrescato finché c'è fuoco)

    -- Death Coil
    DEATHCOIL_HEAL_AMOUNT     = 3.0,    -- HP recuperati per kill

    -- Bone Shield
    BONE_SHIELD_KILLS         = 5,      -- Kill per attivare
    BONE_SHIELD_REDUCTION     = 0.30,   -- 30% riduzione danni
    BONE_SHIELD_DURATION      = 15000,  -- ms durata

    -- Feral Charge
    FERALCHARGE_SPEED_BONUS   = 0.80,   -- +80% velocità
    FERALCHARGE_DURATION      = 3000,   -- ms durata
    FERALCHARGE_COOLDOWN      = 30000,  -- ms cooldown

    -- Generico
    MAX_DAMAGE_REDUCTION      = 0.75,   -- cap riduzione danni combinata (Shield Wall + Bone Shield)
    PROXIMITY_SCAN_INTERVAL   = 250,    -- ms tra le scansioni degli zombie vicini
    FIRE_SCAN_INTERVAL        = 500,    -- ms tra le scansioni del fuoco (81 tile)
}

-- =============================================================================
-- HANDLE DEI TRATTI — risolti una volta al boot dal registro character_trait.
-- =============================================================================
local Traits = {}

local TRAIT_IDS = {
    Berserker       = "wowtraits:trait_berserker",
    SecondWind      = "wowtraits:trait_secondwind",
    ShieldWall      = "wowtraits:trait_shieldwall",
    Whirlwind       = "wowtraits:trait_whirlwind",
    SliceAndDice    = "wowtraits:trait_sliceanddice",
    FrostNova       = "wowtraits:trait_frostnova",
    ArcaneIntellect = "wowtraits:trait_arcaneintellect",
    Immolation      = "wowtraits:trait_immolation",
    DeathCoil       = "wowtraits:trait_deathcoil",
    BoneShield      = "wowtraits:trait_boneshield",
    DetectTraps     = "wowtraits:trait_detecttraps",
    EagleEye        = "wowtraits:trait_eagleeye",
    FeralCharge     = "wowtraits:trait_feralcharge",
    Engineer        = "wowtraits:trait_engineer",
}

local function resolveTraits()
    for key, id in pairs(TRAIT_IDS) do
        Traits[key] = CharacterTrait.get(ResourceLocation.of(id))
        if Traits[key] == nil then
            print("[WoWTraits] ERRORE: tratto non trovato nel registro: " .. id
                .. " (registries.lua non eseguito?)")
        end
    end
end

local function hasTrait(player, key)
    local trait = Traits[key]
    return trait ~= nil and player:hasTrait(trait)
end

-- =============================================================================
-- STATO INTERNO DEI TRAIT — indicizzato per player (playerNum)
-- Evita che i cooldown/stack di un personaggio "sanguinino" su un altro
-- in scenari splitscreen/multi-personaggio.
-- =============================================================================
local PlayerState = {}

local function getPlayerState(player)
    local idx = player:getPlayerNum()
    local state = PlayerState[idx]
    if not state then
        state = {
            -- Berserker
            berserkerActive   = false,

            -- Slice & Dice
            sdLastHitTime     = 0,
            sdStacks          = 0,

            -- Frost Nova
            fnLastActivation  = 0,
            fnActive          = false,
            fnEndTime         = 0,

            -- Whirlwind
            wwLastActivation  = 0,

            -- Bone Shield
            bsKillCount       = 0,
            bsActive          = false,
            bsEndTime         = 0,

            -- Feral Charge
            fcLastActivation  = 0,
            fcActive          = false,
            fcEndTime         = 0,

            -- Shield Wall
            shieldWallActive  = false,

            -- Ultimo HP osservato, usato per calcolare i danni subiti nel tick
            -- e applicare la riduzione danni di Shield Wall / Bone Shield.
            lastHealth        = nil,

            -- Ultimi moltiplicatori applicati: si riscrive moveSpeed/combatSpeed
            -- solo quando cambiano, per non interferire inutilmente col gioco.
            moveMultApplied   = 1.0,
            combatMultApplied = 1.0,

            -- Cache delle scansioni di prossimità (throttling: contare gli
            -- zombie/il fuoco ogni tick è inutile e pesa durante le orde).
            lastProximityScan = 0,
            zombiesNearClose  = 0,      -- entro WHIRLWIND_RADIUS
            zombiesNearMid    = 0,      -- entro FROSTNOVA_RADIUS
            lastFireScan      = 0,
            fireNearby        = false,
        }
        PlayerState[idx] = state
    end
    return state
end

-- Ricalcola e applica i moltiplicatori di velocità movimento/attacco in base
-- ai buff attivi. I flag di stato vengono impostati solo se il player possiede
-- il tratto corrispondente, quindi qui non serve ricontrollare i tratti.
local function refreshSpeeds(player, state, now)
    local moveMult = 1.0
    if state.berserkerActive then moveMult = moveMult + CFG.BERSERKER_SPEED_BONUS end
    if state.fnActive then moveMult = moveMult + CFG.FROSTNOVA_SPEED_BONUS end
    if state.fcActive then moveMult = moveMult + CFG.FERALCHARGE_SPEED_BONUS end

    local combatMult = 1.0
    if state.berserkerActive then combatMult = combatMult + CFG.BERSERKER_ATTACK_BONUS end
    if state.sdStacks > 0 and now - state.sdLastHitTime <= CFG.SLICEANDDICE_WINDOW then
        combatMult = combatMult + state.sdStacks * CFG.SLICEANDDICE_SPEED_BONUS
    end

    if moveMult ~= state.moveMultApplied then
        player:setMoveSpeed(CFG.DEFAULT_MOVE_SPEED * moveMult)
        state.moveMultApplied = moveMult
    end
    if combatMult ~= state.combatMultApplied then
        player:setCombatSpeed(combatMult)
        state.combatMultApplied = combatMult
    end
end

-- =============================================================================
-- STATO EFFETTI TEMPORANEI SUGLI ZOMBIE (rallentamento Immolation)
-- Si salva il walkType originale per ripristinarlo alla scadenza, altrimenti
-- lo zombie resterebbe rallentato per sempre.
-- =============================================================================
local ZombieEffects = {}   -- [zombie] = { originalWalkType = s|nil, expireTime = ms }
local lastZombieCleanup = 0
local ZOMBIE_CLEANUP_INTERVAL = 500 -- ms

local function restoreExpiredZombieEffects(now)
    if now - lastZombieCleanup < ZOMBIE_CLEANUP_INTERVAL then return end
    lastZombieCleanup = now
    for zombie, fx in pairs(ZombieEffects) do
        if now >= fx.expireTime then
            if zombie and not zombie:isDead() and fx.originalWalkType then
                zombie:setWalkType(fx.originalWalkType)
                zombie:setSpeedTypeFromWalkType()
            end
            ZombieEffects[zombie] = nil
        end
    end
end

local function applyTemporaryZombieSlow(zombie, durationMs, now)
    local fx = ZombieEffects[zombie]
    if not fx then
        local original = zombie:getWalkType()
        zombie:setWalkType("slow3")
        zombie:setSpeedTypeFromWalkType()
        fx = { originalWalkType = original }
        ZombieEffects[zombie] = fx
    end
    fx.expireTime = now + durationMs
end

-- =============================================================================
-- UTILITY
-- =============================================================================
local function getTimeMs()
    -- getTimestampMs() e' l'API nativa di PZ per il tempo reale in ms.
    return getTimestampMs and getTimestampMs() or (os.time() * 1000)
end

local function forEachNearbyZombie(player, radius, fn)
    local cell = getCell()
    if not cell then return end
    local zombies = cell:getZombieList()
    if not zombies then return end
    local px, py = player:getX(), player:getY()
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and not z:isDead() then
            local dx = z:getX() - px
            local dy = z:getY() - py
            if math.sqrt(dx * dx + dy * dy) <= radius then
                fn(z)
            end
        end
    end
end

-- Un solo passaggio sulla lista zombie ogni PROXIMITY_SCAN_INTERVAL ms:
-- aggiorna i conteggi cache usati da Whirlwind (raggio corto) e
-- Frost Nova (raggio medio).
local function updateProximityCache(player, state, now)
    if now - state.lastProximityScan < CFG.PROXIMITY_SCAN_INTERVAL then return end
    state.lastProximityScan = now
    local closeCount, midCount = 0, 0
    forEachNearbyZombie(player, CFG.FROSTNOVA_RADIUS, function(z)
        midCount = midCount + 1
        local dx = z:getX() - player:getX()
        local dy = z:getY() - player:getY()
        if math.sqrt(dx * dx + dy * dy) <= CFG.WHIRLWIND_RADIUS then
            closeCount = closeCount + 1
        end
    end)
    state.zombiesNearClose = closeCount
    state.zombiesNearMid = midCount
end

local function isFireNearby(player, radius)
    local cell = getCell()
    if not cell then return false end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    local r = math.ceil(radius)
    for dx = -r, r do
        for dy = -r, r do
            if math.sqrt(dx * dx + dy * dy) <= radius then
                local tile = cell:getGridSquare(px + dx, py + dy, pz)
                if tile then
                    if tile.isBurning and tile:isBurning() then
                        return true
                    end
                    local objects = tile:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if obj and obj.getType and obj:getType() then
                                local typeName = tostring(obj:getType()):lower()
                                if typeName:find("fire") then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function isHoldingShield(player)
    local function isShieldItem(item)
        if not item then return false end
        return item:getFullType():lower():find("shield") ~= nil
    end
    return isShieldItem(player:getPrimaryHandItem())
        or isShieldItem(player:getSecondaryHandItem())
end

-- =============================================================================
-- ON PLAYER UPDATE — logica principale tick per tick
-- =============================================================================
local function WoWTraits_OnPlayerUpdate(player)
    if not player or player:isDead() then return end
    local now = getTimeMs()
    restoreExpiredZombieEffects(now)

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local state = getPlayerState(player)
    local maxHP = 100
    local curHP = bodyDamage:getOverallBodyHealth()

    -- Scansione zombie vicini (cache, throttled) solo se serve a un tratto posseduto
    if hasTrait(player, "FrostNova") or hasTrait(player, "Whirlwind") then
        updateProximityCache(player, state, now)
    end

    if hasTrait(player, "ShieldWall") then
        state.shieldWallActive = isHoldingShield(player)
    else
        state.shieldWallActive = false
    end

    -- -------------------------------------------------------------------------
    -- SHIELD WALL / BONE SHIELD: applica la riduzione danni effettiva.
    -- Confrontiamo l'HP con quello osservato al tick precedente: se e' diminuito,
    -- rimborsiamo al giocatore la percentuale di danno assorbita dagli scudi attivi.
    -- -------------------------------------------------------------------------
    if state.lastHealth == nil then
        state.lastHealth = curHP
    end
    local damageTaken = state.lastHealth - curHP
    if damageTaken > 0 then
        local reduction = 0.0
        if state.shieldWallActive then
            reduction = reduction + CFG.SHIELDWALL_DMG_REDUCTION
        end
        if hasTrait(player, "BoneShield") and state.bsActive then
            reduction = reduction + CFG.BONE_SHIELD_REDUCTION
        end
        if reduction > 0 then
            reduction = math.min(reduction, CFG.MAX_DAMAGE_REDUCTION)
            local refund = damageTaken * reduction
            curHP = math.min(curHP + refund, maxHP)
            bodyDamage:setOverallBodyHealth(curHP)
        end
    end
    state.lastHealth = curHP

    local hpPct = curHP / maxHP

    -- -------------------------------------------------------------------------
    -- BERSERKER: sotto 30% HP → velocità movimento e attacco aumentano
    -- -------------------------------------------------------------------------
    if hasTrait(player, "Berserker") then
        state.berserkerActive = hpPct <= CFG.BERSERKER_HP_THRESHOLD
    else
        state.berserkerActive = false
    end

    -- -------------------------------------------------------------------------
    -- SECOND WIND: sotto 35% HP → rigenera HP lentamente
    -- -------------------------------------------------------------------------
    if hasTrait(player, "SecondWind") then
        if hpPct <= CFG.SECONDWIND_HP_THRESHOLD then
            local regenMult = 1.0 + (CFG.SECONDWIND_HP_THRESHOLD - hpPct) * 3.0
            local newHP = math.min(curHP + CFG.SECONDWIND_REGEN_AMOUNT * regenMult, maxHP)
            bodyDamage:setOverallBodyHealth(newHP)
            state.lastHealth = newHP
        end
    end

    -- -------------------------------------------------------------------------
    -- FROST NOVA: 4+ zombie vicini → burst di velocità
    -- -------------------------------------------------------------------------
    if hasTrait(player, "FrostNova") then
        if state.fnActive then
            if now >= state.fnEndTime then
                state.fnActive = false
            end
        elseif now - state.fnLastActivation >= CFG.FROSTNOVA_COOLDOWN then
            if state.zombiesNearMid >= CFG.FROSTNOVA_ZOMBIE_TRIGGER then
                state.fnActive = true
                state.fnLastActivation = now
                state.fnEndTime = now + CFG.FROSTNOVA_DURATION
            end
        end
    else
        state.fnActive = false
    end

    -- -------------------------------------------------------------------------
    -- WHIRLWIND: 3+ zombie vicini → li fa barcollare all'indietro (con cooldown)
    -- -------------------------------------------------------------------------
    if hasTrait(player, "Whirlwind") then
        if now - state.wwLastActivation >= CFG.WHIRLWIND_COOLDOWN then
            if state.zombiesNearClose >= CFG.WHIRLWIND_ZOMBIE_COUNT then
                state.wwLastActivation = now
                forEachNearbyZombie(player, CFG.WHIRLWIND_RADIUS, function(z)
                    z:setStaggerBack(true)
                end)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- BONE SHIELD: check durata scudo attivo
    -- -------------------------------------------------------------------------
    if state.bsActive and now >= state.bsEndTime then
        state.bsActive = false
    end

    -- -------------------------------------------------------------------------
    -- FERAL CHARGE: gestione durata burst
    -- -------------------------------------------------------------------------
    if state.fcActive and now >= state.fcEndTime then
        state.fcActive = false
    end

    -- -------------------------------------------------------------------------
    -- SLICE & DICE: azzera gli stack fuori dalla finestra di combo
    -- -------------------------------------------------------------------------
    if not hasTrait(player, "SliceAndDice")
            or now - state.sdLastHitTime > CFG.SLICEANDDICE_WINDOW then
        state.sdStacks = 0
    end

    refreshSpeeds(player, state, now)

    -- -------------------------------------------------------------------------
    -- IMMOLATION: fuoco vicino → rallenta gli zombie nel raggio
    -- -------------------------------------------------------------------------
    if hasTrait(player, "Immolation") then
        -- La scansione del fuoco (81 tile) è pesante: si esegue throttled
        -- e si usa il risultato in cache tra una scansione e l'altra.
        if now - state.lastFireScan >= CFG.FIRE_SCAN_INTERVAL then
            state.lastFireScan = now
            state.fireNearby = isFireNearby(player, CFG.IMMOLATION_RADIUS)
            if state.fireNearby then
                forEachNearbyZombie(player, CFG.IMMOLATION_RADIUS, function(z)
                    applyTemporaryZombieSlow(z, CFG.IMMOLATION_SLOW_MS, now)
                end)
            end
        end
    end
end

-- =============================================================================
-- ON WEAPON HIT CHARACTER — effetti al momento dell'attacco
-- (in B42 l'evento si chiama OnWeaponHitCharacter, non OnHitCharacter)
-- =============================================================================
local function WoWTraits_OnWeaponHitCharacter(attacker, target, handWeapon, damage)
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    local now = getTimeMs()
    local state = getPlayerState(attacker)

    -- Slice & Dice: combo stack su hit
    if hasTrait(attacker, "SliceAndDice") then
        if now - state.sdLastHitTime <= CFG.SLICEANDDICE_WINDOW then
            state.sdStacks = math.min(state.sdStacks + 1, CFG.SLICEANDDICE_MAX_STACKS)
        else
            state.sdStacks = 1
        end
        state.sdLastHitTime = now
        refreshSpeeds(attacker, state, now)
    end
end

-- =============================================================================
-- ON ZOMBIE DEAD — effetti alla morte di uno zombie
-- =============================================================================
local function WoWTraits_OnZombieDead(zombie)
    if not zombie then return end
    local players = IsoPlayer.getPlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and not player:isDead() then
            local dx = zombie:getX() - player:getX()
            local dy = zombie:getY() - player:getY()
            local dist = math.sqrt(dx * dx + dy * dy)
            local state = getPlayerState(player)

            -- Death Coil: uccidi zombie in mischia → recupera HP
            if hasTrait(player, "DeathCoil") and dist <= 2.0 then
                local bodyDmg = player:getBodyDamage()
                if bodyDmg then
                    local newHP = math.min(bodyDmg:getOverallBodyHealth() + CFG.DEATHCOIL_HEAL_AMOUNT, 100)
                    bodyDmg:setOverallBodyHealth(newHP)
                    state.lastHealth = newHP
                end
            end

            -- Bone Shield: conta le kill
            if hasTrait(player, "BoneShield") and dist <= 3.0 then
                state.bsKillCount = state.bsKillCount + 1
                if state.bsKillCount >= CFG.BONE_SHIELD_KILLS and not state.bsActive then
                    state.bsKillCount = 0
                    state.bsActive = true
                    state.bsEndTime = getTimeMs() + CFG.BONE_SHIELD_DURATION
                end
            end
        end
    end
end

-- =============================================================================
-- FERAL CHARGE: attivato da keypress (tasto F)
-- =============================================================================
local FERAL_CHARGE_KEY = Keyboard.KEY_F
local function WoWTraits_OnKeyPressed(key)
    if key ~= FERAL_CHARGE_KEY then return end
    local player = getPlayer()
    if not player or player:isDead() then return end
    if not hasTrait(player, "FeralCharge") then return end

    local now = getTimeMs()
    local state = getPlayerState(player)
    if now - state.fcLastActivation < CFG.FERALCHARGE_COOLDOWN then
        -- Cooldown non scaduto
        return
    end

    state.fcActive = true
    state.fcLastActivation = now
    state.fcEndTime = now + CFG.FERALCHARGE_DURATION
    refreshSpeeds(player, state, now)
end

-- =============================================================================
-- ON PLAYER DEATH — pulizia dello stato per evitare che buff/cooldown
-- "sopravvivano" in modo inatteso a un nuovo personaggio nella stessa sessione.
-- =============================================================================
local function WoWTraits_OnPlayerDeath(player)
    if not player then return end
    PlayerState[player:getPlayerNum()] = nil
end

-- =============================================================================
-- INIT — risolve gli handle dei tratti e registra tutti gli eventi al boot
-- =============================================================================
local function WoWTraits_Init()
    resolveTraits()
    Events.OnPlayerUpdate.Add(WoWTraits_OnPlayerUpdate)
    Events.OnWeaponHitCharacter.Add(WoWTraits_OnWeaponHitCharacter)
    Events.OnZombieDead.Add(WoWTraits_OnZombieDead)
    Events.OnKeyPressed.Add(WoWTraits_OnKeyPressed)
    Events.OnPlayerDeath.Add(WoWTraits_OnPlayerDeath)
    -- La riduzione danni di Shield Wall / Bone Shield e' calcolata in
    -- WoWTraits_OnPlayerUpdate confrontando l'HP tra tick consecutivi,
    -- perche' PZ non espone un evento diretto con possibilita' di
    -- modificare il danno subito dal player.
    print("[WoWTraits] Mod caricato correttamente. 14 tratti attivi.")
end

Events.OnGameBoot.Add(WoWTraits_Init)
