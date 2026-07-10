-- =============================================================================
-- WOW TRAITS MOD - Main Script
-- Build 42.19.0 Compatible
-- 14 tratti ispirati a World of Warcraft
-- =============================================================================

WoWTraits = {}

-- =============================================================================
-- COSTANTI DI CONFIGURAZIONE
-- =============================================================================
local CFG = {
    -- Berserker
    BERSERKER_HP_THRESHOLD    = 0.30,   -- 30% HP
    BERSERKER_SPEED_BONUS     = 0.30,   -- +30% velocità
    BERSERKER_ATTACK_BONUS    = 0.30,   -- +30% velocità di attacco

    -- Second Wind
    SECONDWIND_HP_THRESHOLD   = 0.35,   -- 35% HP
    SECONDWIND_REGEN_AMOUNT   = 0.002,  -- HP regen per tick

    -- Shield Wall
    SHIELDWALL_DMG_REDUCTION  = 0.25,   -- 25% riduzione danni

    -- Whirlwind
    WHIRLWIND_ZOMBIE_COUNT    = 3,      -- Zombie minimi per attivare
    WHIRLWIND_RADIUS          = 1.5,    -- Raggio in tile
    WHIRLWIND_PUSH_FORCE      = 3.0,    -- Forza della spinta
    WHIRLWIND_COOLDOWN        = 8000,   -- ms cooldown

    -- Slice & Dice
    SLICEANDDICE_MAX_STACKS   = 5,      -- Massimo stack
    SLICEANDDICE_WINDOW       = 3000,   -- ms finestra combo
    SLICEANDDICE_SPEED_BONUS  = 0.04,   -- +4% per stack

    -- Frost Nova
    FROSTNOVA_ZOMBIE_TRIGGER  = 4,      -- Zombie minimi
    FROSTNOVA_RADIUS          = 3.0,    -- Raggio rilevamento
    FROSTNOVA_SPEED_BONUS     = 0.50,   -- +50% velocità burst
    FROSTNOVA_DURATION        = 4000,   -- ms durata
    FROSTNOVA_COOLDOWN        = 20000,  -- ms cooldown

    -- Immolation
    IMMOLATION_RADIUS         = 4.0,    -- Raggio fuoco
    IMMOLATION_SLOW           = 0.40,   -- Rallentamento zombie 40%

    -- Death Coil
    DEATHCOIL_HEAL_AMOUNT     = 3.0,    -- HP recuperati per kill

    -- Bone Shield
    BONE_SHIELD_KILLS         = 5,      -- Kill per attivare
    BONE_SHIELD_REDUCTION     = 0.30,   -- 30% riduzione danni
    BONE_SHIELD_DURATION      = 15000,  -- ms durata

    -- Detect Traps
    DETECTTRAPS_VISION_BONUS  = 3,      -- Tile extra di visione

    -- Eagle Eye
    EAGLEEYE_VISION_BONUS     = 5,      -- Tile extra di visione

    -- Feral Charge
    FERALCHARGE_SPEED_BONUS   = 0.80,   -- +80% velocità
    FERALCHARGE_DURATION      = 3000,   -- ms durata
    FERALCHARGE_COOLDOWN      = 30000,  -- ms cooldown

    -- Engineer
    ENGINEER_SPEED_BONUS      = 0.15,   -- +15% velocità durante lavoro
}

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
            berserkerActive  = false,

            -- Slice & Dice
            sdLastHitTime    = 0,
            sdStacks         = 0,

            -- Frost Nova
            fnLastActivation = 0,
            fnActive         = false,
            fnEndTime        = 0,

            -- Whirlwind
            wwLastActivation = 0,

            -- Bone Shield
            bsKillCount      = 0,
            bsActive         = false,
            bsEndTime        = 0,

            -- Feral Charge
            fcLastActivation = 0,
            fcActive         = false,
            fcEndTime        = 0,

            -- Shield Wall
            shieldWallActive = false,

            -- Ultimo HP osservato, usato per calcolare i danni subiti nel tick
            -- e applicare la riduzione danni di Shield Wall / Bone Shield.
            lastHealth       = nil,
        }
        PlayerState[idx] = state
    end
    return state
end

-- =============================================================================
-- STATO EFFETTI TEMPORANEI SUGLI ZOMBIE (rallentamento/spinta)
-- Necessario per ripristinare la velocità originale dopo Immolation/Whirlwind,
-- che altrimenti lascerebbero lo zombie rallentato permanentemente.
-- =============================================================================
local ZombieSpeedEffects = {}   -- [zombie] = { originalSpeed = n, expireTime = ms }
local lastZombieCleanup = 0
local ZOMBIE_CLEANUP_INTERVAL = 500 -- ms

local function restoreExpiredZombieSpeeds(now)
    if now - lastZombieCleanup < ZOMBIE_CLEANUP_INTERVAL then return end
    lastZombieCleanup = now
    for zombie, data in pairs(ZombieSpeedEffects) do
        if now >= data.expireTime then
            if zombie and not zombie:isDead() and zombie:getStats() then
                zombie:getStats():setWalkSpeed(data.originalSpeed)
            end
            ZombieSpeedEffects[zombie] = nil
        end
    end
end

local function applyTemporaryZombieSpeed(zombie, speed, durationMs, now)
    local existing = ZombieSpeedEffects[zombie]
    local originalSpeed = existing and existing.originalSpeed or 0.8
    if zombie:getStats() then
        zombie:getStats():setWalkSpeed(speed)
    end
    ZombieSpeedEffects[zombie] = { originalSpeed = originalSpeed, expireTime = now + durationMs }
end

-- =============================================================================
-- UTILITY
-- =============================================================================
local function getTimeMs()
    -- getTimestampMs() e' l'API nativa di PZ per il tempo reale in ms.
    -- Il fallback su os.time()*1000 (tempo reale, risoluzione 1s) e' usato solo
    -- se l'API non fosse disponibile; os.clock() (tempo CPU) e' stato rimosso
    -- perche' non e' adatto a calcolare cooldown di gameplay.
    return getTimestampMs and getTimestampMs() or (os.time() * 1000)
end

local function countNearbyZombies(player, radius)
    local count = 0
    local sq = IsoCell.getInstance()
    if not sq then return 0 end
    local zombies = sq:getZombieList()
    if not zombies then return 0 end
    local px, py = player:getX(), player:getY()
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and not z:isDead() then
            local dx = z:getX() - px
            local dy = z:getY() - py
            if math.sqrt(dx*dx + dy*dy) <= radius then
                count = count + 1
            end
        end
    end
    return count
end

local function isFireNearby(player, radius)
    local sq = IsoCell.getInstance()
    if not sq then return false end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for dx = -math.ceil(radius), math.ceil(radius) do
        for dy = -math.ceil(radius), math.ceil(radius) do
            if math.sqrt(dx*dx + dy*dy) <= radius then
                local tile = sq:getGridSquare(px + dx, py + dy, pz)
                if tile then
                    if tile.isBurning and tile:isBurning() then
                        return true
                    end
                    local objects = tile:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if obj and obj:getType() then
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

-- Durata (ms) del rallentamento/spinta prima che la velocità dello zombie
-- venga ripristinata automaticamente (vedi restoreExpiredZombieSpeeds).
local ZOMBIE_SLOW_REFRESH_MS = 1000
local ZOMBIE_PUSH_STUN_MS    = 800

local function slowNearbyZombies(player, radius, slowFactor, now)
    local sq = IsoCell.getInstance()
    if not sq then return end
    local zombies = sq:getZombieList()
    if not zombies then return end
    local px, py = player:getX(), player:getY()
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and not z:isDead() then
            local dx = z:getX() - px
            local dy = z:getY() - py
            if math.sqrt(dx*dx + dy*dy) <= radius then
                local baseSpeed = 0.8
                local targetSpeed = baseSpeed * (1.0 - slowFactor)
                applyTemporaryZombieSpeed(z, targetSpeed, ZOMBIE_SLOW_REFRESH_MS, now)
            end
        end
    end
end

local function pushNearbyZombies(player, radius, force, now)
    local sq = IsoCell.getInstance()
    if not sq then return end
    local zombies = sq:getZombieList()
    if not zombies then return end
    local px, py = player:getX(), player:getY()
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and not z:isDead() then
            local dx = z:getX() - px
            local dy = z:getY() - py
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 0 and dist <= radius then
                local nx, ny = dx / dist, dy / dist
                z:setX(z:getX() + nx * force * 0.2)
                z:setY(z:getY() + ny * force * 0.2)
                applyTemporaryZombieSpeed(z, 0.1, ZOMBIE_PUSH_STUN_MS, now)
            end
        end
    end
end

local function isHoldingShield(player)
    local primaryHand  = player:getPrimaryHandItem()
    local secondaryHand = player:getSecondaryHandItem()
    local function isShieldItem(item)
        if not item then return false end
        local name = item:getFullType():lower()
        return name:find("shield") ~= nil
    end
    return isShieldItem(primaryHand) or isShieldItem(secondaryHand)
end

-- =============================================================================
-- ON PLAYER UPDATE — logica principale tick per tick
-- =============================================================================
local function WoWTraits_OnPlayerUpdate(player)
    if not player or player:isDead() then return end
    local now = getTimeMs()
    restoreExpiredZombieSpeeds(now)

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then return end

    local state = getPlayerState(player)
    local maxHP = player.getMaxHealth and player:getMaxHealth() or 100
    local curHP = bodyDamage:getOverallBodyHealth()

    -- -------------------------------------------------------------------------
    -- SHIELD WALL / BONE SHIELD: applica la riduzione danni effettiva.
    -- Confrontiamo l'HP con quello osservato al tick precedente: se e' diminuito,
    -- rimborsiamo al giocatore la percentuale di danno assorbita dagli scudi
    -- attivi. Questo sostituisce il flag "WoW_*Active" che in precedenza veniva
    -- impostato ma non letto da nessuna parte.
    -- -------------------------------------------------------------------------
    if state.lastHealth == nil then
        state.lastHealth = curHP
    end
    local damageTaken = state.lastHealth - curHP
    if damageTaken > 0 then
        local reduction = 0.0
        if player:HasTrait("trait_ShieldWall") and state.shieldWallActive then
            reduction = reduction + CFG.SHIELDWALL_DMG_REDUCTION
        end
        if player:HasTrait("trait_BoneShield") and state.bsActive then
            reduction = reduction + CFG.BONE_SHIELD_REDUCTION
        end
        if reduction > 0 then
            reduction = math.min(reduction, 0.75) -- cap a 75% riduzione totale
            local refund = damageTaken * reduction
            curHP = math.min(curHP + refund, maxHP)
            bodyDamage:setOverallBodyHealth(curHP)
        end
    end
    state.lastHealth = curHP

    local hpPct = curHP / maxHP

    -- -------------------------------------------------------------------------
    -- BERSERKER: sotto 30% HP → velocità e attacco aumentano
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Berserker") then
        if hpPct <= CFG.BERSERKER_HP_THRESHOLD then
            if not state.berserkerActive then
                state.berserkerActive = true
            end
            local baseSpeed = stats:getRunSpeed()
            if baseSpeed < 1.0 + CFG.BERSERKER_SPEED_BONUS then
                stats:setRunSpeed(math.min(baseSpeed + 0.01, 1.0 + CFG.BERSERKER_SPEED_BONUS))
            end
        else
            if state.berserkerActive then
                state.berserkerActive = false
                stats:setRunSpeed(1.0)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- SECOND WIND: sotto 35% HP → rigenera HP lentamente
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_SecondWind") then
        if hpPct <= CFG.SECONDWIND_HP_THRESHOLD then
            local regenMult = 1.0 + (CFG.SECONDWIND_HP_THRESHOLD - hpPct) * 3.0
            local regenAmount = CFG.SECONDWIND_REGEN_AMOUNT * regenMult
            local newHP = math.min(curHP + regenAmount, maxHP)
            bodyDamage:setOverallBodyHealth(newHP)
            state.lastHealth = newHP
        end
    end

    -- -------------------------------------------------------------------------
    -- SHIELD WALL: tiene scudo → abilita la riduzione danni sopra
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_ShieldWall") then
        state.shieldWallActive = isHoldingShield(player)
    end

    -- -------------------------------------------------------------------------
    -- FROST NOVA: 4+ zombie vicini → burst di velocità
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_FrostNova") then
        -- Gestione durata buff attivo
        if state.fnActive then
            if now >= state.fnEndTime then
                state.fnActive = false
                stats:setRunSpeed(1.0)
            end
        else
            -- Verifica cooldown e trigger
            if now - state.fnLastActivation >= CFG.FROSTNOVA_COOLDOWN then
                local zombieCount = countNearbyZombies(player, CFG.FROSTNOVA_RADIUS)
                if zombieCount >= CFG.FROSTNOVA_ZOMBIE_TRIGGER then
                    state.fnActive = true
                    state.fnLastActivation = now
                    state.fnEndTime = now + CFG.FROSTNOVA_DURATION
                    stats:setRunSpeed(1.0 + CFG.FROSTNOVA_SPEED_BONUS)
                end
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- WHIRLWIND: 3+ zombie vicini → spinta radiale (con cooldown)
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Whirlwind") then
        if now - state.wwLastActivation >= CFG.WHIRLWIND_COOLDOWN then
            local zombieCount = countNearbyZombies(player, CFG.WHIRLWIND_RADIUS)
            if zombieCount >= CFG.WHIRLWIND_ZOMBIE_COUNT then
                state.wwLastActivation = now
                pushNearbyZombies(player, CFG.WHIRLWIND_RADIUS, CFG.WHIRLWIND_PUSH_FORCE, now)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- BONE SHIELD: check durata scudo attivo
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_BoneShield") then
        if state.bsActive and now >= state.bsEndTime then
            state.bsActive = false
        end
    end

    -- -------------------------------------------------------------------------
    -- FERAL CHARGE: gestione durata burst
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_FeralCharge") then
        if state.fcActive then
            if now >= state.fcEndTime then
                state.fcActive = false
                stats:setRunSpeed(1.0)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- DETECT TRAPS: visione estesa
    -- NOTA: getVisionRadius/setVisionRadius non sono API core documentate di
    -- IsoPlayer in B42; sono protette e, se assenti, viene loggato un avviso
    -- una sola volta invece di fallire silenziosamente.
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_DetectTraps") then
        if player.getVisionRadius and player.setVisionRadius then
            local vis = player:getVisionRadius()
            if vis < 10 + CFG.DETECTTRAPS_VISION_BONUS then
                player:setVisionRadius(10 + CFG.DETECTTRAPS_VISION_BONUS)
            end
        elseif not state.visionApiWarned then
            state.visionApiWarned = true
            print("[WoWTraits] Attenzione: getVisionRadius/setVisionRadius non disponibili in questa build. Detect Traps non applichera' il bonus di visione.")
        end
    end

    -- -------------------------------------------------------------------------
    -- EAGLE EYE: visione estesa (si cumula con Detect Traps se entrambi presi)
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_EagleEye") then
        if player.getVisionRadius and player.setVisionRadius then
            local vis = player:getVisionRadius()
            if vis < 10 + CFG.EAGLEEYE_VISION_BONUS then
                player:setVisionRadius(10 + CFG.EAGLEEYE_VISION_BONUS)
            end
        elseif not state.visionApiWarned then
            state.visionApiWarned = true
            print("[WoWTraits] Attenzione: getVisionRadius/setVisionRadius non disponibili in questa build. Eagle Eye non applichera' il bonus di visione.")
        end
    end

    -- -------------------------------------------------------------------------
    -- IMMOLATION: fuoco vicino → rallenta zombie nel raggio
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Immolation") then
        if isFireNearby(player, CFG.IMMOLATION_RADIUS) then
            slowNearbyZombies(player, CFG.IMMOLATION_RADIUS, CFG.IMMOLATION_SLOW, now)
        end
    end
end

-- =============================================================================
-- ON HIT CHARACTER — effetti al momento dell'attacco
-- =============================================================================
local function WoWTraits_OnHitCharacter(attacker, target, handWeapon, damage)
    if not attacker or not attacker.HasTrait then return end
    local now = getTimeMs()
    local state = getPlayerState(attacker)

    -- Slice & Dice: combo stack su hit
    if attacker:HasTrait("trait_SliceAndDice") then
        if now - state.sdLastHitTime <= CFG.SLICEANDDICE_WINDOW then
            state.sdStacks = math.min(state.sdStacks + 1, CFG.SLICEANDDICE_MAX_STACKS)
        else
            state.sdStacks = 1
        end
        state.sdLastHitTime = now
        local bonus = state.sdStacks * CFG.SLICEANDDICE_SPEED_BONUS
        local stats = attacker:getStats()
        if stats then
            stats:setRunSpeed(math.min(1.0 + bonus, 1.0 + CFG.SLICEANDDICE_MAX_STACKS * CFG.SLICEANDDICE_SPEED_BONUS))
        end
    end
end

-- =============================================================================
-- ON ZOMBIE DEAD — effetti alla morte di uno zombie
-- =============================================================================
local function WoWTraits_OnZombieDead(zombie)
    local players = getActivePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if not player or player:isDead() then goto continue end

        local dx = zombie:getX() - player:getX()
        local dy = zombie:getY() - player:getY()
        local dist = math.sqrt(dx*dx + dy*dy)
        local state = getPlayerState(player)

        -- Death Coil: uccidi zombie in mischia → recupera HP
        if player:HasTrait("trait_DeathCoil") then
            if dist <= 2.0 then
                local bodyDmg = player:getBodyDamage()
                local maxHP = player.getMaxHealth and player:getMaxHealth() or 100
                if bodyDmg then
                    local newHP = math.min(bodyDmg:getOverallBodyHealth() + CFG.DEATHCOIL_HEAL_AMOUNT, maxHP)
                    bodyDmg:setOverallBodyHealth(newHP)
                    state.lastHealth = newHP
                end
            end
        end

        -- Bone Shield: conta le kill
        if player:HasTrait("trait_BoneShield") then
            if dist <= 3.0 then
                state.bsKillCount = state.bsKillCount + 1
                if state.bsKillCount >= CFG.BONE_SHIELD_KILLS and not state.bsActive then
                    state.bsKillCount = 0
                    state.bsActive = true
                    state.bsEndTime = getTimeMs() + CFG.BONE_SHIELD_DURATION
                end
            end
        end

        ::continue::
    end
end

-- =============================================================================
-- FERAL CHARGE: attivato da keypress (tasto Sprint extra)
-- Usiamo OnKeyPressed per intercettare il tasto F (key 33 default)
-- =============================================================================
local FERAL_CHARGE_KEY = Keyboard.KEY_F  -- tasto F
local function WoWTraits_OnKeyPressed(key)
    if key ~= FERAL_CHARGE_KEY then return end
    local player = getPlayer()
    if not player or player:isDead() then return end
    if not player:HasTrait("trait_FeralCharge") then return end

    local now = getTimeMs()
    local state = getPlayerState(player)
    if now - state.fcLastActivation < CFG.FERALCHARGE_COOLDOWN then
        -- Cooldown non scaduto
        return
    end

    state.fcActive = true
    state.fcLastActivation = now
    state.fcEndTime = now + CFG.FERALCHARGE_DURATION
    player:getStats():setRunSpeed(1.0 + CFG.FERALCHARGE_SPEED_BONUS)
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
-- INIT — registra tutti gli eventi al boot
-- =============================================================================
local function WoWTraits_Init()
    Events.OnPlayerUpdate.Add(WoWTraits_OnPlayerUpdate)
    Events.OnHitCharacter.Add(WoWTraits_OnHitCharacter)
    Events.OnZombieDead.Add(WoWTraits_OnZombieDead)
    Events.OnKeyPressed.Add(WoWTraits_OnKeyPressed)
    Events.OnPlayerDeath.Add(WoWTraits_OnPlayerDeath)
    -- La riduzione danni di Shield Wall / Bone Shield e' calcolata in
    -- WoWTraits_OnPlayerUpdate confrontando l'HP tra tick consecutivi,
    -- perche' PZ non espone un evento diretto "OnHitByCharacter" con
    -- possibilita' di modificare il danno subito dal player.
    print("[WoWTraits] Mod caricato correttamente. 14 tratti attivi.")
end

Events.OnGameBoot.Add(WoWTraits_Init)
