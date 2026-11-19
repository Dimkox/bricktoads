local first = game:GetService("ReplicatedFirst")
local players = game:GetService("Players")
local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
local screen = Instance.new("ScreenGui")
screen.Name = "BrickToadsSplash"
screen.DisplayOrder = 100
screen.ResetOnSpawn = false
screen.ScreenInsets = Enum.ScreenInsets.None
local shot = Instance.new("ImageLabel")
shot.Name = "CausewayIllustration"
shot.Size = UDim2.fromScale(1, 1)
shot.BackgroundColor3 = Color3.fromRGB(10, 27, 35)
shot.BorderSizePixel = 0
shot.ScaleType = Enum.ScaleType.Crop
shot.Parent = screen
local brand = Instance.new("TextLabel")
brand.Name = "GameTitle"
brand.AutoLocalize = false
brand.BackgroundTransparency = 1
brand.Text = "BRICKTOADS"
brand.Font = Enum.Font.Arcade
brand.TextColor3 = Color3.fromRGB(255, 224, 118)
brand.TextStrokeColor3 = Color3.fromRGB(13, 30, 36)
brand.TextStrokeTransparency = 0
brand.TextScaled = true
brand.Position = UDim2.fromScale(.07, .12)
brand.Size = UDim2.fromScale(.59, .14)
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.Parent = screen
screen.Parent = playerGui
first:RemoveDefaultLoadingScreen()
local started = os.clock()
task.spawn(function()
    local shared = game:GetService("ReplicatedStorage"):WaitForChild("BrickToads", 8)
    local module = shared and shared:WaitForChild("ArcadeArt", 4)
    if module and screen.Parent then require(module).backdrop(shot) end
end)
repeat
    task.wait(.08)
    local menu = playerGui:FindFirstChild("BrickToadsGameUI")
    if menu and menu:GetAttribute("MenuReady") and os.clock()-started >= 1.1 then break end
until os.clock()-started >= 5
screen:Destroy()
