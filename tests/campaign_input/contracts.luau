local function hero(mode,mounted,finished)
    return {mine=1,heroes={{slot=1,actorId='hero-1',status='Alive',connected=true,movementMode='Ride'}},
        level={mode=mode,modeState={mode=mode,actors={{slot=1,actorId='hero-1',mounted=mounted,finished=finished}}}}}
end
for _,touch in ipairs({false,true})do
    for _,mode in ipairs({'Speeder','Surf','Jet'})do
        local state=actionState(hero(mode,true,false),touch)
        assert(state.primary==false and state.mega==false,mode..' must not offer unavailable ground attacks')
        assert(state.jump==true,mode..' must retain its actual jump/lift action')
        assert(state.run==false,mode..' must not advertise double-tap ground running')
    end
    local clinger=actionState(hero('Clinger',false,false),touch)
    assert(not clinger.primary and not clinger.mega and not clinger.jump and not clinger.run,
        'Clinger accepts directional control, not ground strikes or a no-op jump')
    for _,data in ipairs({hero('Speeder',false,false),hero('Surf',true,true),hero('Jet',false,false)})do
        local state=actionState(data,touch)
        assert(state.primary and state.jump and state.mega==not touch,'boarding and finished heroes keep ordinary controls')
    end
    local other=hero('Speeder',false,false)
    other.level.modeState.actors[2]={slot=2,actorId='hero-2',mounted=true,finished=false}
    assert(actionState(other,touch).primary,'another rider must not hide the current foot hero action')
    for _,kind in ipairs({'Dragon','EnemyCarry'})do
        local data=hero('Causeway',false,false)
        data.interaction={kind=kind,available=true,carrying=true,label='FIRE / THROW'}
        local state=actionState(data,touch)
        assert(state.primary and state.jump and not state.mega,'linked Dragon and held-item actions remain available')
    end
    local rope=hero('Rope',false,false)
    rope.interaction={kind='CampaignKick',available=true,label='Rope kick'}
    assert(actionState(rope,touch).primary and actionState(rope,touch).jump,'rope kick and push-off remain available')
    local rat=hero('Speeder',true,false)
    rat.mine=nil;rat.enemyRole={movementKind='Ride',template='Sentry'}
    local state=actionState(rat,touch)
    assert(state.primary and not state.mega and not state.jump,'human RocketRat keeps Drop instead of hero controls')
    rat.enemyRole={movementKind='Race',template='Racer',resourceKind='CourseRival'}
    state=actionState(rat,touch)
    assert(not state.primary and not state.mega and state.jump,'physical race rival keeps its existing move/jump role')
end
print('PASS actual client action visibility matches mounted, foot, linked and human-enemy controls on desktop/touch')
