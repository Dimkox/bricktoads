-- The bootstrap supplies IsStudio; neither saved attributes nor clients grant access.
local StudioGodMode={}
function StudioGodMode.attach(config,isStudio,storage)
    local allowed=isStudio==true
    if allowed and storage:GetAttribute('BrickToadsGodMode')==nil then
        storage:SetAttribute('BrickToadsGodMode',true)
    end
    config.Development={allowInfiniteLives=allowed,
        infiniteLives=allowed and storage:GetAttribute('BrickToadsGodMode')==true}
    local policy={}
    function policy:bind(hub)
        if not allowed then return end
        self.connection=storage:GetAttributeChangedSignal('BrickToadsGodMode'):Connect(function()
            local enabled=storage:GetAttribute('BrickToadsGodMode')==true
            config.Development.infiniteLives=enabled
            assert(hub:setInfiniteLives(enabled)=='OK','Cannot apply Studio infinite lives')
        end)
    end
    return policy
end
return StudioGodMode
