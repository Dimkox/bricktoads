-- APPEND this do-block to the ordinary BrickToadsClient main in owned native QA.
-- It reads the EXISTING `heroAssetVisibility` coordinator and existing heroCards.
-- No second gate, preload, asset-status API, LTM write, camera or input mutation.
-- PlayerScripts.BrickToadsReleaseHeroLoadingClientQA.Read:Invoke(
--   'summary'|'details'|'history'|'portraits'|'live') returns <=100000 bytes JSON.
-- `live` is a bounded read-only view of other canonical skins, never campaign proof.
-- Cleanup:Invoke() removes this observer and its own heartbeat/control instances.
do
    local function observeReleaseHeroLoading()
    assert(game:GetService('RunService'):IsStudio() and game:GetService('RunService'):IsClient(),'Studio client observer only')
    assert(heroAssetVisibility and heroAssetVisibility.rows,'Append after normal hero visibility initialization')
    local qaHttp=game:GetService('HttpService')
    local qaPlayer=game:GetService('Players').LocalPlayer
    local qaScripts=qaPlayer:WaitForChild('PlayerScripts')
    assert(not qaScripts:FindFirstChild('BrickToadsReleaseHeroLoadingClientQA'),'Use a fresh observer')
    local qaOwner=Instance.new('Folder'); qaOwner.Name='BrickToadsReleaseHeroLoadingClientQA'
    qaOwner:SetAttribute('ReleaseHeroLoadingObserver',true); qaOwner.Parent=qaScripts
    local qaStarted=os.clock()
    local qaConnections,qaHistory,qaLast={},{},{}
    local qaDestroyed=false
    local function qaEncode(value)
        local data=qaHttp:JSONEncode(value)
        assert(#data<=100000,'QA response exceeds 100000-byte bound')
        return data
    end
    local function qaEffective(p)
        return 1-(1-p.Transparency)*(1-p.LocalTransparencyModifier)
    end
    local function qaPart(p,details)
        local out={name=p.Name,serverAlpha=p.Transparency,localModifier=p.LocalTransparencyModifier,
            effectiveAlpha=qaEffective(p),visible=qaEffective(p)<.999}
        if details then
            out.meshId=p:IsA('MeshPart') and p.MeshId or nil
            out.textureId=p:IsA('MeshPart') and p.TextureID or nil
            out.visibleTransparency=p:GetAttribute('HeroVisibleTransparency')
            out.expectedMeshId=p:GetAttribute('HeroExpectedMeshId')
            out.expectedTextureId=p:GetAttribute('HeroExpectedTextureId')
            out.expectedSurfaceCount=p:GetAttribute('HeroExpectedSurfaceCount')
        end
        return out
    end
    local function qaGroup(group,details)
        if not group then return {state='NotActive',complete=false,attempts=0} end
        local entry=group.entry
        local out={state=entry and entry.state or 'Pending',complete=group.complete==true,
            attempts=entry and entry.attempts or 0,resourceCount=0,sourceImageCount=0,
            activeImageProxies=0,typedInvisibleUnparentedProxies=true}
        for _ in pairs(group.ids or {}) do out.resourceCount+=1 end
        for _ in pairs(group.images or {}) do out.sourceImageCount+=1 end
        if details then
            out.sourceImages={}; for _,id in pairs(group.images or {}) do out.sourceImages[#out.sourceImages+1]=id end
            table.sort(out.sourceImages)
        end
        for _,proxy in ipairs(entry and entry.proxies or {}) do
            out.activeImageProxies+=1
            out.typedInvisibleUnparentedProxies=out.typedInvisibleUnparentedProxies
                and proxy:IsA('ImageLabel') and not proxy.Visible and proxy.Parent==nil
        end
        return out
    end
    local function qaSkin(skin,row,details)
        local owner=skin.Parent
        local out={actor=owner and owner.Name or 'Removed',template=owner and owner:GetAttribute('Template'),
            skinId=skin:GetAttribute('HeroSkinId'),tracked=row~=nil,base=qaGroup(row and row.base,details),
            morph=qaGroup(row and row.morph,details),activeMorph=skin:GetAttribute('HeroActiveMorph') or 'None',
            baseCount=0,baseVisible=0,fallbackCount=0,fallbackVisible=0,morphCount=0,morphVisible=0,
            expectedBaseCount=skin:GetAttribute('HeroExpectedBasePartCount'),
            expectedFallbackCount=skin:GetAttribute('HeroExpectedFallbackCount'),sourceAlphaMetadataMatches=true,
            neutralCanonicalVisible=false,activeMorphVisible=false}
        if details then out.parts={}; out.fallback={}; out.morphs={} end
        for _,p in ipairs(skin:GetChildren()) do if p:IsA('MeshPart') then
            local info=qaPart(p,details); out.baseCount+=1
            if info.visible then out.baseVisible+=1 end
            out.sourceAlphaMetadataMatches=out.sourceAlphaMetadataMatches and p.Transparency==p:GetAttribute('HeroVisibleTransparency')
            if details then out.parts[#out.parts+1]=info end
        end end
        local targets={}
        for _,reference in ipairs(skin:GetChildren()) do
            if reference:IsA('ObjectValue') and reference.Name=='HeroFallbackTarget' then
                local p=reference.Value
                if p and p:IsA('BasePart') and not targets[p] then
                    targets[p]=true; out.fallbackCount+=1
                    local info=qaPart(p,details)
                    if info.visible then out.fallbackVisible+=1 end
                    if details then out.fallback[#out.fallback+1]=info end
                end
            end
        end
        local folder=skin:FindFirstChild('Morphs')
        if folder then for _,model in ipairs(folder:GetChildren()) do if model:IsA('Model') then
            local kind=model:GetAttribute('HeroMorphKind')
            local p=model:FindFirstChild('Morph')
            if p and p:IsA('MeshPart') then
                out.morphCount+=1; local info=qaPart(p,details)
                if info.visible then out.morphVisible+=1 end
                out.sourceAlphaMetadataMatches=out.sourceAlphaMetadataMatches and p.Transparency==p:GetAttribute('HeroVisibleTransparency')
                if kind==out.activeMorph then
                    out.activeMorphVisible=info.visible
                    local reference=model:FindFirstChild('HeroMorphOriginal')
                    local original=reference and reference:IsA('ObjectValue') and reference.Value
                    if original and original:IsA('BasePart') then
                        out.neutralCanonicalVisible=qaEffective(original)<.999
                        out.neutralCanonicalPart=original.Name
                    end
                end
                if details then info.kind=kind; out.morphs[#out.morphs+1]=info end
            end
        end end end
        local baseReady=out.base.state=='Ready'
        local morphReady=baseReady and out.morph.state=='Ready' and out.activeMorph~='None'
        out.expectedBaseVisible=baseReady and (morphReady and 14 or 15) or 0
        out.expectedFallbackVisible=baseReady and 0 or out.expectedFallbackCount
        out.visibilityContract=out.baseVisible==out.expectedBaseVisible and out.fallbackVisible==out.expectedFallbackVisible
            and out.morphVisible==(morphReady and 1 or 0)
        if baseReady and out.activeMorph~='None' then
            out.neutralMorphContract=morphReady and not out.neutralCanonicalVisible and out.activeMorphVisible
                or not morphReady and out.neutralCanonicalVisible and not out.activeMorphVisible
        end
        return out
    end
    local function qaPortraits()
        local out={count=0,expectedTemplates={'Mr. Green','Mr. Yellow','Mr. Brown'},images={}}
        for _,card in ipairs(heroCards or {}) do
            local image=card.art and card.art:FindFirstChild('ModelPortrait')
            local row={template=card.template,present=image~=nil and image:IsA('ImageLabel')}
            if row.present then
                out.count+=1; row.sourceImage=image.Image; row.isLoaded=image.IsLoaded; row.visible=image.Visible
                row.expectedSourceImage=heroPortraitAssets[card.template] and 'rbxassetid://'..heroPortraitAssets[card.template]
                row.sourceMatches=row.sourceImage==row.expectedSourceImage
                local visible=true; local ancestor=image
                while ancestor and ancestor~=qaPlayer do
                    if ancestor:IsA('GuiObject') and not ancestor.Visible then visible=false end
                    if ancestor:IsA('ScreenGui') and not ancestor.Enabled then visible=false end
                    ancestor=ancestor.Parent
                end
                row.visibleThroughAncestors=visible
                row.fallbackVisible=0
                for _,child in ipairs(card.art:GetChildren()) do
                    if child~=image and child:IsA('GuiObject') and child.Visible then row.fallbackVisible+=1 end
                end
            end
            out.images[#out.images+1]=row
        end
        return out
    end
    local function qaHeroes(details,live)
        local out={}
        local gallery=workspace:FindFirstChild('BrickToadsReleaseHeroLoadingGallery')
        if not live and gallery then
            for _,palette in ipairs({'Green','Yellow','Brown'}) do
                local actor=gallery:FindFirstChild(palette)
                if actor then for _,skin in ipairs(actor:GetChildren()) do
                    if skin:IsA('Model') and skin:GetAttribute('CanonicalHeroSkin')==true then
                        out[#out+1]=qaSkin(skin,heroAssetVisibility.rows[skin],details)
                    end
                end end
            end
        elseif live then
            local candidates={}
            for skin,row in pairs(heroAssetVisibility.rows) do
                if not gallery or not skin:IsDescendantOf(gallery) then candidates[#candidates+1]={skin=skin,row=row} end
            end
            table.sort(candidates,function(a,b)return a.skin:GetFullName()<b.skin:GetFullName()end)
            for index,candidate in ipairs(candidates) do
                if index>12 then break end
                out[#out+1]=qaSkin(candidate.skin,candidate.row,false)
            end
        end
        return out
    end
    local function qaCapture(reason)
        for _,hero in ipairs(qaHeroes(false,false)) do
            local key=hero.actor
            local signature=table.concat({hero.skinId or '',hero.base.state,hero.morph.state,hero.activeMorph,
                tostring(hero.baseVisible),tostring(hero.fallbackVisible),tostring(hero.morphVisible),
                tostring(hero.base.attempts),tostring(hero.morph.attempts),tostring(hero.base.complete),tostring(hero.morph.complete),
                tostring(hero.base.activeImageProxies),tostring(hero.morph.activeImageProxies),
                tostring(hero.neutralCanonicalVisible),tostring(hero.visibilityContract)},'|')
            if qaLast[key]~=signature then
                qaLast[key]=signature
                qaHistory[#qaHistory+1]={at=math.floor((os.clock()-qaStarted)*1000)/1000,reason=reason,
                    actor=hero.actor,skinId=hero.skinId,baseState=hero.base.state,baseComplete=hero.base.complete,
                    baseAttempts=hero.base.attempts,baseVisible=hero.baseVisible,fallbackVisible=hero.fallbackVisible,
                    activeMorph=hero.activeMorph,morphState=hero.morph.state,morphAttempts=hero.morph.attempts,
                    morphVisible=hero.morphVisible,neutralCanonicalVisible=hero.neutralCanonicalVisible,
                    visibilityContract=hero.visibilityContract,neutralMorphContract=hero.neutralMorphContract,
                    baseProxies=hero.base.activeImageProxies,morphProxies=hero.morph.activeImageProxies}
                if #qaHistory>120 then table.remove(qaHistory,1) end
            end
        end
    end
    local function qaRead(kind)
        qaCapture('Read')
        if kind=='history' then return qaEncode({scope='Observed prepared fixture transitions only',transitions=qaHistory}) end
        if kind=='portraits' then return qaEncode(qaPortraits()) end
        return qaEncode({schema=1,scope=kind=='live' and 'Read-only native canonical skins; no campaign action proof'
                or 'Three prepared loading actors; separate from actual campaign acceptance',
            diagnostic=heroAssetVisibility:diagnostics(),heroes=qaHeroes(kind=='details',kind=='live'),
            portraits=qaPortraits(),historyCount=#qaHistory,
            readinessEvidence='The ordinary coordinator fetches typed MeshParts and owned invisible ImageLabel source-map proxies',
            renderedProcessedPBRPixels='Not certified by source-image fetch success or this observer'})
    end
    local qaReadControl=Instance.new('BindableFunction'); qaReadControl.Name='Read'; qaReadControl.OnInvoke=qaRead; qaReadControl.Parent=qaOwner
    local function qaCleanup()
        if qaDestroyed then return qaEncode({status='AlreadyCleaned'}) end
        qaDestroyed=true
        for _,connection in ipairs(qaConnections) do connection:Disconnect() end
        qaOwner:Destroy()
        return qaEncode({status='Cleaned',ordinaryCoordinatorDestroyed=false})
    end
    local qaCleanupControl=Instance.new('BindableFunction'); qaCleanupControl.Name='Cleanup'; qaCleanupControl.OnInvoke=qaCleanup; qaCleanupControl.Parent=qaOwner
    -- Observe ordinary publication/intent signals as well as heartbeats. These
    -- callbacks do not delay or drive requests; a warmed morph can legitimately
    -- become Ready before an observer ever sees Pending.
    local qaObserved=setmetatable({},{__mode='k'})
    local function qaObserve(skin)
        if qaObserved[skin] or not skin:IsA('Model') then return end
        qaObserved[skin]=true
        qaConnections[#qaConnections+1]=skin:GetAttributeChangedSignal('HeroActiveMorph'):Connect(function()
            qaCapture('HeroActiveMorph')
        end)
        qaCapture('SkinPublished')
    end
    local qaCollection=game:GetService('CollectionService')
    qaConnections[#qaConnections+1]=qaCollection:GetInstanceAddedSignal('BrickToadsHeroSkin'):Connect(qaObserve)
    for _,skin in ipairs(qaCollection:GetTagged('BrickToadsHeroSkin')) do qaObserve(skin) end
    local qaElapsed=0
    qaConnections[#qaConnections+1]=game:GetService('RunService').Heartbeat:Connect(function(dt)
        qaElapsed+=dt
        if qaElapsed>=.05 then qaElapsed=0; qaCapture('Heartbeat') end
    end)
    qaConnections[#qaConnections+1]=script.Destroying:Connect(qaCleanup)
    qaCapture('Installed')
    end
    observeReleaseHeroLoading()
end
