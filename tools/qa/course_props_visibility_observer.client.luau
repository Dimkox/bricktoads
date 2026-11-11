-- Append to the disposable client. Observe the production gate; do not preload
-- resources, change visibility/camera or send player input.
do (function()
    assert(game:GetService('RunService'):IsStudio(),'Studio QA only')
    local endpoint=Instance.new('BindableFunction');endpoint.Name='BrickToadsCoursePropsVisibilityRead'
    local function alpha(p)return 1-(1-p.Transparency)*(1-p.LocalTransparencyModifier)end
    endpoint.OnInvoke=function()
        local gallery=workspace:FindFirstChild('BrickToadsCoursePropsGallery')
        local rows={}
        if gallery then for _,skin in ipairs(game:GetService('CollectionService'):GetTagged('BrickToadsCoursePropSkin'))do
            if skin:IsDescendantOf(gallery)then
                local tracked=coursePropVisibility.rows[skin]
                local row={kind=skin.Name:gsub('Appearance$',''),state=tracked and tracked.state or'Untracked',
                    meshes=0,visibleMeshes=0,fallbacks=0,visibleFallbacks=0,motion={}}
                for _,p in ipairs(skin:GetDescendants())do if p:IsA('MeshPart')then
                    row.meshes+=1;if alpha(p)<.99 then row.visibleMeshes+=1 end
                    if p:GetAttribute('MotionKind')then row.motion[#row.motion+1]={name=p.Name,kind=p:GetAttribute('MotionKind'),frame={p.CFrame:GetComponents()}}end
                end end
                for _,ref in ipairs(skin:GetChildren())do if ref:IsA('ObjectValue')and ref.Name=='CoursePropFallbackTarget'and ref.Value then
                    row.fallbacks+=1;if alpha(ref.Value)<.99 then row.visibleFallbacks+=1 end
                end end
                rows[#rows+1]=row
            end
        end end
        table.sort(rows,function(a,b)return a.kind<b.kind end)
        return game:GetService('HttpService'):JSONEncode({schema=1,scope='Prepared persistent catalog, actual production client gate',
            rows=rows,gate=coursePropVisibility:diagnostics(),at=workspace:GetServerTimeNow(),streamingEnabled=workspace.StreamingEnabled})
    end
    endpoint.Parent=game.Players.LocalPlayer.PlayerScripts
    script.Destroying:Connect(function()endpoint:Destroy()end)
end)()end
