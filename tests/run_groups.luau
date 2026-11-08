require('./gameplay/MatchHub.spec')(
    require('../src/server/gameplay/MatchHub'),require('../src/server/gameplay/GameController'),
    require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/stand/server/Session'),require('../src/stand/server/ConnectionRegistry'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config')),
    require('./stand/FakeWorld'),require('../src/server/gameplay/LevelDirector'),
    require('../src/server/gameplay/BossQueue'),require('../src/server/gameplay/LevelVariation'),
    require('../src/server/gameplay/LevelDefinition'))
