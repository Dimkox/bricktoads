return function(Definition)
    local passed=0
    local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS '..name) end
    local function fingerprint(v)
        if type(v)~='table' then return tostring(v) end
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..fingerprint(v[k]) end
        return '{'..table.concat(out,',')..'}'
    end
    test('all thirteen ordered modes produce independent deterministic playable layouts',function()
        local expected={'Causeway','Rope','Speeder','Ice','Surf','Serpents','Jet','Ascent','Tubes','Race','Clinger','Tower','Finale'}
        assert(Definition.count==13)
        for i,mode in ipairs(expected) do
            local a,b=Definition.build(i,8125),Definition.build(i,8125)
            assert(a.mode==mode and a.campaignIndex==i and #a.zones>0)
            assert(fingerprint(a)==fingerprint(b),'same seed must preserve the same map on retry')
            assert(a.spawn and a.bounds and a.boss.platform and a.zones[1].platforms)
            a.spawn.x=9999;assert(b.spawn.x~=9999)
        end
    end)
    test('new run seeds alter real course geometry while keeping every section authored',function()
        for level=2,12 do
            local seen={}
            for seed=1,25 do
                local d=Definition.build(level,seed);seen[fingerprint({d.zones,d.course.hazards,d.course.path,d.course.platforms})]=true
                assert(d.variation.seed==seed and #d.variation.sectionChoices>0)
                for _,choice in ipairs(d.variation.sectionChoices) do assert(choice>=1 and choice<=3) end
            end
            local n=0;for _ in pairs(seen) do n+=1 end
            assert(n>=2,'new runs must change actual geography for level '..level)
        end
    end)
    test('boss arenas belong only to the six real encounters and serpent course has four rooms',function()
        local bosses={[1]='CausewayGuardian',[5]='BigBlag',[8]='RoboManus',[10]='GeneralSlaughter',[11]='Buzzball',[13]='DarkQueen'}
        for i=1,13 do assert(Definition.build(i,41).boss.kind==bosses[i]) end
        local serpent=Definition.build(6,41)
        assert(#serpent.course.rooms==4 and #serpent.course.supports==4)
        for _,support in ipairs(serpent.course.supports) do assert(#support.path>=3 and support.speed>0) end
        assert(Definition.build(9,41).course.media[1].kind=='Water')
    end)
    test('invalid campaign index and seed cannot silently build another run',function()
        for _,i in ipairs({0,14,2.5,'2'}) do assert(not pcall(Definition.build,i,1)) end
        for _,s in ipairs({0,-1,1.5,math.huge,'1'}) do assert(not pcall(Definition.build,2,s)) end
    end)
    test('authored vehicle sections preserve warning and steering distance for every seed',function()
        for _,level in ipairs({3,5,7}) do for seed=1,250 do
            local d=Definition.build(level,seed);local previous=d.course.mount.x
            for _,h in ipairs(d.course.hazards) do assert(h.x-previous>=25,'obstacles must retain reaction space');previous=h.x end
            assert(previous<d.course.finishPoint.x-18)
        end end
    end)
    test('finale arrival and arena entry retain one continuous supported walking corridor',function()
        for seed=1,100 do
            local d=Definition.build(13,seed);local court=d.zones[1].platforms[1];local arena=d.boss.platform
            assert(court.x-court.w/2<=d.spawn.x and court.x+court.w/2>=d.course.finish.minX)
            assert(court.x+court.w/2>=arena.x-arena.w/2,'ordinary walking cannot cross an arena gap')
            assert(court.y+court.h/2==0 and arena.y+arena.h/2==0)
            assert(court.d>=24 and arena.d>=24)
        end
    end)
    test('new courses retain physical obstacle families and only the entry patrol gates boarding',function()
        for seed=1,100 do
            for index=2,13 do assert(Definition.build(index,seed).requiresClearAtExit==false) end
            local ice=Definition.build(4,seed).course
            assert(#ice.walls>=2 and ice.walls[1].motion and ice.supports[1].kind=='MovingIcePlatform')
            local spikes=0;for _,h in ipairs(ice.hazards) do if h.kind=='Spike' then spikes+=1 end end;assert(spikes>=2)
            local electric,mechanical=false,false
            for _,h in ipairs(Definition.build(8,seed).course.hazards) do
                electric=electric or h.kind=='ElectricTrap';mechanical=mechanical or h.kind=='MechanicalCrusher'
            end
            assert(electric and mechanical)
            local speeder=Definition.build(3,seed)
            for _,e in ipairs(speeder.zones[1].enemies) do assert(e.kind~='RocketRat') end
            local rat=speeder.course.encounters[1]
            assert(rat.kind=='RocketRat' and rat.rawLife==15 and rat.trajectory.duration>0 and rat.allowedDrop)
        end
    end)
    test('speeder has native flat support across the full riding distance and both steering edges',function()
        local function covered(d)
            local c=d.course
            for z=-c.laneLimit,c.laneLimit,3 do
                local spans={}
                for _,p in ipairs(c.platforms) do
                    if math.abs(p.y+p.h/2)<.001 and p.z-p.d/2<=z-1.2 and p.z+p.d/2>=z+1.2 then
                        spans[#spans+1]={left=p.x-p.w/2+1.6,right=p.x+p.w/2-1.6}
                    end
                end
                table.sort(spans,function(a,b) return a.left<b.left end)
                local edge=c.mount.x
                for _,span in ipairs(spans) do
                    if span.left<=edge then edge=math.max(edge,span.right) end
                end
                if edge<c.finishPoint.x then return false,z,edge end
            end
            return true
        end
        for _,seed in ipairs({1,2,7,41,8125}) do
            local d=Definition.build(3,seed);local ok,z,edge=covered(d)
            assert(ok,'logical grounded ride needs physical road: seed='..seed..', lane='..tostring(z)..', support ends='..tostring(edge))
            assert(d.course.mount and #d.course.hazards==12 and d.requiresClearAtExit==false)
            assert(d.course.platforms[1].x+d.course.platforms[1].w/2>d.course.mount.x)
            assert(d.course.finish.minX<d.course.finishPoint.x and d.course.finish.maxX>d.course.finishPoint.x)
            for _,index in ipairs({5,7}) do assert(not covered(Definition.build(index,seed)),'surf/jet must retain their distinct course support') end
        end
        local a,b=Definition.build(3,1),Definition.build(3,41)
        assert(fingerprint(a.course.hazards)~=fingerprint(b.course.hazards),'physical road must retain seed-varied obstacles')
    end)
    print('CampaignDefinition: '..passed..' passed')
end
