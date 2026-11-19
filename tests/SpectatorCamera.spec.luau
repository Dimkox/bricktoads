return function(Camera)
    assert(Camera.phoneFramingWeight(true, {X=390,Y=844}) == 1)
    assert(Camera.phoneFramingWeight(true, {X=844,Y=390}) == 1)
    assert(Camera.phoneFramingWeight(false, {X=844,Y=390}) == 0)
    assert(Camera.phoneFramingWeight(true, {X=1024,Y=768}) == 0)
    assert(Camera.phoneFramingWeight(true, {X=900,Y=630}) == .5)
    assert(Camera.phoneFramingWeight(true, {X=1,Y=1}) == 0)
    local heroes={
        {actorId='zero',status='Alive',hearts=0,dying=false,connected=true},
        {actorId='offline',status='Alive',hearts=3,dying=false,connected=false},
        {actorId='eliminated',status='Eliminated',hearts=5,connected=true},
        {actorId='dying',status='Alive',hearts=2,dying=true,connected=true},
        {actorId='absent',status='Alive',hearts=5,connected=true},
    }
    local targets=Camera.followTargets(heroes,{zero={},offline={},eliminated={},dying={}})
    assert(#targets==2 and targets[1].hero.actorId=='zero' and targets[2].hero.actorId=='offline',
        'Follow targets must use confirmed life state; raw zero alone is not elimination')
    print('PASS spectator targets retain zero-health and offline living heroes; skip eliminated dying absent actors')
end
