local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
print('PlatformDrivers: '..require('./PlatformDrivers')(Definition,Modes)..' passed')
