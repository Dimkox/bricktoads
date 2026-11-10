local V=require('../../src/server/gameplay/LevelVariation')
local id="bricktoads-qa-25-01-b980fe3d"
assert(#id<100 and id~='bricktoads-qa-24-01-eb532d07')
assert(V.seedFromId(id)==1158731273)
print('PASS native25 unique identity derives seed1158731273 through production LevelVariation')
