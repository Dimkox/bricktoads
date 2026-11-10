local Base=require('../src/stand/server/Config')
local Config=require('../src/server/gameplay/GameConfig')(Base,require('../src/server/gameplay/LevelDefinition'))
assert(not Base.Attacks.WalkerLight and not Base.Attacks.WalkerHeavy,'Walker configuration must stay private to the main game')
require('./gameplay/WalkerStrikes.spec')(require('../src/server/gameplay/LevelDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    Config,require('./stand/FakeWorld'),require('../src/server/gameplay/WalkerClubs'))
