pub const UnitType = enum {
    infantry,
    cavalry,
    artilery,
    levy,
    aerial,
    siege,
};

pub const Trait = struct {
    type: enum {
        adaptable,
        dead,
        harrowing,
        relentless,
    }
    
};

pub const DOMAIN_MAX_TRAITS = 3;

pub const Ancestry = enum {
    dragonborn,
    human,
    dwarf,
    elf,
    kobold,
    lizardfolk,
    fiend,
    monstrous,
    giant,
    ocr,
    gnoll,
    gnome,
    specia,
    undead,
    goblinoid,
};
pub const UnitCondition = enum {
    none,
    broken,
    disbanded,
    disorganized,
    disoriented,
    exposed,
    hidden,
    misled,
    weakened,
};

pub const Unit = struct {
    name: []const u8,
    size: u8,
    tier: u8,
    type: UnitType,
    atk: i8,
    def: u8,
    pow: i8,
    tou: u8,
    mor: i8,
    com: i8,
    dmg: u8,
    traits: [DOMAIN_MAX_TRAITS]Trait,
    active_traits: usize,
    attacks: u8,
    movement: u8,
    reactions: u8,
    ancestry: Ancestry,
    condition: UnitCondition,
    pub fn assign_trait(self: *Unit, t: Trait) []Trait {
        if (self.active_traits == self.traits.len) 
            @panic("Too many trais!");
        self.traits[self.active_traits] = t;
        self.active_traits += 1;
        return self.traits[0..self.active_traits];
    }
};

pub const human_infantry = Unit {
    .name = "Human Infantry",
    .size = 6,
    .tier = 1,
    .type = UnitType.infantry,
    .atk = 3,
    .def = 12,
    .pow = 2,
    .tou = 12,
    .mor = 1,
    .com = 2,
    .dmg = 1,
    .slots = undefined,
    .active_slots = 0,
    .attacks = 1,
    .movement = 1,
    .ancestry = Ancestry.human,
    .condition = undefined,
};
