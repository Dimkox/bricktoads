local loaded,Gate=pcall(require,'../src/client/CastAssetVisibility')
assert(loaded,'Cast visibility must be gated on the client: '..tostring(Gate))
local function signal()
    local s={listeners={}}
    function s:Connect(fn) local c={live=true};function c:Disconnect()self.live=false end;self.listeners[#self.listeners+1]={fn=fn,c=c};return c end
    function s:Fire(...)for _,row in ipairs(table.clone(self.listeners))do if row.c.live then row.fn(...)end end end
    return s
end
local N={}
N.__index=function(self,key)return N[key] or self.props[key]end
N.__newindex=function(self,key,value)
    assert(key=='LocalTransparencyModifier','Visibility gate wrote nonlocal property '..tostring(key))
    self.props[key]=value;self.writes+=1
end
local function node(kind,name,parent)
    local n=setmetatable({props={ClassName=kind,Name=name,Parent=parent,LocalTransparencyModifier=0,Transparency=.2,CanCollide=true},
        attrs={},children={},events={},writes=0,AncestryChanged=signal(),DescendantAdded=signal(),DescendantRemoving=signal()},N)
    if parent then parent.children[#parent.children+1]=n end;return n
end
function N:IsA(kind)return self.ClassName==kind or kind=='BasePart'and(self.ClassName=='Part'or self.ClassName=='MeshPart')end
function N:GetChildren()return table.clone(self.children)end
function N:GetDescendants()local out={};for _,n in ipairs(self.children)do out[#out+1]=n;for _,c in ipairs(n:GetDescendants())do out[#out+1]=c end end;return out end
function N:IsDescendantOf(owner)local p=self.Parent;while p do if p==owner then return true end;p=p.Parent end;return false end
function N:GetAttribute(key)return self.attrs[key]end
function N:GetAttributeChangedSignal(key)self.events['a'..key]=self.events['a'..key] or signal();return self.events['a'..key]end
function N:GetPropertyChangedSignal(key)self.events['p'..key]=self.events['p'..key] or signal();return self.events['p'..key]end
function N:setAttr(key,value)self.attrs[key]=value;local s=self.events['a'..key];if s then s:Fire()end end
function N:setProp(key,value)self.props[key]=value;local s=self.events['p'..key];if s then s:Fire()end end
function N:remove()
    if self.Parent then local old=self.Parent;for i,n in ipairs(old.children)do if n==self then table.remove(old.children,i);break end end;self.props.Parent=nil end
    self.AncestryChanged:Fire(self,nil)
end
local function setup(mode,initial,contract)
    local world=node('Workspace','Workspace');local jobs,timers={},{};local added,removed=signal(),signal();local tagged={}
    local collection={GetTagged=function()return table.clone(tagged)end,GetInstanceAddedSignal=function()return added end,GetInstanceRemovedSignal=function()return removed end}
    local provider={calls=0,mode=mode or 'Success'}
    function provider:PreloadAsync(parts,callback)
        self.calls+=1;assert(#parts>0)
        if self.before then self.before(parts)end
        if self.omit then return end
        for _,p in ipairs(parts)do
            assert(p:IsA('MeshPart'),'Preload must receive typed MeshParts, never raw asset strings')
            for _,id in ipairs({p.MeshId,p.TextureID})do if id and id~=''then callback(id,self.mode)end end
            for _,surface in ipairs(p:GetChildren())do if surface:IsA('SurfaceAppearance')and surface.ColorMap~=''then callback(surface.ColorMap,self.mode)end end
        end
    end
    local function actor(id,mesh)
        local course=contract=='Course'
        local owner=node('Model','Actor_'..id,world);owner:setAttr(course and 'CourseAppearance' or 'CastAppearance',course and 'CanonicalCourseVehicle' or 'CanonicalNESCast')
        local skin=node('Model','PigAppearance',owner);skin:setAttr(course and 'CanonicalCourseSkin' or 'CanonicalCastSkin',true);skin:setAttr(course and 'CourseSkinId' or 'CastSkinId',id)
        local p=node('MeshPart','Body',skin);p.props.MeshId=mesh or 'rbxassetid://101';p.props.TextureID='rbxassetid://102';p.props.LocalTransparencyModifier=.25;p:setAttr(course and 'CourseVisibleTransparency' or 'CastVisibleTransparency',.2)
        local surface=node('SurfaceAppearance','Surface',p);surface.props.ColorMap='rbxassetid://103'
        local fallback=node('Part','Torso',owner);fallback.props.LocalTransparencyModifier=.1;fallback:setAttr(course and 'CourseFallbackOwner' or 'CastFallbackOwner',id);fallback:setAttr(course and 'CourseFallbackTransparency' or 'CastFallbackTransparency',.2)
        local ref=node('ObjectValue',course and 'CourseFallbackTarget' or 'CastFallbackTarget',skin);ref.props.Value=fallback
        tagged[#tagged+1]=skin;added:Fire(skin)
        return {owner=owner,skin=skin,part=p,surface=surface,fallback=fallback,ref=ref}
    end
    local existing=initial and actor('existing')or nil
    local gate=Gate.new({workspace=world,collectionService=collection,contentProvider=provider,successStatus='Success',
        spawn=function(fn)jobs[#jobs+1]=fn end,delay=function(seconds,fn)timers[#timers+1]={seconds=seconds,fn=fn}end},contract)
    local function run()while #jobs>0 do table.remove(jobs,1)()end end
    local function retry()assert(#timers>0,'No retry scheduled');local timer=table.remove(timers,1);timer.fn();run();return timer.seconds end
    return gate,actor,run,provider,removed,world,jobs,existing,timers,retry
end
local passed=0
local function test(name,fn)fn();passed+=1;print('PASS cast visibility '..name)end
test('course vehicles use their own typed-resource and fallback contract',function()
    local g,actor,run,provider=setup('Success',nil,'Course');local a=actor('vehicle')
    assert(a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1,
        'Loading vehicle must retain its source placeholder')
    run();assert(provider.calls==1 and a.part.LocalTransparencyModifier==.25 and a.fallback.LocalTransparencyModifier==1)
    assert(a.part.Transparency==.2 and a.fallback.CanCollide)
    g:destroy();assert(a.fallback.LocalTransparencyModifier==.1)
end)
test('course contract rejects wrong owner metadata and protects a replacement fallback',function()
    local g,actor,run=setup('Success',nil,'Course');local a=actor('vehicle');run()
    a.fallback:setAttr('CourseFallbackOwner','new-vehicle');a.fallback.props.LocalTransparencyModifier=.7
    a.owner:setAttr('CourseAppearance',nil)
    assert(g:diagnostics().tracked==0 and a.fallback.LocalTransparencyModifier==.7)
    local b=actor('other');b.owner:setAttr('CourseAppearance','CanonicalNESCast');run()
    assert(g:diagnostics().tracked==0 and b.fallback.LocalTransparencyModifier==.1)
end)
test('Pending keeps fallback visible and Ready switches only local modifiers',function()
    local g,actor,run,provider=setup();local a=actor('a')
    assert(a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
    run();assert(provider.calls==1 and a.part.LocalTransparencyModifier==.25 and a.fallback.LocalTransparencyModifier==1)
    assert(a.part.Transparency==.2 and a.fallback.Transparency==.2 and a.fallback.CanCollide)
    g:destroy();assert(a.part.LocalTransparencyModifier==.25 and a.fallback.LocalTransparencyModifier==.1)
end)
test('Failed typed preload preserves fallback and never reports Ready',function()
    local g,actor,run=setup('Failure');local a=actor('a');run()
    assert(a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1 and g:diagnostics().failed==1)
end)
test('existing tagged skins are gated during startup and missing success evidence fails closed',function()
    local g,_,run,provider,_,_,_,a=setup('Success',true)
    assert(a.part.LocalTransparencyModifier==1 and g:diagnostics().pending==1)
    provider.omit=true;run()
    assert(g:diagnostics().failed==1 and a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
end)
test('identical assets share preload and all maps participate in cache signature',function()
    local g,actor,run,provider=setup();local a=actor('a');local b=actor('b');run();assert(provider.calls==1)
    assert(a.fallback.LocalTransparencyModifier==1 and b.fallback.LocalTransparencyModifier==1)
    a.surface:setProp('ColorMap','rbxassetid://104');assert(a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
    run();assert(provider.calls==2 and a.fallback.LocalTransparencyModifier==1)
    a.part:setProp('TextureID','rbxassetid://105');run();assert(provider.calls==3)
    a.part:setProp('MeshId','rbxassetid://106');run();assert(provider.calls==4)
end)
test('removing a pending skin cancels its callback and does not affect replacement',function()
    local g,actor,run,provider=setup();local old=actor('old');old.skin:remove()
    local new=actor('new','rbxassetid://201');provider.mode='Success';run()
    assert(old.fallback.LocalTransparencyModifier==.1 and new.fallback.LocalTransparencyModifier==1)
    assert(g:diagnostics().tracked==1)
end)
test('cleanup restores cleared backlinks and never writes a fallback claimed by another skin',function()
    local g,actor,run,_,removed=setup();local a=actor('a');run();a.fallback:setAttr('CastFallbackOwner',nil);removed:Fire(a.skin)
    assert(a.fallback.LocalTransparencyModifier==.1)
    local b=actor('b');run();b.fallback:setAttr('CastFallbackOwner','replacement');b.fallback.props.LocalTransparencyModifier=.6
    removed:Fire(b.skin);assert(b.fallback.LocalTransparencyModifier==.6)
end)
test('a replacement keeps shared fallback original visibility while Pending or Failed',function()
    local g,actor,run,provider=setup();local old=actor('old');run()
    local shared=old.fallback;assert(shared.LocalTransparencyModifier==1)
    local replacement=actor('replacement','rbxassetid://201')
    shared:setAttr('CastFallbackOwner','replacement')
    replacement.ref:setProp('Value',shared)
    assert(shared.LocalTransparencyModifier==.1,'New owner captured old gate hidden value as its baseline')
    provider.mode='Failure';run()
    assert(shared.LocalTransparencyModifier==.1 and replacement.part.LocalTransparencyModifier==1)
    old.skin:remove();assert(shared.LocalTransparencyModifier==.1)
    g:destroy();assert(shared.LocalTransparencyModifier==.1)
end)
test('external support needs direct reference and exact backlink',function()
    local g,actor,run,_,_,world=setup();local a=actor('a')
    local support=node('Part','SerpentSupport',world);support.props.LocalTransparencyModifier=.3;support:setAttr('CastFallbackOwner','a');support:setAttr('CastFallbackTransparency',0)
    local ref=node('ObjectValue','CastFallbackTarget',a.skin);ref.props.Value=support;a.skin.DescendantAdded:Fire(ref)
    local foreign=node('Part','OtherSupport',world);foreign:setAttr('CastFallbackOwner','other');foreign:setAttr('CastFallbackTransparency',0)
    local bad=node('ObjectValue','CastFallbackTarget',a.skin);bad.props.Value=foreign;a.skin.DescendantAdded:Fire(bad)
    run();assert(support.LocalTransparencyModifier==1 and foreign.LocalTransparencyModifier==0)
    g:destroy();assert(support.LocalTransparencyModifier==.3 and foreign.LocalTransparencyModifier==0)
end)
test('deleted or retagged objects during fetch cannot be revealed by stale completion',function()
    local g,actor,run,provider=setup();local a=actor('a')
    provider.before=function()a.skin:setAttr('CastSkinId','new-id');a.fallback:setAttr('CastFallbackOwner','new-id');a.part.props.LocalTransparencyModifier=.7 end
    run();assert(a.part.LocalTransparencyModifier==.7 and a.fallback.LocalTransparencyModifier==.1)
    g:destroy()
end)
test('destroy cancels pending callbacks and disconnects discovery',function()
    local g,actor,run=setup();local a=actor('a');g:destroy();run()
    assert(a.part.LocalTransparencyModifier==.25 and a.fallback.LocalTransparencyModifier==.1)
    local b=actor('b');assert(b.part.LocalTransparencyModifier==.25 and g:diagnostics().tracked==0)
end)
test('a transient first load failure retries once and reveals the current live skin',function()
    local g,actor,run,provider,_,_,_,_,timers,retry=setup('Failure');local a=actor('a');run()
    assert(provider.calls==1 and g:diagnostics().failed==1 and #timers==1)
    assert(a.part.LocalTransparencyModifier==1 and a.fallback.LocalTransparencyModifier==.1)
    provider.mode='Success';assert(retry()==1)
    assert(provider.calls==2 and g:diagnostics().ready==1 and #timers==0)
    assert(a.part.LocalTransparencyModifier==.25 and a.fallback.LocalTransparencyModifier==1)
end)
test('persistently missing resources receive only three spaced retries',function()
    local g,actor,run,provider,_,_,_,_,timers,retry=setup('Failure');local a=actor('a');run()
    assert(retry()==1 and retry()==3 and retry()==10)
    assert(provider.calls==4 and #timers==0 and g:diagnostics().failed==1)
    a.surface:setProp('ColorMap',a.surface.ColorMap)
    assert(provider.calls==4 and #timers==0 and a.fallback.LocalTransparencyModifier==.1)
end)
test('retry selects live waiter parts after the first skin is removed',function()
    local g,actor,run,provider,_,_,_,_,timers,retry=setup('Failure');local old=actor('old');local current=actor('current');run()
    assert(provider.calls==1 and #timers==1);old.skin:remove()
    provider.before=function(parts)for _,part in ipairs(parts)do assert(part:IsDescendantOf(current.skin),'Retry reused orphaned first-skin parts')end end
    provider.mode='Success';retry();assert(provider.calls==2 and current.fallback.LocalTransparencyModifier==1)
end)
test('removal or destruction cancels scheduled retries without playback or writes',function()
    for _,mode in ipairs({'remove','destroy'})do
        local g,actor,run,provider,_,_,_,_,timers,retry=setup('Failure');local a=actor('a');run()
        if mode=='remove'then a.skin:remove()else g:destroy()end
        local before=a.part.writes+a.fallback.writes;retry()
        assert(provider.calls==1 and #timers==0 and a.part.writes+a.fallback.writes==before,mode)
    end
end)
print(string.format('CastAssetVisibility: %d contracts passed',passed))
