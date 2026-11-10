local Variation=require('../../src/server/gameplay/LevelVariation')
local previous='b280d913-e985-4f4d-a190-d80e85728ea0'
local requested='bricktoads-qa-22-00-5530a024'
assert(previous~=requested and #requested<100)
assert(Variation.seedFromId(previous)==1158731273)
assert(Variation.seedFromId(requested)==1158731273)
print('PASS unique short run identity derives identical ordinary production seed 1158731273')
