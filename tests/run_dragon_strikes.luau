local Config=require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition'))
require('./gameplay/DragonStrikes.spec')(require('../src/server/gameplay/LevelDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    Config,require('./stand/FakeWorld'))
