require('./gameplay/WalkerClubs.spec')(require('../src/server/gameplay/WalkerClubs'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),
    require('../src/stand/server/Combat'),require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config')),
    require('./stand/FakeWorld'))
