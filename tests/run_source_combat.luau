local Source=require('../src/server/gameplay/SourceCombat')
local Base=require('../src/stand/server/Config')
local Level=require('../src/server/gameplay/LevelDefinition')
local Config=require('../src/server/gameplay/GameConfig')(Base,Level)
require('./gameplay/SourceCombat.spec')(Source,require('../src/server/gameplay/LevelDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    Config,Level,require('./stand/FakeWorld'),require('../src/server/gameplay/EnemyCarry'))
