-- Test-only receding input search. The production game never calls this pilot.
local DT=1/60
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function hit(x0,y0,x1,y1,h,t)
    if h.kind=='ElectricGate' and math.sin(t*2)<=.1 then return false end
    local low,high=0,1
    for _,row in ipairs({{x0-h.x,x1-x0,h.w/2+1.6},{y0-h.y,y1-y0,h.h/2+2.5}}) do
        local a,d,e=row[1],row[2],row[3]
        if math.abs(d)<1e-8 then if math.abs(a)>e then return false end
        else local f,g=(-e-a)/d,(e-a)/d;if f>g then f,g=g,f end;low=math.max(low,f);high=math.min(high,g);if low>high then return false end end
    end
    return true
end
return function(d,m,a)
    local frontier={{y=a.position.y,vy=a.velocity.y,cost=0,first=0}}
    local x=a.position.x;local elapsed=m.elapsed;local fallback=0
    for _=1,18 do
        local nextStates={};local xEnd=x;local timeEnd=elapsed
        for _=1,6 do timeEnd+=DT;xEnd+=math.min(d.course.maxSpeed,d.course.speed+timeEnd*d.course.acceleration)*DT end
        for _,state in ipairs(frontier) do for _,input in ipairs({-1,0,1}) do
            local y,vy=state.y,state.vy;local sx,t=x,elapsed;local alive=true
            for _=1,6 do
                local oldX,oldY=sx,y;t+=DT;sx+=math.min(d.course.maxSpeed,d.course.speed+t*d.course.acceleration)*DT
                vy=clamp(vy-input*48*DT,-17,17)*math.exp(-2*DT);y=clamp(y+vy*DT,d.course.altitudeMin,d.course.altitudeMax)
                for _,h in ipairs(d.course.hazards) do if math.abs(h.x-sx)<5 and hit(oldX,oldY,sx,y,h,t) then alive=false;break end end
                if not alive then break end
            end
            if alive then
                local target=xEnd>d.course.finishPoint.x-72 and 5.5 or 17
                local cost=state.cost+input*input*.005+(y-target)^2*.0001
                local priority=cost
                for _,h in ipairs(d.course.hazards) do local dx=h.x-xEnd
                    if dx>0 and dx<90 then priority+=math.max(0,7-math.abs(y-h.y))^2/(dx+5) end
                end
                local row={y=y,vy=vy,cost=cost,priority=priority,first=state.depth and state.first or input,depth=true}
                local key=math.floor(y*2+.5)..':'..math.floor(vy+.5);local old=nextStates[key]
                if not old or row.priority<old.priority then nextStates[key]=row end
            end
        end end
        local states={};for _,state in pairs(nextStates) do states[#states+1]=state end
        if #states==0 then return fallback end
        table.sort(states,function(a,b) return a.priority<b.priority end)
        while #states>140 do table.remove(states) end
        fallback=states[1].first;frontier=states;x=xEnd;elapsed=timeEnd
    end
    return fallback
end
