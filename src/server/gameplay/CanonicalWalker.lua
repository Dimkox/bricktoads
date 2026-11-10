-- Source-pixel presentation only: pinned Battletoads USA NES renderer.
-- Coordinates are relative to the prepared ground anchor, not world studs.
-- Actor identity, world motion, source clock, hit acceptance and physics belong to callers.
local Walker={}
local SHAFT_TILES=table.freeze({0xd0,0xd0,0xd1,0xd2,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4,0xd4})
local BODY={
    {tile=0xc9,x=-5,y=-32,attributes=2},
    {tile=0xca,x=-9,y=-24,attributes=2},
    {tile=0xcb,x=-4,y=-24,attributes=2},
    {tile=0xcc,x=-9,y=-16,attributes=2},
    {tile=0xcd,x=-5,y=-16,attributes=2},
    {tile=0xce,x=-7,y=-8,attributes=2},
    {tile=0xcf,x=-4,y=-8,attributes=2},
}
for _,part in ipairs(BODY)do table.freeze(part)end
table.freeze(BODY)
local function sourceValues(values)
    local set={};for _,value in ipairs(values)do set[value]=true end
    return table.freeze(set)
end
local ATTACK_VALUES=table.freeze({
    [0x3a]=sourceValues({8,9,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42}),
    [0x3c]=sourceValues({8,12,14,16,20,24,28,32,36,40}),
})
local function integer(value,minimum,maximum)
    return type(value)=='number'and value==value and value%1==0 and value>=minimum and value<=maximum
end

local function leg(delta,segments,startY)
    -- sub_6000_8A4B uses logical shifts plus sign restoration. Its accumulator
    -- is equivalent to this signed integer step and positive fractional byte.
    local step=math.floor(delta/segments)
    local fractionByte=(delta-step*segments)*256/segments
    local slope=math.abs(step)
    local tile=SHAFT_TILES[slope+1]
    if not tile then return nil,'UNKNOWN'end
    local attributes=step<0 and 2 or 0x42
    local sprites={}
    local x,fraction=125,0 -- source screen-safe X_shadow128 minus3.
    for index=1,segments do
        sprites[index]={tile=tile,x=x-128,y=startY+(index-1)*8,attributes=attributes}
        fraction+=fractionByte
        local carry=math.floor(fraction/256)
        fraction%=256
        x+=step+carry
        -- A source screen-edge return is not a complete model pose.
        if x<0 or x>255 then return nil,'UNKNOWN'end
    end
    sprites[segments].tile=0xd3
    return {delta=delta,segments=segments,integerStep=step,fractionByte=fractionByte,
        slopeIndex=slope,start={x=-3,y=startY},attributes=attributes,sprites=sprites}
end

function Walker.pose(objectType,firstDelta,secondDelta)
    if not integer(objectType,0,255)or not integer(firstDelta,-128,127)or not integer(secondDelta,-128,127)then
        return nil,'INVALID_INPUT'
    end
    if objectType~=0x11 and objectType~=0x12 then return nil,'UNKNOWN'end
    local segments=objectType==0x11 and 8 or 4
    local startY=-(segments-1)*8
    local first,reason=leg(firstDelta,segments,startY)
    if not first then return nil,reason end
    local second;second,reason=leg(secondDelta,segments,startY-2)
    if not second then return nil,reason end
    -- tall_walker_sprites restores the body after drawing both shafts. The
    -- source SBC borrow makes slopes0 and1 share the same normalized height.
    local head={x=0,y=startY-1+math.max(0,second.slopeIndex-1)}
    local sprites,bodySprites={},{}
    for _,shaft in ipairs({first,second})do
        for _,part in ipairs(shaft.sprites)do sprites[#sprites+1]=part end
    end
    for _,source in ipairs(BODY)do
        local part={tile=source.tile,x=source.x,y=source.y+head.y,attributes=source.attributes}
        bodySprites[#bodySprites+1]=part;sprites[#sprites+1]=part
    end
    return {objectType=objectType,units='sourcePixels',bodyGraphicsFrame=0x19,headAnchor=head,
        legStarts={{x=-3,y=startY},{x=-3,y=startY-2}},legs={first,second},
        bodySprites=bodySprites,sprites=sprites}
end

function Walker.attackOffsets(animationId,streamValue,facingLeft)
    if not integer(animationId,0,255)or not integer(streamValue,0,255)or type(facingLeft)~='boolean'then
        return nil,'INVALID_INPUT'
    end
    local values=ATTACK_VALUES[animationId]
    if not values or not values[streamValue]then return nil,'UNKNOWN'end
    -- sub_0_95BA reflects the source stream delta by direction. The following
    -- branch holds the other light leg at bodyX, or arithmetic-shifts -delta
    -- by one for the heavy leg. These values are endpoints, not gfx frames.
    local delta=streamValue-0x18
    if facingLeft then delta=-delta end
    return {firstDelta=delta,secondDelta=animationId==0x3a and math.floor(-delta/2)or 0}
end

return table.freeze(Walker)
