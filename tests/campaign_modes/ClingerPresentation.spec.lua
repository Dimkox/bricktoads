-- A frozen pre-fix traversal method is the differential control. The actual
-- Session, Modes stepping, hazards, chase, damage and retry lifecycle run on both.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
-- Frozen from CampaignModes SHA8b7778a4, before the presentation-only correction.
local function baselineClinger(self,s,dt)
    local input=self:_input(s);local c=self.course;local segment=c.path[s.segment]
    if not segment then return end
    local correct=input.x*segment.direction.x+input.z*segment.direction.z>=.8
    local speed=correct and c.speed or 2
    local travel=speed*dt
    local left=segment.length-s.segmentProgress
    local used=math.min(left,travel);s.segmentProgress+=used;s.progress+=used
    s.position={x=segment.from.x+segment.direction.x*s.segmentProgress,y=segment.from.y,
        z=segment.from.z+segment.direction.z*s.segmentProgress}
    if s.segmentProgress>=segment.length-1e-7 then s.segment+=1;s.segmentProgress=0 end
    if not self.chaseFinished and math.abs(self.chaseProgress-s.progress)<=3 then self:_die(s,'CampaignChaseCaught')end
    self:_object('clinger-'..s.slot,'ClingerVehicle',{x=s.position.x,y=s.position.y-2.7,z=s.position.z},
        {w=4,h=.6,d=4},{collidable=false,role='Vehicle'})
end
local function serialize(v)
    if type(v)~='table'then return type(v)..':'..tostring(v)end
    local keys={};for key in pairs(v)do if key~='presentationHeading'then keys[#keys+1]=key end end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local out={};for _,key in ipairs(keys)do out[#out+1]=serialize(key)..'='..serialize(v[key])end
    return '{'..table.concat(out,'|')..'}'
end
local function fixture(Definition,Modes,seed,baseline)
    local d=Definition.build(11,seed);local w=FakeWorld.new();w.positions={};w.objects={};w.poseRows={};w.events={}
    local m
    function w:findSafe(id)return m and m:respawnPosition(id)or table.clone(d.spawn)end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held)local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p)end;return ok end
    function w:position(id)return self.positions[id]end
    function w:campaignPose(id,p,mode,velocity,heading)
        local previous=self.positions[id]
        self.positions[id]=table.clone(p)
        self.poseRows[#self.poseRows+1]={position=table.clone(p),mode=mode,
            velocity=table.clone(velocity),heading=heading and table.clone(heading),
            dx=previous and p.x-previous.x or 0,dz=previous and p.z-previous.z or 0}
    end
    function w:campaignObject(id,kind,p,size,metadata)
        self.objects[id]={kind=kind,position=table.clone(p),size=table.clone(size),metadata=table.clone(metadata)}
    end
    function w:campaignRemove(id)self.objects[id]=nil end
    function w:campaignRelease(id)self.released=id end
    local impulse=w.impulse
    function w:impulse(id,attacker,tuning,profile,direction)
        impulse(self,id,attacker,tuning,profile,direction)
        if m then m:impulse(id,{x=tuning.horizontal or 0,y=tuning.vertical or 0,z=0})end
    end
    local s=Session.new(Core,Combat,GameConfig(Base,d),{{userId=1,template='Mr. Green'}},'clinger-presentation-'..seed,w)
    assert(s:step(0)=='OK');m=Modes.new(s,w,d)
    if baseline then m._clinger=baselineClinger end
    local now=0
    local function step(x,z,dt,contact)
        m:move(1,x,z,false)
        now+=dt;assert(s:step(now)=='OK')
        if contact then s:_hit(-99,1,'Dash')end
        m:step(now,dt)
    end
    local function gameplay()
        local objects={}
        for id,row in pairs(w.objects)do
            local metadata=table.clone(row.metadata);metadata.yaw=nil
            objects[id]={kind=row.kind,position=row.position,size=row.size,metadata=metadata}
        end
        return serialize({state=s.state,combat=s.combat,positions=w.positions,objects=objects,
            actors=m.actors,elapsed=m.elapsed,rotation=m.rotation,discardedSeconds=m.discardedSeconds,
            complete=m.complete,chaseProgress=m.chaseProgress,chaseLife=m.chaseLife,
            chaseFinished=m.chaseFinished,chaseNeedsReset=m.chaseNeedsReset,
            spawns=w.spawns,kills=w.kills,impulses=w.impulses,relocations=w.relocations})
    end
    return d,s,w,m,step,gameplay
end
return function(Definition,Modes)
    local count=0;local directions={}
    local cases={{seed=1158731273,dt=1/60,kind='Correct',limit=5000},
        {seed=41,dt=.133,kind='Coarse',limit=1200},
        {seed=41,dt=.25,kind='Wrong',limit=1200},
        {seed=1158731273,dt=1/60,kind='Contact',limit=5000}}
    for _,case in ipairs(cases)do
        local d,s,_,baseline,stepBaseline,baselineGameplay=fixture(Definition,Modes,case.seed,true)
        local _,other,w,candidate,stepCandidate,candidateGameplay=fixture(Definition,Modes,case.seed,false)
        local ticks=0
        for tick=1,case.limit do
            local a=baseline.actors[1];local segment=d.course.path[a.segment]
            local x,z=segment and segment.direction.x or 0,segment and segment.direction.z or 0
            if case.kind=='Wrong'then x,z=-x,-z end
            local contact=case.kind=='Contact'and tick==240
            stepBaseline(x,z,case.dt,contact);stepCandidate(x,z,case.dt,contact);ticks=tick
            assert(baselineGameplay()==candidateGameplay(),case.kind..' changed earned gameplay at tick'..tick)
            if baseline.complete or s.state.status=='Lost'then break end
        end
        if case.kind=='Correct'then assert(baseline.complete and candidate.complete,'Positive full-path control did not complete')end
        if case.kind=='Wrong'then
            assert(not baseline.complete and not candidate.complete and s.state.heroes[1].attempt>1
                and s.state.heroes[1].respawns<3,'Wrong input must still fail the course and spend ordinary retries')
        end
        for _,pose in ipairs(w.poseRows)do if pose.heading then
            local h=pose.heading;directions[tostring(h.x)..':'..tostring(h.z)]=true
            assert(h.x*h.x+h.z*h.z==1,'Presentation heading is not one authored cardinal')
            local length=math.sqrt(pose.dx*pose.dx+pose.dz*pose.dz)
            if case.kind~='Contact'and length>1e-7 then
                assert((pose.dx*h.x+pose.dz*h.z)/length>1-1e-7,
                    'Heading advanced to the next corner before earning its movement')
            end
        end end
        local vehicle=w.objects['clinger-1']
        assert(vehicle and type(vehicle.metadata.yaw)=='number','Clinger vehicle never received heading metadata')
        local heading=candidate.actors[1].presentationHeading
        assert(heading and math.abs(math.cos(vehicle.metadata.yaw)-heading.x)<1e-6
            and math.abs(-math.sin(vehicle.metadata.yaw)-heading.z)<1e-6,'Vehicle yaw differs from last earned segment')
        count+=1;print('PASS Clinger presentation preserves complete gameplay trace '..case.kind..' ('..ticks..' ticks)')
    end
    for _,key in ipairs({'1:0','0:1','-1:0','0:-1'})do assert(directions[key],'Missing actual cardinal heading '..key)end
    print('PASS Clinger hero heading and vehicle yaw cover all four earned path directions')
    return count+1
end
