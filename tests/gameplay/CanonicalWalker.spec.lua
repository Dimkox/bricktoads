return function(Walker,golden)
    local passed=0
    local function test(name,run)run();passed+=1;print('PASS '..name)end
    local function same(actual,expected,path)
        path=path or 'value'
        assert(type(actual)==type(expected),path..' type differs')
        if type(expected)~='table'then assert(actual==expected,path..' expected '..tostring(expected)..', got '..tostring(actual));return end
        for k,v in pairs(expected)do same(actual[k],v,path..'.'..tostring(k))end
        for k in pairs(actual)do assert(expected[k]~=nil,path..' unexpected key '..tostring(k))end
    end
    local function rejected(call,expected)
        local value,reason=call()
        assert(value==nil and reason==expected,'Expected bounded refusal '..expected..', got '..tostring(reason))
    end

    test('all35 prepared poses match sprites and body anchors emitted by literal source ASM',function()
        assert(#golden.poses==35 and golden.sourceSha256=='71042cf2a4a8fad952e9eb3bcb591cece666c5a790d7ea177b1908d052fca074')
        for _,row in ipairs(golden.poses)do
            local pose,reason=Walker.pose(row.objectType,row.firstDelta,row.secondDelta)
            assert(pose,reason);assert(pose.units=='sourcePixels'and pose.bodyGraphicsFrame==0x19)
            same(pose.headAnchor,row.headAnchor,'pose'..row.poseId..'.head')
            local flattened={}
            for index,leg in ipairs(pose.legs)do
                local expected=row.legs[index]
                assert(leg.segments==expected.segments and leg.integerStep==expected.integerStep
                    and leg.fractionByte==expected.fractionByte and leg.slopeIndex==expected.slopeIndex)
                same(leg.start,expected.start,'leg start')
                for _,part in ipairs(leg.sprites)do flattened[#flattened+1]=part end
            end
            same(flattened,row.legSprites,'pose'..row.poseId..'.legSprites')
        end
    end)

    test('source body tiles follow the verified body anchor rather than a humanoid hip',function()
        for _,row in ipairs(golden.poses)do
            local pose=assert(Walker.pose(row.objectType,row.firstDelta,row.secondDelta))
            assert(#pose.bodySprites==#golden.bodyParts)
            for i,part in ipairs(pose.bodySprites)do
                local src=golden.bodyParts[i]
                same(part,{tile=src.tile,attributes=src.attributes,x=src.x,y=src.y+row.headAnchor.y},'body sprite')
            end
            assert(#pose.sprites==#row.legSprites+#golden.bodyParts)
        end
    end)

    test('58 attack endpoint mappings match independent source instructions in both directions',function()
        assert(#golden.attackOffsets==58)
        for _,row in ipairs(golden.attackOffsets)do
            local offsets,reason=Walker.attackOffsets(row.animationId,row.streamValue,row.facingLeft)
            assert(offsets,reason)
            same(offsets,{firstDelta=row.firstDelta,secondDelta=row.secondDelta},'attack offsets')
        end
    end)

    test('unknown source families slopes animations and stream values remain UNKNOWN',function()
        rejected(function()return Walker.pose(0x13,0,0)end,'UNKNOWN')
        rejected(function()return Walker.pose(0x11,127,0)end,'UNKNOWN')
        rejected(function()return Walker.pose(0x12,80,0)end,'UNKNOWN')
        rejected(function()return Walker.attackOffsets(0x28,24,false)end,'UNKNOWN')
        rejected(function()return Walker.attackOffsets(0x3a,11,false)end,'UNKNOWN')
        rejected(function()return Walker.attackOffsets(0x3c,42,false)end,'UNKNOWN')
    end)

    test('malformed deltas and flags cannot enter byte arithmetic',function()
        for _,bad in ipairs({false,'0',.5,math.huge,-math.huge,0/0,-129,128})do
            rejected(function()return Walker.pose(0x11,bad,0)end,'INVALID_INPUT')
            rejected(function()return Walker.pose(0x11,0,bad)end,'INVALID_INPUT')
        end
        rejected(function()return Walker.pose(nil,0,0)end,'INVALID_INPUT')
        rejected(function()return Walker.attackOffsets(0x3a,24,'left')end,'INVALID_INPUT')
        rejected(function()return Walker.attackOffsets(0x3a,24.5,false)end,'INVALID_INPUT')
        rejected(function()return Walker.attackOffsets(0x3a,256,false)end,'INVALID_INPUT')
    end)

    test('caller mutations cannot poison another actor or the private source data',function()
        local row=golden.poses[2]
        local one=assert(Walker.pose(row.objectType,row.firstDelta,row.secondDelta))
        one.legs[1].sprites[1].tile=0;one.legs[1].start.x=999;one.headAnchor.y=0;one.bodySprites[1].tile=0
        local two=assert(Walker.pose(row.objectType,row.firstDelta,row.secondDelta))
        same(two.legs[1].sprites[1],row.legSprites[1]);same(two.headAnchor,row.headAnchor)
        assert(two.bodySprites[1].tile==golden.bodyParts[1].tile)
        local offsets=assert(Walker.attackOffsets(0x3a,24,false));offsets.firstDelta=999
        assert(Walker.attackOffsets(0x3a,24,false).firstDelta==0)
    end)
    print('CanonicalWalker: '..passed..' passed')
end
