local ok,Walker=pcall(require,'../src/server/gameplay/CanonicalWalker')
assert(ok,'CanonicalWalker must implement the verified source pixel renderer: '..tostring(Walker))
require('./gameplay/CanonicalWalker.spec')(Walker,require('./gameplay/fixtures/canonical_walker_pose_goldens'))
