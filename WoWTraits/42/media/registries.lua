-- =============================================================================
-- WOW TRAITS — Registrazione dei tratti (Build 42)
-- Questo file viene eseguito dal gioco (ModRegistries) PRIMA del parsing degli
-- script in media/scripts: registra i CharacterTrait custom nel registro
-- "character_trait", così i blocchi character_trait_definition in
-- media/scripts/WoWTraits/traits.txt possono referenziarli.
-- Senza questa registrazione il gioco scarta le definizioni con
-- "removing script due to load error".
-- =============================================================================

local TRAIT_IDS = {
    "wowtraits:trait_berserker",
    "wowtraits:trait_secondwind",
    "wowtraits:trait_shieldwall",
    "wowtraits:trait_whirlwind",
    "wowtraits:trait_sliceanddice",
    "wowtraits:trait_frostnova",
    "wowtraits:trait_arcaneintellect",
    "wowtraits:trait_immolation",
    "wowtraits:trait_deathcoil",
    "wowtraits:trait_boneshield",
    "wowtraits:trait_detecttraps",
    "wowtraits:trait_eagleeye",
    "wowtraits:trait_feralcharge",
    "wowtraits:trait_engineer",
}

for _, id in ipairs(TRAIT_IDS) do
    -- Evita la doppia registrazione se il file viene rieseguito (reload script)
    if CharacterTrait.get(ResourceLocation.of(id)) == nil then
        CharacterTrait.register(id)
    end
end

print("[WoWTraits] registries.lua: registrati " .. #TRAIT_IDS .. " tratti nel registro character_trait.")
