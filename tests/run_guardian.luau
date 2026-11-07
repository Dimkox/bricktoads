require('./gameplay/GuardianPattern.spec')(require('../src/server/gameplay/GuardianPattern'))
require('./gameplay/GuardianSession.spec')(require('../src/server/gameplay/GuardianPattern'),require('../src/stand/server/Session'),
    require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition')),
    require('./stand/FakeWorld'))
