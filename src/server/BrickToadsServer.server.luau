-- Keep the lifecycle domain private until a server actor adapter is implemented.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BrickToads"):WaitForChild("BrickToadsConfig"))
local Core = require(script.Parent:WaitForChild("RunLifecycle"))
assert(type(Core.new) == "function" and type(Core.apply) == "function", "Lifecycle core failed to load")
print("[" .. Config.Name .. "] server ready; lifecycle core loaded")
