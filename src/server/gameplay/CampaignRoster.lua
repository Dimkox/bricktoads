-- Pinned source identity/loader profiles, separate from authored Roblox populations.
-- cfg byte 10 OR $0F is loaded by main.asm:28889-28895. Sentinel Life $FF
-- on an Invader is linked health-bar state, never 255 ordinary hit points.
local Roster={}
local prefix='build/canonical-source/'
local function profile(variants,file,lines,extra)
    local p=extra or {};p.lifeVariants=variants;p.source=prefix..file;p.lines=lines
    p.loader='main.asm:28889-28895';return p
end
Roster.profiles={
    Raven=profile({79},'levels_cfgs1.asm',{49,50},{lifeMode='ReactionDeath',handler='main.asm:4990-4998'}),
    LargeRaven=profile({79},'levels_cfgs1.asm',{59,60},{lifeMode='ClawOnReaction',handler='main.asm:4927-4984'}),
    SaturnToadtrap=profile({15,31,47,63},'levels_cfgs1.asm',{53,92,106,108}),
    RetroBlaster=profile({31,47,79},'levels_cfgs1.asm',{67,65,105}),
    Invader=profile({},'levels_cfgs1.asm',{126,127,128},{loaderLife=255,lifeMode='LinkedLife',runtimeLife=15,
        adaptation='Ordinary one-life body; linked raw-eight theft and recoverable token, not linear sentinel HP',handler='main.asm:5472-5723'}),
    RocketRat=profile({15},'levels_cfgs1.asm',{196,197},{handler='main.asm:10088-10124'}),
    Snowman=profile({15,31},'levels_cfgs1.asm',{263,271}),
    SentryDrone=profile({15},'levels_cfgs2.asm',{158}),
    Slug=profile({15},'levels_cfgs2.asm',{176}),
    GasTurret=profile({15},'levels_cfgs2.asm',{185}),
    Robot=profile({15},'levels_cfgs2.asm',{230}),
    Electrofish=profile({15},'levels_cfgs2.asm',{253}),
    Hammerfish=profile({15,31},'levels_cfgs2.asm',{257,282}),
    Shark=profile({15,47,63},'levels_cfgs2.asm',{263,283,275}),
    Duck=profile({15},'levels_cfgs2.asm',{278}),
    Hordhead=profile({47,63},'levels_cfgs1.asm',{336,361}),
    Swellcheeks=profile({47,79,111},'levels_cfgs1.asm',{365,374,380}),
    FlyingHead=profile({15},'levels_cfgs1.asm',{425}),
}
local function assign(e,counts)
    local p=Roster.profiles[e.kind];if not p then return end
    counts[e.kind]=(counts[e.kind] or 0)+1
    local n=e.sourceVariant or (counts[e.kind]-1)%math.max(1,#p.lifeVariants)+1
    e.rawLife=p.runtimeLife or assert(p.lifeVariants[n],'Invalid source Life variant')
    e.sourceVariant=n;e.sourceProfile=p
end
function Roster.apply(def,index)
    if def.rosterProfilesApplied then return def end
    local counts={}
    if index==2 then
        local zone=assert(def.zones[1]);local c=def.course;local hazards,emitters={},{}
        local function add(kind,p)
            local id=-1
            for _,e in ipairs(zone.enemies) do id=math.min(id,e.id-1) end
            zone.enemies[#zone.enemies+1]={id=id,kind=kind,x=p.x,y=p.y,z=p.z}
        end
        for _,h in ipairs(c.hazards) do
            if h.kind=='Raven' or h.kind=='Toadtrap' then add(h.kind=='Raven' and 'Raven' or 'SaturnToadtrap',h)
            else hazards[#hazards+1]=h end
        end
        for _,e in ipairs(c.emitters or {}) do
            if e.kind=='RetroBlaster' then add('RetroBlaster',e.position) else emitters[#emitters+1]=e end
        end
        -- Additional authored large species encounter; source count is not inferred.
        add('LargeRaven',{x=-10,y=128,z=0})
        c.hazards=hazards;c.emitters=emitters
    end
    if index==12 then
        -- Explicit Roblox placements exercise the distinct source capacities;
        -- these are not claims about natural NES object counts or coordinates.
        local zone=def.zones[1];local platforms=def.course.towerPlatforms
        for _,e in ipairs(zone.enemies) do
            if e.kind=='Hordhead' and platforms and platforms[4] then
                local p=platforms[4];e.x=math.cos(p.angle)*p.radius;e.y=p.y+3;e.z=math.sin(p.angle)*p.radius
            end
        end
        local function add(kind,variant,n)
            local p=assert(platforms[n]);local id=-1
            for _,e in ipairs(zone.enemies) do id=math.min(id,e.id-1) end
            zone.enemies[#zone.enemies+1]={id=id,kind=kind,sourceVariant=variant,
                x=math.cos(p.angle)*p.radius,y=p.y+(kind=='Hordhead' and 3 or 7),z=math.sin(p.angle)*p.radius,
                placement='AUTHORED_SOURCE_VARIANT'}
        end
        add('Hordhead',2,7);add('Swellcheeks',2,10);add('Swellcheeks',3,15)
    end
    for _,zone in ipairs(def.zones or {}) do for _,e in ipairs(zone.enemies) do assign(e,counts) end end
    for _,e in ipairs(def.course and def.course.encounters or {}) do assign(e,counts) end
    def.rosterProfilesApplied=true;return def
end
return Roster
