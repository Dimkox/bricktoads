-- One coordinator composes physical fallback, canonical base and active morph.
-- Only local modifiers change here. Assemblies/poses remain server-owned.
local Gate={}
Gate.__index=Gate
local TAG='BrickToadsHeroSkin'
local MAPS={'ColorMap','NormalMap','RoughnessMap','MetalnessMap','EmissiveMask'}
local RETRY_DELAYS={1,3,10}
local function alpha(v)return type(v)=='number'and v==v and v>=0 and v<=1 end
local function identity(v)return type(v)=='string'and #v>0 and #v<=512 end
local function rawId(value)return type(value)=='string'and value or''end
local function mapUri(surface,property)
    -- *Content getters are script-readable; legacy map strings and their
    -- signals require PluginSecurity. Only published URI or None is valid.
    local ok,id=pcall(function()
        local content=surface[property..'Content'];local source=content.SourceType.Name
        if source=='None'then return '' end
        if source=='Uri'then
            local uri=content.Uri;if type(uri)=='string'and uri~=''then return uri end
        end
    end)
    return ok and id or nil
end
local function key(id)
    if type(id)~='string'or id==''then return nil end
    return id:match('^rbxassetid://(%d+)')or id:match('[?&]id=(%d+)')or id
end
local function disconnect(list)
    for _,c in ipairs(list)do c:Disconnect()end;table.clear(list)
end
local function connect(list,event,fn)if event then list[#list+1]=event:Connect(fn)end end
local function watchProperty(list,instance,property,refresh)
    return pcall(function()connect(list,assert(instance:GetPropertyChangedSignal(property)),refresh)end)
end
local function localAlpha(part,value)pcall(function()part.LocalTransparencyModifier=value end)end
function Gate:_valid(row)
    return not self.destroyed and self.rows[row.skin]==row and row.skin.Parent==row.owner
        and row.skin:IsDescendantOf(self.workspace)and row.skin:GetAttribute('CanonicalHeroSkin')==true
        and row.skin:GetAttribute('HeroSkinId')==row.id and row.owner:GetAttribute('Appearance')=='CanonicalNESHero'
        and row.owner:GetAttribute('HeroAppearanceOwner')==row.id
end
function Gate:_live(group)
    local row=group.row
    return self:_valid(row)and(row.base==group or row.morph==group
        and row.skin:GetAttribute('HeroActiveMorph')==group.kind)
end
function Gate:_remember(row,part)
    local baseline=self.baselines[part]
    if not baseline then
        baseline={value=alpha(part.LocalTransparencyModifier)and part.LocalTransparencyModifier or 0,owners={}}
        self.baselines[part]=baseline
    end
    baseline.owners[row]=true;return baseline.value
end
function Gate:_release(row,part,value)
    local backlink=part:GetAttribute('HeroFallbackOwner')
    if part.Parent and(backlink==nil or backlink==row.id)then localAlpha(part,value)end
    local baseline=self.baselines[part]
    if baseline then
        baseline.owners[row]=nil
        -- A newly published backlink may precede the replacement reference.
        if next(baseline.owners)==nil and(backlink==nil or backlink==row.id)then self.baselines[part]=nil end
    end
end
function Gate:_unsubscribe(group)
    if not group or not group.entry then return end
    local entry=group.entry;group.entry=nil;entry.waiters[group]=nil
    if entry.state~='Ready'and next(entry.waiters)==nil then
        entry.cancelled=true
        self:_cleanupProxies(entry)
        if self.cache[entry.signature]==entry then self.cache[entry.signature]=nil end
    end
end
function Gate:_cleanupProxies(entry)
    local proxies=entry.proxies;entry.proxies=nil
    for _,proxy in ipairs(proxies or{})do pcall(function()proxy:Destroy()end)end
end
function Gate:_apply(row)
    if not self:_valid(row)then return end
    local ready=row.base and row.base.entry and row.base.entry.state=='Ready'
    row.state=row.base and row.base.entry and row.base.entry.state or'Pending'
    local morph=row.morph
    local morphReady=ready and morph and self:_live(morph)and morph.entry and morph.entry.state=='Ready'
    for part,value in pairs(row.skinSaved)do if part.Parent and part:IsDescendantOf(row.skin)then
        local visible=ready and row.baseSet[part]or morphReady and part==morph.part
        if morphReady and part==morph.original then visible=false end
        localAlpha(part,visible and value or 1)
    end end
    for part,value in pairs(row.fallbackSaved)do
        if part.Parent and part:GetAttribute('HeroFallbackOwner')==row.id then localAlpha(part,ready and 1 or value)end
    end
end
function Gate:_retry(entry)
    local seconds=RETRY_DELAYS[entry.attempts]
    if not seconds or not self.delay or entry.retryScheduled or entry.cancelled or self.destroyed then return end
    entry.retryScheduled=true
    self.delay(seconds,function()
        entry.retryScheduled=false
        if not self.destroyed and not entry.cancelled and self.cache[entry.signature]==entry then self:_request(entry)end
    end)
end
function Gate:_request(entry)
    self.spawn(function()
        if self.destroyed or entry.cancelled or self.cache[entry.signature]~=entry then return end
        local waiters={};for group in pairs(entry.waiters)do waiters[#waiters+1]=group end
        local selected
        for _,group in ipairs(waiters)do
            if self.rows[group.row.skin]==group.row then self:_refresh(group.row)end
            if group.entry==entry and self:_live(group)then selected=group end
        end
        if not selected or entry.cancelled or self.destroyed then return end
        entry.state='Pending';entry.attempts+=1
        for group in pairs(entry.waiters)do if self:_live(group)then self:_apply(group.row)end end
        local ids,observed,failed=selected.ids,{},false
        local proxies={};entry.proxies=proxies
        local ok=pcall(function()
            local instances=table.clone(selected.instances)
            -- SurfaceAppearance uses processed texture packs and is expressly
            -- unsupported by PreloadAsync. Warm each referenced source image
            -- through an owned invisible typed image; this does not certify
            -- processed texture-pack pixels have rendered on this device.
            for _,id in pairs(selected.images)do
                local proxy=self.newInstance('ImageLabel');proxies[#proxies+1]=proxy
                proxy.Visible=false;proxy.Image=id;instances[#instances+1]=proxy
            end
            if entry.cancelled or self.destroyed then return end
            self.provider:PreloadAsync(instances,function(id,status)
                local resource=key(id)
                if resource and ids[resource]then observed[resource]=true end
                if status~=self.success then failed=true end
            end)
        end)
        self:_cleanupProxies(entry)
        for id in pairs(ids)do if not observed[id]then failed=true end end
        if self.destroyed or entry.cancelled or self.cache[entry.signature]~=entry then return end
        entry.state=ok and not failed and'Ready'or'Failed'
        for group in pairs(entry.waiters)do if group.entry==entry and self:_live(group)then self:_apply(group.row)end end
        if entry.state=='Failed'then self:_retry(entry)end
    end)
end
function Gate:_group(row,old,kind,parts,original,part)
    local instances,ids,signature,images={},{},{},{}
    -- Replication/streaming can publish a tag before every child arrives.
    -- A partial base must never replace the complete physical fallback.
    local complete=kind=='Base'and row.skin:GetAttribute('HeroExpectedBasePartCount')==15
        and #parts==15 and row.fallbackComplete or kind~='Base'and #parts==1
    local function include(prefix,id,required)
        if required and not key(id)then complete=false end
        if key(id)then ids[key(id)]=true;signature[#signature+1]=prefix..#id..':'..id end
    end
    for _,p in ipairs(parts)do
        instances[#instances+1]=p
        if row.unobservable[p]or not alpha(p:GetAttribute('HeroVisibleTransparency'))then complete=false end
        local ok,mesh,texture=pcall(function()return p.MeshId,p.TextureID end)
        if not ok then complete=false;mesh,texture=nil,nil end
        if p:GetAttribute('HeroExpectedMeshId')~=rawId(mesh)
            or p:GetAttribute('HeroExpectedTextureId')~=rawId(texture)then complete=false end
        include('M',mesh,true);include('T',texture,false)
        local surfaces={}
        for _,surface in ipairs(p:GetChildren())do if surface:IsA('SurfaceAppearance')then
            local maps={}
            for _,property in ipairs(MAPS)do
                local id=mapUri(surface,property)
                if id==nil then complete=false;id='' end
                include(property,id,false)
                maps[#maps+1]=property..#id..':'..id
                if key(id)then images[key(id)]=id end
            end
            surfaces[#surfaces+1]=table.concat(maps,'|')
        end end
        table.sort(surfaces)
        local tuples={};for _,surface in ipairs(surfaces)do tuples[#tuples+1]=#surface..':'..surface end
        if p:GetAttribute('HeroExpectedSurfaceCount')~=#surfaces
            or p:GetAttribute('HeroExpectedSurfaceMaps')~=table.concat(tuples,';')then complete=false end
    end
    table.sort(signature);local signatureKey=table.concat(signature,'|')
    if old and old.signature==signatureKey and old.kind==kind and old.original==original and old.part==part and old.complete==complete then
        old.instances,old.ids,old.images=instances,ids,images;return old
    end
    self:_unsubscribe(old)
    return {row=row,kind=kind,instances=instances,ids=ids,images=images,signature=signatureKey,complete=complete,original=original,part=part}
end
function Gate:_subscribe(group)
    if not group or not group.complete then return end
    local entry=self.cache[group.signature]
    if not entry then
        entry={signature=group.signature,state='Pending',attempts=0,waiters={}}
        self.cache[group.signature]=entry;group.entry=entry;entry.waiters[group]=true
        self:_request(entry)
    else group.entry=entry;entry.waiters[group]=true end
end
function Gate:_refresh(row)
    if not self:_valid(row)then self:_remove(row.skin);return end
    disconnect(row.assetConnections)
    local function refresh()if self.rows[row.skin]==row then self:_refresh(row)end end
    local baseParts,baseSet,targets={},{},{}
    row.unobservable={}
    for _,p in ipairs(row.skin:GetDescendants())do if p:IsA('MeshPart')then
        if row.skinSaved[p]==nil then row.skinSaved[p]=alpha(p.LocalTransparencyModifier)and p.LocalTransparencyModifier or 0 end
        connect(row.assetConnections,p:GetAttributeChangedSignal('HeroVisibleTransparency'),refresh)
        for _,attribute in ipairs({'HeroExpectedMeshId','HeroExpectedTextureId','HeroExpectedSurfaceCount','HeroExpectedSurfaceMaps'})do
            connect(row.assetConnections,p:GetAttributeChangedSignal(attribute),refresh)
        end
        for _,property in ipairs({'MeshId','TextureID'})do
            if not watchProperty(row.assetConnections,p,property,refresh)then row.unobservable[p]=true end
        end
        for _,surface in ipairs(p:GetChildren())do if surface:IsA('SurfaceAppearance')then
            for _,property in ipairs(MAPS)do
                if not watchProperty(row.assetConnections,surface,property..'Content',refresh)then row.unobservable[p]=true end
            end
        end end
        if p.Parent==row.skin then baseParts[#baseParts+1]=p;baseSet[p]=true end
    end end
    for _,reference in ipairs(row.skin:GetChildren())do
        if reference:IsA('ObjectValue')and reference.Name=='HeroFallbackTarget'then
            connect(row.assetConnections,reference:GetPropertyChangedSignal('Value'),refresh)
            local p=reference.Value
            if p and p:IsA('BasePart')then
                connect(row.assetConnections,p:GetAttributeChangedSignal('HeroFallbackOwner'),refresh)
                connect(row.assetConnections,p:GetAttributeChangedSignal('HeroFallbackTransparency'),refresh)
                if p.Parent==row.owner and p:GetAttribute('HeroFallbackOwner')==row.id and alpha(p:GetAttribute('HeroFallbackTransparency'))then
                    targets[p]=true
                    if row.fallbackSaved[p]==nil then row.fallbackSaved[p]=self:_remember(row,p)end
                end
            end
        end
    end
    for p,value in pairs(row.fallbackSaved)do if not targets[p]then self:_release(row,p,value);row.fallbackSaved[p]=nil end end
    local targetCount=0;for _ in pairs(targets)do targetCount+=1 end
    local expectedTargets=row.skin:GetAttribute('HeroExpectedFallbackCount')
    row.fallbackComplete=type(expectedTargets)=='number'and expectedTargets>=1 and expectedTargets<=32
        and expectedTargets%1==0 and targetCount==expectedTargets
    row.baseSet=baseSet
    row.base=self:_group(row,row.base,'Base',baseParts)
    -- No inactive morph subscribes or enters the base preload/signature.
    local requested=row.skin:GetAttribute('HeroActiveMorph')
    local folder=row.skin:FindFirstChild('Morphs');local active,original,part
    if folder then for _,model in ipairs(folder:GetChildren())do if model:IsA('Model')then
        connect(row.assetConnections,model:GetAttributeChangedSignal('HeroMorphKind'),refresh)
        local reference=model:FindFirstChild('HeroMorphOriginal')
        if reference and reference:IsA('ObjectValue')then
            connect(row.assetConnections,reference:GetPropertyChangedSignal('Value'),refresh)
            if requested and model:GetAttribute('HeroMorphKind')==requested and baseSet[reference.Value]then
                local found,count=nil,0
                for _,p in ipairs(model:GetChildren())do if p:IsA('MeshPart')then found=p;count+=1 end end
                if count==1 and found.Name=='Morph'then active=model;original=reference.Value;part=found end
            end
        end
    end end end
    if active then row.morph=self:_group(row,row.morph,requested,{part},original,part)
    else self:_unsubscribe(row.morph);row.morph=nil end
    self:_apply(row)
    self:_subscribe(row.base);self:_subscribe(row.morph)
    self:_apply(row)
end
function Gate:_remove(skin)
    local row=self.rows[skin];if not row then return end
    self.rows[skin]=nil;self:_unsubscribe(row.base);self:_unsubscribe(row.morph)
    disconnect(row.connections);disconnect(row.assetConnections)
    -- A retagged/reused instance belongs to its new identity immediately.
    if skin:GetAttribute('HeroSkinId')==row.id then
        for part,value in pairs(row.skinSaved)do if part.Parent and part:IsDescendantOf(skin)then localAlpha(part,value)end end
    end
    for part,value in pairs(row.fallbackSaved)do self:_release(row,part,value)end
end
function Gate:_add(skin)
    if self.destroyed or self.rows[skin]or not skin:IsA('Model')or skin:GetAttribute('CanonicalHeroSkin')~=true then return end
    local owner=skin.Parent;local id=skin:GetAttribute('HeroSkinId')
    if not owner or not owner:IsA('Model')or not identity(id)then return end
    local row={skin=skin,owner=owner,id=id,connections={},assetConnections={},skinSaved={},fallbackSaved={},baseSet={}}
    self.rows[skin]=row
    if not self:_valid(row)then self.rows[skin]=nil;return end
    local function refresh()if self.rows[skin]==row then self:_refresh(row)end end
    connect(row.connections,skin.AncestryChanged,refresh)
    for _,property in ipairs({'CanonicalHeroSkin','HeroSkinId','HeroActiveMorph','HeroExpectedBasePartCount','HeroExpectedFallbackCount'})do
        connect(row.connections,skin:GetAttributeChangedSignal(property),refresh)
    end
    for _,property in ipairs({'Appearance','HeroAppearanceOwner'})do connect(row.connections,owner:GetAttributeChangedSignal(property),refresh)end
    connect(row.connections,skin.DescendantAdded,refresh)
    connect(row.connections,skin.DescendantRemoving,function()self.defer(refresh)end)
    self:_refresh(row)
end
function Gate:_unwatch(skin)
    local candidate=self.candidates[skin];if not candidate then return end
    self.candidates[skin]=nil;disconnect(candidate.connections);disconnect(candidate.ownerConnections)
end
function Gate:_watch(skin)
    if self.destroyed or self.rows[skin]or self.candidates[skin]or not skin:IsA('Model')then return end
    -- Tags, owner attributes and child instances may replicate in separate
    -- packets. Subscribe until metadata is complete instead of dropping a tag.
    local candidate={connections={},ownerConnections={}};self.candidates[skin]=candidate
    local function resolve()
        if self.destroyed or self.candidates[skin]~=candidate then return end
        disconnect(candidate.ownerConnections)
        local owner=skin.Parent
        if owner and owner:IsA('Model')then
            for _,property in ipairs({'Appearance','HeroAppearanceOwner'})do
                connect(candidate.ownerConnections,owner:GetAttributeChangedSignal(property),candidate.resolve)
            end
        end
        self:_add(skin)
        if self.rows[skin]then self:_unwatch(skin)end
    end
    candidate.resolve=resolve
    connect(candidate.connections,skin.AncestryChanged,resolve)
    for _,property in ipairs({'CanonicalHeroSkin','HeroSkinId'})do connect(candidate.connections,skin:GetAttributeChangedSignal(property),resolve)end
    resolve()
end
function Gate.new(deps)
    deps=deps or{}
    local self=setmetatable({workspace=deps.workspace or game:GetService('Workspace'),
        collection=deps.collectionService or game:GetService('CollectionService'),provider=deps.contentProvider or game:GetService('ContentProvider'),
        newInstance=deps.newInstance or Instance.new,
        spawn=deps.spawn or task.spawn,defer=deps.defer or task.defer,delay=deps.delay or task.delay,
        success=deps.successStatus or Enum.AssetFetchStatus.Success,rows={},candidates={},cache={},connections={},baselines=setmetatable({},{__mode='k'})},Gate)
    connect(self.connections,self.collection:GetInstanceAddedSignal(TAG),function(skin)self:_watch(skin)end)
    connect(self.connections,self.collection:GetInstanceRemovedSignal(TAG),function(skin)self:_unwatch(skin);self:_remove(skin)end)
    for _,skin in ipairs(self.collection:GetTagged(TAG))do self:_watch(skin)end
    return self
end
function Gate:diagnostics()
    local out={tracked=0,pending=0,ready=0,failed=0,morphPending=0,morphReady=0,morphFailed=0,destroyed=self.destroyed==true}
    for _,row in pairs(self.rows)do
        out.tracked+=1;out[string.lower(row.state or'Pending')]+=1
        if row.morph then local state=row.morph.entry and row.morph.entry.state or'Pending';out['morph'..state]+=1 end
    end
    return out
end
function Gate:destroy()
    if self.destroyed then return end
    self.destroyed=true;disconnect(self.connections)
    local candidates={};for skin in pairs(self.candidates)do candidates[#candidates+1]=skin end
    for _,skin in ipairs(candidates)do self:_unwatch(skin)end
    local skins={};for skin in pairs(self.rows)do skins[#skins+1]=skin end
    for _,skin in ipairs(skins)do self:_remove(skin)end
    self.cache={};self.baselines={}
end
return Gate
