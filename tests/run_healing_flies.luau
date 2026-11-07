require('./gameplay/HealingFlies.spec')(require('../src/server/gameplay/HealingFlies'),require('../src/stand/server/Session'),
    require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition')),
    require('./stand/FakeWorld'),require('../src/server/gameplay/LevelDefinition'))
