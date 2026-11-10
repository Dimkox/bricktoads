-- Standard IAS Bool actions aggregate keyboard and UIButton presses natively.
-- https://create.roblox.com/docs/input/input-action-system
local RobloxInputBindings={}
RobloxInputBindings.__index=RobloxInputBindings
local definitions={
    {name='Forward',key='W',direction=true},{name='Backward',key='S',direction=true},
    {name='Left',key='A',direction=true},{name='Right',key='D',direction=true},
    {name='Jump',key='Space'},{name='Attack',key='F'},{name='Mega',key='R'},
}

function RobloxInputBindings.new(parent,buttons,callbacks,engine)
    local factory,enums=engine and engine.Instance or Instance,engine and engine.Enum or Enum
    local context=factory.new('InputContext')
    context.Name,context.Enabled,context.Priority,context.Sink='Gameplay',false,2000,true
    context.Parent=parent
    local self=setmetatable({context=context,enabled=false,actions={},connections={}},RobloxInputBindings)
    for _,definition in ipairs(definitions) do
        local action=factory.new('InputAction')
        action.Name,action.Type,action.Enabled=definition.name,enums.InputActionType.Bool,true
        action.Parent=context;self.actions[definition.name]=action
        local keyboard=factory.new('InputBinding')
        keyboard.Name,keyboard.Type,keyboard.KeyCode='Keyboard',enums.InputBindingType.Automatic,enums.KeyCode[definition.key]
        keyboard.Parent=action
        if buttons[definition.name] then
            local touch=factory.new('InputBinding')
            touch.Name,touch.Type,touch.UIButton='Button',enums.InputBindingType.Automatic,buttons[definition.name]
            touch.Parent=action
        end
        table.insert(self.connections,action.Pressed:Connect(function()
            if not self.enabled then return end
            if definition.direction then
                if callbacks.press then callbacks.press(definition.name) end
            elseif callbacks.action then callbacks.action(definition.name) end
        end))
        if definition.direction then
            table.insert(self.connections,action.Released:Connect(function()
                if self.enabled and callbacks.release then callbacks.release(definition.name) end
            end))
        end
    end
    return self
end
function RobloxInputBindings:setEnabled(enabled)
    enabled=enabled==true
    if self.enabled==enabled then return false end
    self.enabled=enabled;self.context.Enabled=enabled
    return true
end
function RobloxInputBindings:heldDirections()
    local held={}
    if self.enabled then
        for _,definition in ipairs(definitions) do
            if definition.direction and self.actions[definition.name]:GetState()==true then held[definition.name]=true end
        end
    end
    return held
end
function RobloxInputBindings:reset()
    local enabled=self.enabled
    self:setEnabled(false);self:setEnabled(enabled)
end
function RobloxInputBindings:destroy()
    self:setEnabled(false)
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={};self.context:Destroy()
end
return RobloxInputBindings
