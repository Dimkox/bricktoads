local Director=require('../src/server/gameplay/LevelDirector')
require('./gameplay/LevelDirector.spec')(Director,require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),
    require('../src/stand/server/Combat'),require('../src/stand/server/Config'),require('./stand/FakeWorld'))
local Controller=require('../src/server/gameplay/GameController')
require('./gameplay/GameController.spec')(Controller,require('../src/server/RunLifecycle'),
    require('../src/stand/server/Combat'),require('../src/stand/server/Session'),
    require('../src/stand/server/ConnectionRegistry'),require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config')),require('./stand/FakeWorld'),Director,
    require('../src/server/gameplay/BossQueue'))
require('./SpectatorCamera.spec')(require('../src/client/SpectatorCamera'))
