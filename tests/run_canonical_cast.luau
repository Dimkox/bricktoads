local P=require('../src/server/gameplay/CanonicalCastPresentation')
local passed,failed=0,0
local function check(name,fn) local ok,why=pcall(fn);if ok then passed+=1;print('PASS cast '..name)else failed+=1;print('FAIL cast '..name..': '..tostring(why))end end
local function accepted(name,start,actorId,epoch)
    return {name=name,start=start or 10,actorId=actorId or 'body-1',levelEpoch=epoch or 1}
end
local function context(kind,more)
    local c={kind=kind,actorId='body-1',levelEpoch=1,now=10,dt=.1,speed=0,mode='Idle'}
    for k,v in pairs(more or {}) do c[k]=v end
    return c
end
check('healing flies use their collectible source cycle and articulated wings',function()
    local row=P.sample(P.new(),context('HealingFly',{mode='Fly'}))
    assert(row and (row.frameId==13 or row.frameId==14) and row.joints.LeftWing and row.joints.RightWing)
end)
check('every gameplay family has a finite articulated cosmetic pose',function()
    local n=0
    for _,kind in ipairs(P.kinds()) do
        local row=assert(P.sample(P.new(),context(kind)))
        assert(row.kind==kind and row.appliesDamage==false and row.joints.Body)
        for _,v in pairs(row.joints) do for _,x in ipairs(v) do assert(x==x and math.abs(x)<100) end end
        n+=1
    end
    assert(n>=28)
end)
check('boss graphics remain in their high-bit namespace',function()
    local row=P.sample(P.new(),context('DarkQueen',{attack=accepted('Sweep'),phase='Tell'}))
    assert(row.animationId==0x8A and row.frameId==0x81 and row.namespace=='heroStatic:Queen')
    local blag=P.sample(P.new(),context('BigBlag',{attack=accepted('Hop'),phase='Tell'}))
    assert(blag.animationId==0x84 and blag.frameId==0xEF)
end)
check('Pig attack and Dragon flight use object graphics rather than hero frames',function()
    local pig=P.sample(P.new(),context('Pig',{attack=accepted('PigJab'),phase='Tell'}))
    assert(pig.animationId==0x28 and pig.frameId==5 and pig.namespace=='object:Canyon')
    local dragon=P.sample(P.new(),context('Dragon',{mode='Fly'}))
    assert(dragon.frameId==9 or dragon.frameId==10)
end)
check('Walker stream values select articulated leg geometry',function()
    local row=P.sample(P.new(),context('Walker',{attack=accepted('WalkerHeavy'),phase='Tell'}))
    assert(row.frameId==0x19 and row.components and row.components.units=='sourcePixels')
end)
check('accepted source markers are inert and emitted once across skipped samples',function()
    local s=P.new();local attack=accepted('PigJab')
    P.sample(s,context('Pig',{attack=attack,phase='Tell'}))
    local row=P.sample(s,context('Pig',{now=10.25,attack=attack,phase='Active'}))
    assert(#row.events>0 and row.appliesDamage==false)
    local again=P.sample(s,context('Pig',{now=10.25,attack=attack,phase='Active'}))
    assert(#again.events==0)
end)
check('skipping beyond a clip end still delivers its markers once without restarting',function()
    local s=P.new();local attack=accepted('PigJab')
    P.sample(s,context('Pig',{attack=attack,phase='Tell'}))
    local last=P.sample(s,context('Pig',{now=12,attack=attack,phase='Recovery'}))
    assert(#last.events>0 and not last.animationId)
    local repeatRow=P.sample(s,context('Pig',{now=12.1,attack=attack,phase='Recovery'}))
    assert(#repeatRow.events==0 and not repeatRow.animationId)
end)
check('reaction and death interrupt a previous attack pose',function()
    local s=P.new();local attack=accepted('Charge')
    P.sample(s,context('GeneralSlaughter',{attack=attack,phase='Tell'}))
    local hit=P.sample(s,context('GeneralSlaughter',{now=10.1,reacting=true,attack=attack}))
    assert(hit.state=='Reaction' and not hit.animationId)
    local dead=P.sample(s,context('GeneralSlaughter',{now=10.2,dead=true,attack=attack}))
    assert(dead.state=='Dead' and not dead.animationId and #dead.events==0)
end)
check('replacement actor and epoch discard old source sequence',function()
    local s=P.new();local attack=accepted('Sweep')
    P.sample(s,context('DarkQueen',{attack=attack,phase='Tell'}))
    local row=P.sample(s,context('DarkQueen',{now=10.2,actorId='body-2'}))
    assert(not row.animationId and #row.events==0 and s.actorId=='body-2')
    row=P.sample(s,context('DarkQueen',{now=10.3,actorId='body-2',levelEpoch=2}))
    assert(not row.animationId and s.levelEpoch==2)
end)
check('flight swim and stationary traps retain distinct articulation',function()
    local a=P.sample(P.new(),context('Raven',{mode='Fly',speed=9}))
    local b=P.sample(P.new(),context('Shark',{mode='Swim',speed=9}))
    local c=P.sample(P.new(),context('SaturnToadtrap',{attack=accepted('Snap'),phase='Active'}))
    assert(a.joints.LeftWing and b.joints.Tail and c.joints.Jaw)
    assert(a.joints.LeftWing[3]~=b.joints.Tail[2] and c.joints.Jaw[1]~=0)
end)
check('invalid identity time and kind fail without corrupting a valid state',function()
    local s=P.new();assert(P.sample(s,context('Pig')))
    for _,bad in ipairs({{now=0/0},{actorId=false},{kind='Unknown'},{now=9}}) do
        assert(P.sample(s,context('Pig',bad))==nil)
    end
    assert(s.actorId=='body-1' and s.lastNow==10)
end)
check('completed or interrupted immutable attacks never replay after an idle gap',function()
    for _,interrupted in ipairs({false,true})do
        local s=P.new();local attack=accepted('PigJab')
        assert(P.sample(s,context('Pig',{attack=attack})).animationId==0x28)
        P.sample(s,context('Pig',{now=interrupted and 10.1 or 12,attack=attack,reacting=interrupted}))
        P.sample(s,context('Pig',{now=12.1}))
        local row=P.sample(s,context('Pig',{now=12.2,attack=attack}))
        assert(not row.animationId and #row.events==0,'Old attack identity replayed')
    end
end)
check('stale actor and epoch action wrappers cannot animate a replacement',function()
    local s=P.new();local attack=accepted('PigJab');P.sample(s,context('Pig',{attack=attack}))
    local row,reason=P.sample(s,context('Pig',{now=10.1,actorId='body-2',attack=attack}))
    assert(not row and reason=='STALE_ATTACK')
    row,reason=P.sample(s,context('Pig',{now=10.2,actorId='body-2',attack=accepted('PigJab',10,'body-2',0)}))
    assert(not row and reason=='STALE_ATTACK')
    assert(P.sample(s,context('Pig',{now=10.3,actorId='body-2',attack=accepted('PigJab',10.3,'body-2')})).animationId==0x28)
end)
check('rewind cancels source playback but a lower-time replacement starts its own clock',function()
    local s=P.new();local attack=accepted('PigJab');P.sample(s,context('Pig',{attack=attack}))
    assert(P.sample(s,context('Pig',{now=9,attack=attack}))==nil)
    local row=P.sample(s,context('Pig',{now=10.1,attack=attack}))
    assert(not row.animationId and #row.events==0,'Rewind resumed a canceled attack')
    row=P.sample(s,context('Pig',{now=0,actorId='fresh',attack=accepted('PigJab',0,'fresh')}))
    assert(row and row.animationId==0x28,'New identity inherited the previous clock')
end)
check('mutating an accepted table cannot switch or restart its source clip',function()
    local s=P.new();local attack=accepted('PigJab');P.sample(s,context('Pig',{attack=attack}))
    attack.name='PigHeavy';local row,reason=P.sample(s,context('Pig',{now=10.1,attack=attack}))
    assert(not row and reason=='ATTACK_CHANGED')
    attack.name='PigJab';row=P.sample(s,context('Pig',{now=10.2,attack=attack}))
    assert(not row.animationId and #row.events==0)
end)
check('source Pig and boss frame transitions actually change the displayed joints',function()
    for _,case in ipairs({{'Pig','PigJab',5,6,.21,'RightArm'},
        {'BigBlag','Hop',0xEF,0xF1,.08,'LeftArm'},
        {'GeneralSlaughter','Charge',0xF3,0xF4,.12,'Head'},
        {'DarkQueen','Sweep',0x81,0x82,.08,'RightArm'}})do
        local s=P.new();local attack=accepted(case[2]);local c=context(case[1],{attack=attack,phase='Tell'})
        local first=assert(P.sample(s,c));assert(first.frameId==case[3])
        c.now=10+case[5];local second=assert(P.sample(s,c));assert(second.frameId==case[4])
        local a,b=first.joints[case[6]],second.joints[case[6]]
        assert(a[1]~=b[1] or a[2]~=b[2] or a[3]~=b[3],'Source frame changed metadata only')
    end
end)
check('Dragon disabled attack and reaction graphics have distinct head and wing silhouettes',function()
    local a=P.sample(P.new(),context('Dragon',{mode='Disabled'}))
    local b=P.sample(P.new(),context('Dragon',{attack=accepted('DragonHeadbutt'),phase='Tell'}))
    local c=P.sample(P.new(),context('Dragon',{reacting=true,reactionTimerRaw=0x26}))
    assert(a.frameId==0x0A and b.frameId==0x0B and c.frameId==0x0C)
    assert(a.joints.Head[1]~=b.joints.Head[1] and c.joints.LeftWing[3]~=b.joints.LeftWing[3])
end)
check('priority agrees with the whole pose and stops wing tail and orb motion',function()
    for _,kind in ipairs({'Raven','Buzzball','DarkQueen'})do
        local s=P.new();local c=context(kind,{now=10,dead=true,reacting=true,carried=true,phase='Active',speed=20})
        local a=P.sample(s,c);c.now=11;local b=P.sample(s,c)
        assert(a.state=='Dead' and math.abs(a.joints.Body[3]-1.45)<1e-6)
        for name,angles in pairs(a.joints)do for index,value in ipairs(angles)do assert(value==b.joints[name][index],'Dead '..name..' still moves')end end
        c.dead=false;local reaction=P.sample(s,c);assert(reaction.state=='Reaction' and math.abs(reaction.joints.Body[1]+.25)<1e-6)
    end
end)
check('later source cycles hold each visible pose until the decoded graphics index changes',function()
    for _,case in ipairs({{'Raven','Fly',0x1C,0x1D,'LeftWing'},
        {'Invader','Walk',0x24,0x25,'LeftLeg'},{'Electrofish','Swim',0xE2,0xE3,'Tail'},
        {'Shark','Swim',0xDE,0xDF,'Tail'},{'Buzzball','Fly',0x7C,0x7D,'Body'},
        {'RacingRat','Walk',0x82,0x83,'LeftLeg'}})do
        local state=P.new();local c=context(case[1],{mode=case[2],speed=12})
        local a=P.sample(state,c);c.now=10.04;local same=P.sample(state,c)
        assert(a.frameId==case[3] and same.frameId==case[3])
        local joint=a.joints[case[5]]
        for index,value in ipairs(joint)do assert(value==same.joints[case[5]][index],'Visible pose runs on a separate sine clock')end
        local changed
        for index=1,4 do c.now=10+index*.125;local row=P.sample(state,c);if row.frameId==case[4] then changed=row;break end end
        assert(changed and (joint[1]~=changed.joints[case[5]][1] or joint[2]~=changed.joints[case[5]][2] or joint[3]~=changed.joints[case[5]][3]))
    end
end)
check('moving Walker drives exact straight component poses through an explicitly authored gait clock',function()
    local state=P.new();local c=context('Walker',{speed=12})
    local a=P.sample(state,c);c.now=10.2;local b=P.sample(state,c)
    assert(a.components and b.components and a.components.legs[1].delta~=b.components.legs[1].delta)
    assert(b.frameBasis=='Authored3DGaitDrivingSourceComponents')
    c.speed=0;c.now=10.3;local rest=P.sample(state,c)
    assert(rest.components.legs[1].delta==0 and rest.components.legs[2].delta==0)
end)
check('real heavy flags and declared reaction progress retain source Pig and Dragon silhouettes',function()
    local s=P.new();local c=context('Pig',{reacting=true,reactionHeavy=true,reactionProgress=0})
    local first=P.sample(s,c);assert(first.frameId==5 and first.frameBasis=='Authored3DReactionPhaseMapping')
    c.now=10.2;c.reactionProgress=.8;local later=P.sample(s,c);assert(later.frameId==8)
    local d=P.sample(P.new(),context('Dragon',{reacting=true,reactionHeavy=true,sourceState='HeavyDisabled'}))
    assert(d.frameId==0xA)
end)
check('light Pig reactions recover through source frame4 instead of the heavy frame8',function()
    -- main.asm:16703-16720: light7 ->4, heavy5 ->8. Progress is authored3D timing.
    local s=P.new();local c=context('Pig',{reacting=true,reactionHeavy=false,reactionProgress=0})
    local first=P.sample(s,c);assert(first.frameId==7)
    c.now=10.2;c.reactionProgress=.8;local later=P.sample(s,c)
    assert(later.frameId==4,'Light Pig recovery must not select the heavy recoil silhouette')
    assert(later.frameBasis=='Authored3DReactionPhaseMapping' and later.joints.LeftLeg[1]==-.55,
        'The light recovery source frame must change the visible leg pose')
end)
check('light Dragon reactions without source timer bytes return from0C to the source flight cycle',function()
    -- main.asm:2997-3001;3046-3056:0C before the timer gate, then9/9/0A/0A.
    local s=P.new();local c=context('Dragon',{reacting=true,reactionHeavy=false,reactionProgress=0,mode='Fly'})
    local first=P.sample(s,c)
    assert(first.frameId==0xC and first.frameBasis=='Authored3DReactionPhaseMapping',
        'A real light Dragon reaction must retain its decoded recoil silhouette')
    c.now=10.2;c.reactionProgress=.8;local earlyFlight=P.sample(s,c)
    c.now=10.3;local lateFlight=P.sample(s,c)
    assert(earlyFlight.frameId==9 and lateFlight.frameId==0xA,
        'Late light recoil must resume both decoded flight poses')
    assert(first.joints.Head[1]~=earlyFlight.joints.Head[1]
        and earlyFlight.joints.LeftWing[3]~=lateFlight.joints.LeftWing[3],
        'Decoded recovery frames must change the visible head and wings')
    c.reactionTimerRaw=0x26;local measured=P.sample(s,c)
    assert(measured.frameId==0xC and measured.frameBasis=='SourceReactionTimer',
        'A supplied source timer takes precedence over authored progress')
end)
print('CanonicalCast: '..passed..' passed; '..failed..' failed')
assert(failed==0,'Canonical cast contracts failed')
