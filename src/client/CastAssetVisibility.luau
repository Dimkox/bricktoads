-- Client content availability changes only local visibility, never server bodies.
local Gate={}
Gate.__index=Gate
local CONTRACTS={
    Cast={tag='BrickToadsCastSkin',skin='CanonicalCastSkin',id='CastSkinId',
        owner='CastAppearance',profile='CanonicalNESCast',alpha='CastVisibleTransparency',
        reference='CastFallbackTarget',backlink='CastFallbackOwner',fallbackAlpha='CastFallbackTransparency'},
    Course={tag='BrickToadsCourseSkin',skin='CanonicalCourseSkin',id='CourseSkinId',
        owner='CourseAppearance',profile='CanonicalCourseVehicle',alpha='CourseVisibleTransparency',
        reference='CourseFallbackTarget',backlink='CourseFallbackOwner',fallbackAlpha='CourseFallbackTransparency'},
}
local RETRY_DELAYS={1,3,10}
local function finite(v)return type(v)=='number' and v==v and v>=0 and v<=1 end
local function identity(v)return type(v)=='string' and #v>0 and #v<=512 end
local function key(id)
    if type(id)~='string' or id=='' then return nil end
    return id:match('^rbxassetid://(%d+)') or id:match('[?&]id=(%d+)') or id
end
local function disconnect(list)
    for _,connection in ipairs(list)do pcall(function()connection:Disconnect()end)end
    table.clear(list)
end
local function connect(list,event,fn)
    if event then list[#list+1]=event:Connect(fn)end
end
local function localAlpha(part,value)
    pcall(function()part.LocalTransparencyModifier=value end)
end
function Gate:_valid(row)
    return not self.destroyed and self.rows[row.skin]==row and row.skin.Parent==row.owner
        and row.skin:IsDescendantOf(self.workspace) and row.skin:GetAttribute(self.contract.skin)==true
        and row.skin:GetAttribute(self.contract.id)==row.id and row.owner:GetAttribute(self.contract.owner)==self.contract.profile
end
function Gate:_restoreFallback(row,part,value)
    local backlink=part:GetAttribute(self.contract.backlink)
    if part.Parent and (backlink==nil or backlink==row.id)then localAlpha(part,value)end
end
function Gate:_rememberFallback(row,part)
    local baseline=self.baselines[part]
    if not baseline then
        baseline={value=finite(part.LocalTransparencyModifier)and part.LocalTransparencyModifier or 0,owners={}}
        self.baselines[part]=baseline
    end
    baseline.owners[row]=true
    return baseline.value
end
function Gate:_releaseFallback(row,part)
    local baseline=self.baselines[part];if not baseline then return end
    baseline.owners[row]=nil
    local backlink=part:GetAttribute(self.contract.backlink)
    -- During handoff the server may replace the backlink before publishing the
    -- new skin's reference. Retain the pre-gate value for that incoming owner.
    if next(baseline.owners)==nil and (backlink==nil or backlink==row.id)then self.baselines[part]=nil end
end
function Gate:_unsubscribe(row)
    local entry=row.entry;row.entry=nil
    if not entry then return end
    entry.waiters[row]=nil
    if entry.state~='Ready' and next(entry.waiters)==nil then
        entry.cancelled=true
        if self.cache[entry.signature]==entry then self.cache[entry.signature]=nil end
    end
end
function Gate:_retry(entry)
    local seconds=RETRY_DELAYS[entry.attempts or 0]
    if not seconds or not self.delay or entry.retryScheduled or entry.cancelled or self.destroyed then return end
    entry.retryScheduled=true
    self.delay(seconds,function()
        entry.retryScheduled=false
        if not entry.cancelled and not self.destroyed and self.cache[entry.signature]==entry then self:_request(entry)end
    end)
end
function Gate:_request(entry)
    self.spawn(function()
        if entry.cancelled or self.destroyed or self.cache[entry.signature]~=entry then return end
        -- Reconcile live subscribers before selecting typed instances. The
        -- original request's skin may have been destroyed during the delay.
        local waiters={};for row in pairs(entry.waiters)do waiters[#waiters+1]=row end
        local selected
        for _,row in ipairs(waiters)do
            if self.rows[row.skin]==row then self:_refresh(row)end
            if row.entry==entry and self:_valid(row)and row.signature==entry.signature and row.parts and #row.parts>0 then selected=row end
        end
        if not selected or entry.cancelled or self.destroyed then return end
        local parts,ids=selected.parts,selected.resourceIds
        entry.state='Pending';entry.attempts=(entry.attempts or 0)+1
        for row in pairs(entry.waiters)do if row.entry==entry and self:_valid(row)then self:_apply(row,'Pending')end end
        local observed,failed={},false
        local ok=pcall(function()
            self.provider:PreloadAsync(parts,function(id,status)
                local resource=key(id)
                if resource and ids[resource]then observed[resource]=true end
                if status~=self.success then failed=true end
            end)
        end)
        for resource in pairs(ids)do if not observed[resource]then failed=true end end
        if entry.cancelled or self.destroyed or self.cache[entry.signature]~=entry then return end
        entry.state=ok and not failed and 'Ready'or'Failed'
        for row in pairs(entry.waiters)do if row.entry==entry and self:_valid(row)then self:_apply(row,entry.state)end end
        if entry.state=='Failed'then self:_retry(entry)end
    end)
end
function Gate:_remove(skin)
    local row=self.rows[skin];if not row then return end
    self.rows[skin]=nil;self:_unsubscribe(row)
    disconnect(row.connections);disconnect(row.assetConnections)
    for part,value in pairs(row.skinSaved)do
        if part.Parent and part:IsDescendantOf(skin)then localAlpha(part,value)end
    end
    for part,value in pairs(row.fallbackSaved)do self:_restoreFallback(row,part,value);self:_releaseFallback(row,part)end
end
function Gate:_apply(row,state)
    if not self:_valid(row)then return end
    row.state=state
    for part,value in pairs(row.skinSaved)do
        if part.Parent and part:IsDescendantOf(row.skin)then localAlpha(part,state=='Ready' and value or 1)end
    end
    for part,value in pairs(row.fallbackSaved)do
        if part.Parent and part:GetAttribute(self.contract.backlink)==row.id then localAlpha(part,state=='Ready' and 1 or value)end
    end
end
function Gate:_refresh(row)
    if not self:_valid(row)then self:_remove(row.skin);return end
    disconnect(row.assetConnections)
    local parts,ids,signature,targets={},{},{},{}
    local complete=true
    local function refresh()if self.rows[row.skin]==row then self:_refresh(row)end end
    local function include(prefix,id,required)
        if required and not key(id)then complete=false end
        if type(id)=='string' and id~=''then
            signature[#signature+1]=prefix..tostring(#id)..':'..id
            ids[key(id)]=true
        end
    end
    for _,part in ipairs(row.skin:GetDescendants())do
        if part:IsA('MeshPart')then
            parts[#parts+1]=part
            if row.skinSaved[part]==nil then row.skinSaved[part]=finite(part.LocalTransparencyModifier)and part.LocalTransparencyModifier or 0 end
            if not finite(part:GetAttribute(self.contract.alpha))then complete=false end
            include('M',part.MeshId,true);include('T',part.TextureID,false)
            connect(row.assetConnections,part:GetPropertyChangedSignal('MeshId'),refresh)
            connect(row.assetConnections,part:GetPropertyChangedSignal('TextureID'),refresh)
            connect(row.assetConnections,part:GetAttributeChangedSignal(self.contract.alpha),refresh)
            for _,surface in ipairs(part:GetChildren())do if surface:IsA('SurfaceAppearance')then
                include('C',surface.ColorMap,false)
                connect(row.assetConnections,surface:GetPropertyChangedSignal('ColorMap'),refresh)
            end end
        end
    end
    -- Explicit references support the serpent's external support collider. A
    -- unique backlink prevents an old skin from controlling a replacement.
    for _,ref in ipairs(row.skin:GetChildren())do
        if ref:IsA('ObjectValue')and ref.Name==self.contract.reference then
            connect(row.assetConnections,ref:GetPropertyChangedSignal('Value'),refresh)
            local part=ref.Value
            if part and part:IsA('BasePart')then
                connect(row.assetConnections,part:GetAttributeChangedSignal(self.contract.backlink),refresh)
                connect(row.assetConnections,part:GetAttributeChangedSignal(self.contract.fallbackAlpha),refresh)
                if part.Parent and part:GetAttribute(self.contract.backlink)==row.id
                    and finite(part:GetAttribute(self.contract.fallbackAlpha))then
                    targets[part]=true
                    if row.fallbackSaved[part]==nil then row.fallbackSaved[part]=self:_rememberFallback(row,part)end
                end
            end
        end
    end
    for part,value in pairs(row.fallbackSaved)do
        if not targets[part]then self:_restoreFallback(row,part,value);self:_releaseFallback(row,part);row.fallbackSaved[part]=nil end
    end
    table.sort(signature)
    local signatureKey=table.concat(signature,'|')
    row.signature,row.parts,row.resourceIds=signatureKey,parts,ids
    if #parts==0 or not complete then
        self:_unsubscribe(row);self:_apply(row,'Pending');return
    end
    local entry=self.cache[signatureKey]
    if row.entry~=entry then self:_unsubscribe(row)end
    if not entry then
        entry={state='Pending',signature=signatureKey,waiters={},attempts=0}
        self.cache[signatureKey]=entry
        row.entry=entry;entry.waiters[row]=true
        self:_apply(row,'Pending')
        self:_request(entry)
    else
        row.entry=entry;entry.waiters[row]=true;self:_apply(row,entry.state)
    end
end
function Gate:_add(skin)
    if self.destroyed or self.rows[skin]or not skin:IsA('Model')or skin:GetAttribute(self.contract.skin)~=true then return end
    local owner=skin.Parent;local id=skin:GetAttribute(self.contract.id)
    if not owner or not owner:IsA('Model')or not identity(id)or not skin:IsDescendantOf(self.workspace)
        or owner:GetAttribute(self.contract.owner)~=self.contract.profile then return end
    local row={skin=skin,owner=owner,id=id,connections={},assetConnections={},skinSaved={},fallbackSaved={}}
    self.rows[skin]=row
    local function refresh()if self.rows[skin]==row then self:_refresh(row)end end
    connect(row.connections,skin.AncestryChanged,refresh)
    connect(row.connections,skin:GetAttributeChangedSignal(self.contract.skin),refresh)
    connect(row.connections,skin:GetAttributeChangedSignal(self.contract.id),refresh)
    connect(row.connections,owner:GetAttributeChangedSignal(self.contract.owner),refresh)
    connect(row.connections,skin.DescendantAdded,refresh)
    -- DescendantRemoving fires before the child leaves. Defer reconciliation so
    -- it cannot keep a removed fallback reference or obsolete asset signature.
    connect(row.connections,skin.DescendantRemoving,function()self.defer(refresh)end)
    self:_refresh(row)
end
function Gate.new(deps,contractName)
    deps=deps or {}
    local contract=assert(CONTRACTS[contractName or 'Cast'],'Unsupported appearance contract')
    local self=setmetatable({workspace=deps.workspace or game:GetService('Workspace'),
        collection=deps.collectionService or game:GetService('CollectionService'),
        provider=deps.contentProvider or game:GetService('ContentProvider'),
        spawn=deps.spawn or task.spawn,defer=deps.defer or deps.spawn or task.defer,delay=deps.delay or (task and task.delay),
        success=deps.successStatus or Enum.AssetFetchStatus.Success,contract=contract,rows={},cache={},connections={},
        baselines=setmetatable({},{__mode='k'})},Gate)
    connect(self.connections,self.collection:GetInstanceAddedSignal(contract.tag),function(skin)self:_add(skin)end)
    connect(self.connections,self.collection:GetInstanceRemovedSignal(contract.tag),function(skin)self:_remove(skin)end)
    for _,skin in ipairs(self.collection:GetTagged(contract.tag))do self:_add(skin)end
    return self
end
function Gate:diagnostics()
    local out={tracked=0,pending=0,ready=0,failed=0,destroyed=self.destroyed==true}
    for _,row in pairs(self.rows)do out.tracked+=1;local state=string.lower(row.state or'Pending');out[state]+=1 end
    return out
end
function Gate:destroy()
    if self.destroyed then return end
    self.destroyed=true;disconnect(self.connections)
    local skins={};for skin in pairs(self.rows)do skins[#skins+1]=skin end
    for _,skin in ipairs(skins)do self:_remove(skin)end
    self.cache={};self.baselines={}
end
return Gate
