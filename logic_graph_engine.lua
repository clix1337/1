-- Logic Node Graph Editor & Virtual Machine Module for Target Autofarm Client
return function(ctx)
    local screenGui = ctx.ScreenGui
    local framedBox = ctx.FramedBox
    local outlined = ctx.Outlined
    local new = ctx.New
    local applyFont = ctx.ApplyFont
    local bind = ctx.Bind
    local makeButton = ctx.MakeButton
    local makeDraggable = ctx.MakeDraggable
    local THEME = ctx.THEME
    local Options = ctx.Options
    local State = ctx.State
    local log = ctx.Log
    local phase = ctx.Phase
    local FONT_BOLD = ctx.FONT_BOLD or Enum.Font.SourceSansBold

    local DEFAULT_NODES = {
        {
            id = "n_start",
            type = "EventStart",
            title = "▶ Event: Bot Step",
            category = "Event",
            pos = { x = 60, y = 140 },
            outputs = { { id = "exec_out", name = "Exec", kind = "exec" } },
            inputs = {},
            data = {}
        },
        {
            id = "n_check_buy",
            type = "Branch",
            title = "◇ Branch: Need Buy?",
            category = "Logic",
            pos = { x = 280, y = 140 },
            inputs = {
                { id = "exec_in", name = "Exec", kind = "exec" },
                { id = "cond_in", name = "Has Drop", kind = "bool", value = true }
            },
            outputs = {
                { id = "true_out", name = "True", kind = "exec" },
                { id = "false_out", name = "False", kind = "exec" }
            },
            data = { condition = "has_pending_buy" }
        },
        {
            id = "n_buy",
            type = "ActionBuy",
            title = "★ Action: Buy Dropped Item",
            category = "Action",
            pos = { x = 560, y = 70 },
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            id = "n_check_run",
            type = "Branch",
            title = "◇ Branch: Should Drive?",
            category = "Logic",
            pos = { x = 560, y = 230 },
            inputs = {
                { id = "exec_in", name = "Exec", kind = "exec" },
                { id = "cond_in", name = "Need Money", kind = "bool", value = true }
            },
            outputs = {
                { id = "true_out", name = "True", kind = "exec" },
                { id = "false_out", name = "False", kind = "exec" }
            },
            data = { condition = "should_launch_drive" }
        },
        {
            id = "n_launch",
            type = "ActionDrive",
            title = "🚗 Action: Launch & Drive",
            category = "Action",
            pos = { x = 840, y = 170 },
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            id = "n_roll",
            type = "ActionRoll",
            title = "🎲 Action: Roll All Stations",
            category = "Action",
            pos = { x = 840, y = 300 },
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        }
    }

    local DEFAULT_LINKS = {
        { fromNode = "n_start", fromPin = "exec_out", toNode = "n_check_buy", toPin = "exec_in" },
        { fromNode = "n_check_buy", fromPin = "true_out", toNode = "n_buy", toPin = "exec_in" },
        { fromNode = "n_check_buy", fromPin = "false_out", toNode = "n_check_run", toPin = "exec_in" },
        { fromNode = "n_check_run", fromPin = "true_out", toNode = "n_launch", toPin = "exec_in" },
        { fromNode = "n_check_run", fromPin = "false_out", toNode = "n_roll", toPin = "exec_in" }
    }

    local graphState = {
        nodes = {},
        links = {},
        pan = Vector2.new(0, 0),
        zoom = 1,
        activePreset = "Standard Farm"
    }

    local function cloneTable(t)
        if type(t) ~= "table" then return t end
        local r = {}
        for k, v in pairs(t) do
            r[k] = type(v) == "table" and cloneTable(v) or v
        end
        return r
    end

    local function loadDefaults()
        graphState.nodes = cloneTable(DEFAULT_NODES)
        graphState.links = cloneTable(DEFAULT_LINKS)
        graphState.pan = Vector2.new(0, 0)
    end

    loadDefaults()

    local SAVE_FILE = "target_logic_graph.json"
    local HttpService = game:GetService("HttpService")

    local function saveGraph()
        pcall(function()
            if writefile then
                local data = {
                    nodes = graphState.nodes,
                    links = graphState.links,
                    preset = graphState.activePreset
                }
                writefile(SAVE_FILE, HttpService:JSONEncode(data))
            end
        end)
    end

    local function loadGraph()
        pcall(function()
            if readfile and isfile and isfile(SAVE_FILE) then
                local raw = readfile(SAVE_FILE)
                if raw and #raw > 0 then
                    local data = HttpService:JSONDecode(raw)
                    if data and type(data.nodes) == "table" and type(data.links) == "table" then
                        graphState.nodes = data.nodes
                        graphState.links = data.links
                        graphState.activePreset = data.preset or "Custom"
                        return true
                    end
                end
            end
        end)
        return false
    end

    pcall(loadGraph)

    local editorWindow, editorFill = framedBox(screenGui, THEME.OuterBorder, THEME.Accent, THEME.PanelFill, {
        Name = "LogicGraphEditorWindow",
        Position = UDim2.fromOffset(260, 40),
        Size = UDim2.fromOffset(780, 520),
        Visible = false,
        ZIndex = 60
    })

    local titleBar = new("Frame", {
        BackgroundColor3 = THEME.HeaderTop,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 30),
        ZIndex = 61
    }, editorFill)

    outlined(titleBar, "⚡ TARGET CLIENT // LOGIC GRAPH & BLUEPRINT EDITOR (v2.0)", THEME.Accent, {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -120, 0, 18),
        Bold = true,
        TextSize = 12,
        ZIndex = 62
    })

    local closeBtn = new("TextButton", {
        BackgroundColor3 = THEME.ComboFill,
        BorderSizePixel = 1,
        BorderColor3 = THEME.InnerBorder,
        Position = UDim2.new(1, -26, 0, 5),
        Size = UDim2.fromOffset(20, 20),
        Text = "×",
        TextColor3 = THEME.TextInactive,
        TextSize = 14,
        ZIndex = 63
    }, titleBar)
    applyFont(closeBtn, true)

    bind(closeBtn.MouseEnter, function() closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80) end)
    bind(closeBtn.MouseLeave, function() closeBtn.TextColor3 = THEME.TextInactive end)
    bind(closeBtn.MouseButton1Click, function()
        editorWindow.Visible = false
        saveGraph()
    end)

    local dragHandle = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1, -40, 1, 0),
        ZIndex = 61
    }, titleBar)
    makeDraggable(editorWindow, dragHandle)

    local toolBar = new("Frame", {
        BackgroundColor3 = THEME.ContentFill,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 30),
        Size = UDim2.new(1, 0, 0, 32),
        ZIndex = 61
    }, editorFill)

    local function makeToolBtn(pos, size, text, color, cb)
        return makeButton(toolBar, pos, size, text, color or THEME.ComboFill, cb)
    end

    local presetLabel = outlined(toolBar, "Пресет: " .. graphState.activePreset, THEME.TextActive, {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.fromOffset(160, 16),
        Bold = true,
        TextSize = 11,
        ZIndex = 62
    })

    makeToolBtn(UDim2.fromOffset(180, 3), UDim2.fromOffset(110, 26), "Базовый фарм", THEME.ComboFill, function()
        loadDefaults()
        graphState.activePreset = "Базовый фарм"
        presetLabel.Text = "Пресет: " .. graphState.activePreset
        saveGraph()
        if ctx.RedrawGraph then ctx.RedrawGraph() end
    end)

    makeToolBtn(UDim2.fromOffset(296, 3), UDim2.fromOffset(100, 26), "Только роллы", THEME.ComboFill, function()
        loadDefaults()
        for _, link in ipairs(graphState.links) do
            if link.toNode == "n_check_run" then
                link.toNode = "n_roll"
                link.toPin = "exec_in"
            end
        end
        graphState.activePreset = "Только роллы"
        presetLabel.Text = "Пресет: " .. graphState.activePreset
        saveGraph()
        if ctx.RedrawGraph then ctx.RedrawGraph() end
    end)

    makeToolBtn(UDim2.fromOffset(402, 3), UDim2.fromOffset(90, 26), "+ Добавить", Color3.fromRGB(34, 52, 78), function()
        if ctx.OpenPalette then ctx.OpenPalette() end
    end)

    makeToolBtn(UDim2.fromOffset(498, 3), UDim2.fromOffset(110, 26), "Сброс к дефолту", Color3.fromRGB(55, 30, 30), function()
        loadDefaults()
        graphState.activePreset = "Standard Farm"
        presetLabel.Text = "Пресет: " .. graphState.activePreset
        saveGraph()
        if ctx.RedrawGraph then ctx.RedrawGraph() end
    end)

    makeToolBtn(UDim2.new(1, -120, 0, 3), UDim2.fromOffset(108, 26), "💾 Сохранить", Color3.fromRGB(30, 68, 38), function()
        saveGraph()
        log("Нодовый граф успешно сохранен!", Color3.fromRGB(100, 255, 120))
    end)

    local canvasFrame = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(13, 14, 18),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 62),
        Size = UDim2.new(1, 0, 1, -86),
        ClipsDescendants = true,
        ZIndex = 61
    }, editorFill)

    local statusFooter = new("Frame", {
        BackgroundColor3 = THEME.ContentFill,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -24),
        Size = UDim2.new(1, 0, 0, 24),
        ZIndex = 61
    }, editorFill)

    local statusHelp = outlined(statusFooter, "💡 Перетаскивайте ноды мышкой | Соединяйте пины протягиванием | Клик по проводу для удаления", THEME.TextInactive, {
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -24, 0, 16),
        TextSize = 10,
        ZIndex = 62
    })

    local graphContainer = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(3000, 2000),
        ZIndex = 62
    }, canvasFrame)

    local wireContainer = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 63
    }, graphContainer)

    local nodeContainer = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 64
    }, graphContainer)

    local connectingState = {
        active = false,
        fromNode = nil,
        fromPin = nil,
        fromPos = Vector2.new(0, 0),
        kind = "exec"
    }

    local pinElements = {}

    local function drawBezierSegment(p0, p1, p2, p3, container, color, thickness)
        local points = 16
        local prev = p0
        for i = 1, points do
            local t = i / points
            local u = 1 - t
            local pt = (u * u * u * p0) + (3 * u * u * t * p1) + (3 * u * t * t * p2) + (t * t * t * p3)
            local diff = pt - prev
            local len = diff.Magnitude
            if len > 0.5 then
                local angle = math.atan2(diff.Y, diff.X)
                local seg = new("Frame", {
                    BackgroundColor3 = color or THEME.Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(prev.X, prev.Y - (thickness / 2)),
                    Size = UDim2.fromOffset(len + 0.8, thickness),
                    Rotation = math.deg(angle),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 63
                }, container)
            end
            prev = pt
        end
    end

    local function drawSpline(startPos, endPos, kind, isSelected, linkRef)
        local dx = math.abs(endPos.X - startPos.X) * 0.55
        dx = math.clamp(dx, 40, 250)
        local c1 = startPos + Vector2.new(dx, 0)
        local c2 = endPos - Vector2.new(dx, 0)

        local color = (kind == "exec") and Color3.fromRGB(255, 255, 255)
            or (kind == "bool") and Color3.fromRGB(255, 60, 60)
            or Color3.fromRGB(100, 200, 255)
        if isSelected then color = Color3.fromRGB(255, 220, 60) end

        local splineGroup = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 63
        }, wireContainer)

        drawBezierSegment(startPos, c1, c2, endPos, splineGroup, color, 2.5)

        if linkRef then
            local mid = (startPos + endPos) * 0.5
            local cutBtn = new("TextButton", {
                BackgroundColor3 = Color3.fromRGB(24, 24, 28),
                BorderSizePixel = 1,
                BorderColor3 = Color3.fromRGB(60, 60, 65),
                Position = UDim2.fromOffset(mid.X - 8, mid.Y - 8),
                Size = UDim2.fromOffset(16, 16),
                Text = "×",
                TextColor3 = Color3.fromRGB(180, 180, 180),
                TextSize = 11,
                ZIndex = 65
            }, splineGroup)
            applyFont(cutBtn, true)
            bind(cutBtn.MouseButton1Click, function()
                for idx, l in ipairs(graphState.links) do
                    if l == linkRef then
                        table.remove(graphState.links, idx)
                        break
                    end
                end
                saveGraph()
                if ctx.RedrawGraph then ctx.RedrawGraph() end
            end)
        end
    end

    local function redrawWires()
        for _, ch in ipairs(wireContainer:GetChildren()) do
            ch:Destroy()
        end
        for _, link in ipairs(graphState.links) do
            local fromKey = link.fromNode .. "_" .. link.fromPin
            local toKey = link.toNode .. "_" .. link.toPin
            local pFrom = pinElements[fromKey]
            local pTo = pinElements[toKey]
            if pFrom and pTo then
                local pos1 = Vector2.new(pFrom.AbsolutePosition.X - graphContainer.AbsolutePosition.X + 6, pFrom.AbsolutePosition.Y - graphContainer.AbsolutePosition.Y + 6)
                local pos2 = Vector2.new(pTo.AbsolutePosition.X - graphContainer.AbsolutePosition.X + 6, pTo.AbsolutePosition.Y - graphContainer.AbsolutePosition.Y + 6)
                local kind = pFrom:GetAttribute("Kind") or "exec"
                drawSpline(pos1, pos2, kind, false, link)
            end
        end
    end

    local function createNodeUI(nodeData)
        local categoryColors = {
            Event = Color3.fromRGB(160, 40, 40),
            Logic = Color3.fromRGB(40, 80, 140),
            Action = Color3.fromRGB(36, 120, 64),
            Param = Color3.fromRGB(120, 90, 30)
        }
        local headerColor = categoryColors[nodeData.category] or THEME.AccentDark

        local nodeFrame, nodeFill = framedBox(nodeContainer, THEME.OuterBorder, headerColor, THEME.ChildFill, {
            Name = nodeData.id,
            Position = UDim2.fromOffset(nodeData.pos.x, nodeData.pos.y),
            Size = UDim2.fromOffset(190, 26 + math.max(#(nodeData.inputs or {}), #(nodeData.outputs or {}), 1) * 24 + 14),
            ZIndex = 64
        })

        local header = new("Frame", {
            BackgroundColor3 = headerColor,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 22),
            ZIndex = 65
        }, nodeFill)

        outlined(header, nodeData.title, Color3.fromRGB(255, 255, 255), {
            Position = UDim2.fromOffset(8, 3),
            Size = UDim2.new(1, -26, 0, 16),
            Bold = true,
            TextSize = 10,
            ZIndex = 66
        })

        if nodeData.id ~= "n_start" then
            local delNodeBtn = new("TextButton", {
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -20, 0, 2),
                Size = UDim2.fromOffset(18, 18),
                Text = "×",
                TextColor3 = Color3.fromRGB(220, 220, 220),
                TextSize = 12,
                ZIndex = 67
            }, header)
            bind(delNodeBtn.MouseButton1Click, function()
                for idx, n in ipairs(graphState.nodes) do
                    if n.id == nodeData.id then
                        table.remove(graphState.nodes, idx)
                        break
                    end
                end
                for i = #graphState.links, 1, -1 do
                    local l = graphState.links[i]
                    if l.fromNode == nodeData.id or l.toNode == nodeData.id then
                        table.remove(graphState.links, i)
                    end
                end
                saveGraph()
                if ctx.RedrawGraph then ctx.RedrawGraph() end
            end)
        end

        local nodeDragging = false
        local nodeStartPos = Vector2.new(0, 0)
        local mouseStart = Vector2.new(0, 0)

        bind(header.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                nodeDragging = true
                mouseStart = UserInputService:GetMouseLocation()
                nodeStartPos = Vector2.new(nodeFrame.Position.X.Offset, nodeFrame.Position.Y.Offset)
            end
        end)

        bind(UserInputService.InputChanged, function(input)
            if nodeDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = UserInputService:GetMouseLocation() - mouseStart
                local newX = math.max(0, nodeStartPos.X + delta.X)
                local newY = math.max(0, nodeStartPos.Y + delta.Y)
                nodeFrame.Position = UDim2.fromOffset(newX, newY)
                nodeData.pos.x = newX
                nodeData.pos.y = newY
                redrawWires()
            end
        end)

        bind(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and nodeDragging then
                nodeDragging = false
                saveGraph()
            end
        end)

        local body = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 24),
            Size = UDim2.new(1, 0, 1, -24),
            ZIndex = 65
        }, nodeFill)

        local pinColors = {
            exec = Color3.fromRGB(255, 255, 255),
            bool = Color3.fromRGB(240, 60, 60),
            num = Color3.fromRGB(60, 180, 255),
            str = Color3.fromRGB(240, 200, 60)
        }

        for idx, pin in ipairs(nodeData.inputs or {}) do
            local yOffset = (idx - 1) * 22 + 6
            local pinDot = new("TextButton", {
                BackgroundColor3 = pinColors[pin.kind] or Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 1,
                BorderColor3 = Color3.fromRGB(15, 15, 20),
                Position = UDim2.fromOffset(4, yOffset + 4),
                Size = UDim2.fromOffset(10, 10),
                Text = "",
                ZIndex = 67
            }, body)
            pinDot:SetAttribute("Kind", pin.kind)

            local pinKey = nodeData.id .. "_" .. pin.id
            pinElements[pinKey] = pinDot

            outlined(body, pin.name, THEME.TextActive, {
                Position = UDim2.fromOffset(18, yOffset),
                Size = UDim2.fromOffset(70, 18),
                TextSize = 10,
                ZIndex = 66
            })

            bind(pinDot.MouseButton1Click, function()
                if connectingState.active then
                    if connectingState.fromNode ~= nodeData.id and connectingState.kind == pin.kind then
                        table.insert(graphState.links, {
                            fromNode = connectingState.fromNode,
                            fromPin = connectingState.fromPin,
                            toNode = nodeData.id,
                            toPin = pin.id
                        })
                        saveGraph()
                        if ctx.RedrawGraph then ctx.RedrawGraph() end
                    end
                    connectingState.active = false
                end
            end)
        end

        for idx, pin in ipairs(nodeData.outputs or {}) do
            local yOffset = (idx - 1) * 22 + 6
            local pinDot = new("TextButton", {
                BackgroundColor3 = pinColors[pin.kind] or Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 1,
                BorderColor3 = Color3.fromRGB(15, 15, 20),
                Position = UDim2.new(1, -14, 0, yOffset + 4),
                Size = UDim2.fromOffset(10, 10),
                Text = "",
                ZIndex = 67
            }, body)
            pinDot:SetAttribute("Kind", pin.kind)

            local pinKey = nodeData.id .. "_" .. pin.id
            pinElements[pinKey] = pinDot

            outlined(body, pin.name, THEME.TextActive, {
                Position = UDim2.new(1, -88, 0, yOffset),
                Size = UDim2.fromOffset(70, 18),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextSize = 10,
                ZIndex = 66
            })

            bind(pinDot.MouseButton1Click, function()
                connectingState.active = true
                connectingState.fromNode = nodeData.id
                connectingState.fromPin = pin.id
                connectingState.kind = pin.kind
                statusHelp.Text = "Протяните связь к входному пину типа [" .. pin.kind:upper() .. "] и кликните по нему!"
            end)
        end
    end

    local function redrawAll()
        for _, ch in ipairs(nodeContainer:GetChildren()) do
            ch:Destroy()
        end
        pinElements = {}
        for _, n in ipairs(graphState.nodes) do
            createNodeUI(n)
        end
        task.defer(redrawWires)
    end
    ctx.RedrawGraph = redrawAll

    local paletteWindow, paletteFill = framedBox(screenGui, THEME.OuterBorder, THEME.Accent, THEME.ChildFill, {
        Name = "NodePalette",
        Position = UDim2.fromOffset(450, 120),
        Size = UDim2.fromOffset(260, 340),
        Visible = false,
        ZIndex = 80
    })

    local palTitle = outlined(paletteFill, "ДОБАВИТЬ НОДУ В ГРАФ", THEME.Accent, {
        Position = UDim2.fromOffset(10, 8),
        Size = UDim2.new(1, -36, 0, 18),
        Bold = true,
        TextSize = 11,
        ZIndex = 81
    })

    local palClose = new("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -24, 0, 4),
        Size = UDim2.fromOffset(20, 20),
        Text = "×",
        TextColor3 = THEME.TextInactive,
        TextSize = 14,
        ZIndex = 82
    }, paletteFill)
    bind(palClose.MouseButton1Click, function() paletteWindow.Visible = false end)

    local palScroll = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 32),
        Size = UDim2.new(1, -20, 1, -40),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        ZIndex = 81
    }, paletteFill)

    local AVAILABLE_NODE_TEMPLATES = {
        {
            title = "🎲 Action: Roll Levers",
            category = "Action",
            type = "ActionRoll",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            title = "★ Action: Buy Item",
            category = "Action",
            type = "ActionBuy",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            title = "🚗 Action: Launch & Drive",
            category = "Action",
            type = "ActionDrive",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            title = "🏠 Action: Return to Base",
            category = "Action",
            type = "ActionReturn",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = {},
            data = {}
        },
        {
            title = "◇ Branch: If / Else",
            category = "Logic",
            type = "Branch",
            inputs = {
                { id = "exec_in", name = "Exec", kind = "exec" },
                { id = "cond_in", name = "Condition", kind = "bool", value = true }
            },
            outputs = {
                { id = "true_out", name = "True", kind = "exec" },
                { id = "false_out", name = "False", kind = "exec" }
            },
            data = { condition = "custom" }
        },
        {
            title = "⏳ Action: Delay (Wait)",
            category = "Action",
            type = "ActionWait",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = { { id = "exec_out", name = "Then", kind = "exec" } },
            data = { seconds = 1.0 }
        },
        {
            title = "⚔ Set Combat / Hunt",
            category = "Param",
            type = "SetHunt",
            inputs = { { id = "exec_in", name = "Exec", kind = "exec" } },
            outputs = { { id = "exec_out", name = "Then", kind = "exec" } },
            data = { enabled = true }
        }
    }

    palScroll.CanvasSize = UDim2.fromOffset(0, #AVAILABLE_NODE_TEMPLATES * 34)

    for idx, tmpl in ipairs(AVAILABLE_NODE_TEMPLATES) do
        local btn = makeButton(palScroll, UDim2.fromOffset(0, (idx - 1) * 34 + 2), UDim2.new(1, -6, 0, 28), tmpl.title, THEME.ComboFill, function()
            local newId = "node_" .. os.clock():gsub("%.", "")
            local newNode = cloneTable(tmpl)
            newNode.id = newId
            newNode.pos = { x = 320 + math.random(-40, 40), y = 160 + math.random(-40, 40) }
            table.insert(graphState.nodes, newNode)
            paletteWindow.Visible = false
            saveGraph()
            redrawAll()
        end)
    end

    ctx.OpenPalette = function()
        paletteWindow.Visible = true
    end

    openGraphEditor = function()
        editorWindow.Visible = true
        redrawAll()
    end
    ctx.OpenGraphEditor = openGraphEditor

    local function evaluateCondition(condName, f)
        if condName == "has_pending_buy" then
            return State.PendingBuy ~= nil and Options.AutoBuy == true
        elseif condName == "should_launch_drive" then
            if not Options.AutoRun then return false end
            local balance = ctx.Cash() or 0
            if balance < Options.Reserve then return true end
            local rollTime = os.clock() - (State.RollStarted or 0)
            if not Options.AutoRoll or (Options.RollSeconds > 0 and rollTime >= Options.RollSeconds) then
                return true
            end
            return false
        elseif condName == "has_car" then
            return ctx.OwnCar() ~= nil
        end
        return false
    end

    local function executeGraphStep(f)
        if not graphState.nodes or #graphState.nodes == 0 then return nil end

        local nodesById = {}
        for _, n in ipairs(graphState.nodes) do
            nodesById[n.id] = n
        end

        local linksBySource = {}
        for _, l in ipairs(graphState.links) do
            local key = l.fromNode .. "_" .. l.fromPin
            linksBySource[key] = l
        end

        local currentNode = nodesById["n_start"]
        if not currentNode then
            for _, n in ipairs(graphState.nodes) do
                if n.type == "EventStart" then currentNode = n; break end
            end
        end
        if not currentNode then return nil end

        local steps = 0
        local currentPin = "exec_out"

        while currentNode and steps < 20 do
            steps = steps + 1
            local nodeType = currentNode.type

            if nodeType == "ActionBuy" then
                return "WaitBuy"
            elseif nodeType == "ActionDrive" then
                return "Launch"
            elseif nodeType == "ActionRoll" then
                return "Roll"
            elseif nodeType == "ActionReturn" then
                return "Return"
            elseif nodeType == "Branch" then
                local cond = currentNode.data and currentNode.data.condition or "has_pending_buy"
                local isTrue = evaluateCondition(cond, f)
                currentPin = isTrue and "true_out" or "false_out"
                local link = linksBySource[currentNode.id .. "_" .. currentPin]
                if link and nodesById[link.toNode] then
                    currentNode = nodesById[link.toNode]
                    currentPin = "exec_out"
                else
                    break
                end
            else
                local link = linksBySource[currentNode.id .. "_" .. currentPin]
                if link and nodesById[link.toNode] then
                    currentNode = nodesById[link.toNode]
                    currentPin = "exec_out"
                else
                    break
                end
            end
        end

        return nil
    end

    ctx.ExecuteGraphStep = executeGraphStep
    return executeGraphStep
end
