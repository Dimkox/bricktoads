local Definition=require('../src/server/gameplay/LevelDefinition')
local Config=require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),Definition)
require('./gameplay/LevelRoute.spec')(require('../src/server/gameplay/LevelDirector'),Definition,Config)
