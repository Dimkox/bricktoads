-- Bounded private evidence and an allowlisted view of the same server records.
local Journal={}
Journal.__index=Journal
local public={Hit=true,EnemyHit=true,AttackMiss=true,EnemyAttackMiss=true,CommitSpawn=true,
    RelocateToSafety=true,EnemyDeath=true,EnemyClaimed=true,FlyCaught=true,ClubEquipped=true,
    ClubDropped=true,ClubSwingHit=true,EnemyGrabbed=true,EnemyThrown=true,EnemyDropped=true,
    DragonMounted=true,DragonCaptured=true,DragonReleased=true,DragonFireHit=true,
    RunResult=true,GuardianBallPickedUp=true,GuardianBallThrown=true,BossHit=true,BossShielded=true,BossWarning=true}
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function text(v)
    if type(v)~='string' then return nil end
    local length=math.min(#v,160)
    while length<#v and length>0 do
        local byte=string.byte(v,length+1)
        if byte<128 or byte>=192 then break end
        length-=1
    end
    local result=string.sub(v,1,length)
    return utf8.len(result) and result or '[invalid-utf8]'
end
local function copy(v)
    if type(v)~='table' then return v end
    local result={};for k,value in pairs(v) do result[k]=copy(value) end;return result
end
local function sanitize(v,depth,budget,seen)
    local kind=type(v)
    if kind=='string' then return text(v) end
    if kind=='number' then return finite(v) and v or nil end
    if kind=='boolean' then return v end
    if kind~='table' or depth>=3 or seen[v] then return nil end
    seen[v]=true
    local result,count={},0
    for key,value in pairs(v) do
        if count>=16 or budget.count>=64 then break end
        count+=1;budget.count+=1
        if (type(key)=='string' and #key<=48 and utf8.len(key)) or (finite(key) and key>=1 and key<=16 and key%1==0) then
            result[key]=sanitize(value,depth+1,budget,seen)
        end
    end
    seen[v]=nil
    return result
end

function Journal.new(context,capacity)
    capacity=capacity or 256
    assert(finite(capacity) and capacity>=1 and capacity<=256 and capacity%1==0,'Invalid journal capacity')
    assert(type(context)=='table' and text(context.runId) and text(context.groupId),'Journal identity required')
    return setmetatable({context={runId=text(context.runId),groupId=text(context.groupId),
        build=text(context.build) or 'unknown',rules=text(context.rules) or 'unknown'},
        capacity=capacity,rows={},keys={},seen={},next=1,count=0,seq=0,dropped=0,invalid=0,duplicates=0,
        publicRows={},lastNow=0},Journal)
end

function Journal:record(row)
    if type(row)~='table' or type(row.kind)~='string' or #row.kind>48 or not row.kind:match('^[A-Za-z][A-Za-z0-9_]*$')
        or (row.data~=nil and type(row.data)~='table')
        or not finite(row.now) or row.now<0 or (row.runId~=nil and row.runId~=self.context.runId)
        or (row.groupId~=nil and row.groupId~=self.context.groupId) then
        self.invalid+=1;return false,'INVALID_RECORD'
    end
    local data=sanitize(row.data or {},0,{count=0},{}) or {}
    local key=type(data.eventId)=='string' and row.kind..':'..data.eventId or nil
    if key and self.seen[key] then self.duplicates+=1;return false,'DUPLICATE' end
    self.seq+=1
    local event={seq=self.seq,kind=row.kind,now=row.now,late=row.now<self.lastNow,data=data}
    for _,name in ipairs({'levelEpoch','userId','attempt','respawns','rawLife','revision','shieldUntil'}) do
        if finite(row[name]) then event[name]=row[name] end
    end
    event.actorId=text(row.actorId) or text(data.actorId)
    event.shieldKind=text(row.shieldKind);event.status=text(row.status);event.view=text(row.view)
    if type(row.connected)=='boolean' then event.connected=row.connected end
    self.lastNow=math.max(self.lastNow,row.now)
    if self.count==self.capacity then
        self.dropped+=1
        local oldKey=self.keys[self.next];if oldKey then self.seen[oldKey]=nil end
    else self.count+=1 end
    self.rows[self.next]=event;self.keys[self.next]=key
    if key then self.seen[key]=true end
    self.next=self.next%self.capacity+1
    if public[event.kind] and (data.code==nil or data.code=='OK') then
        local item={seq=event.seq,now=event.now,kind=event.kind,slot=event.userId,
            actorId=event.actorId or text(data.actorId),levelEpoch=event.levelEpoch,attempt=event.attempt,
            action=text(data.action),result=text(data.result),target=finite(data.target) and data.target or nil,
            attacker=finite(data.attacker) and data.attacker or nil,blocked=data.blocked==true}
        self.publicRows[#self.publicRows+1]=item
        if #self.publicRows>12 then table.remove(self.publicRows,1) end
    end
    return true
end

function Journal:snapshot()
    local result=copy(self.context)
    result.schema=1;result.latestSeq=self.seq;result.dropped=self.dropped;result.invalid=self.invalid
    result.duplicates=self.duplicates;result.events={}
    local first=self.count<self.capacity and 1 or self.next
    for i=1,self.count do result.events[i]=copy(self.rows[(first+i-2)%self.capacity+1]) end
    return result
end

function Journal:feedback()
    return {latestSeq=self.seq,events=copy(self.publicRows)}
end

return Journal
