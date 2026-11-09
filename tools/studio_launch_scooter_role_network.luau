-- Evaluate in idle Edit of an owned helper after injecting the server/client.
return function(options)
    local service=game:GetService("StudioTestService")
    assert(game:GetService("RunService"):IsStudio()and service.EditModeActive,"Owned idle Studio Edit required")
    assert(type(options)=="table"and type(options.name)=="string"and #options.name>0,"Name this role run")
    assert(type(options.sourceId)=="string"and #options.sourceId>0,"Exact expected BuildId required")
    assert(type(options.players)=="number"and options.players%1==0 and options.players>=2 and options.players<=4,"Actual client count2..4 required")
    assert(options.scenario=="Invader"or options.scenario=="InvaderDisconnect"or options.scenario=="HeroCrash"
        or options.scenario=="HeroDisconnectCrash"or options.scenario=="HeroOfflineDeathLateJoin"
        or options.scenario=="RocketRat"or options.scenario=="RocketRatDisconnect",
        "Supported role, crash and actual disconnect scenario required")
    assert(options.invaderOutcome==nil or options.invaderOutcome=="Return"or options.invaderOutcome=="Escape","Invader outcome Return/Escape required")
    local storage=game:GetService("ServerStorage");local evidence=storage:FindFirstChild("BrickToadsScooterRoleNetworkEvidence")
    if not evidence then evidence=Instance.new("Folder");evidence.Name="BrickToadsScooterRoleNetworkEvidence";evidence.Parent=storage end
    assert(not evidence:FindFirstChild(options.name),"Use a fresh run name; preserve prior receipts")
    local output=Instance.new("Folder");output.Name=options.name;output:SetAttribute("Status","RUNNING");output.Parent=evidence
    local network={};for _,p in ipairs({"InboundNetworkMinDelayMs","OutboundNetworkMinDelayMs","InboundNetworkJitterMs","OutboundNetworkJitterMs","InboundNetworkLossPercent","OutboundNetworkLossPercent"})do network[p]=settings().Network[p]end
    local timeout=math.clamp(tonumber(options.timeoutSeconds)or 180,60,180)
    local function fail(err)local f=Instance.new("StringValue");f.Name="Failure";f.Value=string.sub(tostring(err),1,5999);f.Parent=output;output:SetAttribute("Status","ERROR")end
    task.delay(timeout+45,function()if output.Parent and output:GetAttribute("Status")=="RUNNING"then fail("Edit evidence deadline; server teardown unconfirmed")end end)
    task.spawn(function()
        local ok,err=xpcall(function()
            local result=service:ExecuteMultiplayerTestAsync(options.players,{tag="BrickToadsScooterRoleNetworkTest",
                players=options.players,heroes=options.heroes,scenario=options.scenario,invaderOutcome=options.invaderOutcome,
                seed=options.seed or 41,expectedSourceId=options.sourceId,timeoutSeconds=timeout})
            local encoded=game:GetService("HttpService"):JSONEncode({result=result,studioVersion=version(),sourceId=options.sourceId,
                networkSettings=network,networkProfile=options.networkProfile or"Recorded Studio settings",startedPlayers=options.players})
            local first,index=1,0
            while first<=#encoded do
                local last=math.min(#encoded,first+5999)
                while last<#encoded do local b=string.byte(encoded,last+1);if b<128 or b>=192 then break end;last-=1 end
                index+=1;local chunk=Instance.new("StringValue");chunk.Name=string.format("Chunk%04d",index);chunk.Value=string.sub(encoded,first,last);chunk.Parent=output;first=last+1
            end
            output:SetAttribute("Bytes",#encoded);output:SetAttribute("Chunks",index);output:SetAttribute("Status",type(result)=="table"and result.status or"ERROR")
            print("[BT-SCOOTER-ROLE] "..options.name.." "..tostring(output:GetAttribute("Status")))
        end,debug.traceback)
        if not ok then fail(err)end
    end)
    return"Launched actual-client role/crash test "..options.name
end
