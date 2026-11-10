-- A physical course rival, not an ordinary three-heart enemy. Source evidence:
-- research/2026-11-09-campaign-race.md. All spatial/timing budgets are authored.
-- Session alone commits hero deaths and later paid respawns.
local Race={};Race.__index=Race
local FIXED=1/60
local HEIGHT=3
-- The rat's authored body is four studs tall: three below its root and one
-- above, so the six-stud stair spacing leaves actual head clearance.
local TOP=1
local INPUT_TIMEOUT=.35
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function point(x,y,z) return {x=x,y=y,z=z or 0} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function clamp(n,a,b) return math.max(a,math.min(b,n)) end
local function normalized(x,z)
    local n=math.sqrt(x*x+z*z);if n>1 then return x/n,z/n end;return x,z
end
local function direction(x,z)
    local n=math.sqrt(x*x+z*z);if n<.001 then return 0,0 end;return x/n,z/n
end
local function sweptContact(a,b,p,radius)
    -- The bomb uses a finite body volume, not a distance-to-route percentage.
    local enter,leave=0,1
    for _,axis in ipairs({'x','y','z'}) do
        local extent=axis=='y' and 2.6 or radius
        local first=a[axis]-p[axis];local delta=b[axis]-a[axis]
        if math.abs(delta)<1e-8 then if math.abs(first)>extent then return false end
        else
            local lo,hi=(-extent-first)/delta,(extent-first)/delta
            if lo>hi then lo,hi=hi,lo end
            enter=math.max(enter,lo);leave=math.min(leave,hi);if enter>leave then return false end
        end
    end
    return leave>=0 and enter<=1
end

function Race.new(session,world,definition)
    assert(session and world and definition and definition.mode=='Race' and definition.course,'A race course is required')
    assert(type(world.spawnEnemy)=='function','The race rival requires a real enemy body')
    assert(definition.course.bombs and #definition.course.bombs>0,'The race requires authored bombs')
    local epoch=session.state.levelEpoch
    local actorId=session.state.runId..':course-rival:'..epoch..':rat'
    local self=setmetatable({session=session,world=world,definition=definition,course=definition.course,enemyId=-98,
        levelEpoch=epoch,runId=session.state.runId,now=session.now or 0,elapsed=0,simulationTime=0,bombIndex=1,
        failed=false,completeBombs=false,closed=false,discardedSeconds=0,radius=definition.course.ratRadius or 1.3,
        velocity=point(0,0,0),input={x=0,z=0,at=-math.huge},grounded=false,
        enemy={actorId=actorId,kind='RacingRat',courseRival=true,connected=true,connectionEpoch=1,lastSeq=0,
            engaged=false,dead=false,reactionEpoch=0}},Race)
    self.position=copy(self.course.bombs[1].ratStart)
    assert(world:spawnEnemy(self.enemyId,'RacingRat',self.position),'Race rival spawn failed')
    if world.enemyIdentity then world:enemyIdentity(self.enemyId,actorId) end
    if world.courseRival then world:courseRival(self.enemyId,'RACING RAT') end
    self:_beginRound('Initial')
    return self
end
function Race:_log(kind,slot,data)
    if self.session._record then self.session:_record(kind,slot,data,self.now) end
end
function Race:_validContext()
    return self.session.state.runId==self.runId and self.session.state.levelEpoch==self.levelEpoch
end
function Race:_living(slot)
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    return h and h.status=='Alive' and c and not c.deathAt and self.world:position(slot)~=nil
end
function Race:_controlledHero(slot)
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    return self:_living(slot) and h.connected~=false and not c.reactionEnd
        and not (h.shield and h.shield.kind=='Emergency' and self.now<h.shield.deadline)
end
function Race:_pose()
    if self.world.campaignPose then self.world:campaignPose(self.enemyId,self.position,'RaceRival',self.velocity)
    else self.world:placeActor(self.enemyId,self.position) end
end
function Race:_ground(previous)
    local best=-math.huge;local support
    for index,p in ipairs(self.course.platforms or {}) do
        local y=p.y+p.h/2+HEIGHT
        if math.abs(self.position.x-p.x)<=p.w/2 and math.abs(self.position.z-p.z)<=p.d/2
            and previous.y>=y-.4 and self.position.y<=y+.12 and self.velocity.y<=0 and y>best then
            best=y;support=index
        end
    end
    if best>-math.huge then self.position.y=best;self.velocity.y=0;self.grounded=true;self.support=support
    else self.grounded=false;self.support=nil end
end
function Race:_beginRound(reason)
    local bomb=self.course.bombs[self.bombIndex]
    if not bomb then self.completeBombs=true;self:_retire('BombsDefused');return end
    -- A verified defuse or committed retry authorizes the next authored start.
    -- Claiming a role and individual move packets never call this method.
    self.position=copy(bomb.ratStart);self.previous=copy(self.position);self.velocity=point(0,0,0)
    self.input={x=0,z=0,at=-math.huge};self.route=nil;self.stunnedUntil=nil;self.failed=false;self.failedAttempts=nil
    self.elapsed=0;self.grounded=false;self.support=nil;self.nextHop=0
    self.introRemaining=self.course.ratIntroSeconds==nil and 2 or math.max(0,self.course.ratIntroSeconds)
    self:_ground(self.position);self:_pose()
    if self.world.setReaction then self.world:setReaction(self.enemyId,false) end
    self:_log('CampaignRaceStarted',nil,{bomb=self.bombIndex,reason=reason,actorId=self.enemy.actorId,position=copy(self.position)})
end
function Race:resetRound(reason)
    if self.closed or self.completeBombs or not self:_validContext() then return false end
    if reason~='CommittedRetry' and reason~='BombDefused' then return false end
    self:_beginRound(reason);return true
end
function Race:_retry()
    if not self.failed then return false end
    for _,slot in ipairs(self.session.order) do
        local h=self.session.state.heroes[slot]
        local attempt=self.failedAttempts and self.failedAttempts[slot]
        if attempt and self:_living(slot) and h.attempt>attempt then return self:resetRound('CommittedRetry') end
    end
    return false
end
function Race:_lose()
    if self.failed or self.completeBombs or self.closed then return end
    self.failed=true;self.failedAttempts={};self.input={x=0,z=0,at=-math.huge};self.velocity.x=0;self.velocity.z=0
    for _,slot in ipairs(self.session.order) do
        -- A death already pending in Session still belongs to this failed
        -- round. Only its later committed attempt can authorize the retry.
        local hero=self.session.state.heroes[slot]
        if hero then self.failedAttempts[slot]=hero.attempt end
        if self:_living(slot) then
            self.session:_die(slot,'CampaignRatWon')
        end
    end
    self:_log('CampaignRaceLost',nil,{bomb=self.bombIndex,actorId=self.enemy.actorId,position=copy(self.position)})
    local bomb=self.course.bombs[self.bombIndex]
    if self.world.campaignObject then self.world:campaignObject(bomb.id,'Bomb',bomb.position,{w=3,h=3,d=3},
        {collidable=false,role='Exploded',label='EXPLODED',alpha=.75}) end
end

function Race:_dropRoute()
    local bomb=self.course.bombs[self.bombIndex]
    local current=self.support and self.course.platforms[self.support]
    if not current or self.position.y<=bomb.position.y+.25 then self.route=nil;return end
    local nextFloor,nextY=nil,-math.huge
    local currentY=current.y+current.h/2+HEIGHT
    for _,p in ipairs(self.course.platforms or {}) do
        local y=p.y+p.h/2+HEIGHT
        if y<currentY-.2 and y>=bomb.position.y-.2 and y>nextY then nextFloor=p;nextY=y end
    end
    if not nextFloor then self.route=nil;return end
    -- Original randomized floors determine the route. A drop must cross the
    -- real edge and then land; this point is steering, never a placement.
    local dx,dz=nextFloor.x-current.x,nextFloor.z-current.z
    local axis=math.abs(dx)>=math.abs(dz) and 'x' or 'z'
    local difference=axis=='x' and dx or dz
    if math.abs(difference)<.001 then axis='x';difference=bomb.position.x-current.x;if math.abs(difference)<.001 then difference=1 end end
    local sign=difference>0 and 1 or -1
    local edge=axis=='x' and current.x+sign*(current.w/2+self.radius+.25)
        or current.z+sign*(current.d/2+self.radius+.25)
    local target=point(nextFloor.x,nextY,nextFloor.z);target[axis]=edge
    self.route={phase='Leave',fromY=currentY,target=target,landing=point(nextFloor.x,nextY,nextFloor.z),axis=axis}
end
function Race:_npcInput()
    local bomb=self.course.bombs[self.bombIndex]
    if self.grounded then
        if self.route and self.position.y<self.route.fromY-.5 then self.route=nil end
        if not self.route then self:_dropRoute() end
    end
    local route=self.route
    if route and self.position.y<route.fromY-HEIGHT-.2 then route.phase='Fall' end
    local goal=route and (route.phase=='Leave' and route.target or route.landing) or bomb.position
    local x,z=direction(goal.x-self.position.x,goal.z-self.position.z)
    if math.abs(goal.x-self.position.x)<.15 then x=0 end
    if math.abs(goal.z-self.position.z)<.15 then z=0 end
    return x,z
end
function Race:_collisions(previous)
    local obstacles={}
    for _,p in ipairs(self.course.platforms or {}) do obstacles[#obstacles+1]=p end
    for _,p in ipairs(self.course.raceObstacles or {}) do obstacles[#obstacles+1]=p end
    local blocked=false
    for _,p in ipairs(obstacles) do
        local top=p.y+p.h/2;local bottom=p.y-p.h/2
        if previous.y-HEIGHT<top-.05 and self.position.y+TOP>bottom+.05 and self.position.y-HEIGHT<top-.05 then
            local ex,ez=p.w/2+self.radius,p.d/2+self.radius
            if math.abs(self.position.z-p.z)<ez then
                if previous.x<=p.x-ex+.001 and self.position.x>p.x-ex then
                    self.position.x=p.x-ex;self.velocity.x=0;blocked=true
                elseif previous.x>=p.x+ex-.001 and self.position.x<p.x+ex then
                    self.position.x=p.x+ex;self.velocity.x=0;blocked=true
                end
            end
            if math.abs(self.position.x-p.x)<ex then
                if previous.z<=p.z-ez+.001 and self.position.z>p.z-ez then self.position.z=p.z-ez;self.velocity.z=0;blocked=true
                elseif previous.z>=p.z+ez-.001 and self.position.z<p.z+ez then self.position.z=p.z+ez;self.velocity.z=0;blocked=true end
            end
        end
    end
    return blocked
end
function Race:_jump()
    if not self.grounded then return false end
    self.velocity.y=self.course.ratJumpSpeed or 29;self.grounded=false;self.support=nil
    self.nextHop=self.simulationTime+.65
    self:_log('CampaignRaceRatJump',nil,{bomb=self.bombIndex,actorId=self.enemy.actorId})
    return true
end
function Race:_slice(dt)
    self.simulationTime+=dt;self.elapsed+=dt
    local starting=self.introRemaining>0
    if starting then self.introRemaining=math.max(0,self.introRemaining-dt) end
    local old=copy(self.position);self.previous=old
    local stunned=self.stunnedUntil and self.now<self.stunnedUntil
    if self.stunnedUntil and not stunned then
        self.stunnedUntil=nil;if self.world.setReaction then self.world:setReaction(self.enemyId,false) end
    end
    local x,z=0,0
    if not stunned then
        if not starting then
            if self.enemy.ownerUserId then
                if self.enemy.connected and self.now-self.input.at<=INPUT_TIMEOUT then x,z=self.input.x,self.input.z end
            else x,z=self:_npcInput() end
        end
        local speed=self.course.ratSpeed or 9
        self.velocity.x=x*speed;self.velocity.z=z*speed
        if math.abs(x)+math.abs(z)>.001 then self.enemy.engaged=true end
    else
        local damping=math.exp(-2.6*dt);self.velocity.x*=damping;self.velocity.z*=damping
    end
    self.velocity.y-=(self.course.gravity or 150)*dt
    self.position.x+=self.velocity.x*dt;self.position.y+=self.velocity.y*dt;self.position.z+=self.velocity.z*dt
    local blocked=self:_collisions(old)
    self:_ground(old)
    -- Both controllers use the same supported automatic obstacle hop. A tall
    -- obstruction remains an obstruction: hop height cannot bypass it.
    if blocked and not stunned and self.grounded and math.abs(x)+math.abs(z)>.001 and self.simulationTime>=self.nextHop then self:_jump() end
    local bounds=self.definition.bounds or {}
    self.position.x=clamp(self.position.x,bounds.minX or -10000,bounds.maxX or 10000)
    self.position.z=clamp(self.position.z,bounds.minZ or -10000,bounds.maxZ or 10000)
    self:_pose()
    local bomb=self.course.bombs[self.bombIndex]
    if bomb and sweptContact(old,self.position,bomb.position,self.radius+1.5) then self:_lose() end
    if self.position.y<(bounds.minY or -60)-10 then self:_retire('Fell') end
end
function Race:step(now,dt)
    if self.closed then return end
    if not self:_validContext() then self:close('StaleLevel');return end
    if self.session.state.status~='Active' then self:close('RunClosed');return end
    if not finite(now) or not finite(dt) or now<self.now or dt<0 then return end
    self.now=now
    if self.completeBombs or self.enemy.dead then return end
    if self.failed and not self:_retry() then return end
    local accepted=math.min(.5,dt);self.discardedSeconds+=dt-accepted
    while accepted>1e-8 and not self.failed and not self.enemy.dead do
        local slice=math.min(FIXED,accepted);self:_slice(slice);accepted-=slice
    end
end

function Race:interaction(slot)
    if self.closed or self.failed or self.completeBombs or not self:_validContext() or not self:_controlledHero(slot) then return {available=false} end
    local bomb=self.course.bombs[self.bombIndex];local p=self.world:position(slot)
    if bomb and distance(p,bomb.position)<=bomb.radius then return {available=true,action='Defuse bomb',kind='CampaignBomb'} end
    return {available=false}
end
function Race:interact(slot,now,action)
    if action~='Punch' or not finite(now) or now<self.now or not self:interaction(slot).available then return 'NO_INTERACTION' end
    self.now=now
    local bomb=self.course.bombs[self.bombIndex]
    if self.world.campaignObject then self.world:campaignObject(bomb.id,'Bomb',bomb.position,{w=3,h=3,d=3},
        {collidable=false,role='Defused',alpha=.6}) end
    self:_log('CampaignBombDefused',slot,{bomb=self.bombIndex,actorId=self.enemy.actorId})
    self.bombIndex+=1
    self:resetRound('BombDefused')
    return 'OK'
end

function Race:available(userId)
    if self.closed or self.completeBombs or self.enemy.dead or self.enemy.engaged or self.enemy.ownerUserId
        or not self:_validContext() or self.session.state.status~='Active' then return {} end
    return {{enemyId=self.enemyId,actorId=self.enemy.actorId,name='Racing Rat',resourceKind='CourseRival',hearts=0,maxHearts=0}}
end
function Race:claim(userId,id)
    if self.closed or not self:_validContext() or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if id~=self.enemyId then return 'UNKNOWN_ENEMY' end
    local e=self.enemy
    if e.ownerUserId==userId then return e.dead and 'ENEMY_LIFE_SPENT' or 'OK' end
    if e.dead or self.completeBombs then return 'ENEMY_DEAD' end
    if e.ownerUserId then return 'ENEMY_OCCUPIED' end
    if e.engaged then return 'ENEMY_ENGAGED' end
    e.ownerUserId=userId;e.connected=true;e.connectionEpoch=1;e.lastSeq=0
    self.input={x=0,z=0,at=-math.huge}
    if self.world.enemyIdentity then self.world:enemyIdentity(self.enemyId,e.actorId,self.ownerNames and self.ownerNames[userId]) end
    self:_log('CampaignRaceClaimed',nil,{enemyId=self.enemyId,actorId=e.actorId,ownerUserId=userId})
    return 'OK'
end
function Race:controlled(userId)
    local e=self.enemy;if e.ownerUserId~=userId then return nil end
    return {enemyId=self.enemyId,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,connected=e.connected,
        status=e.dead and 'Dead' or 'Alive',template='Racer',name='Racing Rat',resourceKind='CourseRival',hearts=0,maxHearts=0,
        movementKind='Race',reactionEpoch=e.reactionEpoch,progress=self.bombIndex-1,bombIndex=self.bombIndex}
end
function Race:connection(userId,connected)
    local e=self.enemy
    if e.ownerUserId~=userId then return 'UNKNOWN_ENEMY' end
    if type(connected)~='boolean' then return 'INVALID_CONNECTION' end
    if e.connected==connected then return 'NO_CHANGE' end
    e.connected=connected;e.connectionEpoch+=1;e.lastSeq=0;self.input={x=0,z=0,at=-math.huge}
    if not self.stunnedUntil then self.velocity.x=0;self.velocity.z=0 end
    self:_log('CampaignRaceConnection',nil,{actorId=e.actorId,connected=connected,connectionEpoch=e.connectionEpoch})
    return 'OK'
end
function Race:command(userId,payload,now,validator)
    local e=self.enemy
    if e.ownerUserId~=userId then return 'UNKNOWN_ENEMY' end
    if self.closed or not self:_validContext() or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if type(validator)~='function' or not validator(payload) then return 'INVALID_INTENT' end
    if payload.runId~=self.runId then return 'WRONG_RUN' end
    if not e.connected then return 'OFFLINE' end
    if e.dead or self.completeBombs then return 'NOT_ALIVE' end
    if payload.actorId~=e.actorId or payload.attempt~=1 or payload.levelEpoch~=self.levelEpoch then return 'STALE_ACTOR' end
    if payload.connectionEpoch~=e.connectionEpoch then return 'STALE_CONNECTION' end
    if payload.seq<=e.lastSeq then return 'STALE_SEQUENCE' end
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now;e.lastSeq=payload.seq
    if self.failed then return 'RACE_RESET_PENDING' end
    if self.stunnedUntil and now<self.stunnedUntil then return 'REACTION' end
    if payload.kind=='Move' then
        local x,z=normalized(payload.x,payload.z);self.input={x=x,z=z,at=now};return 'OK'
    elseif payload.kind=='Jump' then
        if self.introRemaining>0 then return 'RACE_STARTING' end
        return self:_jump() and 'OK' or 'NO_JUMP'
    end
    return 'NO_ACTION'
end
function Race:closeTargetForAttack(targets)
    for _,id in ipairs(targets) do if id==self.enemyId and not self.enemy.dead then self.enemy.engaged=true;return true end end
    return false
end
function Race:hit(attacker,target,action,tuning)
    if target~=self.enemyId or self.closed or self.failed or self.completeBombs or self.enemy.dead or not self:_validContext() then return false end
    if self.stunnedUntil and self.now<self.stunnedUntil then return false end
    local combat=self.session.Combat
    if not combat or not combat.hitEnemy then return false end
    -- 0xF0 is restored by the racing source handler each running frame. Keep
    -- the source response profile, but do not turn this rival into fake HP.
    local source=combat.hitEnemy(255,action)
    local config=self.session.config
    local policy=tuning and tuning.sourceCombat or config.SourceCombat
    local duration=(policy and (source.heavyReaction and policy.npcHeavyReaction or policy.npcLightReaction))
        or (tuning and tuning.reaction) or self.course.ratStunSeconds or .55
    self.stunnedUntil=self.now+math.max(1/60,duration);self.enemy.reactionEpoch+=1
    if self.session.state.heroes[attacker] then self.enemy.engaged=true end
    self.input={x=0,z=0,at=-math.huge};self.route=nil
    local responses=tuning and tuning.responses or config.Impulses
    local impulse=responses and responses[source.profile]
    local origin=self.world:position(attacker)
    local dx,dz=origin and self.position.x-origin.x or 1,origin and self.position.z-origin.z or 0
    local supplied=tuning and tuning.impulseDirection
    if supplied and finite(supplied.x) and finite(supplied.z) then dx,dz=supplied.x,supplied.z end
    dx,dz=direction(dx,dz);if dx==0 and dz==0 then dx=1 end
    local horizontal=impulse and impulse.horizontal or 6;local vertical=impulse and impulse.vertical or (source.heavyReaction and 16 or 0)
    self.velocity=point(dx*horizontal,vertical,dz*horizontal)
    if vertical>0 then self.grounded=false;self.support=nil end
    if self.world.setReaction then self.world:setReaction(self.enemyId,true) end
    self:_log('CampaignRaceRatHit',nil,{attacker=attacker,action=action,profile=source.profile,actorId=self.enemy.actorId,
        stunUntil=self.stunnedUntil,reactionEpoch=self.enemy.reactionEpoch})
    return true
end
function Race:onHit(attacker,target,action,tuning) return self:hit(attacker,target or self.enemyId,action or 'Punch',tuning) end
function Race:isTarget(id) return id==self.enemyId and not self.enemy.dead and not self.closed end
function Race:_retire(reason)
    if self.enemy.dead then return end
    self.enemy.dead=true;self.input={x=0,z=0,at=-math.huge}
    if self.world.campaignRelease then self.world:campaignRelease(self.enemyId) end
    if self.world.kill then self.world:kill(self.enemyId) end
    self:_log('CampaignRaceRivalClosed',nil,{actorId=self.enemy.actorId,reason=reason})
end
function Race:close(reason)
    if self.closed then return end
    self.closed=true;self:_retire(reason or 'Closed')
end
function Race:snapshot()
    local bomb=self.course.bombs[self.bombIndex]
    return {enemyId=self.enemyId,actorId=self.enemy.actorId,resourceKind='CourseRival',bombIndex=self.bombIndex,
        bombCount=#self.course.bombs,elapsed=self.elapsed,failed=self.failed,completeBombs=self.completeBombs,
        position=copy(self.position),velocity=copy(self.velocity),grounded=self.grounded,support=self.support,
        stunned=self.stunnedUntil~=nil and self.now<self.stunnedUntil,stunUntil=self.stunnedUntil,
        introRemaining=self.introRemaining,engaged=self.enemy.engaged,ownerUserId=self.enemy.ownerUserId,
        connected=self.enemy.connected,dead=self.enemy.dead,
        raceTime=bomb and distance(self.position,bomb.position)/(self.course.ratSpeed or 9) or nil,
        raceTimeKind='DistanceEstimate',discardedSeconds=self.discardedSeconds}
end
return Race
