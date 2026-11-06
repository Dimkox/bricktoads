-- Evaluate in the Edit DataModel through Roblox Studio MCP.
-- Wrap this file in a function, call the returned launcher with options; see RUNBOOK.md.
-- Test runner/client sources must already be injected into this unsaved Studio test copy.
return function(options)
    assert(game:GetService("RunService"):IsStudio(), "Studio only")
    local service = game:GetService("StudioTestService")
    assert(service.EditModeActive, "Launch from the Edit DataModel")
    assert(type(options) == "table" and (options.players == 2 or options.players == 3), "Expected two or three clients")
    assert(type(options.name) == "string" and #options.name > 0, "Name this acceptance run")
    local storage = game:GetService("ServerStorage")
    local evidence = storage:FindFirstChild("CombatStandAcceptanceEvidence")
    if not evidence then
        evidence = Instance.new("Folder")
        evidence.Name = "CombatStandAcceptanceEvidence"
        evidence.Parent = storage
    end
    assert(not evidence:FindFirstChild(options.name), "This run name already exists; use a new name")
    local output = Instance.new("Folder")
    output.Name = options.name
    output:SetAttribute("Status", "RUNNING")
    output.Parent = evidence
    local network = {}
    for _, property in ipairs({"InboundNetworkMinDelayMs", "OutboundNetworkMinDelayMs",
        "InboundNetworkJitterMs", "OutboundNetworkJitterMs", "InboundNetworkLossPercent", "OutboundNetworkLossPercent"}) do
        network[property] = settings().Network[property]
    end
    task.spawn(function()
        local ok, failure = xpcall(function()
            local result = service:ExecuteMultiplayerTestAsync(options.players, {
                tag = "CombatStandAcceptance", players = options.players,
                timeoutSeconds = options.timeoutSeconds or 240,
                emergency = options.emergency == true,
                protectionOnly = options.protectionOnly == true,
                edgeDisconnectOnly = options.edgeDisconnectOnly == true,
            })
            local encoded = game:GetService("HttpService"):JSONEncode({
                ok = true, result = result, networkProfile = options.networkProfile or "recorded settings",
                networkSettings = network, studioVersion = version(),
            })
            -- StringValue rejects strings of 200000 bytes or more. Keep every chunk
            -- small enough for both that engine limit and MCP's text response limit.
            local first, index = 1, 0
            while first <= #encoded do
                local last = math.min(#encoded, first + 5999)
                while last < #encoded do
                    local byte = string.byte(encoded, last + 1)
                    if byte < 128 or byte >= 192 then break end
                    last = last - 1
                end
                index = index + 1
                local chunk = Instance.new("StringValue")
                chunk.Name = string.format("Chunk%04d", index)
                chunk.Value = string.sub(encoded, first, last)
                chunk.Parent = output
                first = last + 1
            end
            output:SetAttribute("Bytes", #encoded)
            output:SetAttribute("Chunks", index)
            output:SetAttribute("Status", type(result) == "table" and result.status or "ERROR")
            print("[BT-MCP-ACCEPTANCE] " .. options.name .. " " .. output:GetAttribute("Status"))
        end, debug.traceback)
        if not ok then
            local errorValue = Instance.new("StringValue")
            errorValue.Name = "Failure"
            errorValue.Value = string.sub(tostring(failure), 1, 5999)
            errorValue.Parent = output
            output:SetAttribute("Status", "ERROR")
            warn("[BT-MCP-ACCEPTANCE] " .. options.name .. " ERROR: " .. tostring(failure))
        end
    end)
    return "Launched " .. options.name .. " through StudioTestService"
end
