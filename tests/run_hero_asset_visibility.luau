local Gate=require('../src/client/HeroAssetVisibility')
-- Instance/event doubles exercise production lifecycle and typed preload requests;
-- they do not simulate Roblox renderer, network replication, or content hosting.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={live=true};function c:Disconnect()self.live=false end;self.listeners[#self.listeners+1]={fn=fn,c=c};return c end
    function s:Fire(...)for _,r in ipairs(table.clone(self.listeners))do if r.c.live then r.fn(...)end end end
    return s
end
local MAPS={'ColorMap','NormalMap','RoughnessMap','MetalnessMap','EmissiveMask'}
local LEGACY_MAPS={ColorMap=true,NormalMap=true,RoughnessMap=true,MetalnessMap=true,EmissiveMask=true}
local function fixtureContent(id)
    return type(id)=='string'and id~=''and{SourceType={Name='Uri'},Uri=id}or{SourceType={Name='None'}}
end
local N={}
N.__index=function(self,k)
    if self.props.ClassName=='SurfaceAppearance'and(LEGACY_MAPS[k]or self.props.deniedRead==k)then
        error('current thread cannot read '..k..' (lacking capability Plugin)')
    end
    return N[k]or self.props[k]
end
N.__newindex=function(self,k,v)
    assert(k=='LocalTransparencyModifier'or self.ClassName=='ImageLabel'and(k=='Visible'or k=='Image'),
        'Hero gate wrote a nonlocal property: '..tostring(k))
    self.props[k]=v;self.writes+=1
end
local function node(kind,name,parent)
    local n=setmetatable({props={ClassName=kind,Name=name,Parent=parent,LocalTransparencyModifier=0,Transparency=.36,CanCollide=true},
        attrs={},children={},events={},writes=0,AncestryChanged=signal(),DescendantAdded=signal(),DescendantRemoving=signal()},N)
    if parent then parent.children[#parent.children+1]=n end;return n
end
function N:IsA(k)return self.ClassName==k or k=='BasePart'and(self.ClassName=='Part'or self.ClassName=='MeshPart')end
function N:GetChildren()return table.clone(self.children)end
function N:GetDescendants()local out={};for _,n in ipairs(self.children)do out[#out+1]=n;for _,c in ipairs(n:GetDescendants())do out[#out+1]=c end end;return out end
function N:FindFirstChild(name)for _,n in ipairs(self.children)do if n.Name==name then return n end end end
function N:IsDescendantOf(owner)local p=self.Parent;while p do if p==owner then return true end;p=p.Parent end;return false end
function N:GetAttribute(k)return self.attrs[k]end
function N:GetAttributeChangedSignal(k)self.events['a'..k]=self.events['a'..k]or signal();return self.events['a'..k]end
function N:GetPropertyChangedSignal(k)
    if self.ClassName=='SurfaceAppearance'and(LEGACY_MAPS[k]or self.props.deniedWatch==k)then error('cannot observe '..k..' (lacking capability Plugin)')end
    self.events['p'..k]=self.events['p'..k]or signal();return self.events['p'..k]
end
function N:setAttr(k,v)self.attrs[k]=v;local s=self.events['a'..k];if s then s:Fire()end end
function N:setProp(k,v)self.props[k]=v;local s=self.events['p'..k];if s then s:Fire()end end
function N:setMap(k,id)self:setProp(k..'Content',fixtureContent(id))end
function N:remove()
    if self.Parent then for i,n in ipairs(self.Parent.children)do if n==self then table.remove(self.Parent.children,i);break end end;self.props.Parent=nil end
    self.AncestryChanged:Fire(self,nil)
end
function N:Destroy()self.props.destroyed=true;self:remove()end
local function mapId(surface,property)return surface[property..'Content'].Uri or''end
local function declareExpected(part)
    local surfaces={}
    for _,surface in ipairs(part:GetChildren())do if surface:IsA('SurfaceAppearance')then
        local maps={}
        for _,property in ipairs(MAPS)do local id=mapId(surface,property);maps[#maps+1]=property..#id..':'..id end
        surfaces[#surfaces+1]=table.concat(maps,'|')
    end end
    table.sort(surfaces)
    local tuples={};for _,surface in ipairs(surfaces)do tuples[#tuples+1]=#surface..':'..surface end
    part:setAttr('HeroExpectedSurfaceCount',#surfaces);part:setAttr('HeroExpectedSurfaceMaps',table.concat(tuples,';'))
    part:setAttr('HeroExpectedMeshId',part.MeshId or'');part:setAttr('HeroExpectedTextureId',part.TextureID or'')
end
local function setup(initial)
    local world=node('Workspace','Workspace');local jobs,timers={},{};local added,removed=signal(),signal();local tagged={}
    local collection={GetTagged=function()return table.clone(tagged)end,GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
    local provider={calls=0,mode='Success',requests={},proxies={}}
    function provider:PreloadAsync(instances,callback)
        self.calls+=1;local captured={};self.requests[#self.requests+1]=captured;local status=self.mode
        for _,n in ipairs(instances)do
            assert(n:IsA('MeshPart')or n:IsA('SurfaceAppearance')or n:IsA('ImageLabel'),'Preload must receive typed content instances')
            captured[#captured+1]=n
        end
        if self.before then self.before(instances)end
        for _,n in ipairs(instances)do
            -- Match the real platform: SurfaceAppearance is unsupported and
            -- provides no callbacks. Invisible ImageLabel proxies do preload.
            local props=n:IsA('MeshPart')and{'MeshId','TextureID'}or n:IsA('ImageLabel')and{'Image'}or{}
            for _,prop in ipairs(props)do local id=n[prop];if id and id~=''and id~=self.omit then callback(id,status)end end
        end
        if self.raise then error('content service unavailable')end
    end
    local function mesh(name,parent,id)
        local p=node('MeshPart',name,parent);p.props.MeshId='rbxassetid://'..id;p.props.TextureID='rbxassetid://'..(id+1)
        p.props.LocalTransparencyModifier=.2;p:setAttr('HeroVisibleTransparency',.36)
        local s=node('SurfaceAppearance','Surface',p)
        for i,prop in ipairs(MAPS)do s.props[prop..'Content']=fixtureContent('rbxassetid://'..(id+1+i))end
        declareExpected(p)
        return p,s
    end
    local function actor(id,owner,shared)
        owner=owner or node('Model','Actor_'..id,world);owner:setAttr('Appearance','CanonicalNESHero');owner:setAttr('HeroAppearanceOwner',id)
        local skin=node('Model','HeroSkin',owner);skin:setAttr('CanonicalHeroSkin',true);skin:setAttr('HeroSkinId',id)
        skin:setAttr('HeroExpectedBasePartCount',15);skin:setAttr('HeroExpectedFallbackCount',1)
        local parts={};local headSurface
        for i,name in ipairs({'LowerTorso','UpperTorso','Head','LeftUpperArm','LeftLowerArm','LeftHand','RightUpperArm','RightLowerArm','RightHand','LeftUpperLeg','LeftLowerLeg','LeftFoot','RightUpperLeg','RightLowerLeg','RightFoot'})do
            local p,s=mesh(name,skin,100+i*10);parts[name]=p;if name=='Head'then headSurface=s end
        end
        local fallback=shared or node('Part','Torso',owner);if not shared then fallback.props.LocalTransparencyModifier=.1 end
        fallback:setAttr('HeroFallbackOwner',id);fallback:setAttr('HeroFallbackTransparency',.36)
        local ref=node('ObjectValue','HeroFallbackTarget',skin);ref.props.Value=fallback
        local folder=node('Folder','Morphs',skin);local morphs={}
        for i,kind in ipairs({'PowerFist','BigBoot','FearBeforeCut','FearAfterCut'})do
            local m=node('Model',kind,folder);m:setAttr('HeroMorphKind',kind)
            local p,s=mesh('Morph',m,1000+i*10);p.props.LocalTransparencyModifier=.35
            local target=node('ObjectValue','HeroMorphOriginal',m);target.props.Value=parts[kind=='PowerFist'and'RightHand'or kind=='BigBoot'and'RightFoot'or'Head']
            morphs[kind]={model=m,part=p,surface=s,target=target}
        end
        tagged[#tagged+1]=skin;added:Fire(skin)
        return {skin=skin,owner=owner,parts=parts,fallback=fallback,morphs=morphs,surface=headSurface,ref=ref}
    end
    local existing=initial and actor('existing')or nil
    if initial=='DelayedMetadata'then existing.owner:setAttr('HeroAppearanceOwner',nil)end
    local gate=Gate.new({workspace=world,collectionService=collection,contentProvider=provider,successStatus='Success',
        newInstance=function(class)
            assert(class=='ImageLabel')
            if provider.factoryFailAt==#provider.proxies+1 then error('proxy allocation failed')end
            local proxy=node(class,'PreloadMap');provider.proxies[#provider.proxies+1]=proxy;return proxy
        end,
        spawn=function(fn)jobs[#jobs+1]=fn end,defer=function(fn)jobs[#jobs+1]=fn end,
        delay=function(seconds,fn)timers[#timers+1]={seconds=seconds,fn=fn}end})
    local function run()while #jobs>0 do table.remove(jobs,1)()end end
    local function retry()assert(#timers>0,'Expected bounded retry');local t=table.remove(timers,1);t.fn();run();return t.seconds end
    return gate,actor,run,provider,removed,timers,retry,existing
end
local passed,failed=0,0
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed+=1;print('PASS hero visibility '..name)
    else failed+=1;print('FAIL hero visibility '..name..': '..tostring(err))end
end
local function inactive(a)for _,m in pairs(a.morphs)do assert(m.part.LocalTransparencyModifier==1,'Unused morph must remain hidden')end end
local function proxiesDestroyed(provider)
    assert(#provider.proxies>0,'No typed image proxies were created')
    for _,proxy in ipairs(provider.proxies)do assert(proxy.destroyed,'Request leaked an owned image proxy')end
end
test('normal runtime can load hero PBR without legacy PluginSecurity reads or signals',function()
    local g,actor,run,p=setup()
    local ok,a=pcall(actor,'normal-security')
    assert(ok,'Normal-script hero discovery accessed a PluginSecurity property: '..tostring(a))
    assert(a.parts.Head.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
    local unused=mapId(a.surface,'EmissiveMask');a.surface:setMap('EmissiveMask','');declareExpected(a.parts.Head)
    run();assert(g:diagnostics().ready==1 and p.calls==1 and a.fallback.LocalTransparencyModifier==1)
    for _,proxy in ipairs(p.proxies)do assert(proxy.Image~=unused,'Declared Content.none must not request a map')end
end)
test('an unreadable optional modern map never delays the base or hides an available neutral limb',function()
    local g,actor,run,p=setup();local a=actor('unreadable-morph');local morph=a.morphs.PowerFist
    morph.surface.props.deniedRead='ColorMapContent';run();assert(p.calls==1 and g:diagnostics().ready==1)
    a.skin:setAttr('HeroActiveMorph','PowerFist');run()
    assert(p.calls==1 and g:diagnostics().morphPending==1 and a.parts.RightHand.LocalTransparencyModifier==.2)
    morph.surface.props.deniedRead=nil;a.skin.DescendantAdded:Fire(morph.surface);run()
    assert(p.calls==2 and g:diagnostics().morphReady==1 and a.parts.RightHand.LocalTransparencyModifier==1)
end)
test('unreadable or unobservable modern map properties keep the physical fallback visible',function()
    for _,failure in ipairs({'deniedRead','deniedWatch'})do
        local g,actor,run,p=setup();local a=actor(failure)
        a.surface.props[failure]='ColorMapContent';a.skin.DescendantAdded:Fire(a.surface);run()
        assert(p.calls==0 and g:diagnostics().pending==1 and a.fallback.LocalTransparencyModifier==.1,failure)
        assert(a.parts.Head.LocalTransparencyModifier==1,'Unreadable canonical art must remain locally hidden')
        a.surface.props[failure]=nil;a.skin.DescendantAdded:Fire(a.surface);run()
        assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
    end
end)
test('object-backed PBR content is not mistaken for an empty published source URI',function()
    local g,actor,run,p=setup();local a=actor('object-content')
    local required=mapId(a.surface,'NormalMap')
    a.surface:setProp('NormalMapContent',{SourceType={Name='Object'},Object={}});run()
    assert(p.calls==0 and g:diagnostics().pending==1 and a.fallback.LocalTransparencyModifier==.1)
    a.surface:setMap('NormalMap',required);run();assert(g:diagnostics().ready==1)
end)
test('delayed SurfaceAppearance children keep complete base meshes behind the physical fallback',function()
    local g,actor,run,p=setup();local a=actor('delayed-surfaces');local surfaces={}
    for _,part in pairs(a.parts)do local surface=part:FindFirstChild('Surface');surfaces[part]=surface;surface:remove()end
    a.skin.DescendantRemoving:Fire();run()
    assert(g:diagnostics().pending==1 and p.calls==0 and a.fallback.LocalTransparencyModifier==.1,
        'Missing declared PBR children prematurely replaced the physical body')
    for part,surface in pairs(surfaces)do surface.props.Parent=part;part.children[#part.children+1]=surface;a.skin.DescendantAdded:Fire(surface)end
    run();assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('missing base PBR map value stays Pending until its declared exact map arrives and succeeds',function()
    local g,actor,run,p,_,_,retry=setup();local a=actor('delayed-map');local required=mapId(a.surface,'NormalMap')
    a.surface:setMap('NormalMap','');run()
    assert(g:diagnostics().pending==1 and p.calls==0 and a.fallback.LocalTransparencyModifier==.1,
        'Missing declared source map prematurely replaced the physical body')
    a.surface:setMap('NormalMap',required);p.mode='Failure';run()
    assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1)
    p.mode='Success';retry();assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('first active morph waits for its declared SurfaceAppearance and exact map while retaining neutral geometry',function()
    local g,actor,run,p=setup();local a=actor('delayed-morph-surface');run()
    local morph=a.morphs.PowerFist;local required=mapId(morph.surface,'ColorMap');morph.surface:remove()
    a.skin.DescendantRemoving:Fire();a.skin:setAttr('HeroActiveMorph','PowerFist');run()
    assert(p.calls==1 and g:diagnostics().morphPending==1 and a.parts.RightHand.LocalTransparencyModifier==.2,
        'A streamed morph without its PBR child hid the available neutral limb')
    morph.surface.props.Parent=morph.part;morph.part.children[#morph.part.children+1]=morph.surface
    morph.surface.props.ColorMapContent=fixtureContent('');a.skin.DescendantAdded:Fire(morph.surface);run()
    assert(p.calls==1 and a.parts.RightHand.LocalTransparencyModifier==.2)
    morph.surface:setMap('ColorMap',required);run()
    assert(g:diagnostics().morphReady==1 and a.parts.RightHand.LocalTransparencyModifier==1)
end)
test('late expected resource attributes cannot be inferred from partial observed children',function()
    local g,actor,run,p=setup();local a=actor('delayed-expectations');local part=a.parts.Head
    local expected=part:GetAttribute('HeroExpectedSurfaceMaps');part:setAttr('HeroExpectedSurfaceCount',nil);part:setAttr('HeroExpectedSurfaceMaps',nil)
    run();assert(g:diagnostics().pending==1 and p.calls==0 and a.fallback.LocalTransparencyModifier==.1)
    part:setAttr('HeroExpectedSurfaceCount',1);run();assert(p.calls==0,'Map identity metadata has not arrived')
    part:setAttr('HeroExpectedSurfaceMaps',expected);run()
    assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('explicit zero-surface resources load without waiting for nonexistent PBR children',function()
    local g,actor,run,p=setup();local a=actor('zero-surfaces')
    for _,part in pairs(a.parts)do part:FindFirstChild('Surface'):remove();declareExpected(part)end
    local morph=a.morphs.PowerFist;morph.surface:remove();declareExpected(morph.part)
    a.skin.DescendantRemoving:Fire();run()
    assert(g:diagnostics().ready==1 and p.calls==1 and #p.proxies==0 and a.fallback.LocalTransparencyModifier==1)
    a.skin:setAttr('HeroActiveMorph','PowerFist');run()
    assert(g:diagnostics().morphReady==1 and p.calls==2 and #p.proxies==0 and a.parts.RightHand.LocalTransparencyModifier==1)
end)
test('exact mesh and texture links must match declared resources before any fetch or replacement',function()
    for _,property in ipairs({'MeshId','TextureID'})do
        local g,actor,run,p=setup();local a=actor(property);local part=a.parts.Head;local expected=part[property]
        part:setProp(property,'rbxassetid://555555');run()
        assert(p.calls==0 and g:diagnostics().pending==1 and a.fallback.LocalTransparencyModifier==.1,property)
        part:setProp(property,expected);run();assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
    end
end)
test('late active morph expectation metadata retains the canonical neutral limb until complete',function()
    local g,actor,run,p=setup();local a=actor('late-morph-metadata');run()
    local part=a.morphs.BigBoot.part;local expected=part:GetAttribute('HeroExpectedSurfaceMaps')
    part:setAttr('HeroExpectedSurfaceMaps',nil);a.skin:setAttr('HeroActiveMorph','BigBoot');run()
    assert(p.calls==1 and g:diagnostics().morphPending==1 and a.parts.RightFoot.LocalTransparencyModifier==.2)
    part:setAttr('HeroExpectedSurfaceMaps',expected);run()
    assert(p.calls==2 and g:diagnostics().morphReady==1 and a.parts.RightFoot.LocalTransparencyModifier==1)
end)
test('PBR hero becomes Ready when SurfaceAppearance preload is unsupported by the real engine',function()
    local g,actor,run,p=setup();local a=actor('platform');run()
    assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1,
        'SurfaceAppearance produces no preload callbacks; direct typed image requests are required')
    local maps={}
    for _,instance in ipairs(p.requests[1])do
        assert(not instance:IsA('SurfaceAppearance'),'Unsupported SurfaceAppearance was sent to PreloadAsync')
        if instance:IsA('ImageLabel')then
            assert(instance.Visible==false and instance.Parent==nil,'Map proxies must never become visible')
            assert(not maps[instance.Image],'Referenced map images must be deduplicated');maps[instance.Image]=true
        end
    end
    for _,property in ipairs(MAPS)do assert(maps[mapId(a.surface,property)],'A referenced PBR map was not warmed')end
    proxiesDestroyed(p)
end)
test('base delay and failure retain physical fallback and never request unused morph resources',function()
    local g,actor,run,p=setup();local a=actor('base')
    assert(a.fallback.LocalTransparencyModifier==.1 and a.parts.Head.LocalTransparencyModifier==1);inactive(a)
    p.mode='Failure';run()
    assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1 and a.parts.Head.LocalTransparencyModifier==1)
    assert(p.calls==1)
    local inactiveImages={}
    for _,morph in pairs(a.morphs)do for _,property in ipairs(MAPS)do inactiveImages[mapId(morph.surface,property)]=true end end
    for _,n in ipairs(p.requests[1])do
        assert(not n:IsDescendantOf(a.skin.Morphs),'Inactive large morph textures blocked the base')
        if n:IsA('ImageLabel')then assert(not inactiveImages[n.Image],'Unused morph image was requested through a proxy')end
    end
    proxiesDestroyed(p)
    assert(a.fallback.Transparency==.36 and a.fallback.CanCollide)
end)
test('shared PBR image IDs create one owned invisible proxy per unique image',function()
    local g,actor,run,p=setup();local a=actor('deduplicated')
    for _,part in pairs(a.parts)do
        for i,property in ipairs(MAPS)do part:FindFirstChild('Surface'):setMap(property,'rbxassetid://'..(9000+i))end
        declareExpected(part)
    end
    run();assert(g:diagnostics().ready==1 and p.calls==1 and #p.proxies==5,'Repeated atlas maps must not allocate per-part proxies')
    proxiesDestroyed(p)
end)
test('owned image proxies are released on failure exception and partial allocation failure',function()
    for _,failure in ipairs({'Status','ProviderException','AllocationException'})do
        local g,actor,run,p=setup();local a=actor(failure)
        if failure=='Status'then p.mode='Failure'elseif failure=='ProviderException'then p.raise=true else p.factoryFailAt=2 end
        run();assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1,failure)
        proxiesDestroyed(p)
    end
end)
test('removal and destruction release in-flight proxies immediately before stale completion',function()
    for _,cancel in ipairs({'Remove','Destroy'})do
        local g,actor,run,p=setup();local a=actor(cancel)
        p.before=function()
            if cancel=='Remove'then a.skin:remove()else g:destroy()end
            proxiesDestroyed(p)
        end
        run();assert(g:diagnostics().tracked==0 and a.fallback.LocalTransparencyModifier==.1 and p.calls==1,cancel)
        proxiesDestroyed(p)
    end
end)
test('one removed subscriber cannot destroy image proxies still serving a live hero',function()
    local g,actor,run,p=setup();local old=actor('old-shared');local current=actor('current-shared')
    p.before=function()
        old.skin:remove()
        assert(#p.proxies>0)
        for _,proxy in ipairs(p.proxies)do assert(not proxy.destroyed,'Shared live request lost its image proxies')end
    end
    run();assert(p.calls==1 and g:diagnostics().ready==1 and current.fallback.LocalTransparencyModifier==1)
    proxiesDestroyed(p)
end)
test('base success requires typed evidence for mesh texture and all five possible PBR maps',function()
    local g,actor,run,p,_,_,retry=setup();local a=actor('maps');p.omit=mapId(a.surface,'NormalMap');run()
    assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1,'Missing NormalMap success must fail closed')
    p.omit=nil;retry()
    assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1 and a.parts.Head.LocalTransparencyModifier==.2)
    inactive(a);assert(a.parts.Head.Transparency==.36)
end)
test('every declared PBR map must report success before a base can replace its physical body',function()
    for _,property in ipairs(MAPS)do
        local g,actor,run,p=setup();local a=actor(property);p.omit=mapId(a.surface,property);run()
        assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1,property..' was not required')
    end
end)
test('a streamed partial base never hides physical fallback until all fifteen parts arrive',function()
    local g,actor,run,p=setup();local a=actor('partial');a.parts.LeftFoot:remove();a.skin.DescendantRemoving:Fire();run()
    assert(p.calls==0 and g:diagnostics().pending==1 and a.fallback.LocalTransparencyModifier==.1,'Partial skin cannot replace the complete physical body')
end)
test('missing streamed fallback references prevent readiness until all declared targets arrive',function()
    local g,actor,run,p=setup();local a=actor('missing-reference');a.ref:setProp('Value',nil);run()
    assert(g:diagnostics().pending==1 and p.calls==0 and a.parts.Head.LocalTransparencyModifier==1,'Unresolved fallback references cannot be Ready')
    a.ref:setProp('Value',a.fallback);run()
    assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('already tagged heroes are gated on coordinator startup',function()
    local g,_,run,p,_,_,_,a=setup(true)
    assert(g:diagnostics().pending==1 and a.parts.Head.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
    run();assert(p.calls==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('metadata arriving after a replicated tag still starts readiness without another tag event',function()
    local g,_,run,p,_,_,_,a=setup('DelayedMetadata')
    assert(p.calls==0 and a.fallback.LocalTransparencyModifier==.1)
    a.owner:setAttr('HeroAppearanceOwner','existing')
    assert(a.parts.Head.LocalTransparencyModifier==1,'Late owner metadata was never discovered')
    run();assert(g:diagnostics().ready==1 and a.fallback.LocalTransparencyModifier==1)
end)
test('first attack failure retains available neutral hand then retry replaces it atomically',function()
    local g,actor,run,p,_,_,retry=setup();local a=actor('first-attack');run();a.skin:setAttr('HeroActiveMorph','PowerFist')
    assert(a.parts.RightHand.LocalTransparencyModifier==.2 and a.morphs.PowerFist.part.LocalTransparencyModifier==1)
    p.mode='Failure';run()
    assert(a.parts.RightHand.LocalTransparencyModifier==.2 and g:diagnostics().morphFailed==1)
    p.mode='Success';retry()
    assert(a.parts.RightHand.LocalTransparencyModifier==1 and a.morphs.PowerFist.part.LocalTransparencyModifier==.35)
    assert(a.parts.LeftHand.LocalTransparencyModifier==.2 and a.fallback.LocalTransparencyModifier==1)
    a.skin:setAttr('HeroActiveMorph',nil);inactive(a);assert(a.parts.RightHand.LocalTransparencyModifier==.2)
    assert(a.parts.RightHand.Transparency==.36)
end)
test('both first fear forms retain the neutral head while unavailable and never overlap',function()
    local g,actor,run,p=setup();local a=actor('fear');run()
    a.skin:setAttr('HeroActiveMorph','FearBeforeCut');p.mode='Failure';run()
    assert(a.parts.Head.LocalTransparencyModifier==.2);inactive(a)
    a.skin:setAttr('HeroActiveMorph','FearAfterCut');p.mode='Success';run()
    assert(a.parts.Head.LocalTransparencyModifier==1 and a.morphs.FearAfterCut.part.LocalTransparencyModifier==.35)
    assert(a.morphs.FearBeforeCut.part.LocalTransparencyModifier==1)
    a.skin:setAttr('HeroActiveMorph','FearBeforeCut')
    assert(a.parts.Head.LocalTransparencyModifier==.2 and a.morphs.FearAfterCut.part.LocalTransparencyModifier==1)
    run();assert(a.parts.Head.LocalTransparencyModifier==1 and a.morphs.FearBeforeCut.part.LocalTransparencyModifier==.35)
end)
test('interrupted morph completion and retry cannot hide the available neutral limb',function()
    local g,actor,run,p,_,timers,retry=setup();local a=actor('interrupted');run()
    a.skin:setAttr('HeroActiveMorph','PowerFist')
    p.before=function()a.skin:setAttr('HeroActiveMorph',nil)end;run()
    assert(a.parts.RightHand.LocalTransparencyModifier==.2);inactive(a)
    p.before=nil;p.mode='Failure';a.skin:setAttr('HeroActiveMorph','BigBoot');run();assert(#timers==1)
    a.skin:setAttr('HeroActiveMorph',nil);local before=p.calls;retry()
    assert(p.calls==before and a.parts.RightFoot.LocalTransparencyModifier==.2);inactive(a)
end)
test('resource replacement during fetch ignores stale success and waits for exact replacement expectation',function()
    local g,actor,run,p=setup();local a=actor('replacement')
    p.before=function()p.before=nil;a.surface:setMap('MetalnessMap','rbxassetid://99999');p.mode='Failure'end
    run();assert(g:diagnostics().pending==1 and p.calls==1 and a.fallback.LocalTransparencyModifier==.1 and a.parts.Head.LocalTransparencyModifier==1)
    declareExpected(a.parts.Head);run()
    assert(g:diagnostics().failed==1 and a.fallback.LocalTransparencyModifier==.1)
    assert(p.calls==2,'Replacement must issue its own typed resource request')
end)
test('a missing morph target and removed active geometry leave neutral geometry available',function()
    local g,actor,run=setup();local a=actor('invalid');run()
    a.morphs.PowerFist.target:setProp('Value',nil);a.skin:setAttr('HeroActiveMorph','PowerFist');run()
    assert(a.parts.RightHand.LocalTransparencyModifier==.2);inactive(a)
    a.skin:setAttr('HeroActiveMorph','BigBoot');run();assert(a.parts.RightFoot.LocalTransparencyModifier==1)
    a.morphs.BigBoot.part:remove();a.skin.DescendantRemoving:Fire();run()
    assert(a.parts.RightFoot.LocalTransparencyModifier==.2)
end)
test('same-body replacement preserves physical baseline and old cleanup never controls new owner',function()
    local g,actor,run,p,removed=setup();local old=actor('old');run();assert(old.fallback.LocalTransparencyModifier==1)
    local current=actor('new',old.owner,old.fallback);current.surface:setMap('ColorMap','rbxassetid://77777');declareExpected(current.parts.Head);p.mode='Failure';run()
    assert(current.fallback.LocalTransparencyModifier==.1 and current.parts.Head.LocalTransparencyModifier==1)
    current.fallback.props.LocalTransparencyModifier=.66;removed:Fire(old.skin)
    assert(current.fallback.LocalTransparencyModifier==.66,'Old skin cleanup changed the replacement body')
    current.fallback:setAttr('HeroFallbackOwner','next-owner');current.fallback.props.LocalTransparencyModifier=.7
    g:destroy();assert(current.fallback.LocalTransparencyModifier==.7)
end)
test('backlink-first handoff retains the pre-gate physical baseline for the incoming skin',function()
    local g,actor,run,p,removed=setup();local old=actor('first');run();local shared=old.fallback
    shared:setAttr('HeroFallbackOwner','incoming');assert(shared.LocalTransparencyModifier==1)
    local current=actor('incoming',old.owner,shared);current.surface:setMap('ColorMap','rbxassetid://77778');declareExpected(current.parts.Head);p.mode='Failure';run()
    assert(shared.LocalTransparencyModifier==.1,'Incoming skin captured outgoing hidden alpha')
    removed:Fire(old.skin);assert(shared.LocalTransparencyModifier==.1)
end)
test('pending skin replacement and gate destruction cancel completions and restore local alpha',function()
    local g,actor,run,p=setup();local old=actor('old');old.skin:remove();local current=actor('current');run()
    assert(p.calls==1 and current.fallback.LocalTransparencyModifier==1 and old.fallback.LocalTransparencyModifier==.1)
    current.skin:setAttr('HeroActiveMorph','PowerFist');g:destroy();run()
    assert(current.parts.Head.LocalTransparencyModifier==.2 and current.parts.RightHand.LocalTransparencyModifier==.2)
    assert(current.fallback.LocalTransparencyModifier==.1 and current.morphs.PowerFist.part.LocalTransparencyModifier==.35)
    assert(g:diagnostics().destroyed and g:diagnostics().tracked==0)
    local later=actor('later');assert(later.parts.Head.LocalTransparencyModifier==.2)
end)
test('retagging the same skin cannot restore alpha over a newer identity',function()
    local g,actor,run,p=setup();local a=actor('identity')
    p.before=function()a.skin:setAttr('HeroSkinId','replacement');a.parts.Head.props.LocalTransparencyModifier=.8 end
    run();assert(a.parts.Head.LocalTransparencyModifier==.8 and a.fallback.LocalTransparencyModifier==.1)
    g:destroy();assert(a.parts.Head.LocalTransparencyModifier==.8)
end)
test('four failed attempts exhaust retries and exceptions retain physical fallback',function()
    local g,actor,run,p,_,timers,retry=setup();local a=actor('retry');p.raise=true;run()
    assert(retry()==1 and retry()==3 and retry()==10 and p.calls==4 and #timers==0)
    assert(a.fallback.LocalTransparencyModifier==.1 and g:diagnostics().failed==1)
end)
print('HeroAssetVisibility: '..passed..' contracts passed')
assert(failed==0,tostring(failed)..' hero visibility contracts failed')
