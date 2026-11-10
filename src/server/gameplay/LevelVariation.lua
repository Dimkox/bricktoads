-- Original authored sections, not copied NES layouts or player navigation assistance.
local Variation={}
local MODULUS=2147483647

local function floor(width,depth,z,top)
    return {w=width,d=depth,z=z or 0,top=top or 0}
end

-- Studs and heights are authored Roblox calibration. Every required crossing
-- keeps the walk16/Jump50 budget: 2.5 takeoff lead plus .5 landing inset.
local SECTIONS={
    {
        {platforms={floor(86,52)}},
        {platforms={floor(94,48,-4)}},
        {platforms={floor(80,56,4)}},
    },
    {
        {platforms={floor(44,38),floor(71,38)},gaps={5}},
        {platforms={floor(50,40,-3),floor(69,36,3)},gaps={5}},
        {platforms={floor(42,36,4),floor(76,42,-4,2)},gaps={4}},
    },
    {
        {platforms={floor(112,56)}},
        {platforms={floor(100,52,-4)}},
        {platforms={floor(124,60,4)}},
    },
    {
        {platforms={floor(34,18),floor(27,18,6,2),floor(27,18,0,4),floor(24,22,-6,2)},gaps={4,4,4}},
        {platforms={floor(40,22,-4),floor(30,20,3,2),floor(28,22,-3,2),floor(30,24,4)},gaps={4,4,4}},
        {platforms={floor(32,20,4),floor(32,22,-4),floor(36,20,4,2),floor(28,22,-4)},gaps={5,4,5}},
    },
    {
        {platforms={floor(126,52)}},
        {platforms={floor(114,48,-4)}},
        {platforms={floor(134,56,4)}},
    },
    {
        {platforms={floor(44,26),floor(55,26)},gaps={5}},
        {platforms={floor(48,30,-2),floor(58,30,2)},gaps={4}},
        {platforms={floor(40,28,3),floor(64,28,-3)},gaps={5}},
    },
}

local function left(p) return p.x-p.w/2 end
local function right(p) return p.x+p.w/2 end
local function top(p) return p.y+p.h/2 end

local function copy(value,seen)
    if type(value)~='table' then return value end
    seen=seen or {}
    if seen[value] then return seen[value] end
    local result={};seen[value]=result
    for k,v in pairs(value) do result[copy(k,seen)]=copy(v,seen) end
    return result
end

function Variation.seedFromId(runId)
    assert(type(runId)=='string' and #runId>0,'A nonempty server run ID is required')
    local hash=17
    for i=1,#runId do hash=(hash*131+string.byte(runId,i))%MODULUS end
    return hash%(MODULUS-1)+1
end

local function mappedPoint(point,oldPlatforms,newPlatforms)
    for i,old in ipairs(oldPlatforms) do
        if point.x>=left(old) and point.x<=right(old)
            and point.z>=old.z-old.d/2 and point.z<=old.z+old.d/2 then
            local new=newPlatforms[i]
            point.x=left(new)+(point.x-left(old))/old.w*new.w
            point.z=new.z+(point.z-old.z)/old.d*new.d
            point.y=top(new)+point.y-top(old)
            return
        end
    end
    error('Canonical actor/item has no corresponding floor: '..tostring(point.id))
end

local function addCover(zone,choice)
    zone.obstacles={}
    if choice==1 then return end
    local p=zone.platforms[1]
    local width,depth,height=6+choice,4,3
    local side=choice==2 and -1 or 1
    for _,direction in ipairs({side,-side}) do for _,fraction in ipairs({.25,.5,.75}) do
        local x=left(p)+p.w*fraction
        local z=p.z+direction*(p.d/2-depth/2-1)
        local clear=math.abs(z)-depth/2>=12
        for _,points in ipairs({zone.enemies,zone.flies or {}}) do for _,point in ipairs(points) do
            if math.abs(point.x-x)<=width/2+2.2 and math.abs(point.z-z)<=depth/2+1.2 then clear=false end
        end end
        if clear then
            zone.obstacles[1]={kind='StoneCover',x=x,y=top(p)+height/2,z=z,w=width,h=height,d=depth}
            return
        end
    end end
end

function Variation.build(baseLevel,seed)
    assert(type(seed)=='number' and seed==seed and seed%1==0 and seed>=1 and seed<MODULUS,'Seed must be an integer in1..2147483646')
    assert(type(baseLevel)=='table' and type(baseLevel.zones)=='table' and #baseLevel.zones==6,'The six-zone canonical route is required')
    local route=copy(baseLevel)
    local choices={}
    local state,cursor=seed,-82
    for zi,zone in ipairs(route.zones) do
        -- Products stay below 2^53, so this integer RNG is stable in Luau's doubles.
        state=(state*48271)%MODULUS
        local choice=state%3+1
        choices[zi]=choice
        local section=SECTIONS[zi][choice]
        local old=baseLevel.zones[zi]
        assert(#old.platforms==#section.platforms,'Canonical floor correspondence changed')
        local platforms,gaps={},{}
        for i,data in ipairs(section.platforms) do
            if i>1 then
                local previous=platforms[i-1]
                local from=cursor
                cursor+=section.gaps[i-1]
                gaps[#gaps+1]={minX=from,maxX=cursor,
                    minZ=math.max(previous.z-previous.d/2,data.z-data.d/2),
                    maxZ=math.min(previous.z+previous.d/2,data.z+data.d/2)}
            end
            local p=copy(old.platforms[i])
            p.x=cursor+data.w/2;p.y=data.top-p.h/2;p.z=data.z;p.w=data.w;p.d=data.d
            platforms[i]=p;cursor+=p.w
        end
        zone.platforms=platforms;zone.gaps=gaps;zone.gateX=cursor
        for _,point in ipairs(zone.enemies) do mappedPoint(point,old.platforms,platforms) end
        for _,point in ipairs(zone.flies or {}) do mappedPoint(point,old.platforms,platforms) end
        local oldLast,newLast=old.platforms[#old.platforms],platforms[#platforms]
        local dx,dz,dy=cursor-right(oldLast),newLast.z-oldLast.z,top(newLast)-top(oldLast)
        zone.exit.minX+=dx;zone.exit.maxX+=dx
        zone.exit.minZ+=dz;zone.exit.maxZ+=dz
        zone.exit.minY+=dy;zone.exit.maxY+=dy
        if zi==1 or zi==3 or zi==5 then addCover(zone,choice) end
    end
    local last=baseLevel.zones[6].platforms
    local delta=cursor-right(last[#last])
    route.boss.position.x+=delta;route.boss.platform.x+=delta;route.boss.gateX+=delta
    route.boss.exit.minX+=delta;route.boss.exit.maxX+=delta;route.boss.pad.x+=delta
    route.bounds.maxX+=delta
    route.variation={version=1,seed=seed,sectionChoices=choices}
    return route
end

return Variation
