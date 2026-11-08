-- Source-state action choice. Public controls never carry target, Life or profile.
local SourceCombat={}

function SourceCombat.bind(session,director,config)
    if not config.SourceCombat then return false end
    session.sourceCombat=config.SourceCombat
    session.groundRunAllowed=function(slot)
        if director.carry and director.carry:interaction(slot).carrying then return false end
        if director.guardian and director.guardian:interaction(slot).carrying then return false end
        if director.dragons and director.dragons.heroes[slot] then return false end
        return true
    end
    session.canRunStrike=function(slot)
        return config.Movement~=nil and session.groundRunAllowed(slot) and session.world.isRunning~=nil
            and session.world:isRunning(slot)==true
    end
    session.attackSelector=function(slot,input)
        director.now=session.now
        for _,target in ipairs(session.world:targets(slot,config.Attacks[input])) do
            local enemy=director.enemies[target]
            local hero=session.state.heroes[target]
            local combat=session.combat[target]
            local raw,heavy,kind
            if enemy and not enemy.boss and not enemy.dead and enemy.rawLife~=nil
                and not (director.carry and director.carry:blocksEnemy(target)) then
                director:_finishReaction(target,enemy)
                raw=enemy.rawLife;heavy=enemy.reactionUntil~=nil and enemy.heavyReaction==true;kind=enemy.kind
            elseif hero and hero.status=='Alive' and combat and not combat.deathAt
                and not (combat.hitProtectedUntil and session.now<combat.hitProtectedUntil) then
                session:_finishReaction(target)
                if combat.hitProtectedUntil and session.now<combat.hitProtectedUntil then continue end
                raw=combat.rawLife;heavy=combat.reactionEnd~=nil and combat.heavyReaction==true
            end
            if raw~=nil then
                if input=='Dash' then return heavy and 'HeroBoot' or 'Dash' end
                if heavy then return raw<8 and 'HeroBoot' or 'HeroKick' end
                if raw<4 then return 'HeroPowerPunch' end
                if raw%16<4 then return kind=='Dragon' and 'HeroElbow' or 'HeroUppercut' end
                return 'HeroJab'
            end
        end
        return input=='Dash' and 'Dash' or 'HeroJab'
    end
    return true
end

return SourceCombat
