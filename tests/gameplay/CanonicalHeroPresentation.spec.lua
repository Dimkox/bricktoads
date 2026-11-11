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
        c.attack=attack('UntracedAction');p,reason=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(reason,'UnsupportedAttack')
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
    test('captured intro selects actual source fear forms without applying source motion',function()
        local state=Presentation.new();local c=context()
        c.fearIntro={id='run:1:intro',actorId=c.actorId,counter=1,frameId=0x32}
        local p=assert(Presentation.sample(state,c));eq(p.kind,'Fear');eq(p.frameId,0x32)
        eq(p.animationId,0x2C);eq(p.morphKind,'FearBeforeCut');eq(#p.events,0)
        c.now=1;c.fearIntro.counter=0xE0
        eq(Presentation.sample(state,c).frameId,0x32)
        c.now=2;c.fearIntro.counter=0xE1;c.fearIntro.frameId=0x33
        p=assert(Presentation.sample(state,c));eq(p.animationId,0x2E);eq(p.morphKind,'FearAfterCut')
        eq(p.frameId,0x33);eq(p.adaptation,'Authored3DJointAngles')
        local count=0;for _,angles in pairs(p.joints)do count+=1;assert(table.isfrozen(angles))end;eq(count,14)
    end)
    test('fear requires the captured living actor and respects higher priority interruption',function()
        for _,invalid in ipairs({'OtherActor','Complete','UnknownFrame','NoIdentity'})do
            local c=context();c.fearIntro={id='intro',actorId=c.actorId,counter=1,frameId=0x32}
            if invalid=='OtherActor'then c.fearIntro.actorId='replacement'
            elseif invalid=='Complete'then c.fearIntro.counter=255
            elseif invalid=='UnknownFrame'then c.fearIntro.frameId=0x1C
            else c.fearIntro.id=nil end
            eq(Presentation.sample(Presentation.new(),c).kind,'Idle')
        end
        for _,reason in ipairs({'Reaction','Dead','Club','Carrying','Dragon','Airborne'})do
            local c=context();c.fearIntro={id='intro',actorId=c.actorId,counter=1,frameId=0x32};c.blocked=reason
            local p,code=Presentation.sample(Presentation.new(),c);eq(p,nil);eq(code,reason)
        end
    end)
    test('intro replaces cosmetic attack state and cannot resume that old accepted action afterward',function()
        local state=Presentation.new();local c=context(.5);c.attack=attack('HeroPowerPunch')
        eq(Presentation.sample(state,c).morphKind,'PowerFist')
        c.now=.6;c.fearIntro={id='intro',actorId=c.actorId,counter=1,frameId=0x32}
        eq(Presentation.sample(state,c).kind,'Fear')
        c.now=.7;c.fearIntro=nil;eq(Presentation.sample(state,c).kind,'Idle')
        c.now=.8;c.attack=attack('HeroJab',.8);eq(Presentation.sample(state,c).kind,'Attack')
    end)
    test('trusted air context selects source apex and held frames without reviving an interrupted boot',function()
        local state=Presentation.new();local c=context(.5);c.attack=attack('HeroBoot')
        eq(Presentation.sample(state,c).morphKind,'BigBoot')
        c.now=.6;c.visualState='Air';c.grounded=false;c.sourceZSpeedRaw=0
        local p=assert(Presentation.sample(state,c));eq(p.kind,'Air');eq(p.frameId,0x2D);eq(p.morphKind,nil)
        c.sourceZSpeedRaw=-4;eq(Presentation.sample(state,c).frameId,0x05)
        c.holding=true;eq(Presentation.sample(state,c).frameId,0x2E)
        c.visualState=nil;c.grounded=true;c.holding=false;c.now=.7
        eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('world velocity air selection states its authored mapping and invalid raw source input never guesses',function()
        local c=context();c.grounded=false;c.visualState='Air';c.verticalSpeed=0
        local p=assert(Presentation.sample(Presentation.new(),c));eq(p.frameId,0x2D);eq(p.frameBasis,'Authored3DVelocityMapping')
        c.verticalSpeed=8;eq(Presentation.sample(Presentation.new(),c).frameId,0x05)
        c.sourceZSpeedRaw=.5
        local row,reason=Presentation.sample(Presentation.new(),c);eq(row,nil);eq(reason,'InvalidSourceZSpeed')
    end)
    test('carry and depth gait use distinct source frames and visible held-arm joints',function()
        local c=context();c.visualState='Carrying';c.holding=true
        local state=Presentation.new();local p=assert(Presentation.sample(state,c));eq(p.frameId,0x11)
        assert(p.joints.LeftShoulder[1]>2 and p.joints.RightShoulder[1]>2)
        c.speed=12.5;c.mode='Walk'
        for phase,want in ipairs({0x11,0x12,0x11,0x10})do
            c.dt=phase==1 and 0 or .1;c.now=phase*.1
            eq(Presentation.sample(state,c).frameId,want)
        end
        state=Presentation.new();c.visualState='DepthWalk';c.holding=false
        for phase,want in ipairs({1,9,1,10})do
            c.dt=phase==1 and 0 or .1;c.now=phase*.1
            eq(Presentation.sample(state,c).frameId,want)
        end
    end)
    test('accepted club tongue pickup and throws consume their actual source clips once',function()
        for _,case in ipairs({{'Club',0x1A,0x26},{'Tongue',0x18,0x29},{'PickupObject',8,0x0B},
            {'PickupEnemy',0x0A,0x0B},{'Throw',0x0C,0x0E},{'BossBallThrow',0x70,0x0E},{'HeroJabB',4,0x1B}})do
            local c=context();c.visualAction=attack(case[1]);local state=Presentation.new()
            local p=assert(Presentation.sample(state,c));eq(p.kind,'Attack');eq(p.animationId,case[2]);eq(p.frameId,case[3])
            c.now=.5;p=assert(Presentation.sample(state,c));assert(p.joints and #p.events>=0)
            for _,event in ipairs(p.events)do eq(event.appliesDamage,false)end
            c.now=4;eq(Presentation.sample(state,c).kind,'Idle')
            c.now=5;eq(Presentation.sample(state,c).kind,'Idle')
        end
    end)
    test('reaction source selectors distinguish rear stun rising falling and ground silhouettes',function()
        for _,case in ipairs({{false,false,true,24,0,0x29},{false,true,true,24,0,0x16},
            {false,false,true,23,0,2},{true,false,false,24,3,0x13},{true,false,false,24,-3,0x14},
            {true,false,true,24,0,0x15}})do
            local c=context();c.visualState='Reaction';c.verticalSpeed=case[5]
            c.reaction={heavy=case[1],fromRear=case[2],grounded=case[3],timerRaw=case[4],startedAt=0}
            local p=assert(Presentation.sample(Presentation.new(),c));eq(p.kind,'Reaction');eq(p.frameId,case[6]);eq(p.morphKind,nil)
        end
    end)
    test('death carried mounted and course poses interrupt all limbs with explicit adaptation provenance',function()
        for _,kind in ipairs({'Dead','Carried','DragonMounted','DragonCaptured','Swim','Ride','Rope'})do
            local state=Presentation.new();local c=context(.5);c.attack=attack('HeroBoot')
            eq(Presentation.sample(state,c).morphKind,'BigBoot')
            c.now=.6;c.visualState=kind;c.verticalSpeed=0
            c.fearIntro={id='intro',actorId=c.actorId,counter=1,frameId=0x32}
            local p=assert(Presentation.sample(state,c));eq(p.kind,kind);eq(p.morphKind,nil)
            eq(p.frameBasis,'Authored3DAdaptation');eq(p.namespace,'Authored3D');assert(table.isfrozen(p.joints))
            c.visualState=nil;c.fearIntro=nil;c.now=.7;eq(Presentation.sample(state,c).kind,'Idle')
        end
    end)
    test('course gait has visible animation and a replacement actor cannot inherit the phase or accepted action',function()
        local state=Presentation.new();local c=context();c.visualState='Swim'
        local p=assert(Presentation.sample(state,c));local first=p.joints.RightShoulder[1]
        c.now=.2;p=assert(Presentation.sample(state,c));assert(math.abs(first-p.joints.RightShoulder[1])>.2)
        c.actorId='replacement';c.visualAction=attack('Throw');c.visualState=nil
        local row,reason=Presentation.sample(state,c);eq(row,nil);eq(reason,'StaleAttack')
        c.visualAction=nil;eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('folded windup and both fear frames carry immutable positive whole-body geometry profiles',function()
        local folded=context();folded.attack=attack('HeroBoot')
        local before=context();before.fearIntro={id='fear',actorId=before.actorId,counter=1,frameId=0x32}
        local after=context();after.fearIntro={id='fear',actorId=after.actorId,counter=0xE1,frameId=0x33}
        local first=assert(Presentation.sample(Presentation.new(),folded))
        local a=assert(Presentation.sample(Presentation.new(),before));local b=assert(Presentation.sample(Presentation.new(),after))
        for _,p in ipairs({first,a,b})do
            assert(p.geometry and table.isfrozen(p.geometry) and table.isfrozen(p.geometry.parts))
            eq(p.geometry.adaptation,'Authored3DSourceSilhouetteMapping')
            for _,scale in pairs(p.geometry.parts)do
                assert(table.isfrozen(scale));for _,v in ipairs(scale)do assert(v==v and v>0 and v<=3)end
            end
        end
        assert(first.geometry.parts.RightUpperLeg[2]<1 and first.geometry.parts.RightUpperLeg[1]>1)
        assert(a.geometry.parts.UpperTorso[1]<1 and b.geometry.parts.UpperTorso[1]<a.geometry.parts.UpperTorso[1])
        assert(b.geometry.parts.LeftLowerArm[2]>1 and b.geometry.parts.RightLowerLeg[2]>1)
        eq(a.geometry.parts.Head,nil);eq(b.geometry.parts.Head,nil)
    end)
    print(string.format('Canonical hero presentation: %d passed, %d failed',passed,failed))
    assert(failed==0,'Canonical hero presentation contracts failed')
end
