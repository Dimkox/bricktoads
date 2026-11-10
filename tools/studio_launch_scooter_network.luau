-- Evaluate as a function in the owned helper's Edit DataModel through Studio MCP.
-- Acceptance module/startup hook and real-client driver must already be injected.
return function(options)
    assert(game:GetService("RunService"):IsStudio(), "Studio only")
    local service = game:GetService("StudioTestService")
    assert(service.EditModeActive, "Launch from idle Edit")
    assert(type(options) == "table" and type(options.players) == "number" and options.players % 1 == 0
        and options.players >= 1 and options.players <= 3, "Network scenario requires an integer 1..3 clients")
    assert(type(options.name) == "string" and #options.name > 0, "Name this run")
    assert(type(options.sourceId) == "string" and #options.sourceId > 0, "Supply the exact expected BuildId")
    assert(options.scenario == nil or options.scenario == "Heroes", "Initial scenario is Heroes")
    local timeout = math.clamp(tonumber(options.timeoutSeconds) or 180, 60, 180)
    local storage = game:GetService("ServerStorage")
    local evidence = storage:FindFirstChild("BrickToadsScooterNetworkEvidence")
    if not evidence then
        evidence = Instance.new("Folder")
        evidence.Name, evidence.Parent = "BrickToadsScooterNetworkEvidence", storage
    end
    assert(not evidence:FindFirstChild(options.name), "Use a new evidence name")
    local output = Instance.new("Folder")
    output.Name = options.name
    output:SetAttribute("Status", "RUNNING")
    output.Parent = evidence
    local network = {}
    for _, property in ipairs({"InboundNetworkMinDelayMs", "OutboundNetworkMinDelayMs",
        "InboundNetworkJitterMs", "OutboundNetworkJitterMs", "InboundNetworkLossPercent", "OutboundNetworkLossPercent"}) do
        local readOK, value = pcall(function() return settings().Network[property] end)
        network[property] = readOK and value or "Unavailable"
    end
    local function failure(message)
        local errorValue = Instance.new("StringValue")
        errorValue.Name, errorValue.Value, errorValue.Parent = "Failure", string.sub(tostring(message), 1, 5999), output
        output:SetAttribute("Status", "ERROR")
        warn("[BT-SCOOTER-NETWORK] " .. options.name .. " ERROR: " .. tostring(message))
    end
    -- This bounds Edit evidence even if a test never initializes or Studio cannot return.
    -- The active server's independent watchdog owns normal EndTest cleanup.
    task.delay(timeout + 45, function()
        if output.Parent and output:GetAttribute("Status") == "RUNNING" then
            failure("Studio test did not return before the Edit evidence deadline; server teardown is unconfirmed")
        end
    end)
    task.spawn(function()
        local ok, err = xpcall(function()
            local result = service:ExecuteMultiplayerTestAsync(options.players, {
                tag = "BrickToadsScooterNetworkTest", players = options.players,
                scenario = options.scenario or "Heroes", seed = options.seed or 41, timeoutSeconds = timeout,
                expectedSourceId = options.sourceId,
            })
            local encoded = game:GetService("HttpService"):JSONEncode({
                result = result, studioVersion = version(), networkSettings = network,
                networkProfile = options.networkProfile or "Recorded Studio settings",
                sourceId = options.sourceId, startedPlayers = options.players,
            })
            local first, index = 1, 0
            while first <= #encoded do
                local last = math.min(#encoded, first + 5999)
                while last < #encoded do
                    local byte = string.byte(encoded, last + 1)
                    if byte < 128 or byte >= 192 then break end
                    last -= 1
                end
                index += 1
                local chunk = Instance.new("StringValue")
                chunk.Name, chunk.Value = string.format("Chunk%04d", index), string.sub(encoded, first, last)
                chunk.Parent = output
                first = last + 1
            end
            output:SetAttribute("Bytes", #encoded)
            output:SetAttribute("Chunks", index)
            output:SetAttribute("Status", type(result) == "table" and result.status or "ERROR")
            print("[BT-SCOOTER-NETWORK] " .. options.name .. " " .. tostring(output:GetAttribute("Status")))
        end, debug.traceback)
        if not ok then failure(err) end
    end)
    return "Launched " .. options.name .. " through real Studio multiplayer clients"
end
