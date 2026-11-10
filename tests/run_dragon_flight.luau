local ok,Flight=pcall(require,'../src/server/gameplay/DragonFlight')
require('./gameplay/DragonFlight.spec')(ok and Flight or nil,
    require('../src/server/gameplay/LevelDirector'),require('../src/stand/server/Session'),
    require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition')),
    require('./stand/FakeWorld'),require('../src/server/gameplay/SourceCombat'))
