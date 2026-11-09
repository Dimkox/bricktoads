return function(Presentation,Animation)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function eq(a,b) assert(a==b,tostring(a)..' vs '..tostring(b)) end
    local function context(now)
        return {now=now or 0,dt=0,actorId='hero:1',enabled=true,grounded=true,mode='Idle',speed=0}
    end
    local function attack(action,start)
        return {action=action,actorId='hero:1',at=(start or 0)+.1,untilTime=(start or 0)+.25,tuning={windup=.1},order=1}
    end
    test('idle is a complete immutable source01 pose with explicit adaptation provenance',function()
        local p=assert(Presentation.sample(Presentation.new(),context()))
        eq(p.frameId,1);eq(p.kind,'Idle');eq(p.adaptation,'Authored3DJointAngles')
        local count=0
        for _,angles in pairs(p.joints) do
            count+=1;assert(table.isfrozen(angles));for _,angle in ipairs(angles) do assert(angle==angle and math.abs(angle)<=math.pi) end
        end
        eq(count,14);assert(table.isfrozen(p.joints))
        eq(Presentation.provenance.sourceCommit,Animation.provenance.commit)
        eq(Presentation.provenance.sourceCatalogSha256,Animation.provenance.sourceCatalogSha256)
        eq(Presentation.provenance.callsPerSecond,60);eq(Presentation.provenance.firstFrameCounterPhase,0)
    end)
    test('walk and run use source ordering with an explicit distance phase rather than a sine',function()
        for _,mode in ipairs({'Walk','Run'}) do
            local state=Presentation.new();local c=context();c.mode=mode;c.speed=12.5
            for phase=0,7 do
                c.dt=phase==0 and 0 or .1;c.now=phase*.1
                local p=assert(Presentation.sample(state,c))
                eq(p.kind,mode);eq(p.locomotionPhase,phase)
                eq(p.frameId,Animation.heroFrame(mode,{phase=phase}))
            end
        end
        local state=Presentation.new();local c=context();c.mode='Run';c.speed=0
        eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('every supported accepted action follows actual source clock frames and drives different joints',function()
        local cases={HeroJab=2,HeroUppercut=6,HeroPowerPunch=0xE,HeroKick=0x12,HeroBoot=0x14,HeroElbow=0x36,Dash=0x16}
        for action,id in pairs(cases) do
            local state=Presentation.new();local c=context();c.attack=attack(action)
            local seen={}
            for call=0,100 do
                c.now=call/60
                local expected=assert(Animation.sampleClock(id,{elapsedCalls=call,callerMask=1,firstFrameCounterPhase=0,firstRead='Read'}))
                local p=assert(Presentation.sample(state,c))
                if expected.ended then eq(p.kind,'Idle');break end
                eq(p.kind,'Attack');eq(p.animationId,id);eq(p.frameId,expected.frameId);eq(p.sourceCall,call)
                assert(p.joints~=Presentation.sample(Presentation.new(),context()).joints)
                seen[p.frameId]=true
            end
            assert(next(seen),'Action must display at least one source pose: '..action)
        end
    end)
    test('a punch extends a hand and kick extends a leg instead of changing metadata only',function()
        local c=context();c.attack=attack('HeroJab')
        local jab=Presentation.sample(Presentation.new(),c)
        assert(jab.joints.RightShoulder[1]>1 and math.abs(jab.joints.RightElbow[1])<.25)
        c.attack=attack('HeroKick');c.now=17/60
        local kick=Presentation.sample(Presentation.new(),c)
        eq(kick.frameId,0x20);assert(kick.joints.RightHip[1]>1 and math.abs(kick.joints.RightKnee[1])<.25)
    end)
    test('only verified graphics1C and1E request morphs while folded1F and uppercut22 keep normal limbs',function()
        for _,action in ipairs({'HeroPowerPunch','HeroBoot','HeroUppercut','HeroJab','HeroKick','HeroElbow','Dash'})do
            local state=Presentation.new();local c=context();c.attack=attack(action)
            for call=0,90 do
                c.now=call/60;local p=assert(Presentation.sample(state,c))
                local expected=p.frameId==0x1C and'PowerFist'or(p.frameId==0x1E and'BigBoot'or nil)
                eq(p.morphKind,expected)
                if p.frameId==0x1F or p.frameId==0x22 then eq(p.morphKind,nil)end
            end
        end
    end)
    test('source time starts at accepted windup timestamp and late observation does not replay windup',function()
        local c=context(.4);c.attack=attack('HeroUppercut',.1)
        local p=Presentation.sample(Presentation.new(),c)
        eq(p.sourceCall,18);eq(p.clockBasis,'AcceptedWindupTimestamp')
        eq(p.frameId,Animation.sampleClock(6,{elapsedCalls=18,callerMask=1,firstFrameCounterPhase=0,firstRead='Read'}).frameId)
    end)
    test('a new accepted table replaces the sequence immediately even when the action repeats',function()
        local state=Presentation.new();local c=context();c.attack=attack('HeroPowerPunch')
        Presentation.sample(state,c);c.now=.5;eq(Presentation.sample(state,c).frameId,0x1C)
        c.attack=attack('HeroPowerPunch',.5)
        eq(Presentation.sample(state,c).frameId,0x1D)
        c.attack=attack('HeroJab',.5)
        local p=Presentation.sample(state,c);eq(p.frameId,0x19);eq(p.sourceCall,0)
    end)
    test('accepted table mutation is canceled and cannot masquerade as a second acceptance',function()
        local state=Presentation.new();local c=context();c.attack=attack('HeroJab')
        Presentation.sample(state,c);c.attack.action='HeroBoot';c.now=.1
        local p,reason=Presentation.sample(state,c);eq(p,nil);eq(reason,'AttackChanged')
        c.now=.2;eq(Presentation.sample(state,c),nil)
        c.attack=attack('HeroBoot',.2);eq(Presentation.sample(state,c).animationId,0x14)
    end)
    test('a resolved attack can finish its source recovery without holding the gameplay attack open',function()
        local state=Presentation.new();local c=context();c.attack=attack('HeroBoot')
        Presentation.sample(state,c);c.now=.1;c.attack=nil;c.recoveryAction='HeroBoot';c.recoveryUntil=.3
        eq(Presentation.sample(state,c).kind,'Attack')
        c.now=.65;eq(Presentation.sample(state,c).frameId,0x1E)
        c.now=2;local idle=Presentation.sample(state,c);eq(idle.kind,'Idle');eq(idle.joints.RightHip[1],0)
    end)
    test('canceling before resolution clears the extended limb and never restarts the same table',function()
        local state=Presentation.new();local c=context();local a=attack('HeroJab');c.attack=a
        eq(Presentation.sample(state,c).kind,'Attack')
        c.attack=nil;c.now=.05;eq(Presentation.sample(state,c).kind,'Idle')
        c.attack=a;c.now=.1;eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('all priority fallbacks cancel old clips and preserve the existing retarget path',function()
        for _,reason in ipairs({'Dead','Reaction','Carrying','Carried','Club','Dragon','Airborne','Paused'}) do
            local state=Presentation.new();local c=context();c.attack=attack('HeroBoot')
            Presentation.sample(state,c);c.blocked=reason;c.now=.1
            local p,code=Presentation.sample(state,c);eq(p,nil);eq(code,reason)
            c.blocked=nil;c.now=.2;eq(Presentation.sample(state,c).kind,'Idle')
            c.attack=attack('HeroJab',.2);eq(Presentation.sample(state,c).kind,'Attack')
        end
    end)
    test('reactions that begin and end between visual updates still cancel the remembered clip',function()
        local state=Presentation.new();local c=context();c.reactionEpoch=1;c.attack=attack('HeroBoot')
        Presentation.sample(state,c);c.now=.1;c.reactionEpoch=2
        local p=Presentation.sample(state,c);eq(p.kind,'Idle')
        c.now=.2;eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('stale actor unknown attack and unverified airborne mapping use fallback atomically',function()
        local c=context();c.attack=attack('HeroJab');c.attack.actorId='old:hero'
        local p,reason=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(reason,'StaleAttack')
        c.attack=attack('Club');p,reason=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(reason,'UnsupportedAttack')
        c.attack=nil;c.grounded=false;p,reason=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(reason,'Airborne')
        c.grounded=true;c.enabled=false;p,reason=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(reason,'Disabled')
    end)
    test('source hit opportunities are inert markers delivered once across skipped render samples',function()
        local state=Presentation.new();local c=context();local a=attack('Dash');c.attack=a
        local count=0
        local function collect(p)
            for _,event in ipairs(p.events) do
                assert(event.appliesDamage==false)
                if event.kind=='HitOpportunity' then count+=1 end
            end
        end
        collect(Presentation.sample(state,c));c.now=.4;collect(Presentation.sample(state,c))
        collect(Presentation.sample(state,c));eq(count,11)
        eq(c.attack,a);eq(a.action,'Dash');eq(a.at,.1);eq(a.tuning.windup,.1)
        eq(a.damage,nil);eq(a.health,nil)
    end)
    test('actors have independent clocks and time rewind does not resurrect an accepted attack',function()
        local first,second=Presentation.new(),Presentation.new();local c=context();c.attack=attack('HeroBoot')
        Presentation.sample(first,c);local other=context();other.actorId='hero:2'
        eq(Presentation.sample(second,other).kind,'Idle')
        c.now=.5;eq(Presentation.sample(first,c).frameId,0x1E)
        c.now=.1;local p,reason=Presentation.sample(first,c);eq(p,nil);eq(reason,'ClockRewind')
        c.now=.2;eq(Presentation.sample(first,c).kind,'Idle')
    end)
    print(string.format('Canonical hero presentation: %d passed, %d failed',passed,failed))
    assert(failed==0,'Canonical hero presentation contracts failed')
end
