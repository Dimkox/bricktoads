require('./campaign_progression/Session.spec')(require('../src/stand/server/Session'),
    require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/stand/server/Config'),require('./stand/FakeWorld'))
local ok,CampaignDirector=pcall(function() return require('../src/server/gameplay/CampaignDirector') end)
require('./campaign_progression/Director.spec')(ok and CampaignDirector or {},require('../src/server/gameplay/LevelDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config')),require('./stand/FakeWorld'))
require('./campaign_progression/Runtime.spec')(require('../src/server/gameplay/CampaignDefinition'),
    require('../src/server/gameplay/CampaignModes'),require('../src/server/gameplay/CampaignBoss'),
    require('../src/server/gameplay/LevelDirector'),require('../src/server/gameplay/CampaignDirector'),
    require('../src/stand/server/Session'),require('../src/server/RunLifecycle'),require('../src/stand/server/Combat'),
    require('../src/server/gameplay/GameConfig'),require('../src/stand/server/Config'),require('./stand/FakeWorld'),
    require('../src/server/gameplay/SourceCombat'),require('../src/server/gameplay/CampaignEnemies'))
require('./campaign_progression/Controller.spec')(require('../src/server/gameplay/GameController'),require('../src/server/RunLifecycle'),
    require('../src/stand/server/Combat'),require('../src/stand/server/Session'),require('../src/stand/server/ConnectionRegistry'),
    require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config')),require('./stand/FakeWorld'),
    require('../src/server/gameplay/BossQueue'))
require('./campaign_progression/VictorySurvivor.spec')()
