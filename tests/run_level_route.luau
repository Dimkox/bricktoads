local Definition=require('../src/server/gameplay/LevelDefinition')
local Base=require('../src/stand/server/Config')
local Config=require('../src/server/gameplay/GameConfig')(Base,Definition)
assert(Config.Attacks.Club and not Base.Attacks.Club and not Base.Impulses[2] and not Base.Impulses[20],
    'Adding a trusted Club profile must not mutate shared stand defaults')
require('./gameplay/LevelRoute.spec')(require('../src/server/gameplay/LevelDirector'),Definition,Config,
    require('../src/server/gameplay/HealingFlies'),require('../src/server/gameplay/EnemyCarry'),
    require('../src/server/gameplay/WalkerClubs'))
