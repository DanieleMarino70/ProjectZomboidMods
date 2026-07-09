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
-- STATO INTERNO DEI TRAIT (per player)
-- =============================================================================
local TraitState = {
    -- Berserker
    berserkerActive      = false,

    -- Slice & Dice
    sdLastHitTime        = 0,
    sdStacks             = 0,

    -- Frost Nova
    fnLastActivation     = 0,
    fnActive             = false,
    fnEndTime            = 0,

    -- Whirlwind
    wwLastActivation     = 0,

    -- Bone Shield
    bsKillCount          = 0,
    bsActive             = false,
    bsEndTime            = 0,

    -- Feral Charge
    fcLastActivation     = 0,
    fcActive             = false,
    fcEndTime            = 0,
}

-- =============================================================================
-- UTILITY
-- =============================================================================
local function getTimeMs()
    return getTimestampMs and getTimestampMs() or (os.clock() * 1000)
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
                    local objects = tile:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if obj and obj:getType() then
                                local typeName = tostring(obj:getType())
                                if typeName:find("Fire") or typeName:find("fire") then
                                    return true
                                end
                            end
                        end
                    end
                    if tile:isBurning and tile:isBurning() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function slowNearbyZombies(player, radius, slowFactor)
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
                if z:getStats() then
                    z:getStats():setWalkSpeed(targetSpeed)
                end
            end
        end
    end
end

local function pushNearbyZombies(player, radius, force)
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
                if z:getStats() then
                    z:getStats():setWalkSpeed(0.1)
                end
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

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then return end

    local maxHP = player:getMaxHealth and player:getMaxHealth() or 100
    local curHP = bodyDamage:getOverallBodyHealth()
    local hpPct = curHP / maxHP

    -- -------------------------------------------------------------------------
    -- BERSERKER: sotto 30% HP → velocità e attacco aumentano
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Berserker") then
        if hpPct <= CFG.BERSERKER_HP_THRESHOLD then
            if not TraitState.berserkerActive then
                TraitState.berserkerActive = true
            end
            local baseSpeed = stats:getRunSpeed()
            if baseSpeed < 1.0 + CFG.BERSERKER_SPEED_BONUS then
                stats:setRunSpeed(math.min(baseSpeed + 0.01, 1.0 + CFG.BERSERKER_SPEED_BONUS))
            end
        else
            if TraitState.berserkerActive then
                TraitState.berserkerActive = false
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
        end
    end

    -- -------------------------------------------------------------------------
    -- SHIELD WALL: tiene scudo → riduzione danni (applicata tramite modifier)
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_ShieldWall") then
        if isHoldingShield(player) then
            -- Il danno ridotto viene gestito in OnHitByCharacter (vedi sotto)
            -- Qui semplicemente aggiorniamo un flag
            player:getModData()["WoW_ShieldWallActive"] = true
        else
            player:getModData()["WoW_ShieldWallActive"] = false
        end
    end

    -- -------------------------------------------------------------------------
    -- FROST NOVA: 4+ zombie vicini → burst di velocità
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_FrostNova") then
        -- Gestione durata buff attivo
        if TraitState.fnActive then
            if now >= TraitState.fnEndTime then
                TraitState.fnActive = false
                stats:setRunSpeed(1.0)
            end
        else
            -- Verifica cooldown e trigger
            if now - TraitState.fnLastActivation >= CFG.FROSTNOVA_COOLDOWN then
                local zombieCount = countNearbyZombies(player, CFG.FROSTNOVA_RADIUS)
                if zombieCount >= CFG.FROSTNOVA_ZOMBIE_TRIGGER then
                    TraitState.fnActive = true
                    TraitState.fnLastActivation = now
                    TraitState.fnEndTime = now + CFG.FROSTNOVA_DURATION
                    stats:setRunSpeed(1.0 + CFG.FROSTNOVA_SPEED_BONUS)
                end
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- WHIRLWIND: 3+ zombie vicini → spinta radiale (con cooldown)
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Whirlwind") then
        if now - TraitState.wwLastActivation >= CFG.WHIRLWIND_COOLDOWN then
            local zombieCount = countNearbyZombies(player, CFG.WHIRLWIND_RADIUS)
            if zombieCount >= CFG.WHIRLWIND_ZOMBIE_COUNT then
                TraitState.wwLastActivation = now
                pushNearbyZombies(player, CFG.WHIRLWIND_RADIUS, CFG.WHIRLWIND_PUSH_FORCE)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- BONE SHIELD: check durata scudo attivo
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_BoneShield") then
        if TraitState.bsActive and now >= TraitState.bsEndTime then
            TraitState.bsActive = false
            player:getModData()["WoW_BoneShieldActive"] = false
        end
    end

    -- -------------------------------------------------------------------------
    -- FERAL CHARGE: gestione durata burst
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_FeralCharge") then
        if TraitState.fcActive then
            if now >= TraitState.fcEndTime then
                TraitState.fcActive = false
                stats:setRunSpeed(1.0)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- DETECT TRAPS: visione estesa
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_DetectTraps") then
        local vis = player:getVisionRadius and player:getVisionRadius() or 10
        if vis < 10 + CFG.DETECTTRAPS_VISION_BONUS then
            if player.setVisionRadius then
                player:setVisionRadius(10 + CFG.DETECTTRAPS_VISION_BONUS)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- EAGLE EYE: visione estesa (si cumula con Detect Traps se entrambi presi)
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_EagleEye") then
        local vis = player:getVisionRadius and player:getVisionRadius() or 10
        if vis < 10 + CFG.EAGLEEYE_VISION_BONUS then
            if player.setVisionRadius then
                player:setVisionRadius(10 + CFG.EAGLEEYE_VISION_BONUS)
            end
        end
    end

    -- -------------------------------------------------------------------------
    -- IMMOLATION: fuoco vicino → rallenta zombie nel raggio
    -- -------------------------------------------------------------------------
    if player:HasTrait("trait_Immolation") then
        if isFireNearby(player, CFG.IMMOLATION_RADIUS) then
            slowNearbyZombies(player, CFG.IMMOLATION_RADIUS, CFG.IMMOLATION_SLOW)
        end
    end
end

-- =============================================================================
-- ON HIT CHARACTER — effetti al momento dell'attacco
-- =============================================================================
local function WoWTraits_OnHitCharacter(attacker, target, handWeapon, damage)
    if not attacker or not attacker.HasTrait then return end
    local now = getTimeMs()

    -- Slice & Dice: combo stack su hit
    if attacker:HasTrait("trait_SliceAndDice") then
        if now - TraitState.sdLastHitTime <= CFG.SLICEANDDICE_WINDOW then
            TraitState.sdStacks = math.min(TraitState.sdStacks + 1, CFG.SLICEANDDICE_MAX_STACKS)
        else
            TraitState.sdStacks = 1
        end
        TraitState.sdLastHitTime = now
        local bonus = TraitState.sdStacks * CFG.SLICEANDDICE_SPEED_BONUS
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

        -- Death Coil: uccidi zombie in mischia → recupera HP
        if player:HasTrait("trait_DeathCoil") then
            if dist <= 2.0 then
                local bodyDmg = player:getBodyDamage()
                local maxHP = player:getMaxHealth and player:getMaxHealth() or 100
                if bodyDmg then
                    local newHP = math.min(bodyDmg:getOverallBodyHealth() + CFG.DEATHCOIL_HEAL_AMOUNT, maxHP)
                    bodyDmg:setOverallBodyHealth(newHP)
                end
            end
        end

        -- Bone Shield: conta le kill
        if player:HasTrait("trait_BoneShield") then
            if dist <= 3.0 then
                TraitState.bsKillCount = TraitState.bsKillCount + 1
                if TraitState.bsKillCount >= CFG.BONE_SHIELD_KILLS and not TraitState.bsActive then
                    TraitState.bsKillCount = 0
                    TraitState.bsActive = true
                    TraitState.bsEndTime = getTimeMs() + CFG.BONE_SHIELD_DURATION
                    player:getModData()["WoW_BoneShieldActive"] = true
                end
            end
        end

        ::continue::
    end
end

-- =============================================================================
-- ON BEFORE PLAYER DIE / ON DAMAGED — riduzione danni (Shield Wall, Bone Shield)
-- =============================================================================
local function WoWTraits_OnHitByCharacter(attacker, player, handWeapon, damage)
    if not player or not player.HasTrait then return damage end

    local reduction = 0.0

    -- Shield Wall
    if player:HasTrait("trait_ShieldWall") then
        if player:getModData()["WoW_ShieldWallActive"] then
            reduction = reduction + CFG.SHIELDWALL_DMG_REDUCTION
        end
    end

    -- Bone Shield
    if player:HasTrait("trait_BoneShield") then
        if player:getModData()["WoW_BoneShieldActive"] then
            reduction = reduction + CFG.BONE_SHIELD_REDUCTION
        end
    end

    if reduction > 0 then
        return damage * (1.0 - math.min(reduction, 0.75)) -- cap a 75% riduzione totale
    end
    return damage
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
    if now - TraitState.fcLastActivation < CFG.FERALCHARGE_COOLDOWN then
        -- Cooldown non scaduto
        return
    end

    TraitState.fcActive = true
    TraitState.fcLastActivation = now
    TraitState.fcEndTime = now + CFG.FERALCHARGE_DURATION
    player:getStats():setRunSpeed(1.0 + CFG.FERALCHARGE_SPEED_BONUS)
end

-- =============================================================================
-- INIT — registra tutti gli eventi al boot
-- =============================================================================
local function WoWTraits_Init()
    Events.OnPlayerUpdate.Add(WoWTraits_OnPlayerUpdate)
    Events.OnHitCharacter.Add(WoWTraits_OnHitCharacter)
    Events.OnZombieDead.Add(WoWTraits_OnZombieDead)
    Events.OnKeyPressed.Add(WoWTraits_OnKeyPressed)
    -- OnHitByCharacter non esiste come evento diretto in PZ:
    -- la riduzione danni di ShieldWall/BoneShield è gestita
    -- via modData controllato in OnPlayerUpdate
    print("[WoWTraits] Mod caricato correttamente. 14 tratti attivi.")
end

Events.OnGameBoot.Add(WoWTraits_Init)
