-- Finite first-route Boss Walker INTRO. Source counters/events come from the
-- canonical profile; 60 Hz / 4.25 seconds is a local presentation calibration.
-- Provenance: research/2026-11-09-canonical-character-animation-source.md,
-- "Boss Walker appearance": main 4103-4187 and bank-six arena setup.
-- The source addresses two heroes. Applying fear to the party's three captured
-- identities is an explicit cooperative adaptation, with no gameplay effects.
return function(Animation)
    local Intro={}
    Intro.__index=Intro
    local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end

    function Intro.new(director)
        local s=director.session
        local actors={}
        for _,slot in ipairs(s.order) do
            local h,c=s.state.heroes[slot],s.combat[slot]
            if h and h.status=='Alive' and h.actorId and c and not c.deathAt then actors[slot]=h.actorId end
        end
        local state={id=s.state.runId..':boss-intro:'..s.state.levelEpoch,runId=s.state.runId,
            levelEpoch=s.state.levelEpoch,startedAt=director.now,counter=0,active=true,cameraCut=false,
            phase='BeforeCut',heroActors=actors,bossPosition=table.clone(director.route.boss.position),events={}}
        local self=setmetatable({director=director,session=s,world=director.world,state=state},Intro)
        self:_advance(1)
        return self
    end

    function Intro:_advance(counter)
        local state=self.state
        local row=assert(Animation.bossWalkerIntro(counter))
        state.events=assert(Animation.bossWalkerEventsBetween(state.counter,counter))
        -- E0 and FF skip write_anim_fear, rather than clearing the previous
        -- animation. Recover the preceding write even when a heartbeat skips it.
        local written=row.fearAnimation and row or Animation.bossWalkerIntro(counter-1)
        if written and written.fearAnimation then
            state.fearAnimation=written.fearAnimation;state.fearFrame=written.fearFrame
            state.fearPointerMask=written.fearPointerMask
        end
        state.counter=counter;state.phase=row.phase
        state.footFrame=row.footFrame;state.footMotion=row.footMotion
        for _,event in ipairs(state.events) do if event.kind=='ArenaCut' then state.cameraCut=true end end
        -- Every published context is plain data. Actor replacements can never
        -- inherit this intro's presentation, even within the same party slot.
        local actors={}
        for slot,actorId in pairs(state.heroActors) do
            local h,c=self.session.state.heroes[slot],self.session.combat[slot]
            if h and h.actorId==actorId and h.status=='Alive' and c and not c.deathAt then actors[slot]=actorId end
        end
        state.heroActors=actors
        if self.world.bossIntro then self.world:bossIntro(state) end
        if row.ended then
            state.active=false;self.complete=true
            if self.world.bossIntro then self.world:bossIntro(nil) end
            return 'Complete'
        end
        return 'Active'
    end

    function Intro:step(now)
        if self.cancelled then return 'Cancelled' end
        if self.complete then return 'Complete' end
        local state=self.state
        if self.director.result or self.session.state.status~='Active' then return self:cancel('RunEnded') end
        if self.session.state.runId~=state.runId or self.session.state.levelEpoch~=state.levelEpoch then
            return self:cancel('RunReplaced')
        end
        if not finite(now) or now<state.startedAt then return 'INVALID_TIME' end
        local counter=math.clamp(math.floor((now-state.startedAt)*60+1e-7),1,255)
        if counter<=state.counter then return 'Active' end
        return self:_advance(counter)
    end

    function Intro:cancel(reason)
        if self.cancelled or self.complete then return self.complete and 'Complete' or 'Cancelled' end
        self.cancelled=true;self.state.active=false;self.state.phase='Cancelled';self.state.events={}
        self.state.cancelReason=reason
        if self.world.bossIntro then self.world:bossIntro(nil) end
        return 'Cancelled'
    end

    function Intro:snapshot()
        local s=self.state
        return {id=s.id,runId=s.runId,levelEpoch=s.levelEpoch,counter=s.counter,fearFrame=s.fearFrame,
            phase=s.phase,startedAt=s.startedAt,cameraCut=s.cameraCut,active=s.active}
    end
    return Intro
end
