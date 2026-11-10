local V=require('../../src/server/gameplay/LevelVariation')
local id="bricktoads-qa-24-01-eb532d07"
assert(#id<100 and id~='bricktoads-qa-23-01-384fb79f')
assert(V.seedFromId(id)==1158731273)
print('PASS native24 unique identity derives seed1158731273 through production LevelVariation')
