return function(Animation)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function eq(a,b,message) assert(a==b,(message or 'Unexpected value')..': '..tostring(a)..' vs '..tostring(b)) end
    test('catalog exposes69 finite source clips with frozen provenance and explicit bounds',function()
        eq(#Animation.ids(),69)
        eq(Animation.provenance.commit,'f1a43b69577246850d136473700a333b3cdfe93f')
        assert(table.isfrozen(Animation.provenance) and table.isfrozen(Animation.ids()))
        for _,id in ipairs(Animation.ids()) do
            local clip=assert(Animation.describe(id))
            assert(table.isfrozen(clip) and clip.animationId==id and clip.displayAdvances>=0)
            eq(Animation.sampleAdvance(id,clip.displayAdvances).ended,true)
        end
        local row,code=Animation.describe(3);eq(row,nil);eq(code,'UNKNOWN_ANIMATION')
    end)
    test('uppercut command arguments never become visual frames',function()
        local expected={}
        for i=0,8 do expected[i]=0x18 end
        expected[9]=0x1D;expected[10]=0x1D
        for i=11,26 do expected[i]=0x22 end
        expected[27]=0x1D;expected[28]=0x1D
        for advance=0,28 do eq(Animation.sampleAdvance(6,advance).frameId,expected[advance]) end
        local events=Animation.eventsBetween(6,-1,29)
        local hits={}
        for _,event in ipairs(events) do if event.kind=='HitOpportunity' then hits[#hits+1]=event end end
        eq(#hits,1);eq(hits[1].advance,12);eq(hits[1].params[1],2);eq(hits[1].params[2],0x23)
        eq(hits[1].appliesDamage,false)
    end)
    test('large fist and boot keep distinct source windup and recovery forms',function()
        eq(Animation.sampleAdvance(0x0E,2).frameId,0x1D)
        eq(Animation.sampleAdvance(0x0E,3).frameId,0x18)
        eq(Animation.sampleAdvance(0x0E,11).frameId,0x1C)
        eq(Animation.sampleAdvance(0x0E,32).frameId,0x1D)
        eq(Animation.sampleAdvance(0x14,11).frameId,0x1F)
        eq(Animation.sampleAdvance(0x14,12).frameId,0x1E)
        eq(Animation.sampleAdvance(0x14,37).ended,true)
    end)
    test('intentional label fallthrough is present rather than early truncation',function()
        local a,b=Animation.describe(0x26),Animation.describe(0x38)
        assert(a.fallsThroughDeclaredBlock and b.fallsThroughDeclaredBlock)
        eq(a.displayAdvances,22);eq(b.displayAdvances,22)
        eq(Animation.sampleAdvance(0x26,21).frameId,6)
    end)
    test('running strike keeps eleven opportunities while the query applies no damage',function()
        local events=Animation.eventsBetween(0x16,-1,18)
        local hits=0
        for _,event in ipairs(events) do if event.kind=='HitOpportunity' then
            hits+=1;eq(event.advance,hits);eq(event.appliesDamage,false)
        end end
        eq(hits,11)
        eq(#Animation.eventsBetween(0x16,18,100),0)
    end)
    test('Dash lowLife branch starts after the ordinary terminator and preserves its alternate tail',function()
        local branch={branch='DashLowLifeTail'}
        eq(Animation.describe(0x16).displayAdvances,18)
        eq(Animation.sampleAdvance(0x16,0,branch).frameId,0x31)
        eq(Animation.sampleAdvance(0x16,10,branch).frameId,0x31)
        eq(Animation.sampleAdvance(0x16,11,branch).frameId,0x23)
        eq(Animation.sampleAdvance(0x16,15,branch).ended,true)
        local sample=assert(Animation.sampleClock(0x16,{elapsedCalls=0,callerMask=1,firstFrameCounterPhase=0,branch='DashLowLifeTail'}))
        eq(sample.frameId,0x31);eq(sample.sourceByte,0x37)
        local invalid,code=Animation.sampleAdvance(2,0,branch);eq(invalid,nil);eq(code,'UNKNOWN_BRANCH')
    end)
    test('source clock phase is explicit and affects the first read rather than being silently guessed',function()
        local even=Animation.sampleClock(2,{elapsedCalls=0,callerMask=1,firstFrameCounterPhase=0})
        local odd=Animation.sampleClock(2,{elapsedCalls=0,callerMask=1,firstFrameCounterPhase=1})
        eq(even.frameId,0x19);eq(odd.frameId,0x19)
        eq(#even.events,3);eq(#odd.events,0)
        eq(even.events[3].kind,'HitOpportunity')
        eq(Animation.sampleClock(2,{elapsedCalls=1,callerMask=1,firstFrameCounterPhase=1}).events[3].kind,'HitOpportunity')
        local invalid,code=Animation.sampleClock(2,{elapsedCalls=1,callerMask=1})
        eq(invalid,nil);eq(code,'INVALID_CLOCK')
    end)
    test('clock reads all69 clips finitely for each supported source stride and phase',function()
        for _,id in ipairs(Animation.ids()) do for _,mask in ipairs({0,1,3}) do for phase=0,mask do
            local last=assert(Animation.sampleClock(id,{elapsedCalls=1024,callerMask=mask,firstFrameCounterPhase=phase,firstRead='Read'}))
            assert(last.ended,'A decoded finite clip must terminate: '..id..'/'..mask..'/'..phase)
        end end end
        local zero=Animation.sampleAdvance(0x5E,0)
        assert(zero.ended and zero.frameId==nil and #zero.events==2,'Command-only clips must not invent a body frame')
    end)
    test('caller family strides are source facts and missing families remain unknown',function()
        eq(Animation.callerMask('Hero'),1);eq(Animation.callerMask('Pig'),3)
        eq(Animation.callerMask('TallWalker'),0);eq(Animation.callerMask('Dragon'),3)
        local mask,code=Animation.callerMask('DarkQueen');eq(mask,nil);eq(code,'UNKNOWN_CALLER')
    end)
    test('hero gait tables retain source ordering and idle blinking',function()
        local walk={4,5,4,8,6,7,6,3};local run={5,5,8,8,7,7,3,3}
        for phase=0,15 do
            eq(Animation.heroFrame('Walk',{phase=phase}),walk[phase%8+1])
            eq(Animation.heroFrame('Run',{phase=phase}),run[phase%8+1])
        end
        eq(Animation.heroFrame('Idle'),1);eq(Animation.heroFrame('Idle',{blink=true}),2)
        eq(Animation.heroFrame('CarryWalk',{phase=3}),0x10)
        eq(Animation.heroFrame('DepthWalk',{phase=3}),0x0A)
        eq(Animation.heroFrame('CarryIdle'),0x11)
    end)
    test('jump frame selector uses the exact unsigned source speed condition and held override',function()
        for speed=-128,255 do
            local expected=(speed+2)%256<5 and 0x2D or 5
            eq(Animation.heroFrame('Air',{zSpeedRaw=speed}),expected)
            eq(Animation.heroFrame('Air',{zSpeedRaw=speed,holding=true}),0x2E)
        end
        local row,code=Animation.heroFrame('Air',{zSpeedRaw=.5});eq(row,nil);eq(code,'INVALID_STATE_INPUT')
    end)
    test('Dragon uses final caller frames instead of the shared intermediate bird table',function()
        local cycle={9,9,10,10}
        for phase=0,7 do eq(Animation.dragonFrame('Locomotion',{phase=phase}),cycle[phase%4+1]) end
        eq(Animation.dragonFrame('Locomotion',{phase=3,approaching=true,zSpeedRaw=1}),9)
        eq(Animation.dragonFrame('Locomotion',{phase=3,approaching=true,zSpeedRaw=0}),10)
        eq(Animation.dragonFrame('Disabled'),10)
        eq(Animation.dragonFrame('LightReaction',{timerRaw=0x26,phase=0}),12)
        eq(Animation.dragonFrame('LightReaction',{timerRaw=0x25,phase=3}),10)
        eq(Animation.dragonFrame('Attack'),11);eq(Animation.dragonFrame('Capture'),11)
    end)
    test('boss intro has the exact source counter boundaries and skips fear assignment on camera cut',function()
        eq(Animation.bossWalkerIntro(1).fearAnimation,0x2C)
        eq(Animation.bossWalkerIntro(0x2F).stomp,false)
        eq(Animation.bossWalkerIntro(0x30).stomp,true)
        eq(Animation.bossWalkerIntro(0x4F).footFrame,nil)
        eq(Animation.bossWalkerIntro(0x50).footFrame,0x12)
        eq(Animation.bossWalkerIntro(0x64).stomp,true)
        eq(Animation.bossWalkerIntro(0xDF).fearAnimation,0x2C)
        local cut=Animation.bossWalkerIntro(0xE0)
        eq(cut.cameraCut,true);eq(cut.fearAnimation,nil);eq(cut.footMotion,false)
        eq(cut.clearExistingFear,false)
        eq(Animation.bossWalkerIntro(0xE1).fearAnimation,0x2E)
        eq(Animation.bossWalkerIntro(0xFE).fearAnimation,0x2E)
        local last=Animation.bossWalkerIntro(0xFF)
        eq(last.ended,true);eq(last.footFrame,nil);eq(last.fearAnimation,nil)
    end)
    test('counter range events survive large visual steps without replaying old milestones',function()
        local events=Animation.bossWalkerEventsBetween(0,255)
        eq(#events,5)
        eq(events[1].counter,0x30);eq(events[2].counter,0x50);eq(events[3].counter,0x64)
        eq(events[4].kind,'ArenaCut');eq(events[5].kind,'IntroEnded')
        eq(#Animation.bossWalkerEventsBetween(0x64,0xDF),0)
        eq(#Animation.bossWalkerEventsBetween(255,255),0)
    end)
    test('unknown states and malformed clock inputs fail explicitly without guessing poses',function()
        for _,state in ipairs({'Surfing','Swimming','DarkQueenIntro'}) do
            local frame,code=Animation.heroFrame(state);eq(frame,nil);eq(code,'UNKNOWN_STATE')
        end
        for _,clock in ipairs({{elapsedCalls=-1,callerMask=1,firstFrameCounterPhase=0},
            {elapsedCalls=1.5,callerMask=1,firstFrameCounterPhase=0},
            {elapsedCalls=1,callerMask=2,firstFrameCounterPhase=0},
            {elapsedCalls=1,callerMask=3,firstFrameCounterPhase=4}}) do
            local row,code=Animation.sampleClock(2,clock);eq(row,nil);eq(code,'INVALID_CLOCK')
        end
        for _,counter in ipairs({0,-1,256,.5,math.huge}) do
            local row,code=Animation.bossWalkerIntro(counter);eq(row,nil);eq(code,'INVALID_COUNTER')
        end
    end)
    test('public metadata and event params cannot mutate later query results',function()
        local clip=Animation.describe(6)
        assert(not pcall(function() clip.displayAdvances=1 end))
        local events=Animation.eventsBetween(6,-1,29)
        assert(table.isfrozen(events) and table.isfrozen(events[2].params))
        assert(not pcall(function() events[2].params[1]=0xFF end))
        eq(Animation.eventsBetween(6,-1,29)[2].params[1],2)
    end)
    print(string.format('CanonicalAnimation: %d passed, %d failed',passed,failed))
    assert(failed==0,'CanonicalAnimation failures: '..failed)
end
