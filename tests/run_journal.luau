require('./gameplay/RunJournal.spec')(require('../src/server/gameplay/RunJournal'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/stand/server/Config'),require('./stand/FakeWorld'))
