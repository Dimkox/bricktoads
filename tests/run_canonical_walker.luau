local ok,Walker=pcall(require,'../src/server/gameplay/CanonicalWalker')
assert(ok,'CanonicalWalker must implement the verified source pixel renderer: '..tostring(Walker))
require('./gameplay/CanonicalWalker.spec')(Walker,require('./gameplay/fixtures/canonical_walker_pose_goldens'))

for _,forward in ipairs({-2,0,2}) do
    local lastBend=0
    for _,drop in ipairs({6.84,5.0,4.35}) do
        local hip,hock,foot=Walker.legAngles(drop,forward)
        local shin=hip+hock
        assert(hip<math.atan2(forward,drop) and hock>lastBend,"The hock must fold behind the hip-to-foot line")
        assert(math.abs(3.55*math.cos(hip)+3.7*math.cos(shin)-drop)<.001)
        assert(math.abs(3.55*math.sin(hip)+3.7*math.sin(shin)-forward)<.001)
        assert(math.abs(shin+foot)<.001,"Foot must stay planted")
        lastBend=hock
    end
end
