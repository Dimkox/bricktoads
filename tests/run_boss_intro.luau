local Animation=require('../src/server/gameplay/CanonicalAnimation')
local Intro=require('../src/server/gameplay/BossIntro')(Animation)
local Base=require('../src/stand/server/Config')
local Config=require('../src/server/gameplay/GameConfig')(Base,require('../src/server/gameplay/LevelDefinition'))
require('./gameplay/BossIntro.spec')(Intro,require('../src/server/gameplay/LevelDirector'),Config,
    require('../src/stand/server/Combat'),require('../src/server/gameplay/GameController'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),
    require('../src/stand/server/ConnectionRegistry'),require('./stand/FakeWorld'),
    require('../src/server/gameplay/BossIntroWorld'),require('../src/server/gameplay/EnemyCarry'))
