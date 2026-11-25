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

-- Three-dimensional field Walker. Coordinates are in the actor's facing frame (-Z forward).
local UPPER, LOWER = 3.55, 3.7
function Walker.legAngles(drop, forward)
    local reach=math.clamp(math.sqrt(drop*drop+forward*forward),math.abs(UPPER-LOWER)+.001,UPPER+LOWER-.001)
    local hip=math.atan2(forward,drop)-math.acos(math.clamp((UPPER^2+reach^2-LOWER^2)/(2*UPPER*reach),-1,1))
    local hock=math.pi-math.acos(math.clamp((UPPER^2+LOWER^2-reach^2)/(2*UPPER*LOWER),-1,1))
    return hip,hock,-hip-hock
end

function Walker.buildRig(root)
    local model=Instance.new("Model")
    model.Name="WalkerAppearance"
    local gold=Color3.fromRGB(215,157,46)
    local iron=Color3.fromRGB(60,67,66)
    local ivory=Color3.fromRGB(228,218,158)
    local brass=Color3.fromRGB(154,111,43)
    local V,at=Vector3.new,CFrame.new
    local function segment(name,size,tint,shape,parent,base,pivot,moving)
        local part=Instance.new("Part")
        part.Name=name
        part.Size=size
        if shape==Enum.PartType.Ball then
            -- A sphere mesh follows all three parent dimensions, including long tapered struts.
            local mesh=Instance.new("SpecialMesh")
            mesh.MeshType=Enum.MeshType.Sphere
            mesh.Parent=part
        else
            part.Shape=shape
        end
        part.Material=Enum.Material.Metal
        part.Color=tint
        part.Massless=true
        part.CanCollide=false
        part.CanQuery=false
        part.CanTouch=false
        part.CFrame=parent.CFrame*base*pivot:Inverse()
        part.Parent=model
        local joint=Instance.new(moving and "Motor6D" or "Weld")
        joint.Name=name.."Joint"
        joint.Part0=parent
        joint.Part1=part
        joint.C0=base
        joint.C1=pivot
        joint.Parent=part
        return part,joint
    end
    local ball,box,cylinder=Enum.PartType.Ball,Enum.PartType.Block,Enum.PartType.Cylinder
    local origin=at()
    local hipHeight=4.25
    local hull,hullJoint=segment("Carapace",V(3.45,3.15,4.4),gold,ball,root,at(0,hipHeight+1,0),origin,true)
    local function detail(name,size,tint,shape,parent,offset)
        return segment(name,size,tint,shape,parent,offset,origin,false)
    end
    detail("RearCounterweight",V(2.7,2.15,2.9),iron,ball,hull,at(0,-.25,1.32))
    detail("Brow",V(2.9,1.65,2.15),ivory,ball,hull,at(0,.26,-1.16))
    local legs={}
    for i,side in ipairs({-1,1}) do
        local prefix=i==1 and "Left" or "Right"
        detail(prefix.."EyeSocket",V(.65,1.1,1.3),iron,ball,hull,at(side*1.22,.25,-1.3))
        local eye=detail(prefix.."Optic",V(.42,.60,.74),Color3.fromRGB(255,131,44),ball,hull,at(side*1.50,.3,-1.52))
        eye.Material=Enum.Material.Neon
        local hip=at(side*1.16,-1,side*.18)
        detail(prefix.."HipBearing",V(1.05,1.35,1.35),brass,cylinder,hull,hip)
        local thigh,thighJoint=segment(prefix.."Thigh",V(.8,UPPER,.99),gold,ball,hull,hip,at(0,UPPER/2,0),true)
        local ankle=at(0,-UPPER/2,0)
        detail(prefix.."HockPin",V(1.1,1,1),ivory,cylinder,thigh,ankle)
        local shin,shinJoint=segment(prefix.."Shin",V(.52,LOWER,.66),iron,box,thigh,ankle,at(0,LOWER/2,0),true)
        detail(prefix.."Piston",V(.30,LOWER*.74,.30),ivory,box,shin,at(side*.28,.1,0))
        local footBase=at(0,-LOWER/2,0)
        local foot,footJoint=segment(prefix.."Foot",V(.95,.68,1.85),brass,ball,shin,footBase,at(0,.05,.34),true)
        for toe=-1,1,2 do
            detail(prefix.."Toe"..toe,V(.31,.3,1.65),ivory,ball,foot,at(toe*.29,-.17,-.92)*CFrame.Angles(0,-toe*.19,0))
        end
        legs[i]={hip=thighJoint,hock=shinJoint,foot=footJoint,hipBase=hip,hockBase=ankle,footBase=footBase}
    end
    return {model=model,hull=hullJoint,height=hipHeight,legs=legs}
end

function Walker.animateRig(rig,pose,context)
    local reaction=pose and pose.state=="Reaction"
    local progress=math.clamp(context and context.reactionProgress or 0,0,1)
    local bend=0
    if reaction then
        -- Compress promptly, hold the load briefly, then extend before recovery.
        bend=math.min(1,.55+progress*4)*math.clamp((1-progress)/.48,0,1)
        bend*=context.reactionHeavy and 2.5 or 1.85
    end
    local height=rig.height-bend
    rig.hull.C0=CFrame.new(0,height+1,bend*.18)
    for i,leg in ipairs(rig.legs) do
        local source=pose and pose.components and pose.components.legs[i]
        local stride=source and math.clamp(source.delta*.09,-2.3,2.3) or 0
        local lift=math.max(0,stride)*.29
        local a,b,c=Walker.legAngles(height+2.59-lift,stride+bend*.18)
        leg.hip.C0=leg.hipBase*CFrame.Angles(a,0,0)
        leg.hock.C0=leg.hockBase*CFrame.Angles(b,0,0)
        leg.foot.C0=leg.footBase*CFrame.Angles(c,0,0)
    end
end

return table.freeze(Walker)
