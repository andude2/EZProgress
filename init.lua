--[[
    ezprogress
    Tracks configured armor-set completion and shares status via actors.
]]

local mq = require('mq')
local ImGui = require('ImGui')
local actors = require('actors')

local loaded_script_name = 'ezprogress'
local source = debug.getinfo(1, 'S').source or ''
if source:find('EZProgress') then
    loaded_script_name = 'EZProgress'
elseif source:find('ezprogress') then
    loaded_script_name = 'ezprogress'
end

local SCRIPT_NAME = loaded_script_name
local WINDOW_NAME = 'EZProgress'
local HEADER = '\ay[\agEZProgress\ay]'
local REFRESH_INTERVAL_US = 3000000
local PUBLISH_INTERVAL_US = 30000000
local STALE_PEER_TIMEOUT_US = 180000000
local FRAME_ROUNDING = 8
local POPUP_ROUNDING = 8
local WINDOW_ROUNDING = 10

local COLOR_COMPLETE = { 0.25, 0.85, 0.40, 1.00 }
local COLOR_INCOMPLETE = { 0.95, 0.35, 0.35, 1.00 }
local COLOR_WARN = { 0.95, 0.85, 0.35, 1.00 }
local COLOR_MUTED = { 0.65, 0.65, 0.65, 1.00 }
local COLOR_HEADER = { 0.65, 0.85, 1.00, 1.00 }
local COLOR_COMPONENTS = { 0.95, 0.55, 0.20, 1.00 }
local DEFAULT_TIER_KEY = 'Tier 12'
local FACTION_AUTO_CONSIDER_INTERVAL_US = 30000000
local FACTION_TARGETS = {
    ['stone sergeant grognir'] = {
        name = 'Stone Sergeant Grognir',
        faction_name = 'Faydwer Alliance',
        zone = 'sunderock',
    },
    ['grand summoner agwin'] = {
        name = 'Grand Summoner Agwin',
        faction_name = 'Indigo Vanguard',
    },
    ['warlord asmodae'] = {
        name = 'Warlord Asmodae',
        faction_name = 'Cabilis Foreign Legion',
    },
}
local FACTION_RANK_TO_SLOT = {
    Dubious = 'Feet',
    Apprehensive = 'Wrist',
    Indifferent = 'Head',
    Amiable = 'Hands',
    Kindly = 'Arms',
    Warmly = 'Legs',
    Ally = 'Chest',
}
local TIER_10_FACTION_CHOICES = {
    {
        key = 'Faydwer Alliance',
        label = 'Orc (Faydwer)',
        target_name = 'Stone Sergeant Grognir',
    },
    {
        key = 'Indigo Vanguard',
        label = 'Goblin (Indigo)',
        target_name = 'Grand Summoner Agwin',
    },
    {
        key = 'Cabilis Foreign Legion',
        label = 'Sarnak (Cabilis)',
        target_name = 'Warlord Asmodae',
    },
}
local DEFAULT_TIER_10_FACTION = 'Faydwer Alliance'

local function make_piece_def(name, slot_name, alternates)
    return {
        name = name,
        slot = slot_name,
        alternates = alternates or {},
    }
end

local BLIGHTFORGED_PLATE_PIECES = {
    make_piece_def('Plate Helmet of the Blightforged Warlord', 'Head', { 'Reforged Plate Helmet of the Blightforged Warlord' }),
    make_piece_def('Breastplate of the Blightforged Warlord', 'Chest', { 'Reforged Breastplate of the Blightforged Warlord' }),
    make_piece_def('Plate Armguards of the Blightforged Warlord', 'Arms', { 'Reforged Plate Armguards of the Blightforged Warlord' }),
    make_piece_def('Legplates of the Blightforged Warlord', 'Legs', { 'Reforged Legplates of the Blightforged Warlord' }),
    make_piece_def('Plate Handguards of the Blightforged Warlord', 'Hands', { 'Reforged Plate Handguards of the Blightforged Warlord' }),
    make_piece_def('Plate Wristguards of the Blightforged Warlord', 'Wrist', {
        'Reforged Plate Wristguards of the Blightforged Warlord',
        'Reforged Bracer of the Blightforged Warlord',
    }),
    make_piece_def('Plate Sabatons of the Blightforged Warlord', 'Feet', { 'Reforged Plate Sabatons of the Blightforged Warlord' }),
}
local ROTFANG_CHAIN_PIECES = {
    make_piece_def('Chain Helmet of the Rotfang Hunter', 'Head', { 'Hardened Chain Helmet of the Rotfang Hunter' }),
    make_piece_def('Chain Armguards of the Rotfang Hunter', 'Arms', { 'Hardened Chain Armguards of the Rotfang Hunter' }),
    make_piece_def('Chain Handguards of the Rotfang Hunter', 'Hands', { 'Hardened Chain Handguards of the Rotfang Hunter' }),
    make_piece_def('Chain Sabatons of the Rotfang Hunter', 'Feet', { 'Hardened Chain Sabatons of the Rotfang Hunter' }),
    make_piece_def('Chain Hauberk of the Rotfang Hunter', 'Chest', { 'Hardened Chain Hauberk of the Rotfang Hunter' }),
    make_piece_def('Chain Legguards of the Rotfang Hunter', 'Legs', { 'Hardened Chain Legguards of the Rotfang Hunter' }),
    make_piece_def('Chain Wristguards of the Rotfang Hunter', 'Wrist', { 'Hardened Chain Wristguards of the Rotfang Hunter' }),
}
local MOORSHADE_SILK_PIECES = {
    make_piece_def('Silk Crown of the Moorshade Magus', 'Head', { 'Gusseted Silk Crown of the Moorshade Magus' }),
    make_piece_def('Silk Sleeves of the Moorshade Magus', 'Arms', { 'Gusseted Silk Sleeves of the Moorshade Magus' }),
    make_piece_def('Silk Gloves of the Moorshade Magus', 'Hands', { 'Gusseted Silk Gloves of the Moorshade Magus' }),
    make_piece_def('Silk Wristguards of the Moorshade Magus', 'Wrist', { 'Gusseted Silk Wristguards of the Moorshade Magus' }),
    make_piece_def('Silk Slippers of the Moorshade Magus', 'Feet', { 'Gusseted Silk Slippers of the Moorshade Magus' }),
    make_piece_def('Silk Robes of the Moorshade Magus', 'Chest', { 'Gusseted Silk Robes of the Moorshade Magus' }),
    make_piece_def('Silk Leggings of the Moorshade Magus', 'Legs', { 'Gusseted Silk Leggings of the Moorshade Magus' }),
}
local BLIGHTCLAW_LEATHER_PIECES = {
    make_piece_def('Leather Hood of the Blightclaw Stalker', 'Head', { 'Reinforced Leather Hood of the Blightclaw Stalker' }),
    make_piece_def('Leather Sleeves of the Blightclaw Stalker', 'Arms', { 'Reinforced Leather Sleeves of the Blightclaw Stalker' }),
    make_piece_def('Leather Grasp of the Blightclaw Stalker', 'Hands', { 'Reinforced Leather Grasp of the Blightclaw Stalker' }),
    make_piece_def('Leather Boots of the Blightclaw Stalker', 'Feet', { 'Reinforced Leather Boots of the Blightclaw Stalker' }),
    make_piece_def('Leather Vest of the Blightclaw Stalker', 'Chest', { 'Reinforced Leather Vest of the Blightclaw Stalker' }),
    make_piece_def('Leather Leggings of the Blightclaw Stalker', 'Legs', { 'Reinforced Leather Leggings of the Blightclaw Stalker' }),
    make_piece_def('Leather Bindings of the Blightclaw Stalker', 'Wrist', { 'Reinforced Leather Bindings of the Blightclaw Stalker' }),
}
local TORMAX_PLATE_PIECES = {
    'Plate Helmet of King Tormax',
    'Plate Armguards of King Tormax',
    'Plate Handguards of King Tormax',
    'Plate Sabatons of King Tormax',
    'Breastplate of King Tormax',
    'Legplates of King Tormax',
    'Plate Wristguards of King Tormax',
}
local FJORDAVIND_CHAIN_PIECES = {
    'Chain Helmet of Fjordavind the Fearless',
    'Chain Armguards of Fjordavind the Fearless',
    'Chain Handguards of Fjordavind the Fearless',
    'Chain Sabatons of Fjordavind the Fearless',
    'Chain Hauberk of Fjordavind the Fearless',
    'Chain Legguards of Fjordavind the Fearless',
    'Chain Bindings of Fjordavind the Fearless',
}
local VELKETOR_SILK_PIECES = {
    'Silk Crown of Velketor the Sorcerer',
    'Silk Sleeves of Velketor the Sorcerer',
    'Silk Gloves of Velketor the Sorcerer',
    'Silk Wristguards of Velketor the Sorcerer',
    'Silk Slippers of Velketor the Sorcerer',
    'Silk Robes of Velketor the Sorcerer',
    'Silk Leggings of Velketor the Sorcerer',
}
local RAGNAR_LEATHER_PIECES = {
    'Leather Hood of Ragnar Fjordason',
    'Leather Sleeves of Ragnar Fjordason',
    'Leather Grasps of Ragnar Fjordason',
    'Leather Boots of Ragnar Fjordason',
    'Leather Vest of Ragnar Fjordason',
    'Leather Leggings of Ragnar Fjordason',
    'Leather Bindings of Ragnar Fjordason',
}
local KORMAX_PLATE_PATTERNS = {
    Head = 'Kael Plate Head Pattern',
    Chest = 'Kael Plate Chest Pattern',
    Arms = 'Kael Plate Arms Pattern',
    Wrist = 'Kael Plate Wrist Pattern',
    Legs = 'Kael Plate Legs Pattern',
    Hands = 'Kael Plate Hands Pattern',
    Feet = 'Kael Plate Feet Pattern',
}
local KORMAX_LEATHER_PATTERNS = {
    Head = 'Kael Leather Head Pattern',
    Chest = 'Kael Leather Chest Pattern',
    Arms = 'Kael Leather Arms Pattern',
    Wrist = 'Kael Leather Wrist Pattern',
    Legs = 'Kael Leather Legs Pattern',
    Hands = 'Kael Leather Hands Pattern',
    Feet = 'Kael Leather Feet Pattern',
}
local KORMAX_SILK_PATTERNS = {
    Head = 'Kael Silk Head Pattern',
    Chest = 'Kael Silk Chest Pattern',
    Arms = 'Kael Silk Arms Pattern',
    Wrist = 'Kael Silk Wrist Pattern',
    Legs = 'Kael Silk Legs Pattern',
    Hands = 'Kael Silk Hands Pattern',
    Feet = 'Kael Silk Feet Pattern',
}
local KORMAX_CHAIN_PATTERNS = {
    Head = 'Kael Chain Head Pattern',
    Chest = 'Kael Chain Chest Pattern',
    Arms = 'Kael Chain Arms Pattern',
    Wrist = 'Kael Chain Wrist Pattern',
    Legs = 'Kael Chain Legs Pattern',
    Hands = 'Kael Chain Hands Pattern',
    Feet = 'Kael Chain Feet Pattern',
}
local TIER_11_COMPONENTS = {
    major = 'Major Drakkel Shard',
    minor = 'Minor Drakkel Shard',
    water = 'Cooled Drakkel Water',
}
local TIER_11_COMPONENT_REQUIREMENTS = {
    Chest = { major = 5, minor = 2, water = 1 },
    Legs = { major = 4, minor = 2, water = 1 },
    Arms = { major = 3, minor = 1, water = 3 },
    Hands = { major = 3, minor = 1, water = 3 },
    Head = { major = 2, minor = 2, water = 3 },
    Wrist = { major = 1, minor = 2, water = 4 },
    Feet = { major = 1, minor = 2, water = 4 },
}
local TIER_10_PLATE_SET_TEMPLATES = {
    ['Faydwer Alliance'] = {
        set_name = 'Brutish Enforcer',
        pieces = {
            make_piece_def('Helm of the Brutish Enforcer', 'Head'),
            make_piece_def('Cuirass of the Brutish Enforcer', 'Chest'),
            make_piece_def('Vambraces of the Brutish Enforcer', 'Arms'),
            make_piece_def('Wristplates of the Brutish Enforcer', 'Wrist'),
            make_piece_def('Greaves of the Brutish Enforcer', 'Legs'),
            make_piece_def('Gauntlets of the Brutish Enforcer', 'Hands'),
            make_piece_def('Boots of the Brutish Enforcer', 'Feet'),
        },
    },
    ['Indigo Vanguard'] = {
        set_name = 'Cunning Brawler',
        pieces = {
            make_piece_def('Helm of the Cunning Brawler', 'Head'),
            make_piece_def('Cuirass of the Cunning Brawler', 'Chest'),
            make_piece_def('Vambraces of the Cunning Brawler', 'Arms'),
            make_piece_def('Wristplates of the Cunning Brawler', 'Wrist'),
            make_piece_def('Greaves of the Cunning Brawler', 'Legs'),
            make_piece_def('Gauntlets of the Cunning Brawler', 'Hands'),
            make_piece_def('Boots of the Cunning Brawler', 'Feet'),
        },
    },
    ['Cabilis Foreign Legion'] = {
        set_name = 'Imposing Sentinel',
        pieces = {
            make_piece_def('Helm of the Imposing Sentinel', 'Head'),
            make_piece_def('Cuirass of the Imposing Sentinel', 'Chest'),
            make_piece_def('Vambraces of the Imposing Sentinel', 'Arms'),
            make_piece_def('Wristplates of the Imposing Sentinel', 'Wrist'),
            make_piece_def('Greaves of the Imposing Sentinel', 'Legs'),
            make_piece_def('Gauntlets of the Imposing Sentinel', 'Hands'),
            make_piece_def('Boots of the Imposing Sentinel', 'Feet'),
        },
    },
}
local TIER_10_CHAIN_SET_TEMPLATES = {
    ['Faydwer Alliance'] = {
        set_name = 'Feral Enforcer',
        pieces = {
            make_piece_def('Crown of the Feral Enforcer', 'Head'),
            make_piece_def('Mail of the Feral Enforcer', 'Chest'),
            make_piece_def('Armguards of the Feral Enforcer', 'Arms'),
            make_piece_def('Wristguards of the Feral Enforcer', 'Wrist'),
            make_piece_def('Greaves of the Feral Enforcer', 'Legs'),
            make_piece_def('Mitts of the Feral Enforcer', 'Hands'),
            make_piece_def('Boots of the Feral Enforcer', 'Feet'),
        },
    },
    ['Indigo Vanguard'] = {
        set_name = 'Crafty Brawler',
        pieces = {
            make_piece_def('Crown of the Crafty Brawler', 'Head'),
            make_piece_def('Mail of the Crafty Brawler', 'Chest'),
            make_piece_def('Armguards of the Crafty Brawler', 'Arms'),
            make_piece_def('Wristguards of the Crafty Brawler', 'Wrist'),
            make_piece_def('Greaves of the Crafty Brawler', 'Legs'),
            make_piece_def('Mitts of the Crafty Brawler', 'Hands'),
            make_piece_def('Boots of the Crafty Brawler', 'Feet'),
        },
    },
    ['Cabilis Foreign Legion'] = {
        set_name = 'Towering Sentinel',
        pieces = {
            make_piece_def('Crown of the Towering Sentinel', 'Head'),
            make_piece_def('Mail of the Towering Sentinel', 'Chest'),
            make_piece_def('Armguards of the Towering Sentinel', 'Arms'),
            make_piece_def('Wristguards of the Towering Sentinel', 'Wrist'),
            make_piece_def('Greaves of the Towering Sentinel', 'Legs'),
            make_piece_def('Mitts of the Towering Sentinel', 'Hands'),
            make_piece_def('Boots of the Towering Sentinel', 'Feet'),
        },
    },
}
local TIER_10_LEATHER_SET_TEMPLATES = {
    ['Faydwer Alliance'] = {
        set_name = 'Bestial Enforcer',
        pieces = {
            make_piece_def('Skullcap of the Bestial Enforcer', 'Head'),
            make_piece_def('Robe of the Bestial Enforcer', 'Chest'),
            make_piece_def('Sleeves of the Bestial Enforcer', 'Arms'),
            make_piece_def('Wristwraps of the Bestial Enforcer', 'Wrist'),
            make_piece_def('Pantaloons of the Bestial Enforcer', 'Legs'),
            make_piece_def('Gloves of the Bestial Enforcer', 'Hands'),
            make_piece_def('Boots of the Bestial Enforcer', 'Feet'),
        },
    },
    ['Indigo Vanguard'] = {
        set_name = 'Shifty Brawler',
        pieces = {
            make_piece_def('Skullcap of the Shifty Brawler', 'Head'),
            make_piece_def('Robe of the Shifty Brawler', 'Chest'),
            make_piece_def('Sleeves of the Shifty Brawler', 'Arms'),
            make_piece_def('Wristwraps of the Shifty Brawler', 'Wrist'),
            make_piece_def('Pantaloons of the Shifty Brawler', 'Legs'),
            make_piece_def('Gloves of the Shifty Brawler', 'Hands'),
            make_piece_def('Boots of the Shifty Brawler', 'Feet'),
        },
    },
    ['Cabilis Foreign Legion'] = {
        set_name = 'Ominous Sentinel',
        pieces = {
            make_piece_def('Skullcap of the Ominous Sentinel', 'Head'),
            make_piece_def('Robe of the Ominous Sentinel', 'Chest'),
            make_piece_def('Sleeves of the Ominous Sentinel', 'Arms'),
            make_piece_def('Wristwraps of the Ominous Sentinel', 'Wrist'),
            make_piece_def('Pantaloons of the Ominous Sentinel', 'Legs'),
            make_piece_def('Gloves of the Ominous Sentinel', 'Hands'),
            make_piece_def('Boots of the Ominous Sentinel', 'Feet'),
        },
    },
}
local TIER_10_CLOTH_SET_TEMPLATES = {
    ['Faydwer Alliance'] = {
        set_name = 'Corporeal Enforcer',
        pieces = {
            make_piece_def('Cowl of the Corporeal Enforcer', 'Head'),
            make_piece_def('Robes of the Corporeal Enforcer', 'Chest'),
            make_piece_def('Sleeves of the Corporeal Enforcer', 'Arms'),
            make_piece_def('Wristcuffs of the Corporeal Enforcer', 'Wrist'),
            make_piece_def('Breeches of the Corporeal Enforcer', 'Legs'),
            make_piece_def('Gloves of the Corporeal Enforcer', 'Hands'),
            make_piece_def('Slippers of the Corporeal Enforcer', 'Feet'),
        },
    },
    ['Indigo Vanguard'] = {
        set_name = 'Astute Brawler',
        pieces = {
            make_piece_def('Cowl of the Astute Brawler', 'Head'),
            make_piece_def('Robes of the Astute Brawler', 'Chest'),
            make_piece_def('Sleeves of the Astute Brawler', 'Arms'),
            make_piece_def('Wristcuffs of the Astute Brawler', 'Wrist'),
            make_piece_def('Breeches of the Astute Brawler', 'Legs'),
            make_piece_def('Gloves of the Astute Brawler', 'Hands'),
            make_piece_def('Slippers of the Astute Brawler', 'Feet'),
        },
    },
    ['Cabilis Foreign Legion'] = {
        set_name = 'Striking Sentinel',
        pieces = {
            make_piece_def('Cowl of the Striking Sentinel', 'Head'),
            make_piece_def('Robes of the Striking Sentinel', 'Chest'),
            make_piece_def('Sleeves of the Striking Sentinel', 'Arms'),
            make_piece_def('Wristcuffs of the Striking Sentinel', 'Wrist'),
            make_piece_def('Breeches of the Striking Sentinel', 'Legs'),
            make_piece_def('Gloves of the Striking Sentinel', 'Hands'),
            make_piece_def('Slippers of the Striking Sentinel', 'Feet'),
        },
    },
}
local TIER_9_COMPONENTS_BY_ARMOR_TYPE = {
    Plate = {
        sheets = 'High Quality Metal',
        blood = 'Shadow Blood',
        carapace = 'Large Fire Beetle Carapace',
        bone = 'Cursed Bone Chips',
    },
    Chain = {
        sheets = 'High Quality Metal',
        carapace = 'Large Fire Beetle Carapace',
        bone = 'Cursed Bone Chips',
        skin = 'Shiny Snake Skin',
        oil = 'Smelly Fish Oil',
    },
    Leather = {
        skins = 'High Quality Animal Skin',
        snake = 'Shiny Snake Skin',
        oil = 'Smelly Fish Oil',
        blood = 'Shadow Blood',
    },
    Cloth = {
        silk = 'Strong Spider Silk',
        lightstone = 'Glowing Lightstone',
        bone = 'Cursed Bone Chips',
        blood = 'Shadow Blood',
    },
}
local TIER_9_COMPONENT_REQUIREMENTS = {
    Plate = {
        Chest = { sheets = 5, blood = 1, carapace = 1 },
        Legs = { sheets = 4, blood = 1, carapace = 1 },
        Arms = { sheets = 3, blood = 1, bone = 1 },
        Head = { sheets = 3, blood = 1, bone = 1 },
        Wrist = { sheets = 2, blood = 1 },
        Feet = { sheets = 2, blood = 1 },
        Hands = { sheets = 2, blood = 1 },
    },
    Chain = {
        Chest = { sheets = 3, carapace = 2, bone = 1, skin = 1 },
        Legs = { sheets = 2, carapace = 2, bone = 1, skin = 1 },
        Arms = { sheets = 2, carapace = 1, bone = 1, oil = 1 },
        Head = { sheets = 2, carapace = 1, bone = 1, oil = 1 },
        Wrist = { sheets = 1, carapace = 1, bone = 1 },
        Feet = { sheets = 1, carapace = 1, bone = 1 },
        Hands = { sheets = 1, carapace = 1, bone = 1 },
    },
    Leather = {
        Chest = { skins = 4, snake = 1, oil = 1 },
        Legs = { skins = 3, snake = 1, oil = 1 },
        Arms = { skins = 2, snake = 1, blood = 1 },
        Head = { skins = 2, snake = 1, blood = 1 },
        Wrist = { skins = 1, snake = 1 },
        Feet = { skins = 1, snake = 1 },
        Hands = { skins = 1, snake = 1 },
    },
    Cloth = {
        Chest = { silk = 3, lightstone = 1, bone = 1 },
        Legs = { silk = 3, lightstone = 1, bone = 1 },
        Arms = { silk = 2, lightstone = 1, blood = 1 },
        Head = { silk = 2, lightstone = 1, blood = 1 },
        Wrist = { silk = 1, lightstone = 1 },
        Feet = { silk = 1, lightstone = 1 },
        Hands = { silk = 1, lightstone = 1 },
    },
}

local CLASS_TO_ARMOR_TYPE = {
    war = 'Plate', warrior = 'Plate',
    clr = 'Plate', cleric = 'Plate',
    pal = 'Plate', paladin = 'Plate',
    shd = 'Plate', shadowknight = 'Plate',
    brd = 'Plate', bard = 'Plate',
    rng = 'Chain', ranger = 'Chain',
    rog = 'Chain', rogue = 'Chain',
    shm = 'Chain', shaman = 'Chain',
    ber = 'Chain', berserker = 'Chain',
    nec = 'Cloth', necromancer = 'Cloth',
    wiz = 'Cloth', wizard = 'Cloth',
    mag = 'Cloth', magician = 'Cloth',
    enc = 'Cloth', enchanter = 'Cloth',
    dru = 'Leather', druid = 'Leather',
    mnk = 'Leather', monk = 'Leather',
    bst = 'Leather', beastlord = 'Leather',
}

local TIER_12_SETS_BY_ARMOR_TYPE = {
    Plate = {
        class_group = 'Plate',
        set_name = 'Blightforged Warlord',
        pieces = BLIGHTFORGED_PLATE_PIECES,
    },
    Chain = {
        class_group = 'Chain',
        set_name = 'Rotfang Hunter',
        pieces = ROTFANG_CHAIN_PIECES,
    },
    Cloth = {
        class_group = 'Cloth',
        set_name = 'Moorshade Magus',
        pieces = MOORSHADE_SILK_PIECES,
    },
    Leather = {
        class_group = 'Leather',
        set_name = 'Blightclaw Stalker',
        pieces = BLIGHTCLAW_LEATHER_PIECES,
    },
}

local LEGACY_TIER_CONFIGS = require('EZProgress.tier_data')

local TIER_11_PLATE_PIECES = {
    make_piece_def('Plate Helmet of King Tormax', 'Head', { KORMAX_PLATE_PATTERNS.Head }),
    make_piece_def('Breastplate of King Tormax', 'Chest', { KORMAX_PLATE_PATTERNS.Chest }),
    make_piece_def('Plate Armguards of King Tormax', 'Arms', { KORMAX_PLATE_PATTERNS.Arms }),
    make_piece_def('Plate Wristguards of King Tormax', 'Wrist', { KORMAX_PLATE_PATTERNS.Wrist }),
    make_piece_def('Legplates of King Tormax', 'Legs', { KORMAX_PLATE_PATTERNS.Legs }),
    make_piece_def('Plate Handguards of King Tormax', 'Hands', { KORMAX_PLATE_PATTERNS.Hands }),
    make_piece_def('Plate Sabatons of King Tormax', 'Feet', { KORMAX_PLATE_PATTERNS.Feet }),
}
local TIER_11_LEATHER_PIECES = {
    make_piece_def('Leather Hood of Ragnar Fjordason', 'Head', { KORMAX_LEATHER_PATTERNS.Head }),
    make_piece_def('Leather Vest of Ragnar Fjordason', 'Chest', { KORMAX_LEATHER_PATTERNS.Chest }),
    make_piece_def('Leather Sleeves of Ragnar Fjordason', 'Arms', { KORMAX_LEATHER_PATTERNS.Arms }),
    make_piece_def('Leather Bindings of Ragnar Fjordason', 'Wrist', { KORMAX_LEATHER_PATTERNS.Wrist }),
    make_piece_def('Leather Leggings of Ragnar Fjordason', 'Legs', { KORMAX_LEATHER_PATTERNS.Legs }),
    make_piece_def('Leather Grasps of Ragnar Fjordason', 'Hands', { KORMAX_LEATHER_PATTERNS.Hands }),
    make_piece_def('Leather Boots of Ragnar Fjordason', 'Feet', { KORMAX_LEATHER_PATTERNS.Feet }),
}
local TIER_11_SILK_PIECES = {
    make_piece_def('Silk Crown of Velketor the Sorcerer', 'Head', { KORMAX_SILK_PATTERNS.Head }),
    make_piece_def('Silk Robes of Velketor the Sorcerer', 'Chest', { KORMAX_SILK_PATTERNS.Chest }),
    make_piece_def('Silk Sleeves of Velketor the Sorcerer', 'Arms', { KORMAX_SILK_PATTERNS.Arms }),
    make_piece_def('Silk Wristguards of Velketor the Sorcerer', 'Wrist', { KORMAX_SILK_PATTERNS.Wrist }),
    make_piece_def('Silk Leggings of Velketor the Sorcerer', 'Legs', { KORMAX_SILK_PATTERNS.Legs }),
    make_piece_def('Silk Gloves of Velketor the Sorcerer', 'Hands', { KORMAX_SILK_PATTERNS.Hands }),
    make_piece_def('Silk Slippers of Velketor the Sorcerer', 'Feet', { KORMAX_SILK_PATTERNS.Feet }),
}
local TIER_11_CHAIN_PIECES = {
    make_piece_def('Chain Helmet of Fjordavind the Fearless', 'Head', { KORMAX_CHAIN_PATTERNS.Head }),
    make_piece_def('Chain Hauberk of Fjordavind the Fearless', 'Chest', { KORMAX_CHAIN_PATTERNS.Chest }),
    make_piece_def('Chain Armguards of Fjordavind the Fearless', 'Arms', { KORMAX_CHAIN_PATTERNS.Arms }),
    make_piece_def('Chain Bindings of Fjordavind the Fearless', 'Wrist', { KORMAX_CHAIN_PATTERNS.Wrist }),
    make_piece_def('Chain Legguards of Fjordavind the Fearless', 'Legs', { KORMAX_CHAIN_PATTERNS.Legs }),
    make_piece_def('Chain Handguards of Fjordavind the Fearless', 'Hands', { KORMAX_CHAIN_PATTERNS.Hands }),
    make_piece_def('Chain Sabatons of Fjordavind the Fearless', 'Feet', { KORMAX_CHAIN_PATTERNS.Feet }),
}
local TIER_11_SETS_BY_ARMOR_TYPE = {
    Plate = {
        class_group = 'Plate',
        set_name = 'King Tormax',
        pieces = TIER_11_PLATE_PIECES,
    },
    Chain = {
        class_group = 'Chain',
        set_name = 'Fjordavind the Fearless',
        pieces = TIER_11_CHAIN_PIECES,
    },
    Cloth = {
        class_group = 'Cloth',
        set_name = 'Velketor the Sorcerer',
        pieces = TIER_11_SILK_PIECES,
    },
    Leather = {
        class_group = 'Leather',
        set_name = 'Ragnar Fjordason',
        pieces = TIER_11_LEATHER_PIECES,
    },
}
local TIER_11_COLD_BARGAIN_ITEMS = {
    frostbloom = 'Crystalized Frostbloom',
    pelt = 'Glacierbound Pelt',
    gem = 'Northern Lights Gem',
}
local TIER_11_COLD_BARGAIN_REQUIRED = 3
local TIER_11_COLD_BARGAIN_REWARD = 'Mount Dhoom'

local TIER_CONFIGS = {
    ['Tier 10'] = {
        label = 'Tier 10',
    },
    ['Tier 11'] = {
        label = 'Tier 11',
        sets_by_armor_type = TIER_11_SETS_BY_ARMOR_TYPE,
    },
    [DEFAULT_TIER_KEY] = {
        label = DEFAULT_TIER_KEY,
        sets_by_armor_type = TIER_12_SETS_BY_ARMOR_TYPE,
    },
}

for tier_key, tier_config in pairs(LEGACY_TIER_CONFIGS) do
    TIER_CONFIGS[tier_key] = tier_config
end

local TIER_ORDER = {
    'Tier 1',
    'Tier 2',
    'Tier 3',
    'Tier 4',
    'Tier 5',
    'Tier 6',
    'Tier 7',
    'Tier 8',
    'Tier 9',
    'Tier 10',
    'Tier 11',
    DEFAULT_TIER_KEY,
}

_G.ezprogress_state = _G.ezprogress_state or {
    actor_handle = nil,
    local_progress = nil,
    peer_progress = {},
    peer_order = {},
    selected_tier = DEFAULT_TIER_KEY,
    selected_tier_10_faction = DEFAULT_TIER_10_FACTION,
    track_mount_dhoom = true,
}
local state = _G.ezprogress_state
state.selected_tier = state.selected_tier or DEFAULT_TIER_KEY
state.selected_tier_10_faction = state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
if state.track_mount_dhoom == nil then
    state.track_mount_dhoom = true
end

_G.ezprogress_triggers = _G.ezprogress_triggers or {
    do_refresh = false,
    need_publish = false,
    startup_refresh_at = 0,
    faction_scan_reason = nil,
    faction_scan_key = nil,
    plagueborn_refresh_reason = nil,
}
local triggers = _G.ezprogress_triggers

_G.ezprogress_faction_state = _G.ezprogress_faction_state or {
    active = nil,
    by_faction = {},
    last_seen_line = '',
    last_seen_ms = 0,
    last_auto_consider_ms = 0,
}
local faction_state = _G.ezprogress_faction_state

_G.ezprogress_quest_state = _G.ezprogress_quest_state or {
    plagueborn_kills = nil,
    plagueborn_goal = nil,
    plagueborn_status_text = '',
    plagueborn_instruction = '',
    plagueborn_last_seen_ms = 0,
}
local quest_state = _G.ezprogress_quest_state

if _G.ezprogress_running == nil then
    _G.ezprogress_running = true
end

local running = _G.ezprogress_running
local draw_gui = false
local debug_mode = false
local args = { ... }
local exchange_mailbox = 'ezprogress_exchange'
local my_name = mq.TLO.Me.CleanName() or 'Unknown'
local pending_publish_tier = nil
local pending_publish_tier_10_faction = nil

local function log_debug(fmt, ...)
    if debug_mode then
        printf(HEADER .. ' ' .. fmt, ...)
    end
end

local function colored_text(color, text)
    ImGui.TextColored(color[1], color[2], color[3], color[4], text)
end

local function push_soft_theme()
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, FRAME_ROUNDING)
    ImGui.PushStyleVar(ImGuiStyleVar.PopupRounding, POPUP_ROUNDING)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, WINDOW_ROUNDING)
end

local function pop_soft_theme()
    ImGui.PopStyleVar(3)
end

local function trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$')
end

local function normalize_whitespace(text)
    return trim(tostring(text or ''):gsub('%s+', ' '))
end

local function normalize_lookup_key(text)
    return normalize_whitespace(text):lower()
end

local function extract_character_name(name)
    local cleaned = trim(name)
    if cleaned == '' then
        return ''
    end
    cleaned = cleaned:gsub('%b()', '')
    cleaned = trim(cleaned)
    return cleaned:match('^([^%.%s]+)') or cleaned
end

local function get_zone_short_name()
    return normalize_lookup_key(mq.TLO.Zone.ShortName() or '')
end

local function get_faction_target(target_name)
    return FACTION_TARGETS[normalize_lookup_key(target_name)]
end

local function get_tier_10_choice(choice_key)
    local desired_key = choice_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
    for _, choice in ipairs(TIER_10_FACTION_CHOICES) do
        if choice.key == desired_key then
            return choice
        end
    end
    return TIER_10_FACTION_CHOICES[1]
end

local function normalize_faction_rank(raw_rank)
    local value = normalize_lookup_key(raw_rank)
    value = value:gsub('^an%s+', '')
    value = value:gsub('^a%s+', '')
    value = value:gsub('[%.,!]+$', '')

    if value:find('ally', 1, true) then
        return 'Ally'
    end
    if value:find('warmly', 1, true) then
        return 'Warmly'
    end
    if value:find('kindly', 1, true) then
        return 'Kindly'
    end
    if value:find('amiably', 1, true) or value:find('amiable', 1, true) then
        return 'Amiable'
    end
    if value:find('indifferently', 1, true) or value:find('indifferent', 1, true) then
        return 'Indifferent'
    end
    if value:find('apprehensively', 1, true) or value:find('apprehensive', 1, true) then
        return 'Apprehensive'
    end
    if value:find('dubiously', 1, true) or value:find('dubious', 1, true) then
        return 'Dubious'
    end
    if value:find('scowls', 1, true) or value:find('threateningly', 1, true) or value:find('threatenly', 1, true) then
        return 'Hostile'
    end

    return nil
end

local function get_faction_unlock_slot(rank)
    return FACTION_RANK_TO_SLOT[rank]
end

local function update_faction_cache(target_name, rank, raw_line)
    local target = get_faction_target(target_name)
    if not target or not rank then
        return false
    end

    local changed = false
    if not faction_state.active then
        changed = true
    else
        changed = faction_state.active.target_name ~= target.name or faction_state.active.rank ~= rank
    end

    faction_state.active = {
        target_name = target.name,
        faction_name = target.faction_name,
        rank = rank,
        unlocked_slot = get_faction_unlock_slot(rank),
        zone = get_zone_short_name(),
    }
    faction_state.by_faction[target.faction_name] = {
        target_name = target.name,
        faction_name = target.faction_name,
        rank = rank,
        unlocked_slot = get_faction_unlock_slot(rank),
        zone = get_zone_short_name(),
        line = tostring(raw_line or ''),
        last_seen_ms = mq.gettime(),
    }
    faction_state.last_seen_line = tostring(raw_line or '')
    faction_state.last_seen_ms = mq.gettime()

    return changed
end

local function request_faction_scan(reason)
    triggers.faction_scan_reason = reason or 'manual'
    triggers.faction_scan_key = state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
end

local function request_faction_scan_for_key(reason, faction_key)
    triggers.faction_scan_reason = reason or 'manual'
    triggers.faction_scan_key = faction_key or DEFAULT_TIER_10_FACTION
end

local function is_plagueborn_zone()
    return get_zone_short_name() == 'sunderock'
end

local function should_refresh_plagueborn_progress(reason)
    if reason == 'manual' then
        return true
    end

    return is_plagueborn_zone()
end

local function request_plagueborn_refresh(reason)
    triggers.plagueborn_refresh_reason = reason or 'periodic'
end

local handle_faction_consider_line
local handle_faction_consider_alt_line
local handle_faction_consider_phrase_line

local function execute_faction_scan(reason, faction_key)
    local choice = get_tier_10_choice(faction_key)
    local target_name = choice.target_name
    local faction_target = get_faction_target(target_name)
    local previous_target_id = mq.TLO.Target.ID() or 0
    local restored_previous_target = false

    local function restore_previous_target()
        if restored_previous_target or previous_target_id <= 0 then
            return
        end
        restored_previous_target = true
        if (mq.TLO.Target.ID() or 0) ~= previous_target_id then
            mq.delay(100)
            mq.cmdf('/target id %d', previous_target_id)
        end
    end

    mq.cmdf('/target "%s"', choice.target_name)
    mq.delay(500, function()
        return normalize_lookup_key(mq.TLO.Target.CleanName() or mq.TLO.Target.Name() or '') == normalize_lookup_key(choice.target_name)
    end)
    target_name = mq.TLO.Target.CleanName() or mq.TLO.Target.Name() or ''
    faction_target = get_faction_target(target_name)
    if not faction_target then
        restore_previous_target()
        return false
    end

    if reason == 'auto' and faction_target.zone and faction_target.zone ~= get_zone_short_name() then
        restore_previous_target()
        return false
    end

    mq.cmd('/consider')
    faction_state.last_auto_consider_ms = mq.gettime()
    restore_previous_target()
    log_debug('Faction consider requested for %s (%s).', faction_target.name, reason or 'manual')
    return true
end

local function register_faction_events()
    for _, choice in ipairs(TIER_10_FACTION_CHOICES) do
        local key = choice.key:gsub('%s+', '')
        mq.event('EZPFactionRegards' .. key,
            choice.target_name .. ' regards you as #1# --#2#',
            function(rank, suffix)
                handle_faction_consider_line(choice.target_name, rank, suffix)
            end)
        mq.event('EZPFactionConsiders' .. key,
            choice.target_name .. ' considers you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_alt_line(choice.target_name, rank, suffix)
            end)
        mq.event('EZPFactionConsidersPrefix' .. key,
            choice.target_name .. ' #1# considers you --#2#',
            function(rank, suffix)
                handle_faction_consider_alt_line(choice.target_name, rank, suffix)
            end)
        mq.event('EZPFactionRegardsAdverb' .. key,
            choice.target_name .. ' regards you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'regards you')
            end)
        mq.event('EZPFactionLooksUpon' .. key,
            choice.target_name .. ' looks upon you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'looks upon you')
            end)
        mq.event('EZPFactionJudges' .. key,
            choice.target_name .. ' judges you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'judges you')
            end)
        mq.event('EZPFactionLooksYourWay' .. key,
            choice.target_name .. ' looks your way #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'looks your way')
            end)
        mq.event('EZPFactionGlowers' .. key,
            choice.target_name .. ' glowers at you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'glowers at you')
            end)
        mq.event('EZPFactionGlares' .. key,
            choice.target_name .. ' glares at you #1#.#2#',
            function(rank, suffix)
                handle_faction_consider_phrase_line(choice.target_name, rank, suffix, 'glares at you')
            end)
    end
end

handle_faction_consider_line = function(target_name, raw_rank, suffix)
    local faction_target = get_faction_target(target_name)
    if not faction_target then
        return
    end

    local normalized_rank = normalize_faction_rank(raw_rank)
    if not normalized_rank then
        return
    end

    local line = normalize_whitespace(string.format('%s regards you as %s %s', target_name or '', raw_rank or '', suffix or ''))
    local changed = update_faction_cache(target_name, normalized_rank, line)
    if changed then
        pending_publish_tier = 'Tier 10'
        pending_publish_tier_10_faction = faction_target.faction_name
        triggers.need_publish = true
        local unlocked_slot = get_faction_unlock_slot(normalized_rank)
        if unlocked_slot then
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax (%s unlocked).', HEADER, faction_target.faction_name, normalized_rank, unlocked_slot)
        else
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax.', HEADER, faction_target.faction_name, normalized_rank)
        end
    end
end

handle_faction_consider_alt_line = function(target_name, raw_rank, suffix)
    local faction_target = get_faction_target(target_name)
    if not faction_target then
        return
    end

    local normalized_rank = normalize_faction_rank(raw_rank)
    if not normalized_rank then
        return
    end

    local line = normalize_whitespace(string.format('%s considers you %s %s', target_name or '', raw_rank or '', suffix or ''))
    local changed = update_faction_cache(target_name, normalized_rank, line)
    if changed then
        pending_publish_tier = 'Tier 10'
        pending_publish_tier_10_faction = faction_target.faction_name
        triggers.need_publish = true
        local unlocked_slot = get_faction_unlock_slot(normalized_rank)
        if unlocked_slot then
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax (%s unlocked).', HEADER, faction_target.faction_name, normalized_rank, unlocked_slot)
        else
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax.', HEADER, faction_target.faction_name, normalized_rank)
        end
    end
end

handle_faction_consider_phrase_line = function(target_name, raw_rank, suffix, phrase)
    local faction_target = get_faction_target(target_name)
    if not faction_target then
        return
    end

    local normalized_rank = normalize_faction_rank(raw_rank)
    if not normalized_rank then
        return
    end

    local line = normalize_whitespace(string.format('%s %s %s %s', target_name or '', phrase or '', raw_rank or '', suffix or ''))
    local changed = update_faction_cache(target_name, normalized_rank, line)
    if changed then
        pending_publish_tier = 'Tier 10'
        pending_publish_tier_10_faction = faction_target.faction_name
        triggers.need_publish = true
        local unlocked_slot = get_faction_unlock_slot(normalized_rank)
        if unlocked_slot then
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax (%s unlocked).', HEADER, faction_target.faction_name, normalized_rank, unlocked_slot)
        else
            printf('%s \agTier 10 faction updated: \at%s\ax -> \ay%s\ax.', HEADER, faction_target.faction_name, normalized_rank)
        end
    end
end

local function get_piece_slot(piece_name)
    local text = tostring(piece_name or ''):lower()
    if text:find('helmet', 1, true) or text:find('crown', 1, true) or text:find('hood', 1, true) then
        return 'Head'
    end
    if text:find('breastplate', 1, true) or text:find('hauberk', 1, true) or text:find('robes', 1, true) or text:find('vest', 1, true) then
        return 'Chest'
    end
    if text:find('armguards', 1, true) or text:find('sleeves', 1, true) then
        return 'Arms'
    end
    if text:find('legplates', 1, true) or text:find('legguards', 1, true) or text:find('leggings', 1, true) then
        return 'Legs'
    end
    if text:find('handguards', 1, true) or text:find('gloves', 1, true) or text:find('grasp', 1, true) then
        return 'Hands'
    end
    if text:find('wristguards', 1, true) or text:find('bindings', 1, true) then
        return 'Wrist'
    end
    if text:find('sabatons', 1, true) or text:find('slippers', 1, true) or text:find('boots', 1, true) then
        return 'Feet'
    end
    return 'Other'
end

local function get_connected_peers()
    local peers = {}
    local seen = {}
    local self_name = extract_character_name(mq.TLO.Me.CleanName())

    local function add_peer(raw_name)
        local peer_name = extract_character_name(raw_name)
        if peer_name ~= '' and peer_name ~= self_name and not seen[peer_name:lower()] then
            seen[peer_name:lower()] = true
            table.insert(peers, peer_name)
        end
    end

    if mq.TLO.Plugin('MQ2Mono') and mq.TLO.Plugin('MQ2Mono').IsLoaded() then
        local peers_str = mq.TLO.MQ2Mono.Query('e3,E3Bots.ConnectedClients')()
        if peers_str and type(peers_str) == 'string' and peers_str:lower() ~= 'null' and peers_str ~= '' then
            for peer in string.gmatch(peers_str, '([^,]+)') do
                add_peer(peer)
            end
        end
    elseif mq.TLO.Plugin('MQ2DanNet') and mq.TLO.Plugin('MQ2DanNet').IsLoaded() then
        local peers_str = mq.TLO.DanNet.Peers() or ''
        for peer in string.gmatch(peers_str, '([^|]+)') do
            add_peer(peer)
        end
    elseif mq.TLO.Plugin('MQ2EQBC') and mq.TLO.Plugin('MQ2EQBC').IsLoaded() and mq.TLO.EQBC.Connected() then
        local names = mq.TLO.EQBC.Names() or ''
        for peer in string.gmatch(names, '([^%s]+)') do
            add_peer(peer)
        end
    end

    table.sort(peers, function(a, b)
        return a:lower() < b:lower()
    end)

    return peers
end

local function sort_peer_order()
    state.peer_order = {}
    for name in pairs(state.peer_progress) do
        table.insert(state.peer_order, name)
    end
    table.sort(state.peer_order, function(a, b)
        return a:lower() < b:lower()
    end)
end

local function cleanup_stale_peers()
    local now = mq.gettime()
    local removed = false
    for peer_name, peer_data in pairs(state.peer_progress) do
        if (now - (peer_data.last_update_ms or 0)) > STALE_PEER_TIMEOUT_US then
            state.peer_progress[peer_name] = nil
            removed = true
        end
    end
    if removed then
        sort_peer_order()
    end
end

local function copy_pieces(pieces)
    local result = {}
    for index, piece in ipairs(pieces or {}) do
        result[index] = {
            name = piece.name,
            slot = piece.slot,
            count = piece.count or 0,
            owned = piece.owned == true,
            direct_count = piece.direct_count or 0,
            alternate_count = piece.alternate_count or 0,
            alternates = piece.alternates,
            component_counts = piece.component_counts,
            component_requirements = piece.component_requirements,
            has_required_components = piece.has_required_components == true,
            status_code = piece.status_code,
            status_text = piece.status_text,
        }
    end
    return result
end

local function copy_cold_bargain_progress(progress)
    if not progress then
        return nil
    end

    return {
        collected = progress.collected or 0,
        total = progress.total or 0,
        completed = progress.completed == true,
        reward_owned = progress.reward_owned == true,
        item_counts = {
            frostbloom = progress.item_counts and progress.item_counts.frostbloom or 0,
            pelt = progress.item_counts and progress.item_counts.pelt or 0,
            gem = progress.item_counts and progress.item_counts.gem or 0,
        },
    }
end

local function get_tier_config(tier_key)
    local key = tier_key or state.selected_tier or DEFAULT_TIER_KEY
    return TIER_CONFIGS[key]
end

local function get_available_tiers()
    local tiers = {}
    for _, tier_key in ipairs(TIER_ORDER) do
        if TIER_CONFIGS[tier_key] then
            table.insert(tiers, tier_key)
        end
    end
    return tiers
end

local function clone_progress(progress)
    if not progress then
        return nil
    end

    return {
        character = progress.character,
        class = progress.class,
        class_group = progress.class_group,
        tier_key = progress.tier_key,
        tier_10_faction = progress.tier_10_faction,
        tier_10_faction_rank = progress.tier_10_faction_rank,
        plagueborn_kills = progress.plagueborn_kills,
        cold_bargain = copy_cold_bargain_progress(progress.cold_bargain),
        set_name = progress.set_name,
        supported = progress.supported == true,
        completed = progress.completed or 0,
        total = progress.total or 0,
        missing_count = progress.missing_count or 0,
        pieces = copy_pieces(progress.pieces),
    }
end

local component_maps_equal

local function progress_changed(previous, updated)
    if not previous or not updated then
        return previous ~= updated
    end

    if previous.completed ~= updated.completed
        or previous.missing_count ~= updated.missing_count
        or previous.tier_10_faction_rank ~= updated.tier_10_faction_rank
        or previous.plagueborn_kills ~= updated.plagueborn_kills then
        return true
    end

    local previous_cold_bargain = previous.cold_bargain
    local updated_cold_bargain = updated.cold_bargain
    if (previous_cold_bargain and not updated_cold_bargain) or (updated_cold_bargain and not previous_cold_bargain) then
        return true
    end
    if previous_cold_bargain and updated_cold_bargain then
        if previous_cold_bargain.collected ~= updated_cold_bargain.collected
            or previous_cold_bargain.total ~= updated_cold_bargain.total
            or previous_cold_bargain.completed ~= updated_cold_bargain.completed
            or previous_cold_bargain.reward_owned ~= updated_cold_bargain.reward_owned
            or not component_maps_equal(previous_cold_bargain.item_counts, updated_cold_bargain.item_counts) then
            return true
        end
    end

    local previous_pieces = previous.pieces or {}
    local updated_pieces = updated.pieces or {}
    if #previous_pieces ~= #updated_pieces then
        return true
    end

    for index, piece in ipairs(updated_pieces) do
        local prior_piece = previous_pieces[index]
        if not prior_piece then
            return true
        end

        if prior_piece.status_code ~= piece.status_code or
            prior_piece.count ~= piece.count or
            prior_piece.direct_count ~= piece.direct_count or
            prior_piece.alternate_count ~= piece.alternate_count or
            prior_piece.has_required_components ~= piece.has_required_components then
            return true
        end

        local prior_components = prior_piece.component_counts
        local components = piece.component_counts
        if (prior_components and not components) or (components and not prior_components) then
            return true
        end
        if prior_components and components and not component_maps_equal(prior_components, components) then
            return true
        end
    end

    return false
end

local function count_item_owned(item_name)
    local query = '=' .. item_name
    local inv_count = mq.TLO.FindItemCount(query)() or 0
    local bank_count = mq.TLO.FindItemBankCount(query)() or 0
    return inv_count + bank_count
end

local function get_component_counts(component_names)
    local counts = {}
    for key, item_name in pairs(component_names or {}) do
        counts[key] = count_item_owned(item_name)
    end
    return counts
end

local function build_cold_bargain_progress()
    local item_counts = get_component_counts(TIER_11_COLD_BARGAIN_ITEMS)
    local collected = 0
    for _, count in pairs(item_counts) do
        collected = collected + math.min(count or 0, TIER_11_COLD_BARGAIN_REQUIRED)
    end

    local total = TIER_11_COLD_BARGAIN_REQUIRED * 3
    return {
        collected = collected,
        total = total,
        completed = collected >= total,
        reward_owned = count_item_owned(TIER_11_COLD_BARGAIN_REWARD) > 0,
        item_counts = item_counts,
    }
end

component_maps_equal = function(left, right)
    if left == right then
        return true
    end
    if not left or not right then
        return false
    end
    for key, value in pairs(left) do
        if (right[key] or 0) ~= value then
            return false
        end
    end
    for key, value in pairs(right) do
        if (left[key] or 0) ~= value then
            return false
        end
    end
    return true
end

local function components_meet_requirements(component_counts, component_requirements)
    for key, required in pairs(component_requirements or {}) do
        if required > 0 and (component_counts[key] or 0) < required then
            return false
        end
    end
    return true
end

local function total_component_count(component_counts)
    local total = 0
    for _, count in pairs(component_counts or {}) do
        total = total + (count or 0)
    end
    return total
end

local function append_component_tooltip_lines(lines, piece)
    if not piece.component_counts or not piece.component_requirements then
        return
    end
    for key, required in pairs(piece.component_requirements) do
        if required and required > 0 then
            local label = (piece.component_labels and piece.component_labels[key]) or key
            table.insert(lines, string.format('%s: %d / %d', label, piece.component_counts[key] or 0, required))
        end
    end
end

local function get_tier_component_config(tier_key, armor_type)
    if tier_key == 'Tier 11' then
        return {
            component_names = TIER_11_COMPONENTS,
            component_requirements = TIER_11_COMPONENT_REQUIREMENTS,
            component_labels = TIER_11_COMPONENTS,
        }
    end
    if tier_key == 'Tier 9' and TIER_9_COMPONENTS_BY_ARMOR_TYPE[armor_type] then
        return {
            component_names = TIER_9_COMPONENTS_BY_ARMOR_TYPE[armor_type],
            component_requirements = TIER_9_COMPONENT_REQUIREMENTS[armor_type],
            component_labels = TIER_9_COMPONENTS_BY_ARMOR_TYPE[armor_type],
        }
    end
    return nil
end

local function normalize_piece_def(piece_def)
    if type(piece_def) == 'table' then
        return {
            name = piece_def.name or '',
            slot = piece_def.slot or get_piece_slot(piece_def.name),
            alternates = piece_def.alternates or {},
        }
    end

    return {
        name = tostring(piece_def or ''),
        slot = get_piece_slot(piece_def),
        alternates = {},
    }
end

local function get_armor_type_by_class(class_name)
    if not class_name or class_name == '' then
        return 'Unknown'
    end

    local key = tostring(class_name):gsub('%s+', ''):lower()
    return CLASS_TO_ARMOR_TYPE[key] or 'Unknown'
end

local function get_tier_10_set_config(armor_type, tier_10_faction_key)
    local active_faction = tier_10_faction_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
    if not active_faction or active_faction == '' then
        return nil
    end

    if armor_type == 'Plate' then
        local template = TIER_10_PLATE_SET_TEMPLATES[active_faction]
        if template then
            return {
                class_group = 'Plate',
                set_name = string.format('%s (%s)', template.set_name, active_faction),
                pieces = template.pieces,
            }
        end
    elseif armor_type == 'Chain' then
        local template = TIER_10_CHAIN_SET_TEMPLATES[active_faction]
        if template then
            return {
                class_group = 'Chain',
                set_name = string.format('%s (%s)', template.set_name, active_faction),
                pieces = template.pieces,
            }
        end
    elseif armor_type == 'Leather' then
        local template = TIER_10_LEATHER_SET_TEMPLATES[active_faction]
        if template then
            return {
                class_group = 'Leather',
                set_name = string.format('%s (%s)', template.set_name, active_faction),
                pieces = template.pieces,
            }
        end
    elseif armor_type == 'Cloth' then
        local template = TIER_10_CLOTH_SET_TEMPLATES[active_faction]
        if template then
            return {
                class_group = 'Cloth',
                set_name = string.format('%s (%s)', template.set_name, active_faction),
                pieces = template.pieces,
            }
        end
    end

    return nil
end

local function refresh_plagueborn_progress()
    local taskWnd = mq.TLO.Window('TaskWnd')
    if not taskWnd() then
        return false
    end

    local was_open = taskWnd.Open()
    if not was_open then
        taskWnd.DoOpen()
        local open_start = mq.gettime()
        while not taskWnd.Open() do
            if mq.gettime() - open_start > 3000 then
                return false
            end
            mq.delay(50)
        end
    end

    local taskList = mq.TLO.Window('TaskWnd/TASK_TaskList')
    local taskElementList = mq.TLO.Window('TaskWnd/TASK_TaskElementList')
    if not taskList() or not taskElementList() then
        if not was_open then
            taskWnd.DoClose()
        end
        return false
    end

    local found_kills = nil
    local found_goal = nil
    local found_status = ''
    local found_instruction = ''

    for i = 1, taskList.Items() do
        local task_type = taskList.List(i, 1)() or ''
        local task_name = taskList.List(i, 2)() or ''
        local task_key = normalize_lookup_key(task_type .. ' ' .. task_name)
        if task_key:find('purge the plagueborn', 1, true) then
            taskList.Select(i)
            local select_start = mq.gettime()
            while taskList.GetCurSel() ~= i do
                if mq.gettime() - select_start > 1000 then
                    break
                end
                mq.delay(25)
            end

            for j = 1, taskElementList.Items() do
                local objective_text = taskElementList.List(j, 1)() or ''
                local status_text = taskElementList.List(j, 2)() or ''
                local objective_key = normalize_lookup_key(objective_text)
                if objective_key:find('kill 750 plagueborn creatures', 1, true)
                    or objective_key:find('plagueborn', 1, true) then
                    local current, total = tostring(status_text):match('(%d+)%s*/%s*(%d+)')
                    if not current then
                        current, total = tostring(objective_text):match('(%d+)%s*/%s*(%d+)')
                    end
                    found_kills = tonumber(current or '')
                    found_goal = tonumber(total or '')
                    found_status = tostring(status_text or '')
                    found_instruction = tostring(objective_text or '')
                    break
                end
            end
            break
        end
    end

    if not was_open then
        taskWnd.DoClose()
    end

    local changed = false
    if quest_state.plagueborn_kills ~= found_kills
        or quest_state.plagueborn_goal ~= found_goal
        or quest_state.plagueborn_status_text ~= found_status
        or quest_state.plagueborn_instruction ~= found_instruction then
        changed = true
    end

    if found_kills ~= nil then
        quest_state.plagueborn_kills = found_kills
        quest_state.plagueborn_goal = found_goal
        quest_state.plagueborn_status_text = found_status
        quest_state.plagueborn_instruction = found_instruction
        quest_state.plagueborn_last_seen_ms = mq.gettime()
    end

    return changed
end

local function build_local_progress(tier_key, tier_10_faction_key)
    local selected_tier = tier_key or state.selected_tier or DEFAULT_TIER_KEY
    local class_short_name = mq.TLO.Me.Class.ShortName() or ''
    local armor_type = get_armor_type_by_class(class_short_name)
    local tier_config = get_tier_config(selected_tier)
    local effective_tier_10_faction = tier_10_faction_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
    local cached_tier_10_faction = selected_tier == 'Tier 10' and faction_state.by_faction[effective_tier_10_faction] or nil
    local set_config = nil
    if selected_tier == 'Tier 10' then
        set_config = get_tier_10_set_config(armor_type, effective_tier_10_faction)
    elseif tier_config and tier_config.sets_by_class then
        set_config = tier_config.sets_by_class[class_short_name]
    end
    if not set_config and tier_config and tier_config.sets_by_armor_type then
        set_config = tier_config.sets_by_armor_type[armor_type]
    end

    if not set_config then
        return {
            character = my_name,
            class = class_short_name,
            class_group = armor_type,
            tier_key = selected_tier,
            tier_10_faction = selected_tier == 'Tier 10' and effective_tier_10_faction or nil,
            tier_10_faction_rank = cached_tier_10_faction and cached_tier_10_faction.rank or nil,
            plagueborn_kills = selected_tier == 'Tier 10' and quest_state.plagueborn_kills or nil,
            cold_bargain = selected_tier == 'Tier 11' and build_cold_bargain_progress() or nil,
            set_name = '',
            supported = false,
            completed = 0,
            total = 0,
            missing_count = 0,
            pieces = {},
        }
    end

    local progress = {
        character = my_name,
        class = class_short_name,
        class_group = set_config.class_group,
        tier_key = selected_tier,
        tier_10_faction = selected_tier == 'Tier 10' and effective_tier_10_faction or nil,
        tier_10_faction_rank = cached_tier_10_faction and cached_tier_10_faction.rank or nil,
        plagueborn_kills = selected_tier == 'Tier 10' and quest_state.plagueborn_kills or nil,
        cold_bargain = selected_tier == 'Tier 11' and build_cold_bargain_progress() or nil,
        set_name = set_config.set_name,
        supported = true,
        completed = 0,
        total = #set_config.pieces,
        missing_count = 0,
        pieces = {},
    }
    local tier_component_config = get_tier_component_config(selected_tier, armor_type)
    local shared_components = tier_component_config and get_component_counts(tier_component_config.component_names) or nil
    local has_tier_component_config = tier_component_config ~= nil

    for _, item_name in ipairs(set_config.pieces) do
        local piece_def = normalize_piece_def(item_name)
        local direct_count = count_item_owned(piece_def.name)
        local alternate_count = 0
        local owned_item_name = nil
        if direct_count > 0 then
            owned_item_name = piece_def.name
        end
        for _, alternate_name in ipairs(piece_def.alternates or {}) do
            local alt_count = count_item_owned(alternate_name)
            alternate_count = alternate_count + alt_count
            if alt_count > 0 and not owned_item_name then
                owned_item_name = alternate_name
            end
        end
        local count = direct_count + alternate_count
        local owned = direct_count > 0
        local has_alternate = alternate_count > 0
        local component_requirements = nil
        local component_counts = nil
        local has_required_components = false
        local status_code = owned and 'armor' or (has_alternate and 'pattern' or 'missing')
        local status_text = owned and 'Done' or (has_alternate and 'Have Pattern' or 'Missing')

        if has_tier_component_config and piece_def.slot and tier_component_config.component_requirements[piece_def.slot] then
            component_requirements = tier_component_config.component_requirements[piece_def.slot]
            component_counts = {}
            for key, count in pairs(shared_components or {}) do
                component_counts[key] = count
            end
            has_required_components = components_meet_requirements(component_counts, component_requirements)

            local total_components = total_component_count(component_counts)

            if direct_count > 0 then
                status_code = 'armor'
                status_text = 'Done'
            elseif has_alternate and has_required_components then
                status_code = 'ready'
                status_text = 'Ready to combine'
            elseif has_alternate then
                status_code = 'pattern'
                status_text = 'Missing Components'
            elseif total_components > 0 then
                status_code = 'components'
                status_text = 'Missing Pattern'
            else
                status_code = 'missing'
                status_text = 'Missing Both'
            end
        elseif has_alternate then
            status_code = 'armor'
            status_text = 'Done'
        end
        if status_code == 'armor' then
            progress.completed = progress.completed + 1
        end
        table.insert(progress.pieces, {
            name = piece_def.name,
            slot = piece_def.slot,
            count = count,
            direct_count = direct_count,
            alternate_count = alternate_count,
            owned_item_name = owned_item_name,
            alternates = piece_def.alternates,
            component_counts = component_counts,
            component_requirements = component_requirements,
            component_labels = tier_component_config and tier_component_config.component_labels or nil,
            has_required_components = has_required_components,
            status_code = status_code,
            status_text = status_text,
            owned = owned,
        })
    end

    progress.missing_count = progress.total - progress.completed
    return progress
end

local function send_message(payload)
    if not state.actor_handle then
        log_debug('Cannot send %s; actor mailbox not initialized yet.', tostring(payload and payload.id))
        return false
    end

    payload = payload or {}
    payload.sender = my_name
    payload.script = SCRIPT_NAME
    state.actor_handle:send({ mailbox = exchange_mailbox }, payload)
    return true
end

local function send_message_to_peer(peer_name, payload)
    if not state.actor_handle or not peer_name or peer_name == '' then
        return false
    end

    payload = payload or {}
    payload.sender = my_name
    payload.script = SCRIPT_NAME
    payload.target_peer = peer_name
    state.actor_handle:send({ character = peer_name, mailbox = exchange_mailbox }, payload)
    return true
end

local function publish_progress(target_peer, tier_key, tier_10_faction_key)
    local selected_tier = tier_key or state.selected_tier or DEFAULT_TIER_KEY
    local selected_tier_10_faction = tier_10_faction_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
    local progress = build_local_progress(selected_tier, selected_tier_10_faction)
    if selected_tier == state.selected_tier then
        state.local_progress = progress
    end
    local payload = {
        id = 'PROGRESS_DATA',
        requested_tier = selected_tier,
        requested_tier_10_faction = selected_tier == 'Tier 10' and selected_tier_10_faction or nil,
        progress = clone_progress(progress),
    }

    if target_peer and target_peer ~= '' then
        send_message_to_peer(target_peer, payload)
    else
        send_message(payload)
    end
end

local function request_progress_from_peers(tier_key, tier_10_faction_key)
    local selected_tier = tier_key or state.selected_tier or DEFAULT_TIER_KEY
    local selected_tier_10_faction = tier_10_faction_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
    send_message({
        id = 'REQUEST_ALL',
        requester = my_name,
        requested_tier = selected_tier,
        requested_tier_10_faction = selected_tier == 'Tier 10' and selected_tier_10_faction or nil,
    })
    publish_progress(nil, selected_tier, selected_tier_10_faction)
end

local function broadcast_faction_scan(faction_key)
    send_message({
        id = 'REQUEST_FACTION_SCAN',
        requested_tier_10_faction = faction_key or state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION,
    })
end

local function handle_message(message)
    local content = message.content
    if not content or not content.id then
        return
    end

    local incoming_script = (content.script or ''):lower()
    if incoming_script ~= SCRIPT_NAME:lower() then
        return
    end

    if content.id == 'REQUEST_ALL' then
        pending_publish_tier = content.requested_tier or state.selected_tier or DEFAULT_TIER_KEY
        pending_publish_tier_10_faction = content.requested_tier_10_faction
        return
    end

    if content.id == 'REQUEST_PROGRESS' then
        if content.target_peer and content.target_peer ~= my_name then
            return
        end
        pending_publish_tier = content.requested_tier or state.selected_tier or DEFAULT_TIER_KEY
        pending_publish_tier_10_faction = content.requested_tier_10_faction
        return
    end

    if content.id == 'REQUEST_FACTION_SCAN' then
        if get_zone_short_name() == 'sunderock' then
            request_faction_scan_for_key('remote', content.requested_tier_10_faction)
            request_plagueborn_refresh('remote')
        end
        return
    end

    if content.id == 'PROGRESS_DATA' then
        local sender_name = (message.sender and message.sender.character) or content.sender
        if not sender_name or sender_name == my_name then
            return
        end

        local incoming_progress = clone_progress(content.progress) or {
            character = sender_name,
            tier_key = content.progress and content.progress.tier_key or DEFAULT_TIER_KEY,
            tier_10_faction = content.progress and content.progress.tier_10_faction or nil,
            tier_10_faction_rank = content.progress and content.progress.tier_10_faction_rank or nil,
            plagueborn_kills = content.progress and content.progress.plagueborn_kills or nil,
            supported = false,
            completed = 0,
            total = 0,
            missing_count = 0,
            pieces = {},
        }

        if (incoming_progress.tier_key or DEFAULT_TIER_KEY) ~= (state.selected_tier or DEFAULT_TIER_KEY) then
            return
        end
        if (state.selected_tier or DEFAULT_TIER_KEY) == 'Tier 10'
            and (incoming_progress.tier_10_faction or DEFAULT_TIER_10_FACTION) ~= (state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION) then
            return
        end

        state.peer_progress[sender_name] = incoming_progress
        state.peer_progress[sender_name].character = sender_name
        state.peer_progress[sender_name].last_update_ms = mq.gettime()
        sort_peer_order()
        return
    end

    if content.id == 'END_SCRIPT' then
        _G.ezprogress_running = false
        running = false
    end
end

local function render_piece_row(piece)
    local marker_color = COLOR_INCOMPLETE
    local marker_text = '[X]'
    if piece.status_code == 'armor' or piece.owned then
        marker_color = COLOR_COMPLETE
        marker_text = '[OK]'
    elseif piece.status_code == 'ready' then
        marker_color = COLOR_WARN
        marker_text = '[RDY]'
    elseif piece.status_code == 'pattern' then
        marker_color = COLOR_WARN
        marker_text = '[PAT]'
    elseif piece.status_code == 'components' then
        marker_color = COLOR_COMPONENTS
        marker_text = '[MAT]'
    end
    colored_text(marker_color, marker_text)
    ImGui.SameLine(0, 6)
    local display_name = piece.owned_item_name or piece.name
    ImGui.Text(display_name)
    ImGui.SameLine()
    colored_text(COLOR_MUTED, string.format('(%d)', piece.count or 0))
    if piece.status_code == 'pattern' and piece.alternate_count and piece.alternate_count > 0 and (piece.direct_count or 0) == 0 then
        ImGui.SameLine()
        colored_text(COLOR_WARN, '[Pattern]')
    elseif piece.status_code == 'ready' then
        ImGui.SameLine()
        colored_text(COLOR_WARN, '[Ready]')
    elseif piece.status_code == 'components' then
        ImGui.SameLine()
        colored_text(COLOR_COMPONENTS, '[Components]')
    end
    if ImGui.IsItemHovered() then
        local lines = { string.format('Armor: %d', piece.direct_count or 0) }
        if piece.alternates and #piece.alternates > 0 then
            table.insert(lines, string.format('Alternates: %d', piece.alternate_count or 0))
            for _, alternate_name in ipairs(piece.alternates) do
                table.insert(lines, alternate_name)
            end
        end
        if piece.component_counts and piece.component_requirements then
            append_component_tooltip_lines(lines, piece)
        end
        ImGui.SetTooltip(table.concat(lines, '\n'))
    end
end

local render_cold_bargain_block

local function render_progress_block(progress, is_self)
    if not progress then
        colored_text(COLOR_MUTED, 'No data available.')
        return
    end

    local name_label = progress.character or 'Unknown'
    if is_self then
        name_label = name_label .. ' (You)'
    end
    colored_text(COLOR_HEADER, name_label)
    ImGui.SameLine()
    colored_text(COLOR_MUTED, string.format('[%s]', progress.class or '?'))

    if not progress.supported then
        if progress.tier_key == 'Tier 10' then
            colored_text(COLOR_WARN, 'Tier 10 set not available for the selected armor type/faction selector yet.')
            return
        end
        colored_text(COLOR_WARN, 'No tracked armor set configured for this class yet.')
        render_cold_bargain_block(progress)
        return
    end

    ImGui.Text(string.format('%s Set: %d/%d complete', progress.set_name, progress.completed or 0, progress.total or 0))
    ImGui.SameLine()
    colored_text(COLOR_MUTED, string.format('(%s)', progress.tier_key or DEFAULT_TIER_KEY))
    if (progress.missing_count or 0) == 0 then
        colored_text(COLOR_COMPLETE, 'Complete')
    else
        colored_text(COLOR_INCOMPLETE, string.format('%d piece(s) missing', progress.missing_count or 0))
    end

    for _, piece in ipairs(progress.pieces or {}) do
        render_piece_row(piece)
    end
    render_cold_bargain_block(progress)
end

local function render_faction_status()
    colored_text(COLOR_HEADER, 'Tier 10 Faction')
    local choice = get_tier_10_choice()
    local cached = faction_state.by_faction[choice.key]
    ImGui.Text(string.format('Selected: %s', choice.label))
    ImGui.SameLine()
    colored_text(COLOR_MUTED, string.format('[%s]', choice.target_name))

    if not cached then
        colored_text(COLOR_MUTED, 'No cached consider line yet for this target. Use /ezp factionscan to scan the selected Tier 10 target.')
        return
    end

    ImGui.Text(string.format('%s: %s', cached.faction_name or 'Unknown', cached.rank or 'Unknown'))
    if cached.unlocked_slot then
        ImGui.SameLine()
        colored_text(COLOR_WARN, string.format('(%s unlocked)', cached.unlocked_slot))
    end
    colored_text(COLOR_MUTED, string.format('Source: %s', cached.target_name or 'Unknown'))
    if cached.line and cached.line ~= '' then
        ImGui.SetNextItemOpen(false, ImGuiCond.Once)
        if ImGui.TreeNode('Last Consider Line##EZPFactionLine') then
            ImGui.TextWrapped(cached.line)
            ImGui.TreePop()
        end
    end
end

local function get_piece_status_color(piece)
    if not piece then
        return COLOR_MUTED
    end
    if piece.status_code == 'armor' or piece.owned then
        return COLOR_COMPLETE
    end
    if piece.status_code == 'ready' then
        return COLOR_WARN
    end
    if piece.status_code == 'pattern' then
        return COLOR_WARN
    end
    if piece.status_code == 'components' then
        return COLOR_COMPONENTS
    end
    return COLOR_INCOMPLETE
end

local function render_tier_11_legend()
    colored_text(COLOR_MUTED, 'Tier 11 Legend:')
    ImGui.SameLine()
    colored_text(COLOR_COMPLETE, 'Green = Done')
    ImGui.SameLine()
    colored_text(COLOR_WARN, 'Yellow = Pattern / Ready')
    ImGui.SameLine()
    colored_text(COLOR_COMPONENTS, 'Orange = Missing Pattern')
    ImGui.SameLine()
    colored_text(COLOR_INCOMPLETE, 'Red = Missing Both')
end

render_cold_bargain_block = function(progress)
    if not progress or progress.tier_key ~= 'Tier 11' or not progress.cold_bargain then
        return
    end

    local cold_bargain = progress.cold_bargain
    ImGui.Separator()
    colored_text(COLOR_HEADER, 'A Cold Bargain')
    ImGui.SameLine()
    colored_text(COLOR_MUTED, string.format('[Reward: %s]', TIER_11_COLD_BARGAIN_REWARD))
    colored_text(cold_bargain.completed and COLOR_COMPLETE or COLOR_WARN,
        string.format('Progress: %d/%d', cold_bargain.collected or 0, cold_bargain.total or 0))

    local item_order = { 'frostbloom', 'pelt', 'gem' }
    for _, key in ipairs(item_order) do
        local count = cold_bargain.item_counts and cold_bargain.item_counts[key] or 0
        local color = count >= TIER_11_COLD_BARGAIN_REQUIRED and COLOR_COMPLETE or COLOR_INCOMPLETE
        colored_text(color, string.format('%s: %d/%d', TIER_11_COLD_BARGAIN_ITEMS[key], count, TIER_11_COLD_BARGAIN_REQUIRED))
    end

    colored_text(cold_bargain.reward_owned and COLOR_COMPLETE or COLOR_MUTED,
        string.format('Mount Dhoom: %s', cold_bargain.reward_owned and 'Owned' or 'Not Owned'))
end

local SLOT_TAB_ORDER = { 'Head', 'Chest', 'Arms', 'Legs', 'Hands', 'Wrist', 'Feet' }

local function find_piece_for_slot(progress, slot_name)
    if not progress or not progress.supported then
        return nil
    end

    for _, piece in ipairs(progress.pieces or {}) do
        if (piece.slot or get_piece_slot(piece.name)) == slot_name then
            return piece
        end
    end

    return nil
end

local function get_tier_11_component_deficits(progress)
    local deficits = {
        major = 0,
        minor = 0,
        water = 0,
    }

    if not progress or not progress.supported or progress.tier_key ~= 'Tier 11' then
        return deficits
    end

    local required = {
        major = 0,
        minor = 0,
        water = 0,
    }
    local available = {
        major = 0,
        minor = 0,
        water = 0,
    }

    for _, piece in ipairs(progress.pieces or {}) do
        if piece.status_code ~= 'armor' and piece.component_requirements then
            required.major = required.major + (piece.component_requirements.major or 0)
            required.minor = required.minor + (piece.component_requirements.minor or 0)
            required.water = required.water + (piece.component_requirements.water or 0)
        end
        if piece.component_counts then
            available.major = piece.component_counts.major or 0
            available.minor = piece.component_counts.minor or 0
            available.water = piece.component_counts.water or 0
        end
    end

    deficits.major = math.max(0, required.major - available.major)
    deficits.minor = math.max(0, required.minor - available.minor)
    deficits.water = math.max(0, required.water - available.water)
    return deficits
end

local PIECE_STATUS_SORT_RANK = {
    armor = 1,
    ready = 2,
    pattern = 3,
    components = 4,
    missing = 5,
}

local function compare_sort_values(left, right, ascending)
    if left == right then
        return 0
    end
    if left == nil then
        return 1
    end
    if right == nil then
        return -1
    end

    if type(left) == 'string' and type(right) == 'string' then
        left = left:lower()
        right = right:lower()
    end

    if left < right then
        return ascending and -1 or 1
    end
    return ascending and 1 or -1
end

local function compare_tier_11_deficits(left, right, component_key, ascending)
    local left_value = nil
    local right_value = nil

    if left and left.supported and left.tier_key == 'Tier 11' then
        left_value = get_tier_11_component_deficits(left)[component_key]
    end
    if right and right.supported and right.tier_key == 'Tier 11' then
        right_value = get_tier_11_component_deficits(right)[component_key]
    end

    return compare_sort_values(left_value, right_value, ascending)
end

local function compare_cold_bargain_progress(left, right, ascending)
    local function quest_value(progress)
        if not progress or progress.tier_key ~= 'Tier 11' or not progress.cold_bargain then
            return nil
        end

        local cold_bargain = progress.cold_bargain
        return string.format('%01d:%01d:%03d:%03d',
            cold_bargain.completed and 1 or 0,
            cold_bargain.reward_owned and 1 or 0,
            cold_bargain.collected or 0,
            cold_bargain.total or 0
        )
    end

    return compare_sort_values(quest_value(left), quest_value(right), ascending)
end

local function compare_cold_bargain_item(left, right, item_key, ascending)
    local left_value = nil
    local right_value = nil

    if left and left.tier_key == 'Tier 11' and left.cold_bargain and left.cold_bargain.item_counts then
        left_value = left.cold_bargain.item_counts[item_key] or 0
    end
    if right and right.tier_key == 'Tier 11' and right.cold_bargain and right.cold_bargain.item_counts then
        right_value = right.cold_bargain.item_counts[item_key] or 0
    end

    return compare_sort_values(left_value, right_value, ascending)
end

local function compare_cold_bargain_reward(left, right, ascending)
    local left_value = nil
    local right_value = nil

    if left and left.tier_key == 'Tier 11' and left.cold_bargain then
        left_value = left.cold_bargain.reward_owned and 1 or 0
    end
    if right and right.tier_key == 'Tier 11' and right.cold_bargain then
        right_value = right.cold_bargain.reward_owned and 1 or 0
    end

    return compare_sort_values(left_value, right_value, ascending)
end

local function compare_progress_completion(left, right, ascending)
    local function completion_value(progress)
        if not progress or not progress.supported then
            return nil
        end
        local total = progress.total or 0
        local completed = progress.completed or 0
        local ratio = total > 0 and (completed / total) or 0
        return string.format('%08.5f:%04d:%04d', ratio, completed, total)
    end

    return compare_sort_values(completion_value(left), completion_value(right), ascending)
end

local function compare_slot_status(left, right, slot_name, ascending)
    local function status_value(progress)
        if not progress or not progress.supported then
            return nil
        end
        local piece = find_piece_for_slot(progress, slot_name)
        if not piece then
            return nil
        end
        local status_code = piece.status_code or (piece.owned and 'armor' or 'missing')
        return string.format('%02d:%s', PIECE_STATUS_SORT_RANK[status_code] or 99, status_code)
    end

    return compare_sort_values(status_value(left), status_value(right), ascending)
end

local function compare_rows(left_row, right_row, compare_fn)
    local result = compare_fn(left_row.progress, right_row.progress)
    if result ~= 0 then
        return result < 0
    end

    return ((left_row.progress.character or ''):lower() < (right_row.progress.character or ''):lower())
end

local function get_sorted_progress_rows(mode, sort_specs, slot_name)
    local rows = {}
    local show_faction = (state.selected_tier or DEFAULT_TIER_KEY) == 'Tier 10'
    local show_plagueborn = show_faction
    local show_cold_bargain = (state.selected_tier or DEFAULT_TIER_KEY) == 'Tier 11' and state.track_mount_dhoom == true

    if state.local_progress then
        table.insert(rows, { progress = state.local_progress, is_self = true })
    end
    for _, peer_name in ipairs(state.peer_order) do
        local progress = state.peer_progress[peer_name]
        if progress then
            table.insert(rows, { progress = progress, is_self = false })
        end
    end

    local column_index = 0
    local ascending = true
    if sort_specs and sort_specs.SpecsCount and sort_specs.SpecsCount > 0 then
        local spec = sort_specs:Specs(1)
        if spec then
            column_index = spec.ColumnIndex or 0
            ascending = spec.SortDirection == ImGuiSortDirection.Ascending
        end
    end

    local function compare_fn(left, right)
        if mode == 'peer_summary' then
            if column_index == 1 then
                return compare_sort_values(left.class or '', right.class or '', ascending)
            end
            if column_index == 2 then
                return compare_sort_values(left.supported and (left.set_name or '') or nil, right.supported and (right.set_name or '') or nil, ascending)
            end
            if show_faction and column_index == 3 then
                return compare_sort_values(left.tier_10_faction_rank or nil, right.tier_10_faction_rank or nil, ascending)
            end
            if show_plagueborn and column_index == 4 then
                return compare_sort_values(left.plagueborn_kills or nil, right.plagueborn_kills or nil, ascending)
            end
            if column_index == (show_faction and 5 or 3) then
                return compare_progress_completion(left, right, ascending)
            end
            if column_index == (show_faction and 7 or 4) then
                return compare_tier_11_deficits(left, right, 'major', ascending)
            end
            if column_index == (show_faction and 8 or 5) then
                return compare_tier_11_deficits(left, right, 'minor', ascending)
            end
            if column_index == (show_faction and 9 or 6) then
                return compare_tier_11_deficits(left, right, 'water', ascending)
            end
            if show_cold_bargain and column_index == (show_faction and 10 or 7) then
                return compare_cold_bargain_item(left, right, 'frostbloom', ascending)
            end
            if show_cold_bargain and column_index == (show_faction and 11 or 8) then
                return compare_cold_bargain_item(left, right, 'pelt', ascending)
            end
            if show_cold_bargain and column_index == (show_faction and 12 or 9) then
                return compare_cold_bargain_item(left, right, 'gem', ascending)
            end
            return compare_sort_values(left.character or '', right.character or '', ascending)
        end

        if mode == 'cold_bargain' then
            if column_index == 1 then
                return compare_sort_values(left.class or '', right.class or '', ascending)
            end
            if column_index == 2 then
                return compare_cold_bargain_item(left, right, 'frostbloom', ascending)
            end
            if column_index == 3 then
                return compare_cold_bargain_item(left, right, 'pelt', ascending)
            end
            if column_index == 4 then
                return compare_cold_bargain_item(left, right, 'gem', ascending)
            end
            if column_index == 5 then
                return compare_cold_bargain_progress(left, right, ascending)
            end
            if column_index == 6 then
                return compare_cold_bargain_reward(left, right, ascending)
            end
        end
        if column_index == 1 then
            return compare_sort_values(left.class or '', right.class or '', ascending)
        end
        if column_index == 2 then
            return compare_sort_values(left.supported and (left.set_name or '') or nil, right.supported and (right.set_name or '') or nil, ascending)
        end
        if column_index == 3 then
            local left_piece = find_piece_for_slot(left, slot_name)
            local right_piece = find_piece_for_slot(right, slot_name)
            return compare_sort_values(left_piece and (left_piece.name or '') or nil, right_piece and (right_piece.name or '') or nil, ascending)
        end
        if column_index == 4 then
            return compare_slot_status(left, right, slot_name, ascending)
        end
        return compare_sort_values(left.character or '', right.character or '', ascending)
    end

    table.sort(rows, function(left_row, right_row)
        return compare_rows(left_row, right_row, compare_fn)
    end)

    if sort_specs and sort_specs.SpecsDirty then
        sort_specs.SpecsDirty = false
    end

    return rows
end

local function render_mount_dhoom_table()
    local selected_tier = state.selected_tier or DEFAULT_TIER_KEY
    if selected_tier ~= 'Tier 11' then
        return
    end

    if ImGui.BeginTable('EZProgressMountDhoom##' .. selected_tier, 7, bit32.bor(
        ImGuiTableFlags.RowBg,
        ImGuiTableFlags.BordersInner,
        ImGuiTableFlags.BordersOuter,
        ImGuiTableFlags.SizingFixedFit,
        ImGuiTableFlags.Resizable,
        ImGuiTableFlags.Sortable,
        ImGuiTableFlags.NoSavedSettings
    )) then
        ImGui.TableSetupColumn('Character', ImGuiTableColumnFlags.DefaultSort)
        ImGui.TableSetupColumn('Class')
        ImGui.TableSetupColumn('Frostbloom')
        ImGui.TableSetupColumn('Pelt')
        ImGui.TableSetupColumn('Gem')
        ImGui.TableSetupColumn('Progress')
        ImGui.TableSetupColumn('Mount')
        ImGui.TableHeadersRow()

        local rows = get_sorted_progress_rows('cold_bargain', ImGui.TableGetSortSpecs())
        for _, row in ipairs(rows) do
            local progress = row.progress
            local cold_bargain = progress and progress.cold_bargain or nil

            ImGui.TableNextRow()

            ImGui.TableNextColumn()
            ImGui.Text((progress.character or 'Unknown') .. (row.is_self and ' (You)' or ''))

            ImGui.TableNextColumn()
            ImGui.Text(progress.class or '?')

            local item_order = { 'frostbloom', 'pelt', 'gem' }
            for _, key in ipairs(item_order) do
                ImGui.TableNextColumn()
                if cold_bargain and cold_bargain.item_counts then
                    local count = cold_bargain.item_counts[key] or 0
                    local color = count >= TIER_11_COLD_BARGAIN_REQUIRED and COLOR_COMPLETE or COLOR_INCOMPLETE
                    colored_text(color, string.format('%d/%d', count, TIER_11_COLD_BARGAIN_REQUIRED))
                else
                    colored_text(COLOR_MUTED, '--')
                end
            end

            ImGui.TableNextColumn()
            if cold_bargain then
                colored_text(cold_bargain.completed and COLOR_COMPLETE or COLOR_WARN,
                    string.format('%d/%d', cold_bargain.collected or 0, cold_bargain.total or 0))
            else
                colored_text(COLOR_MUTED, '--')
            end

            ImGui.TableNextColumn()
            if cold_bargain then
                colored_text(cold_bargain.reward_owned and COLOR_COMPLETE or COLOR_MUTED,
                    cold_bargain.reward_owned and 'Owned' or 'Not Owned')
            else
                colored_text(COLOR_MUTED, '--')
            end
        end

        ImGui.EndTable()
    end
end

local function render_peer_summary_table()
    local selected_tier = state.selected_tier or DEFAULT_TIER_KEY
    local show_components = selected_tier == 'Tier 11'
    local show_faction = selected_tier == 'Tier 10'
    local show_plagueborn = show_faction
    local show_cold_bargain = selected_tier == 'Tier 11' and state.track_mount_dhoom == true
    local column_count = show_components and (show_faction and 12 or 10) or (show_faction and 6 or 4)

    if ImGui.BeginTable('EZProgressPeers##' .. selected_tier, column_count, bit32.bor(
        ImGuiTableFlags.RowBg,
        ImGuiTableFlags.BordersInner,
        ImGuiTableFlags.BordersOuter,
        ImGuiTableFlags.SizingFixedFit,
        ImGuiTableFlags.Resizable,
        ImGuiTableFlags.Sortable,
        ImGuiTableFlags.NoSavedSettings
    )) then
        ImGui.TableSetupColumn('Character', ImGuiTableColumnFlags.DefaultSort)
        ImGui.TableSetupColumn('Class')
        ImGui.TableSetupColumn('Set')
        if show_faction then
            ImGui.TableSetupColumn('Faction')
            ImGui.TableSetupColumn('Plagueborn')
        end
        ImGui.TableSetupColumn('Progress')
        if show_components then
            ImGui.TableSetupColumn('Majors')
            ImGui.TableSetupColumn('Minors')
            ImGui.TableSetupColumn('Waters')
        end
        if show_cold_bargain then
            ImGui.TableSetupColumn('Frostbloom')
            ImGui.TableSetupColumn('Pelt')
            ImGui.TableSetupColumn('Gem')
        end
        ImGui.TableHeadersRow()

        local rows = get_sorted_progress_rows('peer_summary', ImGui.TableGetSortSpecs())

        local function render_progress_tooltip(progress)
            if not progress or not progress.supported then
                return
            end

            local missing_pieces = {}
            for _, piece in ipairs(progress.pieces or {}) do
                if (piece.status_code or (piece.owned and 'armor' or 'missing')) ~= 'armor' then
                    table.insert(missing_pieces, piece.name)
                end
            end

            if #missing_pieces == 0 then
                ImGui.SetTooltip('Complete set')
                return
            end

            local tooltip = 'Missing pieces:\n' .. table.concat(missing_pieces, '\n')
            ImGui.SetTooltip(tooltip)
        end

        local function render_cold_bargain_tooltip(progress)
            if not progress or not progress.cold_bargain then
                return
            end

            local cold_bargain = progress.cold_bargain
            local lines = {
                'A Cold Bargain',
                string.format('Reward: %s', TIER_11_COLD_BARGAIN_REWARD),
            }

            local item_order = { 'frostbloom', 'pelt', 'gem' }
            for _, key in ipairs(item_order) do
                table.insert(lines, string.format('%s: %d / %d', TIER_11_COLD_BARGAIN_ITEMS[key],
                    cold_bargain.item_counts and cold_bargain.item_counts[key] or 0,
                    TIER_11_COLD_BARGAIN_REQUIRED))
            end

            table.insert(lines, string.format('Mount Owned: %s', cold_bargain.reward_owned and 'Yes' or 'No'))
            ImGui.SetTooltip(table.concat(lines, '\n'))
        end

        local function add_row(progress, is_self)
            local deficits = show_components and get_tier_11_component_deficits(progress) or nil
            ImGui.TableNextRow()

            ImGui.TableNextColumn()
            ImGui.Text((progress.character or 'Unknown') .. (is_self and ' (You)' or ''))

            ImGui.TableNextColumn()
            ImGui.Text(progress.class or '?')

            ImGui.TableNextColumn()
            if progress.supported then
                ImGui.Text(progress.set_name or '')
            else
                colored_text(COLOR_MUTED, 'Not configured')
            end

            if show_faction then
                ImGui.TableNextColumn()
                if progress.tier_10_faction_rank and progress.tier_10_faction_rank ~= '' then
                    ImGui.Text(progress.tier_10_faction_rank)
                else
                    colored_text(COLOR_MUTED, '--')
                end

                if show_plagueborn then
                    ImGui.TableNextColumn()
                    if progress.plagueborn_kills ~= nil then
                        ImGui.Text(tostring(progress.plagueborn_kills))
                    else
                        colored_text(COLOR_MUTED, '--')
                    end
                end
            end

            ImGui.TableNextColumn()
            if progress.supported then
                local complete = (progress.completed or 0) >= (progress.total or 0) and (progress.total or 0) > 0
                colored_text(complete and COLOR_COMPLETE or COLOR_INCOMPLETE, string.format('%d/%d', progress.completed or 0, progress.total or 0))
                if ImGui.IsItemHovered() then
                    render_progress_tooltip(progress)
                end
            else
                colored_text(COLOR_MUTED, '--')
            end

            if show_components then
                ImGui.TableNextColumn()
                if progress.supported and progress.tier_key == 'Tier 11' then
                    colored_text(deficits.major == 0 and COLOR_COMPLETE or COLOR_COMPONENTS, tostring(deficits.major))
                else
                    colored_text(COLOR_MUTED, '--')
                end

                ImGui.TableNextColumn()
                if progress.supported and progress.tier_key == 'Tier 11' then
                    colored_text(deficits.minor == 0 and COLOR_COMPLETE or COLOR_COMPONENTS, tostring(deficits.minor))
                else
                    colored_text(COLOR_MUTED, '--')
                end

                ImGui.TableNextColumn()
                if progress.supported and progress.tier_key == 'Tier 11' then
                    colored_text(deficits.water == 0 and COLOR_COMPLETE or COLOR_COMPONENTS, tostring(deficits.water))
                else
                    colored_text(COLOR_MUTED, '--')
                end
            end

            if show_cold_bargain then
                local item_order = { 'frostbloom', 'pelt', 'gem' }
                for _, key in ipairs(item_order) do
                    ImGui.TableNextColumn()
                    if progress.tier_key == 'Tier 11' and progress.cold_bargain and progress.cold_bargain.item_counts then
                        local cold_bargain = progress.cold_bargain
                        local text
                        local color
                        if cold_bargain.reward_owned then
                            text = 'Done'
                            color = COLOR_COMPLETE
                        else
                            local count = cold_bargain.item_counts[key] or 0
                            color = count >= TIER_11_COLD_BARGAIN_REQUIRED and COLOR_COMPLETE or COLOR_INCOMPLETE
                            text = string.format('%d/%d', count, TIER_11_COLD_BARGAIN_REQUIRED)
                        end
                        colored_text(color, text)
                        if ImGui.IsItemHovered() then
                            render_cold_bargain_tooltip(progress)
                        end
                    else
                        colored_text(COLOR_MUTED, '--')
                    end
                end
            end
        end

        for _, row in ipairs(rows) do
            add_row(row.progress, row.is_self)
        end

        ImGui.EndTable()
    end
end

local function render_slot_summary_table(slot_name)
    if not slot_name or slot_name == '' then
        return
    end

    local selected_tier = state.selected_tier or DEFAULT_TIER_KEY
    if ImGui.BeginTable('EZProgressSlot##' .. selected_tier .. '_' .. slot_name, 5, bit32.bor(
        ImGuiTableFlags.RowBg,
        ImGuiTableFlags.BordersInner,
        ImGuiTableFlags.BordersOuter,
        ImGuiTableFlags.SizingFixedFit,
        ImGuiTableFlags.Resizable,
        ImGuiTableFlags.Sortable,
        ImGuiTableFlags.NoSavedSettings
    )) then
        ImGui.TableSetupColumn('Character', ImGuiTableColumnFlags.DefaultSort)
        ImGui.TableSetupColumn('Class')
        ImGui.TableSetupColumn('Set')
        ImGui.TableSetupColumn(slot_name .. ' Piece')
        ImGui.TableSetupColumn('Status')
        ImGui.TableHeadersRow()

        local rows = get_sorted_progress_rows('slot_summary', ImGui.TableGetSortSpecs(), slot_name)

        local function add_row(progress, is_self)
            ImGui.TableNextRow()

            ImGui.TableNextColumn()
            ImGui.Text((progress.character or 'Unknown') .. (is_self and ' (You)' or ''))

            ImGui.TableNextColumn()
            ImGui.Text(progress.class or '?')

            ImGui.TableNextColumn()
            if progress.supported then
                ImGui.Text(progress.set_name or '')
            else
                colored_text(COLOR_MUTED, 'Not configured')
            end

            ImGui.TableNextColumn()
            local piece = find_piece_for_slot(progress, slot_name)
            if piece then
                ImGui.Text(piece.name or '')
            elseif progress.supported then
                colored_text(COLOR_MUTED, 'No tracked piece')
            else
                colored_text(COLOR_MUTED, '--')
            end

            ImGui.TableNextColumn()
            if piece then
                colored_text(get_piece_status_color(piece), piece.status_text or (piece.owned and 'Owned' or 'Missing'))
                if ImGui.IsItemHovered() then
                    local lines = {
                        string.format('%s', piece.name or 'Unknown'),
                        string.format('Armor: %d', piece.direct_count or 0),
                        string.format('Alternates: %d', piece.alternate_count or 0),
                    }
                    if piece.component_counts and piece.component_requirements then
                        append_component_tooltip_lines(lines, piece)
                    end
                    ImGui.SetTooltip(table.concat(lines, '\n'))
                end
            else
                colored_text(COLOR_MUTED, '--')
            end
        end

        for _, row in ipairs(rows) do
            add_row(row.progress, row.is_self)
        end

        ImGui.EndTable()
    end
end

local function get_slot_completion_state(slot_name)
    local has_supported = false
    local worst_rank = 0
    local status_ranks = {
        armor = 1,
        ready = 2,
        pattern = 3,
        components = 4,
        missing = 5,
    }

    local function consume_progress(progress)
        if not progress or not progress.supported then
            return
        end

        local piece = find_piece_for_slot(progress, slot_name)
        if piece then
            has_supported = true
            local rank = status_ranks[piece.status_code or (piece.owned and 'armor' or 'missing')] or 5
            if rank > worst_rank then
                worst_rank = rank
            end
        end
    end

    consume_progress(state.local_progress)
    for _, peer_name in ipairs(state.peer_order) do
        consume_progress(state.peer_progress[peer_name])
    end

    if not has_supported then
        return 'neutral'
    end

    if worst_rank <= 1 then
        return 'complete'
    end
    if worst_rank == 2 then
        return 'ready'
    end
    if worst_rank == 3 then
        return 'pattern'
    end
    if worst_rank == 4 then
        return 'components'
    end
    return 'incomplete'
end

local function push_slot_tab_colors(state_name)
    if state_name == 'complete' then
        ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.16, 0.42, 0.20, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabHovered, ImVec4(0.22, 0.55, 0.27, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.20, 0.62, 0.30, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocused, ImVec4(0.12, 0.28, 0.15, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, ImVec4(0.16, 0.42, 0.20, 1.0))
        return 5
    end

    if state_name == 'pattern' then
        ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.48, 0.40, 0.12, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabHovered, ImVec4(0.62, 0.52, 0.16, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.76, 0.64, 0.20, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocused, ImVec4(0.34, 0.28, 0.08, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, ImVec4(0.48, 0.40, 0.12, 1.0))
        return 5
    end

    if state_name == 'ready' then
        ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.40, 0.36, 0.12, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabHovered, ImVec4(0.54, 0.48, 0.16, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.68, 0.60, 0.20, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocused, ImVec4(0.28, 0.25, 0.08, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, ImVec4(0.40, 0.36, 0.12, 1.0))
        return 5
    end

    if state_name == 'components' then
        ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.54, 0.28, 0.08, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabHovered, ImVec4(0.68, 0.36, 0.10, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.82, 0.44, 0.12, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocused, ImVec4(0.38, 0.20, 0.06, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, ImVec4(0.54, 0.28, 0.08, 1.0))
        return 5
    end

    if state_name == 'incomplete' then
        ImGui.PushStyleColor(ImGuiCol.Tab, ImVec4(0.42, 0.15, 0.15, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabHovered, ImVec4(0.56, 0.20, 0.20, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.68, 0.24, 0.24, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocused, ImVec4(0.30, 0.11, 0.11, 1.0))
        ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, ImVec4(0.42, 0.15, 0.15, 1.0))
        return 5
    end

    return 0
end

local function display_gui()
    if not draw_gui then
        return
    end

    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        return
    end

    push_soft_theme()
    ImGui.SetNextWindowSize(ImVec2(700, 520), ImGuiCond.FirstUseEver)
    local open, show = ImGui.Begin(WINDOW_NAME .. '##' .. my_name, true)
    if not open then
        draw_gui = false
    end

    if show then
        if not state.local_progress or (state.local_progress.tier_key or DEFAULT_TIER_KEY) ~= (state.selected_tier or DEFAULT_TIER_KEY) then
            state.local_progress = build_local_progress(state.selected_tier)
        end

        local reporting_count = #state.peer_order + (state.local_progress and 1 or 0)

        if ImGui.Button('Refresh') then
            triggers.do_refresh = true
            request_plagueborn_refresh('manual')
        end
        ImGui.SameLine()
        if ImGui.Button('Hide') then
            draw_gui = false
        end
        ImGui.SameLine()
        ImGui.Text('Reporting: %d', reporting_count)
        ImGui.SameLine()
        ImGui.SetNextItemWidth(120)
        local previous_tier = state.selected_tier or DEFAULT_TIER_KEY
        local selected_tier = state.selected_tier or DEFAULT_TIER_KEY
        if ImGui.BeginCombo('##EZProgressTier', selected_tier) then
            for _, tier_key in ipairs(get_available_tiers()) do
                local _, pressed = ImGui.Selectable(tier_key, selected_tier == tier_key)
                if pressed then
                    state.selected_tier = TIER_CONFIGS[tier_key] and tier_key or DEFAULT_TIER_KEY
                end
            end
            ImGui.EndCombo()
        end
        selected_tier = state.selected_tier or DEFAULT_TIER_KEY
        if previous_tier ~= selected_tier then
            state.peer_progress = {}
            sort_peer_order()
            pending_publish_tier = nil
            state.local_progress = build_local_progress(selected_tier)
            triggers.do_refresh = true
            if selected_tier == 'Tier 10' and is_plagueborn_zone() then
                request_plagueborn_refresh('zone')
            end
        end
        if selected_tier == 'Tier 10' then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(190)
            local current_choice = get_tier_10_choice()
            if ImGui.BeginCombo('##EZProgressTier10Faction', current_choice.label) then
                for _, choice in ipairs(TIER_10_FACTION_CHOICES) do
                    local _, pressed = ImGui.Selectable(choice.label, state.selected_tier_10_faction == choice.key)
                    if pressed then
                        state.selected_tier_10_faction = choice.key
                        state.peer_progress = {}
                        sort_peer_order()
                        state.local_progress = build_local_progress(selected_tier)
                        triggers.do_refresh = true
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.SameLine()
            if ImGui.Button('Scan Faction') then
                broadcast_faction_scan(state.selected_tier_10_faction)
                request_faction_scan('manual')
                request_plagueborn_refresh('manual')
            end
        end
        if selected_tier == 'Tier 11' then
            ImGui.SameLine()
            render_tier_11_legend()
        end

        ImGui.Separator()
        if ImGui.CollapsingHeader('My Items', ImGuiTreeNodeFlags.DefaultOpen) then
            render_progress_block(state.local_progress, true)
        end

        if selected_tier == 'Tier 10' then
            ImGui.Separator()
            if ImGui.CollapsingHeader('Faction Status', ImGuiTreeNodeFlags.DefaultOpen) then
                render_faction_status()
            end
        end

        ImGui.Separator()
        colored_text(COLOR_HEADER, 'Group Overview')
        if selected_tier == 'Tier 11' then
            ImGui.SameLine()
            local track_mount_dhoom = state.track_mount_dhoom == true
            local value, changed = ImGui.Checkbox('Track Mount Dhoom', track_mount_dhoom)
            if changed then
                state.track_mount_dhoom = value == true
            end
        end
        if ImGui.BeginTabBar('EZProgressOverviewTabs', ImGuiTabBarFlags.None) then
            if ImGui.BeginTabItem('Overall') then
                render_peer_summary_table()
                ImGui.EndTabItem()
            end

            for _, slot_name in ipairs(SLOT_TAB_ORDER) do
                local pushed = push_slot_tab_colors(get_slot_completion_state(slot_name))
                if ImGui.BeginTabItem(slot_name) then
                    render_slot_summary_table(slot_name)
                    ImGui.EndTabItem()
                end
                if pushed > 0 then
                    ImGui.PopStyleColor(pushed)
                end
            end

            if selected_tier == 'Tier 11' and state.track_mount_dhoom == true and ImGui.BeginTabItem('Mount Dhoom') then
                render_mount_dhoom_table()
                ImGui.EndTabItem()
            end

            ImGui.EndTabBar()
        end

    end

    ImGui.End()
    pop_soft_theme()
end

local function cmd_ezp(cmd)
    cmd = (cmd or ''):lower()

    if cmd == '' or cmd == 'help' then
        printf('%s \ar/ezp show \ao--- Show HUD', HEADER)
        printf('%s \ar/ezp hide \ao--- Hide HUD', HEADER)
        printf('%s \ar/ezp refresh \ao--- Request fresh status from peers', HEADER)
        printf('%s \ar/ezp factionscan \ao--- Consider current Tier 10 faction NPC target', HEADER)
        printf('%s \ar/ezp debug \ao--- Toggle debug logging', HEADER)
        printf('%s \ar/ezp exit \ao--- Stop script', HEADER)
        return
    end

    if cmd == 'show' then
        draw_gui = true
        triggers.do_refresh = true
    elseif cmd == 'hide' then
        draw_gui = false
    elseif cmd == 'refresh' then
        triggers.do_refresh = true
        request_plagueborn_refresh('manual')
    elseif cmd == 'factionscan' then
        broadcast_faction_scan(state.selected_tier_10_faction)
        request_faction_scan('manual')
    elseif cmd == 'debug' then
        debug_mode = not debug_mode
        printf('%s \aoDebug mode %s.', HEADER, debug_mode and 'enabled' or 'disabled')
    elseif cmd == 'exit' or cmd == 'quit' or cmd == 'stop' then
        _G.ezprogress_running = false
        _G.ezprogress_initialized = false
        _G.ezprogress_imgui_initialized = false
        running = false
    end
end

local is_primary_launch = false

local function check_args()
    if _G.ezprogress_initialized then
        draw_gui = true
        triggers.do_refresh = true
        is_primary_launch = false
        return
    end

    is_primary_launch = true
    if #args == 0 then
        mq.cmdf('/dge /lua run %s nohud', SCRIPT_NAME)
        draw_gui = true
        triggers.startup_refresh_at = mq.gettime() + 2000
        return
    end

    for _, arg in ipairs(args) do
        local normalized = tostring(arg):lower()
        if normalized == 'nohud' then
            draw_gui = false
        elseif normalized == 'debug' then
            debug_mode = true
            draw_gui = true
            mq.cmdf('/dge /lua run %s nohud', SCRIPT_NAME)
            triggers.startup_refresh_at = mq.gettime() + 2000
        end
    end
end

local function init()
    local ok, mailbox = pcall(function()
        return actors.register(exchange_mailbox, handle_message)
    end)

    if not ok or not mailbox then
        print(string.format('[EZProgress] Failed to register %s: %s', exchange_mailbox, tostring(mailbox)))
        return false
    end

    state.actor_handle = mailbox

    if not _G.ezprogress_imgui_initialized then
        mq.imgui.init('ezprogress_gui', display_gui)
        _G.ezprogress_imgui_initialized = true
    end

    register_faction_events()

    mq.bind('/ezp', cmd_ezp)

    if not _G.ezprogress_initialized then
        _G.ezprogress_initialized = true
        triggers.need_publish = true
        printf('%s \agstarting. use \ar/ezp help \agfor commands.', HEADER)
    end

    return true
end

local function main()
    local next_poll_at = 0
    local next_publish_at = 0
    local next_plagueborn_poll_at = 0

    mq.delay(500)
    while running do
        running = _G.ezprogress_running
        mq.doevents()
        mq.delay(100)

        cleanup_stale_peers()

        if pending_publish_tier then
            local tier_to_publish = pending_publish_tier
            local tier_10_faction_to_publish = pending_publish_tier_10_faction
            pending_publish_tier = nil
            pending_publish_tier_10_faction = nil
            publish_progress(nil, tier_to_publish, tier_10_faction_to_publish)
        end

        if triggers.faction_scan_reason then
            local scan_reason = triggers.faction_scan_reason
            local scan_key = triggers.faction_scan_key
            triggers.faction_scan_reason = nil
            triggers.faction_scan_key = nil
            if not execute_faction_scan(scan_reason, scan_key) and scan_reason == 'manual' then
                printf('%s \arUnable to scan selected Tier 10 faction target right now.', HEADER)
            end
        end

        if triggers.plagueborn_refresh_reason then
            local refresh_reason = triggers.plagueborn_refresh_reason
            triggers.plagueborn_refresh_reason = nil
            if should_refresh_plagueborn_progress(refresh_reason) and refresh_plagueborn_progress() then
                pending_publish_tier = 'Tier 10'
                pending_publish_tier_10_faction = state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
                triggers.need_publish = true
            end
        end

        if triggers.do_refresh then
            triggers.do_refresh = false
            request_progress_from_peers(state.selected_tier)
        end

        if triggers.startup_refresh_at > 0 and mq.gettime() >= triggers.startup_refresh_at then
            triggers.startup_refresh_at = 0
            request_progress_from_peers(state.selected_tier)
        end

        if triggers.need_publish then
            triggers.need_publish = false
            local publish_tier = pending_publish_tier or state.selected_tier
            local publish_tier_10_faction = pending_publish_tier_10_faction
            pending_publish_tier = nil
            pending_publish_tier_10_faction = nil
            publish_progress(nil, publish_tier, publish_tier_10_faction)
            next_poll_at = mq.gettime() + REFRESH_INTERVAL_US
            next_publish_at = mq.gettime() + PUBLISH_INTERVAL_US
        end

        if mq.gettime() >= next_poll_at then
            local previous_progress = state.local_progress and clone_progress(state.local_progress) or nil
            local updated = build_local_progress(state.selected_tier)
            state.local_progress = updated
            if progress_changed(previous_progress, updated) then
                publish_progress(nil, state.selected_tier)
                next_publish_at = mq.gettime() + PUBLISH_INTERVAL_US
            end
            next_poll_at = mq.gettime() + REFRESH_INTERVAL_US
        end

        if is_plagueborn_zone() and mq.gettime() >= next_plagueborn_poll_at then
            if refresh_plagueborn_progress() then
                pending_publish_tier = 'Tier 10'
                pending_publish_tier_10_faction = state.selected_tier_10_faction or DEFAULT_TIER_10_FACTION
                triggers.need_publish = true
            end
            next_plagueborn_poll_at = mq.gettime() + 30000
        end

        if mq.gettime() >= next_publish_at then
            publish_progress(nil, state.selected_tier)
            next_publish_at = mq.gettime() + PUBLISH_INTERVAL_US
        end

    end

    mq.exit()
end

check_args()
if init() then
    if is_primary_launch then
        local peers = get_connected_peers()
        log_debug('Primary launch found %d peers.', #peers)
    end
    main()
end
