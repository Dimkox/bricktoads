local Base=require('../src/stand/server/Config')
local Definition=require('../src/server/gameplay/LevelDefinition')
local Config=require('../src/server/gameplay/GameConfig')(Base,Definition)
assert(not Base.Attacks.PigJab and not Base.Attacks.PigHeavy and not Base.Attacks.PigRush,
    'Pig tuning must not mutate stand defaults')
require('./gameplay/PigStrikes.spec')(require('../src/server/gameplay/LevelDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),
    require('../src/stand/server/Combat'),Config,require('./stand/FakeWorld'))
