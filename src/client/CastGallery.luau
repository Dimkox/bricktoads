-- Paginate the two illustrated cast sheets so touch devices only render eight cards at once.
local Gallery = {}

function Gallery.attach(shell, header, art, colors, translate, button, label, frame)
    local page = 1
    local panel = frame(shell, "CastGallery", colors.ink)
    panel.Size = UDim2.fromScale(1,1)
    panel.ZIndex = 6
    panel.Visible = false
    panel.Active = true
    local heading = label(panel, "Heading", translate("Character gallery"), 19, colors.yellow, true)
    heading.Position, heading.Size = UDim2.fromOffset(12,0), UDim2.new(1,-110,0,44)
    heading.Font = Enum.Font.Arcade
    local close = button(panel, "CloseGallery", translate("Close"), colors.card, function() panel.Visible = false end)
    close.Position, close.Size = UDim2.new(1,-84,0,0), UDim2.fromOffset(80,44)
    local grid = frame(panel, "PortraitGrid")
    grid.BackgroundTransparency = 1
    grid.Position, grid.Size = UDim2.fromOffset(4,48), UDim2.new(1,-8,1,-98)
    local cards = {}
    local count = math.ceil(#art.cast / 8)
    local counter = label(panel, "Page", "", 16, colors.text, true)
    counter.Position, counter.Size = UDim2.new(.25,0,1,-46), UDim2.new(.5,0,0,44)
    counter.TextXAlignment = Enum.TextXAlignment.Center
    local function draw()
        local columns = if grid.AbsoluteSize.X >= grid.AbsoluteSize.Y then 4 else 2
        local rows = 8 / columns
        for i = 1, 8 do
            local key = art.cast[(page-1)*8+i]
            local card = cards[i]
            if not card then
                local tile = frame(grid, "CastCard"..i, colors.panel)
                local face = art.portrait(tile, key)
                face.Position, face.Size = UDim2.fromOffset(1,1), UDim2.new(1,-2,1,-29)
                local name = label(tile, "CharacterName", "", 14, colors.text, true)
                name.Position, name.Size = UDim2.new(0,2,1,-27), UDim2.new(1,-4,0,26)
                name.TextXAlignment = Enum.TextXAlignment.Center
                card = {tile=tile, face=face, name=name}
                cards[i] = card
            end
            card.tile.Position = UDim2.fromScale((i-1)%columns/columns, math.floor((i-1)/columns)/rows)
            card.tile.Size = UDim2.new(1/columns,-3,1/rows,-3)
            card.tile.Visible = key ~= nil
            if key then
                art.setPortrait(card.face, key)
                local display = key:gsub("(%l)(%u)", "%1 %2")
                card.name.Text = translate(if key == "RoboManus" then "Robo-Manus" else display)
            end
        end
        counter.Text = string.format("%d / %d", page, count)
    end
    for _, step in ipairs({-1,1}) do
        local direction = button(panel, if step < 0 then "PreviousPage" else "NextPage",
            if step < 0 then "◀" else "▶", colors.card, function()
                page = (page-1+step)%count+1
                draw()
            end)
        direction.Position = UDim2.new(if step < 0 then 0 else .75,2,1,-46)
        direction.Size = UDim2.new(.25,-4,0,44)
    end
    grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if panel.Visible then draw() end end)
    local open = button(header, "OpenCastGallery", translate("Cast"), colors.card, function()
        page = 1
        panel.Visible = true
        draw()
    end)
    open.Size, open.Position = UDim2.fromOffset(100,44), UDim2.new(1,-106,0,3)
    open.Font, open.TextColor3 = Enum.Font.Arcade, colors.yellow
end

return Gallery
