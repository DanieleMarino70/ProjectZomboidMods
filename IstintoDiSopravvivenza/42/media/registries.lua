-- =============================================================================
-- ISTINTO DI SOPRAVVIVENZA — Registrazione del tratto (Build 42)
-- Questo file viene eseguito dal gioco (ModRegistries) PRIMA del parsing degli
-- script in media/scripts: registra il CharacterTrait custom nel registro
-- "character_trait", così il blocco character_trait_definition in
-- media/scripts/IstintoDiSopravvivenza/traits.txt può referenziarlo.
-- =============================================================================

local TRAIT_ID = "istintodisopravvivenza:trait_survivalinstinct"

-- Evita la doppia registrazione se il file viene rieseguito (reload script)
if CharacterTrait.get(ResourceLocation.of(TRAIT_ID)) == nil then
    CharacterTrait.register(TRAIT_ID)
end

print("[IstintoDiSopravvivenza] registries.lua: tratto registrato nel registro character_trait.")
