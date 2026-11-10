local V=require('../../src/server/gameplay/LevelVariation')
local id="bricktoads-qa-23-01-384fb79f"
assert(#id<100 and id~='bricktoads-qa-22-00-5530a024')
assert(V.seedFromId(id)==1158731273)
print('PASS native23 unique identity derives seed1158731273 through production LevelVariation')
