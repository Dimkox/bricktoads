return function(Variation,Base)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function copy(value)
        if type(value)~='table' then return value end
        local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
    end
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    local function freeze(value)
        if type(value)=='table' then for _,v in pairs(value) do freeze(v) end;table.freeze(value) end
        return value
    end
    local function near(a,b) assert(math.abs(a-b)<1e-7,string.format('Expected %.8f, got %.8f',b,a)) end
    local function left(p) return p.x-p.w/2 end
    local function right(p) return p.x+p.w/2 end
    local function top(p) return p.y+p.h/2 end
    local function supported(p,point,hx,hz)
        return point.x-hx>=left(p)-1e-7 and point.x+hx<=right(p)+1e-7
            and point.z-hz>=p.z-p.d/2-1e-7 and point.z+hz<=p.z+p.d/2+1e-7
    end
    local function floorIndex(zone,point)
        for i,p in ipairs(zone.platforms) do if supported(p,point,0,0) then return i end end
        error('Base point has no corresponding support')
    end
    local function geometry(route,relative)
        local out={}
        for _,z in ipairs(route.zones) do
            local origin=relative and left(z.platforms[1]) or 0
            for _,p in ipairs(z.platforms) do out[#out+1]=string.format('%g,%g,%g,%g,%g',p.x-origin,p.y,p.z,p.w,p.d) end
        end
        return table.concat(out,';')
    end
    local function eachPoint(route,fn)
        for zi,z in ipairs(route.zones) do
            for _,p in ipairs(z.enemies) do fn(p,zi,'enemy') end
            for _,p in ipairs(z.flies or {}) do fn(p,zi,'fly') end
        end
    end
    local function mappedPoints(route,key)
        for zi,oldZone in ipairs(Base.zones) do
            local zone=route.zones[zi]
            assert(#(oldZone[key] or {})==#(zone[key] or {}))
            for i,old in ipairs(oldZone[key] or {}) do
                local index=floorIndex(oldZone,old)
                local a,b=oldZone.platforms[index],zone.platforms[index]
                local p=zone[key][i]
                assert(p.id==old.id and p.kind==old.kind and p.rawLife==old.rawLife)
                near((p.x-left(b))/b.w,(old.x-left(a))/a.w)
                near((p.z-b.z)/b.d,(old.z-a.z)/a.d)
                near(p.y-top(b),old.y-top(a))
                assert(supported(b,p,key=='enemies' and 2.2 or .8,key=='enemies' and 1.2 or .8),'Remapped actor/item clips its own support')
            end
        end
    end
    local routes={}
    local function allRoutes()
        if #routes==0 then for seed=1,1000 do routes[seed]=Variation.build(Base,seed) end end
        return routes
    end

    test('run ID seeds are stable bounded integers and distinguish real run IDs',function()
        local a=Variation.seedFromId('run-1140dbeb-8b8b-4d28-ae9b-8a7f38021395')
        local b=Variation.seedFromId('run-9265bbec-d31a-417a-8c9a-2347d30f851a')
        assert(a==Variation.seedFromId('run-1140dbeb-8b8b-4d28-ae9b-8a7f38021395') and a~=b)
        assert(a>=1 and a<=2147483646 and a%1==0 and b>=1 and b<=2147483646)
    end)
    test('server-only builder rejects missing invalid or fractional seeds',function()
        for _,seed in ipairs({0,-1,1.5,math.huge,-math.huge,2147483647,'42',false}) do
            assert(not pcall(Variation.build,Base,seed),'Invalid seed must fail closed: '..tostring(seed))
        end
        assert(not pcall(Variation.build,Base,nil))
        assert(not pcall(Variation.seedFromId,'') and not pcall(Variation.seedFromId,23))
        assert(Variation.build(Base,2147483646).variation.seed==2147483646)
    end)
    test('same seed is independent of intervening builds and global random draws',function()
        local a=Variation.build(Base,84319)
        Variation.build(Base,983);for _=1,20 do math.random() end
        assert(equal(a,Variation.build(Base,84319)))
    end)
    test('frozen canonical template and arbitrary nested metadata remain unmodified',function()
        local canonical=copy(Base);canonical.resources={hearts=5,respawns=3,owners={{id=19}}}
        local before=copy(canonical);freeze(canonical)
        local a=Variation.build(canonical,53);local b=Variation.build(canonical,53)
        assert(equal(canonical,before) and equal(a.resources,canonical.resources))
        a.zones[1].platforms[1].w=2;a.zones[1].enemies[1].rawLife=0
        a.resources.owners[1].id=0;a.variation.sectionChoices[1]=99
        assert(equal(canonical,before) and equal(b,Variation.build(canonical,53)))
    end)
    test('six authored choices retain source level zone names objectives and families',function()
        local r=Variation.build(Base,41)
        assert(r~=Base and #r.zones==6 and r.id==Base.id and r.name==Base.name and r.source==Base.source)
        assert(r.variation.version==1 and r.variation.seed==41 and #r.variation.sectionChoices==6)
        for i,z in ipairs(r.zones) do
            assert(z.id==Base.zones[i].id and z.name==Base.zones[i].name and z.objective==Base.zones[i].objective)
            local choice=r.variation.sectionChoices[i];assert(choice>=1 and choice<=3 and choice%1==0)
        end
    end)
    test('1000 seeds vary real floor geometry with all three alternatives per zone',function()
        local seen,zoneSeen={},{}
        for _,r in ipairs(allRoutes()) do
            seen[geometry(r)]=true
            for zi,z in ipairs(r.zones) do
                zoneSeen[zi]=zoneSeen[zi] or {}
                zoneSeen[zi][geometry({zones={z}},true)]=true
            end
        end
        local count=0;for _ in pairs(seen) do count+=1 end;assert(count>=100,'A seed must change geometry, not just metadata or colour')
        for _,choices in pairs(zoneSeen) do local n=0;for _ in pairs(choices) do n+=1 end;assert(n==3) end
    end)
    test('all 1000 routes preserve 13 ordinary actors and six flies on their original floor correspondence',function()
        for _,r in ipairs(allRoutes()) do
            mappedPoints(r,'enemies');mappedPoints(r,'flies')
            local actors,flies,expected=0,0,-1
            eachPoint(r,function(p,_,kind)
                if kind=='enemy' then assert(p.id==expected);expected-=1;actors+=1 else flies+=1 end
            end)
            assert(actors==13 and flies==6)
        end
    end)
    test('1000 routes begin at -82 and safely support the unchanged first hero spawn',function()
        for _,r in ipairs(allRoutes()) do
            local p=r.zones[1].platforms[1]
            near(left(p),-82);near(top(p),0)
            assert(supported(p,{x=-65,z=0},2.2,1.2))
        end
    end)
    test('all floor links retain body clearance around z0 and bounded rises offsets and depth',function()
        for _,r in ipairs(allRoutes()) do
            local previous=nil
            for zi,z in ipairs(r.zones) do for _,p in ipairs(z.platforms) do
                assert(p.w>=24 and p.h==2 and p.d>=(zi==6 and 26 or 18))
                assert(math.abs(p.z)<=6 and p.d/2-math.abs(p.z)>=1.2)
                if previous then
                    assert(left(p)>=right(previous)-1e-7 and math.abs(top(p)-top(previous))<=2)
                end
                previous=p
            end end
            near(left(r.boss.platform),right(previous))
            assert(math.abs(top(r.boss.platform)-top(previous))<=2)
        end
    end)
    test('every mandatory gap in 1000 routes fits walk16 jump50 with unchanged takeoff and landing budget',function()
        for _,r in ipairs(allRoutes()) do
            local checked=0
            for _,z in ipairs(r.zones) do for i=1,#z.platforms-1 do
                local a,b=z.platforms[i],z.platforms[i+1]
                local gap=left(b)-right(a);local rise=top(b)-top(a)
                local discriminant=50^2-2*196.2*rise
                assert(discriminant>0 and gap>=4 and gap<=5)
                local available=16*(50+math.sqrt(discriminant))/196.2
                assert(available>=gap+2.5+.5,'Mandatory crossing requires running or a reduced takeoff margin')
                local g=z.gaps[i]
                near(g.minX,right(a));near(g.maxX,left(b))
                assert(type(g.minZ)=='number' and type(g.maxZ)=='number' and g.minZ<=-1.2 and g.maxZ>=1.2,
                    'Gap must describe the shared physical support corridor')
                checked+=1
            end end
            assert(checked==5)
        end
    end)
    test('zones meet without gaps and their exits remain reachable on the last support',function()
        for _,r in ipairs(allRoutes()) do
            for zi,z in ipairs(r.zones) do
                local last=z.platforms[#z.platforms];near(z.gateX,right(last))
                local root={x=(z.exit.minX+z.exit.maxX)/2,z=(z.exit.minZ+z.exit.maxZ)/2}
                assert(supported(last,root,2.2,1.2))
                near(z.exit.minY,top(last)+1);near(z.exit.maxY,top(last)+9)
                assert(top(last)+3>=z.exit.minY and top(last)+3<=z.exit.maxY)
                if zi<6 then near(left(r.zones[zi+1].platforms[1]),right(last)) end
            end
        end
    end)
    test('guardian position court gate exit pad and bounds translate together from the new route end',function()
        local oldEnd=right(Base.zones[6].platforms[2])
        for _,r in ipairs(allRoutes()) do
            local delta=right(r.zones[6].platforms[2])-oldEnd
            near(r.boss.position.x,Base.boss.position.x+delta)
            near(r.boss.platform.x,Base.boss.platform.x+delta)
            near(r.boss.gateX,Base.boss.gateX+delta)
            near(r.boss.exit.minX,Base.boss.exit.minX+delta);near(r.boss.exit.maxX,Base.boss.exit.maxX+delta)
            near(r.boss.pad.x,Base.boss.pad.x+delta);near(r.bounds.maxX,Base.bounds.maxX+delta)
            assert(r.boss.position.y==Base.boss.position.y and r.boss.platform.w==Base.boss.platform.w)
            assert(supported(r.boss.platform,r.boss.position,2.2,1.2))
            assert(supported(r.boss.platform,{x=r.boss.pad.x,z=r.boss.pad.z},r.boss.pad.w/2,r.boss.pad.d/2))
        end
    end)
    test('peripheral stone cover leaves the central corridor and all actors/items clear',function()
        local count=0
        for _,r in ipairs(allRoutes()) do for zi,z in ipairs(r.zones) do for _,o in ipairs(z.obstacles or {}) do
            assert(zi==1 or zi==3 or zi==5)
            assert(o.kind=='StoneCover' and o.w>0 and o.h>0 and o.d>0)
            assert(math.abs(o.z)-o.d/2>=12,'Cover intrudes into the central z corridor')
            local found=false
            for _,p in ipairs(z.platforms) do if supported(p,o,o.w/2+.5,o.d/2+.5) then
                near(o.y-o.h/2,top(p));found=true
            end end
            assert(found,'Cover must stand entirely on its own floor')
            for _,points in ipairs({z.enemies,z.flies or {}}) do for _,p in ipairs(points) do
                assert(math.abs(p.x-o.x)>o.w/2+2.2 or math.abs(p.z-o.z)>o.d/2+1.2,'Cover overlaps a spawn or fly')
            end end
            count+=1
        end end end
        assert(count>0,'Accepted variation includes actual collidable peripheral cover metadata')
    end)
    test('bounds contain every floor actor fly and cover in group-local coordinates',function()
        for _,r in ipairs(allRoutes()) do
            assert(r.bounds.minX==-90 and r.bounds.minZ==Base.bounds.minZ and r.bounds.maxZ==Base.bounds.maxZ)
            for _,z in ipairs(r.zones) do for _,p in ipairs(z.platforms) do
                assert(left(p)>=r.bounds.minX and right(p)<=r.bounds.maxX)
                assert(p.z-p.d/2>=r.bounds.minZ and p.z+p.d/2<=r.bounds.maxZ)
            end end
            eachPoint(r,function(p) assert(p.x>=r.bounds.minX and p.x<=r.bounds.maxX and p.z>=r.bounds.minZ and p.z<=r.bounds.maxZ) end)
            near(left(r.zones[1].platforms[1]),-82)
            assert(not r.groupOffset and not r.variation.groupOffset,'World alone owns group translation')
        end
    end)
    print(string.format('LevelVariation: %d passed, %d failed',passed,failed))
    assert(failed==0,'Level variation contracts failed')
    return passed
end
