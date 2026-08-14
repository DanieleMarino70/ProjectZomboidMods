-- =============================================================================
-- SURVIVAL INSTINCT — Registrazione del tratto (Build 42)
-- Questo file viene eseguito dal gioco (ModRegistries) PRIMA del parsing degli
-- script in media/scripts: registra il CharacterTrait custom nel registro
-- "character_trait", così il blocco character_trait_definition in
-- media/scripts/SurvivalInstinct/traits.txt può referenziarlo.
--
-- ATTENZIONE: questo ID deve restare identico in tre punti:
--   1. qui
--   2. media/scripts/SurvivalInstinct/traits.txt (nome del blocco + campo
--      CharacterTrait)
--   3. media/lua/client/SurvivalInstinct.lua (costante TRAIT_ID)
-- Il namespace corrisponde al nome del module in traits.txt, in minuscolo
-- (come vanilla: "module Base" -> "base:").
-- =============================================================================

local TRAIT_ID = "survivalinstinct:trait_survivalinstinct"

-- Evita la doppia registrazione se il file viene rieseguito (reload script)
if CharacterTrait.get(ResourceLocation.of(TRAIT_ID)) == nil then
    CharacterTrait.register(TRAIT_ID)
end

print("[SurvivalInstinct] registries.lua: tratto registrato nel registro character_trait.")
