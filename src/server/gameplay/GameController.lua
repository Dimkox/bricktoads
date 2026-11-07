-- One playable group. Player identity comes from the server, never from payload fields.
local Controller={}
Controller.__index=Controller
local templates={['Mr. Green']=true,['Mr. Yellow']=true,['Mr. Brown']=true}
local function exact(payload,allowed)
    if type(payload)~='table' then return false end
    local count=0
    for key in pairs(payload) do count+=1; if count>2 or not allowed[key] then return false end end
    return true
end
function Controller.new(deps,world)
    return setmetatable({deps=deps,world=world,connections=deps.Registry.new(),choices={},owners={},ownerSlots={},buckets={},notices={}},Controller)
end
function Controller:join(player)
    if not self.connections:join(player) then return end
    local slot=self.ownerSlots[player.UserId]
    if self.current and slot and self.current.state.status=='Active' and not self.director.result then
        if self.current.state.heroes[slot].connected then self.current:connection(slot,false,self.deps.clock()) end
        self.current:connection(slot,true,self.deps.clock())
    end
end
function Controller:leave(player)
    local changed=self.connections:remove(player)
    local slot=self.ownerSlots[player.UserId]
    if changed and self.current and slot and self.current.state.status=='Active' and not self.director.result then
        self.current:connection(slot,false,self.deps.clock())
    end
    self.buckets[player]=nil; self.notices[player]=nil
end
function Controller:_open()
    return not self.current or self.current.state.status=='Lost' or self.director.result~=nil
end
function Controller:_begin(player,players)
    local online=self.connections:online(players)
    if online[1]~=player then return 'HOST_ONLY' end
    if not self:_open() then return 'RUN_ACTIVE' end
    self.world:clearActors(); self.ownerSlots={}; self.owners={}
    local roster={}
    for index=1,math.min(3,#online) do
        local owner=online[index]
        local template=self.choices[owner.UserId] or 'Mr. Green'
        self.ownerSlots[owner.UserId]=index
        self.owners[index]={userId=owner.UserId,displayName=owner.DisplayName,username=owner.Name,template=template}
        self.world.names[index]=owner.DisplayName..' @'..owner.Name
        roster[index]={userId=index,template=template}
    end
    self.current=self.deps.Session.new(self.deps.Core,self.deps.Combat,self.deps.Config,roster,self.deps.guid(),self.world,function(row)
        if row.kind=='Hit' then self.world:cue(row.userId,row.data.blocked) end
    end)
    self.current:step(self.deps.clock())
    self.director=self.deps.Director.new(self.current,self.world,self.deps.Combat,self.deps.Config)
    local originalHit=self.current._hit
    local director=self.director
    self.current._hit=function(session,attacker,target,action)
        if type(target)=='number' and target<0 then return director:hit(attacker,target,action) end
        return originalHit(session,attacker,target,action)
    end
    self.finished=false
    return 'OK'
end
function Controller:handle(player,payload,players)
    if not player.Parent or not self.connections:isCurrent(player) then return 'STALE_CONNECTION' end
    local at=self.deps.clock()
    local rate=self.deps.Config.MaxIntentRate
    local bucket=self.buckets[player] or {tokens=rate,last=at}
    bucket.tokens=math.min(rate,bucket.tokens+math.max(0,at-bucket.last)*rate); bucket.last=at; self.buckets[player]=bucket
    if bucket.tokens<1 then return 'RATE_LIMIT' end
    bucket.tokens-=1
    if type(payload)~='table' or type(payload.kind)~='string' then return 'INVALID_INTENT' end
    local code
    if payload.kind=='Sync' or payload.kind=='Start' then
        if not exact(payload,{kind=true}) then return 'INVALID_INTENT' end
        code=payload.kind=='Start' and self:_begin(player,players) or 'OK'
    elseif payload.kind=='SelectHero' then
        if not exact(payload,{kind=true,template=true}) or not templates[payload.template] then return 'INVALID_INTENT' end
        if not self:_open() then code='RUN_ACTIVE'
        else self.choices[player.UserId]=payload.template; code='OK' end
    elseif self.current then
        local slot=self.ownerSlots[player.UserId]
        if self:_open() then code='RUN_CLOSED'
        elseif not slot then code='SPECTATOR'
        else code=self.current:intent(slot,payload,at) end
    else code='NO_RUN' end
    if code=='OK' then self.notices[player]=nil else self.notices[player]=code end
    return code
end
function Controller:step(now,dt)
    if not self.current or self.finished then return end
    self.director.now=now
    self.current:step(now); self.director:step(now,dt)
    if self.director.result then
        self.finished=true
        for _,id in ipairs(self.current.order) do
            self.world:move(id,0,0)
            if self.world.hold then self.world:hold(id,true) end
        end
    end
end
function Controller:snapshot(player,players)
    if not self.connections:isCurrent(player) then return nil end
    local online=self.connections:online(players)
    local data=self.current and self.current:snapshot() or {status='Lobby',heroes={},now=self.deps.clock()}
    data.status=self.director and self.director.result or data.status
    data.level=self.director and self.director:snapshot() or {stage='Lobby',objective='Выберите героя и отправляйтесь в путь'}
    for _,hero in ipairs(data.heroes) do
        local owner=self.owners[hero.slot]
        for key,value in pairs(owner) do hero[key]=value end
    end
    data.lobby={}
    for _,owner in ipairs(online) do
        data.lobby[#data.lobby+1]={userId=owner.UserId,displayName=owner.DisplayName,username=owner.Name,
            template=self.choices[owner.UserId] or 'Mr. Green'}
    end
    data.mine=self.ownerSlots[player.UserId]
    data.online=#online; data.host=online[1] and online[1].UserId
    data.canStart=online[1]==player and self:_open()
    data.canSelect=self:_open()
    data.selectedTemplate=self.choices[player.UserId] or 'Mr. Green'
    data.notice=self.notices[player]
    return data
end
return Controller
