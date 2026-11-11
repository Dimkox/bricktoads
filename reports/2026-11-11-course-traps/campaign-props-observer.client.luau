-- Disposable observation appended after the real client and input-only QA adapter.
do (function()
    local expected=assert(script:GetAttribute('PropsExpectedRunId'))
    local Collection=game:GetService('CollectionService')
    local report={schema=1,runId=expected,stages={},samples=0,errors={},limits={perStage=12,interval=.5},
        scope='Actual ordinary client, natural campaign streaming and production Prop visibility gate; read only'}
    local last=-math.huge
    local function alpha(p)return 1-(1-p.Transparency)*(1-p.LocalTransparencyModifier)end
    local heartbeat=RunService.Heartbeat:Connect(function()
        local now=workspace:GetServerTimeNow()
        if now-last<.5 then return end;last=now
        if not snapshot or snapshot.runId~=expected or not snapshot.level then return end
        local index=snapshot.level.campaignIndex or 1
        local stage=report.stages[tostring(index)]
        if not stage then stage={index=index,samples=0,kinds={},frames={},maxMeshes=0,maxSkins=0};report.stages[tostring(index)]=stage end
        local frame={at=now,index=index,epoch=snapshot.levelEpoch,stage=snapshot.level.stage,gate=coursePropVisibility:diagnostics(),kinds={},meshes=0,skins=0}
        for _,skin in ipairs(Collection:GetTagged('BrickToadsCoursePropSkin'))do
            if skin:IsDescendantOf(workspace)then
                local tracked=coursePropVisibility.rows[skin];local kind=skin.Name:gsub('Appearance$','')
                local row=frame.kinds[kind]or{skins=0,meshes=0,ready=0,pending=0,failed=0,visible=0,expectedVisible=0,visibleFallbacks=0}
                frame.kinds[kind]=row;row.skins+=1;frame.skins+=1
                local state=tracked and tracked.state or'Pending';local key=string.lower(state);row[key]=(row[key]or 0)+1
                for _,p in ipairs(skin:GetDescendants())do if p:IsA('MeshPart')then
                    row.meshes+=1;frame.meshes+=1;if p.Transparency<.99 then row.expectedVisible+=1 end
                    if alpha(p)<.99 then row.visible+=1 end
                end end
                for _,ref in ipairs(skin:GetChildren())do
                    if ref:IsA('ObjectValue')and ref.Name=='CoursePropFallbackTarget'and ref.Value
                        and ref.Value:GetAttribute('CoursePropFallbackOwner')==skin:GetAttribute('CoursePropSkinId')then
                        if alpha(ref.Value)<.99 then row.visibleFallbacks+=1 end
                    end
                end
            end
        end
        stage.samples+=1;report.samples+=1;stage.maxMeshes=math.max(stage.maxMeshes,frame.meshes);stage.maxSkins=math.max(stage.maxSkins,frame.skins)
        for kind,row in pairs(frame.kinds)do
            local k=stage.kinds[kind]or{observations=0,maxReady=0,maxPending=0,maxFailed=0,maxVisible=0,maxMeshes=0,readySamples=0}
            stage.kinds[kind]=k;k.observations+=1;k.maxReady=math.max(k.maxReady,row.ready);k.maxPending=math.max(k.maxPending,row.pending)
            k.maxFailed=math.max(k.maxFailed,row.failed);k.maxVisible=math.max(k.maxVisible,row.visible);k.maxMeshes=math.max(k.maxMeshes,row.meshes)
            if row.ready==row.skins then
                k.readySamples+=1
                if(row.visible<row.expectedVisible or row.visibleFallbacks>0)and #report.errors<32 then
                    report.errors[#report.errors+1]={index=index,kind=kind,at=now,row=row}
                end
            end
        end
        if #stage.frames>=12 then table.remove(stage.frames,1)end;stage.frames[#stage.frames+1]=frame
    end)
    local read=Instance.new('BindableFunction');read.Name='BrickToadsCampaignPropsRead'
    read.OnInvoke=function()return game:GetService('HttpService'):JSONEncode(report)end
    read.Parent=game.Players.LocalPlayer.PlayerScripts
    script.Destroying:Connect(function()heartbeat:Disconnect();read:Destroy()end)
end)()end
