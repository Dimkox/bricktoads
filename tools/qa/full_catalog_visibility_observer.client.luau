-- Prepared gallery resource observation; the production gate owns loading.
-- Append after the regular client and set CatalogExpectedSourceSha256.
do (function()
    local Http=game:GetService('HttpService')
    local Collection=game:GetService('CollectionService')
    local expected=assert(script:GetAttribute('CatalogExpectedSourceSha256'))
    assert(type(expected)=='string' and #expected==64 and expected:match('^[0-9a-f]+$'),'Invalid catalog source')
    local function alpha(p)return 1-(1-p.Transparency)*(1-p.LocalTransparencyModifier)end
    local endpoint=Instance.new('BindableFunction');endpoint.Name='BrickToadsCatalogVisibilityRead'
    endpoint.OnInvoke=function()
        local gallery=workspace:FindFirstChild('BrickToadsFullCatalogGallery')
        local rows={}
        if gallery then for _,skin in Collection:GetTagged('BrickToadsCastSkin')do
            if skin:IsDescendantOf(gallery)then
                local tracked=castAssetVisibility.rows[skin]
                local row={kind=skin.Parent.Name,state=tracked and tracked.state or 'Untracked',
                    meshes=0,visibleMeshes=0,fallbacks=0,visibleFallbacks=0}
                for _,p in skin:GetDescendants()do if p:IsA('MeshPart')then
                    row.meshes+=1;if alpha(p)<.99 then row.visibleMeshes+=1 end
                end end
                for _,v in skin:GetChildren()do
                    if v:IsA('ObjectValue')and v.Value and v.Value:IsA('BasePart')then
                        row.fallbacks+=1;if alpha(v.Value)<.99 then row.visibleFallbacks+=1 end
                    end
                end
                rows[#rows+1]=row
            end
        end end
        table.sort(rows,function(a,b)return a.kind<b.kind end)
        return Http:JSONEncode({schema=1,sourceSha256=expected,
            scope='Prepared actual client gallery; natural production gate loading; no preload, visibility or input writes',
            streamingEnabled=workspace.StreamingEnabled,rows=rows,gate=castAssetVisibility:diagnostics()})
    end
    endpoint.Parent=game.Players.LocalPlayer.PlayerScripts
    script.Destroying:Connect(function()endpoint:Destroy()end)
end)()end
