-- Standard Roblox table/translator adapter. Engine services are injected for native contracts.
local Localization={}
Localization.__index=Localization

local function formatEnglish(source,args)
    return (source:gsub('{([%w_]+):?[%w_]*}',function(name)
        local value=type(args)=='table' and args[name]
        return value~=nil and tostring(value) or '{'..name..'}'
    end))
end

function Localization.new(catalog,service,create)
    local native=create('LocalizationTable')
    native.Name='BrickToadsText'
    native.SourceLocaleId='en-us'
    local entries,bySource={},{}
    for _,entry in ipairs(catalog.entries) do
        local values=table.clone(entry.Values)
        -- Roblox uses ru-ru for the selected client locale; ru also remains a
        -- valid language entry for translation maintenance and regional fallback.
        if values.ru then values['ru-ru']=values.ru end
        entries[#entries+1]={Key=entry.Key,Source=entry.Source,Values=values}
        bySource[entry.Source]=entry.Key
    end
    native:SetEntries(entries)
    native.Parent=service
    return setmetatable({native=native,service=service,bySource=bySource},Localization)
end

function Localization:locale()
    local locale=self.service.RobloxLocaleId
    return type(locale)=='string' and locale~='' and string.lower(locale:gsub('_','-')) or 'en-us'
end

function Localization:text(source,args)
    if type(source)~='string' then return '' end
    local key=self.bySource[source]
    if key then
        local locale=self:locale()
        if self.translatorLocale~=locale then
            local ok,translator=pcall(self.native.GetTranslator,self.native,locale)
            self.translator=ok and translator or nil
            self.translatorLocale=ok and locale or nil
        end
        if self.translator then
            local ok,text=pcall(self.translator.FormatByKey,self.translator,key,args or {})
            if ok and type(text)=='string' then return text end
        end
    end
    -- Missing/unsupported translations and a temporarily unavailable translator
    -- always retain readable English rather than an empty label or another locale.
    return formatEnglish(source,args)
end

function Localization:groupName(name,id)
    local index=type(id)=='string' and id:match('^group%-(%d+)$')
    if index then return self:text('Team {index:int}',{index=tonumber(index)}) end
    return self:text(name or 'Team')
end

function Localization:bind(root)
    root.RootLocalizationTable=self.native
    root.AutoLocalize=true
end

function Localization:bindWorld(workspace)
    local function apply(object)
        if not object:IsA('BillboardGui') then return end
        local parent=object.Parent
        while parent and parent~=workspace do
            if parent:GetAttribute('OriginalArt')==true then
                if object.Name=='OwnerNameplate' then object.AutoLocalize=false
                else self:bind(object) end
                return
            end
            parent=parent.Parent
        end
    end
    for _,object in ipairs(workspace:GetDescendants()) do apply(object) end
    self.worldConnection=workspace.DescendantAdded:Connect(apply)
end

function Localization:destroy()
    if self.worldConnection then self.worldConnection:Disconnect() end
    self.native:Destroy()
end

return Localization
