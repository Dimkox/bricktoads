-- Owned course cosmetics. The renderer's original part remains the sole collider.
-- Source vehicle silhouettes are fitted below the rider; structure is authored3D.
local Appearance={}
local PIN='f1a43b69577246850d136473700a333b3cdfe93f'
local VEHICLES={Speeder='Speeder',Surfboard='Surfboard',Jet='Jet',ClingerVehicle='ClingerVehicle',Board='Surfboard'}
local STRUCTURES={Wall=true,LowBarrier=true,Overhead=true,MovingWall=true,MechanicalCrusher=true,PipeCrusher=true,ElectricGate=true}
local sequence=0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function tagged(model,name,value)
    local n=model:FindFirstChild(name);return n and n:IsA('StringValue')and n.Value==value
end
local function scalar(model,name)
    local n=assert(model:FindFirstChild(name),'Missing '..name)
    assert(n:IsA('NumberValue')and finite(n.Value),'Invalid '..name);return n.Value
end
local function checked(frame)
    for _,v in ipairs({frame:GetComponents()})do assert(finite(v),'Nonfinite course transform')end
end
local function sameSize(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local function scaled(frame,scale)return CFrame.new(frame.Position*scale)*frame.Rotation end
function Appearance.remove(row)
    local state=row.courseAppearance;if not state then return end
    row.courseAppearance=nil;state.model:Destroy()
    local p=row.part
    if state.skin then
        if p.Parent and p:GetAttribute('CourseFallbackOwner')==state.id then
            p:SetAttribute('CourseFallbackOwner',state.previousOwner)
            p:SetAttribute('CourseFallbackTransparency',state.previousFallbackAlpha)
        end
    elseif p.Parent then p.Transparency=state.previousAlpha end
end
local function vehicle(row,parent,kind)
    local folder=game:GetService('ServerStorage'):FindFirstChild('BrickToadsCourseTemplates')
    local template=folder and folder:FindFirstChild(kind)
    if not template or not template:IsA('Model')or not tagged(template,'AppearanceProfile','CanonicalCourseVehicle')
        or not tagged(template,'CourseKind',kind)or not tagged(template,'SourcePin',PIN)then return end
    local model,skin
    local ok,state=pcall(function()
        skin=assert(template:Clone(),'Uncloneable course resource')
        local length,width,top=scalar(skin,'DeckLength'),scalar(skin,'DeckWidth'),scalar(skin,'DeckTop')
        assert(length>0 and width>0 and math.abs(top)<=100,'Invalid course deck')
        local scale=math.min(row.part.Size.X/length,row.part.Size.Z/width)
        assert(finite(scale)and scale>0 and scale<=100,'Invalid course fit')
        local rows={};local lowest=math.huge;local actualDeckTop
        for _,p in ipairs(skin:GetChildren())do
            if p:IsA('MeshPart')then
                assert(type(p.MeshId)=='string'and p.MeshId:match('^rbxassetid://%d+$'),'Missing uploaded course mesh')
                assert(finite(p.Transparency)and p.Transparency>=0 and p.Transparency<1,'Invisible course resource')
                for _,v in ipairs({p.Size.X,p.Size.Y,p.Size.Z})do assert(finite(v)and v>0,'Invalid course dimensions')end
                checked(p.CFrame)
                for _,child in ipairs(p:GetChildren())do
                    assert(child:IsA('SurfaceAppearance')and #child:GetChildren()==0,'Unexpected course mesh descendant')
                end
                p.Size=p.Size*scale;p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
                p:SetAttribute('CourseVisibleTransparency',p.Transparency)
                local frame=scaled(p.CFrame,scale);local v={frame:GetComponents()}
                local halfY=(math.abs(v[7])*p.Size.X+math.abs(v[8])*p.Size.Y+math.abs(v[9])*p.Size.Z)/2
                lowest=math.min(lowest,frame.Position.Y-halfY)
                if p.Name==(kind=='Surfboard'and'Deck'or'RiderDeck')then actualDeckTop=frame.Position.Y+halfY end
                rows[#rows+1]={part=p,frame=frame}
            else
                assert((p:IsA('StringValue')or p:IsA('NumberValue'))and #p:GetChildren()==0,'Unexpected course resource descendant')
            end
        end
        assert(#rows>=1 and #rows<=32,'Invalid course segment count')
        model=Instance.new('Model');model.Name='CourseVehicle_'..tostring(row.id)
        model:SetAttribute('CourseAppearance','CanonicalCourseVehicle')
        sequence+=1;local id=kind..':'..tostring(sequence)
        skin.Name=kind..'Appearance';skin:SetAttribute('CanonicalCourseSkin',true);skin:SetAttribute('CourseSkinId',id)
        local ref=Instance.new('ObjectValue');ref.Name='CourseFallbackTarget';ref.Value=row.part;ref.Parent=skin
        skin.Parent=model
        -- Modes place ride plates rootY-2.6, clingers rootY-2.7. Their old
        -- anchor foot plane is rootY-3. Keep every fitted mesh above this plane;
        -- consumers may move only the hero's cosmetic skin onto deckWorldY.
        local deck=kind=='ClingerVehicle'and-.3 or-.4
        return {model=model,skin=skin,id=id,rows=rows,size=row.part.Size,kind=row.kind,
            anchorDeckOffset=deck,deckLocalY=top*scale,actualDeckLocalY=actualDeckTop or top*scale,meshMinY=lowest,
            previousOwner=row.part:GetAttribute('CourseFallbackOwner'),
            previousFallbackAlpha=row.part:GetAttribute('CourseFallbackTransparency')}
    end)
    if not ok then if model then model:Destroy()elseif skin then skin:Destroy()end;return end
    row.part:SetAttribute('CourseFallbackOwner',state.id)
    row.part:SetAttribute('CourseFallbackTransparency',row.part.Transparency)
    state.model.Parent=parent
    game:GetService('CollectionService'):AddTag(state.skin,'BrickToadsCourseSkin')
    return state
end
local function structure(row,parent)
    local model=Instance.new('Model');model.Name='CourseStructure_'..tostring(row.id)
    model:SetAttribute('CourseAppearance','AuthoredIndustrialCourseStructure')
    local rows={};local s=row.part.Size;local x,y,z=s.X,s.Y,s.Z
    local metal=Color3.fromRGB(56,71,76);local plate=Color3.fromRGB(112,129,127)
    local cap=Color3.fromRGB(155,169,155);local warning=Color3.fromRGB(226,176,66)
    local function part(name,size,position,color,material,round)
        local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=material or Enum.Material.Metal
        p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        if round then p.Shape=Enum.PartType.Ball end
        local localFrame=CFrame.new(position);p.CFrame=row.part.CFrame*localFrame;p.Parent=model
        rows[#rows+1]={part=p,frame=localFrame}
    end
    -- Recessed opaque panels, full-depth piers and capped edges give the hazard
    -- visible thickness without changing the simulation's authored envelope.
    part('InsetCore',Vector3.new(x*.68,y*.88,z*.86),Vector3.new(),plate,Enum.Material.Concrete)
    local pier=math.min(.55,z*.16);local rail=math.min(.55,y*.15)
    for _,side in ipairs({-1,1})do
        part('EdgePier'..side,Vector3.new(x,y,pier),Vector3.new(0,0,side*(z-pier)/2),metal)
        part('CapRail'..side,Vector3.new(x,rail,z),Vector3.new(0,side*(y-rail)/2,0),cap)
    end
    local sections=math.clamp(math.ceil(z/5),2,8)
    for n=1,sections do
        local q=-z/2+(n-.5)*z/sections
        part('RivetSeam'..n,Vector3.new(x*.85,y*.8,math.min(.12,z/sections*.12)),Vector3.new(0,0,q),metal)
        if row.kind=='LowBarrier'or row.kind=='MechanicalCrusher'or row.kind=='PipeCrusher'then
            part('WarningBand'..n,Vector3.new(x*.95,math.min(.32,y*.12),z/sections*.55),
                Vector3.new(0,y*.27,q),n%2==0 and metal or warning)
        end
    end
    for _,face in ipairs({-1,1})do for _,side in ipairs({-1,1})do
        part('Bolt'..face..side,Vector3.new(math.min(.14,x*.12),math.min(.2,y*.1),math.min(.2,z*.1)),
            Vector3.new(face*x*.44,side*y*.32,side*z*.35),cap,nil,true)
    end end
    if row.kind=='Overhead'then
        part('DoorHeader',Vector3.new(x*.95,math.min(.45,y*.18),z*.88),Vector3.new(0,-y*.32,0),warning)
    elseif row.kind=='ElectricGate'then
        for _,side in ipairs({-1,1})do
            part('Insulator'..side,Vector3.new(x*.9,y*.7,math.min(.25,z*.1)),Vector3.new(0,0,side*z*.3),warning)
        end
    end
    model.Parent=parent
    return {model=model,rows=rows,size=s,kind=row.kind,previousAlpha=row.part.Transparency or 0}
end
function Appearance.update(row,parent,metadata,waterSurfaceY)
    if not row or not row.part or not row.part.Parent then return end
    metadata=metadata or{}
    local state=row.courseAppearance
    if state and(state.kind~=row.kind or not sameSize(state.size,row.part.Size)or state.model.Parent~=parent)then
        Appearance.remove(row);state=nil
    end
    if not state then
        local kind=VEHICLES[row.kind]
        state=kind and vehicle(row,parent,kind)or STRUCTURES[row.kind]and structure(row,parent)
        row.courseAppearance=state
    end
    if not state then return end
    if state.skin then
        local anchorY=row.part.CFrame.Position.Y+state.anchorDeckOffset
        local bottomY=anchorY+state.meshMinY-state.deckLocalY
        local deckOffset=state.actualDeckLocalY-state.deckLocalY
        local lift=math.max(0,anchorY+.03-bottomY)
        if finite(waterSurfaceY)then lift=math.max(lift,waterSurfaceY+.1-anchorY-deckOffset)end
        state.groundPlaneY=anchorY;state.deckOriginWorldY=anchorY+lift
        state.deckWorldY=state.deckOriginWorldY+deckOffset
        state.meshBottomWorldY=bottomY+lift
        state.fit=CFrame.new(0,state.deckOriginWorldY-row.part.CFrame.Position.Y-state.deckLocalY,0)
            *CFrame.Angles(0,-math.pi/2,0)
    end
    local fit=state.fit or CFrame.new()
    for _,p in ipairs(state.rows)do p.part.CFrame=row.part.CFrame*fit*p.frame end
    if not state.skin then
        if metadata.alpha~=nil then state.previousAlpha=metadata.alpha end
        local alpha=state.previousAlpha>=.5 and state.previousAlpha or 0
        for _,p in ipairs(state.rows)do p.part.Transparency=alpha end
        row.part.Transparency=1
    end
end
return Appearance
