--// variables
local DRAIN_BUILD = 'singlefile-2026-07-30-66'
local Environment = getgenv()

if Environment.drain_loaded then
    if Environment.drain_build == DRAIN_BUILD then
        local ExistingLibrary = Environment.Library
        if ExistingLibrary and type(ExistingLibrary.Notify) == 'function' then
            pcall(function()
                ExistingLibrary:Notify('drain.solutions is already loaded', 5)
            end)
        end
        return
    end

    --// reload
    if type(Environment.DrainHavocCleanup) == 'function' then
        pcall(Environment.DrainHavocCleanup)
        Environment.DrainHavocCleanup = nil
    end

    local OldLibrary = Environment.Library
    if OldLibrary and type(OldLibrary.Unload) == 'function' then
        pcall(function()
            OldLibrary:Unload()
        end)
    end

    Environment.drain_loaded = false
    Environment.drain_build = nil
end

local LoadSuccess, LoadError = xpcall(function()

local Library = (function()
local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local Stats = game:GetService('Stats');
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    UnloadCallbacks = {};
    ScreenGui = ScreenGui;

    WatermarkEnabled = false;
    WatermarkTemplate = 'drain.solutions | {fps} FPS | {ping} ms';
    CurrentFPS = 0;
    CurrentPing = 0;
    DragUpdateRate = 1 / 60;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    local Dragging = false;
    local DragOffset = Vector2.zero;
    local DragElapsed = 0;
    local LastPosition;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            DragOffset = ObjPos;
            DragElapsed = Library.DragUpdateRate;
            LastPosition = nil;
            Dragging = true;
        end;
    end);

    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = false;
        end;
    end));

    Library:GiveSignal(RenderStepped:Connect(function(Delta)
        if not Dragging then
            return;
        end;

        DragElapsed = DragElapsed + Delta;
        if DragElapsed < Library.DragUpdateRate then
            return;
        end;
        DragElapsed = DragElapsed % Library.DragUpdateRate;

        local NewPosition = Vector2.new(
            math.floor(Mouse.X - DragOffset.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X) + 0.5),
            math.floor(Mouse.Y - DragOffset.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y) + 0.5)
        );

        if NewPosition == LastPosition then
            return;
        end;

        LastPosition = NewPosition;
        Instance.Position = UDim2.fromOffset(NewPosition.X, NewPosition.Y);
    end));
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    --// external signals
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    --// cleanup
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    for Idx = #Library.UnloadCallbacks, 1, -1 do
        local Callback = table.remove(Library.UnloadCallbacks, Idx)
        pcall(Callback)
    end

    for _, DrawingObject in ipairs(Library.CursorDrawings or {}) do
        pcall(DrawingObject.Remove, DrawingObject)
    end
    Library.CursorDrawings = nil

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadCallbacks, Callback)
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        -- transparency texture
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        -- library gui offset

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        local function UpdatePickerPosition()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end;

        local PickerPositionConnection;
        PickerFrameOuter:GetPropertyChangedSignal('Visible'):Connect(function()
            if PickerFrameOuter.Visible then
                UpdatePickerPosition();
                if not PickerPositionConnection then
                    PickerPositionConnection = DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdatePickerPosition);
                end;
            elseif PickerPositionConnection then
                PickerPositionConnection:Disconnect();
                PickerPositionConnection = nil;
            end;
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            local MenuPositionConnection
            ContextMenu.Container:GetPropertyChangedSignal('Visible'):Connect(function()
                if ContextMenu.Container.Visible then
                    updateMenuPosition();
                    if not MenuPositionConnection then
                        MenuPositionConnection = DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
                    end
                elseif MenuPositionConnection then
                    MenuPositionConnection:Disconnect()
                    MenuPositionConnection = nil
                end;
            end)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                updateMenuPosition()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value, ColorPicker.Transparency)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            UpdatePickerPosition();
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- always, toggle, hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        local function UpdateModeSelectPosition()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end;

        local ModeSelectPositionConnection;
        ModeSelectOuter:GetPropertyChangedSignal('Visible'):Connect(function()
            if ModeSelectOuter.Visible then
                UpdateModeSelectPosition();
                if not ModeSelectPositionConnection then
                    ModeSelectPositionConnection = ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateModeSelectPosition);
                end;
            elseif ModeSelectPositionConnection then
                ModeSelectPositionConnection:Disconnect();
                ModeSelectPositionConnection = nil;
            end;
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = ParentObj.Type == 'Toggle' and ParentObj.Value or KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = State;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';
            if Library.RefreshKeybindFrame then Library:RefreshKeybindFrame(); end;
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                UpdateModeSelectPosition();
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                elseif KeyPicker.Mode == 'Hold' then
                    local Key = KeyPicker.Value;
                    local Matches = (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                        or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key);

                    if Matches and not KeyPicker.Toggled then
                        KeyPicker.Toggled = true;
                        KeyPicker:DoClick();
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Hold' and KeyPicker.Toggled then
                    local Key = KeyPicker.Value;
                    local Matches = (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                        or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key);

                    if Matches then
                        KeyPicker.Toggled = false;
                        KeyPicker:DoClick();
                    end;
                end;

                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        --// key picker
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;

            -- keep the caret position
            if Box.Text ~= Text then
                Box.Text = Text;
            end;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- textbox cursor offset

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- default position
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- focused overflow
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- cursor width
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- cursor bounds
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- position correction
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, math.max(Container.AbsoluteSize.X - 23, 0), 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, math.max(Container.AbsoluteSize.X, 13), 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        local function UpdateToggleLayout()
            ToggleLabel.Size = UDim2.new(0, math.max(Container.AbsoluteSize.X - 23, 0), 1, 0);
            ToggleRegion.Size = UDim2.new(0, math.max(Container.AbsoluteSize.X, 13), 1, 0);
        end;

        Container:GetPropertyChangedSignal('AbsoluteSize'):Connect(UpdateToggleLayout);
        task.defer(UpdateToggleLayout);

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' then
                    if Addon.SyncToggleState then Addon.Toggled = Bool end
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 1;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;
        local PreviousChildren = {};

        for _, Child in next, Container:GetChildren() do
            PreviousChildren[Child] = true;
        end;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:GetMaxSize()
            Slider.MaxSize = math.max(SliderInner.AbsoluteSize.X, 1);
            return Slider.MaxSize;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local MaxSize = Slider:GetMaxSize();
            local X = math.clamp(math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, MaxSize)), 0, MaxSize);
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider:GetMaxSize(), Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider:GetMaxSize());

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        SliderInner:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
            Slider:Display();
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Slider.Elements = {};
        for _, Child in next, Container:GetChildren() do
            if not PreviousChildren[Child] and Child:IsA('GuiObject') then
                table.insert(Slider.Elements, Child);
            end;
        end;

        function Slider:SetVisibility(Bool)
            Bool = not not Bool;
            for _, Element in next, Slider.Elements do
                Element.Visible = Bool;
            end;
            Groupbox:Resize();
        end;

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- player or team
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        local ListPositionConnection;

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            RecalculateListPosition();
            ListOuter.Visible = true;
            if not ListPositionConnection then
                ListPositionConnection = DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);
            end;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            if ListPositionConnection then
                ListPositionConnection:Disconnect();
                ListPositionConnection = nil;
            end;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

--// ui
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library.KeybindFrameEnabled = false;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:RefreshKeybindFrame()
    local YSize = 0;
    local XSize = 0;

    for _, Label in next, Library.KeybindContainer:GetChildren() do
        if Label:IsA('TextLabel') and Label.Visible then
            YSize = YSize + 18;
            if Label.TextBounds.X > XSize then XSize = Label.TextBounds.X; end;
        end;
    end;

    Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23);
    Library.KeybindFrame.Visible = Library.KeybindFrameEnabled and YSize > 0;
end;

function Library:SetWatermarkVisibility(Bool)
    Library.WatermarkEnabled = not not Bool;
    Library.Watermark.Visible = Library.WatermarkEnabled;

    if Library.WatermarkEnabled then
        Library:RefreshWatermark();
    end;
end;

function Library:SetKeybindVisibility(Bool)
    Library.KeybindFrameEnabled = not not Bool;
    Library:RefreshKeybindFrame();
end;

function Library:SetWindowTitleGlowVisibility(Bool)
    Library.WindowTitleGlowEnabled = not not Bool;

    for _, GlowLabel in ipairs(Library.WindowTitleGlowLabels or {}) do
        GlowLabel.Visible = Library.WindowTitleGlowEnabled;
    end;

    Library:RefreshWindowTitleDomain();
end;

function Library:RefreshWindowTitleDomain()
    local Title = tostring(Library.WindowTitleText or '');
    local DotPosition = Title:find('.', 1, true);
    local HasDomain = DotPosition ~= nil and DotPosition < #Title;
    local PrefixText = HasDomain and Title:sub(1, DotPosition - 1) or Title;
    local DotText = HasDomain and '.' or '';
    local DomainText = HasDomain and Title:sub(DotPosition + 1) or '';
    local PrefixWidth = Library:GetTextBounds(PrefixText, Library.Font, 16);
    local DotWidth = Library:GetTextBounds(DotText, Library.Font, 16);
    local DomainWidth = Library:GetTextBounds(DomainText, Library.Font, 16);
    local StartOffset = math.floor(-(PrefixWidth + DotWidth + DomainWidth) * 0.5 + 0.5);
    local DomainColor = Library.WindowTitleDomainColorEnabled
        and (Library.WindowTitleDomainColor or Library.AccentColor)
        or Library.FontColor;

    for _, Entry in ipairs(Library.WindowTitleLabels or {}) do
        local LayerVisible = not Entry.IsGlow or Library.WindowTitleGlowEnabled;

        Entry.PrefixLabel.Text = PrefixText;
        Entry.PrefixLabel.Position = UDim2.new(0.5, StartOffset + Entry.OffsetX, 0, Entry.OffsetY);
        Entry.PrefixLabel.Size = UDim2.new(0, PrefixWidth, 0, 25);
        Entry.PrefixLabel.Visible = LayerVisible;

        Entry.DotLabel.Text = DotText;
        Entry.DotLabel.Position = UDim2.new(0.5, StartOffset + PrefixWidth + Entry.OffsetX, 0, Entry.OffsetY);
        Entry.DotLabel.Size = UDim2.new(0, DotWidth, 0, 25);
        Entry.DotLabel.Visible = HasDomain and LayerVisible;

        Entry.DomainLabel.Text = DomainText;
        Entry.DomainLabel.TextColor3 = DomainColor;
        Entry.DomainLabel.Position = UDim2.new(
            0.5,
            StartOffset + PrefixWidth + DotWidth + Entry.OffsetX,
            0,
            Entry.OffsetY
        );
        Entry.DomainLabel.Size = UDim2.new(0, DomainWidth, 0, 25);
        Entry.DomainLabel.Visible = HasDomain and LayerVisible;
    end;
end;

function Library:SetWindowTitleDomainColorVisibility(Bool)
    Library.WindowTitleDomainColorEnabled = not not Bool;
    Library:RefreshWindowTitleDomain();
    Library:RefreshWindowTitleGradient();
    Library:UpdateColorsUsingRegistry();
end;

function Library:SetWindowTitleDomainColor(Color)
    Library.WindowTitleDomainColor = Color;
    Library:RefreshWindowTitleDomain();
end;

function Library:RefreshWindowTitleGradient()
    local StartColor = Library.WindowTitleGradientStart or Color3.new(1, 1, 1);
    local EndColor = Library.WindowTitleGradientEnd or Library.AccentColor;
    local Rotation = Library.WindowTitleGradientRotation or 0;

    for _, Gradient in ipairs(Library.WindowTitleGradients or {}) do
        Gradient.Color = ColorSequence.new(StartColor, EndColor);
        Gradient.Rotation = Rotation;
        Gradient.Enabled = Library.WindowTitleGradientEnabled;
    end;
end;

function Library:SetWindowTitleGradientVisibility(Bool)
    Library.WindowTitleGradientEnabled = not not Bool;
    Library:RefreshWindowTitleGradient();
    Library:UpdateColorsUsingRegistry();
end;

function Library:SetWindowTitleGradientStart(Color)
    Library.WindowTitleGradientStart = Color;
    Library:RefreshWindowTitleGradient();
end;

function Library:SetWindowTitleGradientEnd(Color)
    Library.WindowTitleGradientEnd = Color;
    Library:RefreshWindowTitleGradient();
end;

function Library:SetWindowTitleGradientRotation(Rotation)
    Library.WindowTitleGradientRotation = Rotation;
    Library:RefreshWindowTitleGradient();
end;

function Library:SetWindowTitleGradientSpin(Bool)
    Library.WindowTitleGradientSpinEnabled = not not Bool;
end;

function Library:SetWindowTitleGradientSpinSpeed(Speed)
    Library.WindowTitleGradientSpinSpeed = Speed;
end;

function Library:GetWatermarkText()
    local Text = tostring(Library.WatermarkTemplate or '');
    local FPS = tostring(Library.CurrentFPS or 0);
    local Ping = tostring(Library.CurrentPing or 0);

    Text = Text:gsub('{fps}', FPS):gsub('{FPS}', FPS);
    Text = Text:gsub('{ping}', Ping):gsub('{PING}', Ping);

    return Text;
end;

function Library:RefreshWatermark()
    local Text = Library:GetWatermarkText();
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library.WatermarkText.Text = Text;
end;

function Library:SetWatermarkTemplate(Text)
    Library.WatermarkTemplate = tostring(Text or '');

    local WatermarkOption = Options and Options.Settings_WatermarkText;
    if WatermarkOption and WatermarkOption.Value ~= Library.WatermarkTemplate then
        WatermarkOption:SetValue(Library.WatermarkTemplate);
    end;

    Library:RefreshWatermark();
end;

function Library:SetWatermark(Text)
    Library:SetWatermarkTemplate(Text);
    Library:SetWatermarkVisibility(true);
end;

do
    local Frames = 0;
    local Elapsed = 0;

    Library:GiveSignal(RenderStepped:Connect(function(Delta)
        Frames = Frames + 1;
        Elapsed = Elapsed + Delta;

        if Elapsed < 0.25 then
            return;
        end;

        Library.CurrentFPS = math.floor((Frames / Elapsed) + 0.5);

        local Success, Ping = pcall(function()
            return Stats.Network.ServerStatsItem['Data Ping']:GetValue();
        end);

        if not Success then
            Success, Ping = pcall(function()
                return LocalPlayer:GetNetworkPing() * 1000;
            end);
        end;

        Library.CurrentPing = Success and math.floor(Ping + 0.5) or 0;
        Frames = 0;
        Elapsed = 0;

        if Library.WatermarkEnabled then
            Library:RefreshWatermark();
        end;

    end));
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    local ColumnCount = Config.Columns or Config.ColumnCount;
    if type(ColumnCount) ~= 'number' then ColumnCount = 3 end
    Config.Columns = math.clamp(math.floor(ColumnCount), 2, 3);
    if Config.AutoDistributeRight == nil then Config.AutoDistributeRight = Config.Columns == 3 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then
        Config.Size = Config.Columns == 3 and UDim2.fromOffset(760, 520) or UDim2.fromOffset(550, 600)
    end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
        Columns = Config.Columns;
    };

    local Outer = Library:Create('CanvasGroup', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        GroupTransparency = 1;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer, 25);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    Library.WindowTitleGlowEnabled = Library.WindowTitleGlowEnabled == true;
    Library.WindowTitleGlowLabels = {};
    Library.WindowTitleLabels = {};
    Library.WindowTitleText = Config.Title or '';
    Library.WindowTitleDomainColorEnabled = Library.WindowTitleDomainColorEnabled == true;
    Library.WindowTitleDomainColor = Library.WindowTitleDomainColor or Library.AccentColor;
    Library.WindowTitleGradientEnabled = Library.WindowTitleGradientEnabled == true;
    Library.WindowTitleGradientStart = Library.WindowTitleGradientStart or Color3.new(1, 1, 1);
    Library.WindowTitleGradientEnd = Library.WindowTitleGradientEnd or Library.AccentColor;
    Library.WindowTitleGradientRotation = Library.WindowTitleGradientRotation or 0;
    Library.WindowTitleGradientSpinEnabled = Library.WindowTitleGradientSpinEnabled == true;
    Library.WindowTitleGradientSpinSpeed = Library.WindowTitleGradientSpinSpeed or 90;
    Library.WindowTitleGradients = {};

    local function AddWindowTitleGradient(Label)
        local Gradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(Library.WindowTitleGradientStart, Library.WindowTitleGradientEnd);
            Enabled = Library.WindowTitleGradientEnabled;
            Rotation = Library.WindowTitleGradientRotation;
            Parent = Label;
        });

        table.insert(Library.WindowTitleGradients, Gradient);
    end;

    local WindowGlowOffsets = {
        { X = 0, Y = 0, TextTransparency = 0.42, StrokeTransparency = 0.22 };
        { X = -1, Y = 0, TextTransparency = 0.62, StrokeTransparency = 0.58 };
        { X = 1, Y = 0, TextTransparency = 0.62, StrokeTransparency = 0.58 };
        { X = 0, Y = -1, TextTransparency = 0.62, StrokeTransparency = 0.58 };
        { X = 0, Y = 1, TextTransparency = 0.62, StrokeTransparency = 0.58 };
    };

    for _, GlowInfo in ipairs(WindowGlowOffsets) do
        local WindowGlow = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Font = Library.Font;
            Position = UDim2.new(0.5, GlowInfo.X, 0, GlowInfo.Y);
            Size = UDim2.new(0, 0, 0, 25);
            Text = '';
            TextColor3 = Library.FontColor;
            TextSize = 16;
            TextTransparency = GlowInfo.TextTransparency;
            TextStrokeColor3 = Library.FontColor;
            TextStrokeTransparency = GlowInfo.StrokeTransparency;
            TextXAlignment = Enum.TextXAlignment.Left;
            Visible = Library.WindowTitleGlowEnabled;
            ZIndex = 1;
            Parent = Inner;
        });

        local WindowDotGlow = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Font = Library.Font;
            Position = UDim2.new(0.5, GlowInfo.X, 0, GlowInfo.Y);
            Size = UDim2.new(0, 0, 0, 25);
            Text = '';
            TextColor3 = Library.FontColor;
            TextSize = 16;
            TextTransparency = GlowInfo.TextTransparency;
            TextStrokeColor3 = Library.FontColor;
            TextStrokeTransparency = GlowInfo.StrokeTransparency;
            TextXAlignment = Enum.TextXAlignment.Left;
            Visible = false;
            ZIndex = 1;
            Parent = Inner;
        });

        local WindowDomainGlow = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Font = Library.Font;
            Position = UDim2.new(0.5, GlowInfo.X, 0, GlowInfo.Y);
            Size = UDim2.new(0, 0, 0, 25);
            Text = '';
            TextColor3 = Library.WindowTitleDomainColor;
            TextSize = 16;
            TextTransparency = GlowInfo.TextTransparency;
            TextStrokeColor3 = Library.FontColor;
            TextStrokeTransparency = GlowInfo.StrokeTransparency;
            TextXAlignment = Enum.TextXAlignment.Left;
            Visible = false;
            ZIndex = 1;
            Parent = Inner;
        });

        Library:AddToRegistry(WindowGlow, {
            TextColor3 = function()
                return Library.WindowTitleGradientEnabled and Color3.new(1, 1, 1) or Library.FontColor;
            end;
            TextStrokeColor3 = function()
                return Library.WindowTitleGradientEnabled and Color3.new(1, 1, 1) or Library.FontColor;
            end;
        });

        Library:AddToRegistry(WindowDotGlow, {
            TextColor3 = 'FontColor';
            TextStrokeColor3 = 'FontColor';
        });

        Library:AddToRegistry(WindowDomainGlow, {
            TextColor3 = function()
                return Library.WindowTitleDomainColorEnabled
                    and (Library.WindowTitleDomainColor or Library.AccentColor)
                    or Library.FontColor;
            end;
            TextStrokeColor3 = 'FontColor';
        });

        table.insert(Library.WindowTitleGlowLabels, WindowGlow);
        table.insert(Library.WindowTitleGlowLabels, WindowDotGlow);
        table.insert(Library.WindowTitleGlowLabels, WindowDomainGlow);
        table.insert(Library.WindowTitleLabels, {
            PrefixLabel = WindowGlow;
            DotLabel = WindowDotGlow;
            DomainLabel = WindowDomainGlow;
            OffsetX = GlowInfo.X;
            OffsetY = GlowInfo.Y;
            IsGlow = true;
        });
        AddWindowTitleGradient(WindowGlow);
    end;

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0.5, 0, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = '';
        TextSize = 16;
        TextStrokeTransparency = 0.55;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 2;
        Parent = Inner;
    });

    local WindowDotLabel = Library:CreateLabel({
        Position = UDim2.new(0.5, 0, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = '';
        TextSize = 16;
        TextStrokeTransparency = 0.55;
        TextXAlignment = Enum.TextXAlignment.Left;
        Visible = false;
        ZIndex = 2;
        Parent = Inner;
    });

    local WindowDomainLabel = Library:CreateLabel({
        Position = UDim2.new(0.5, 0, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = '';
        TextSize = 16;
        TextStrokeTransparency = 0.55;
        TextXAlignment = Enum.TextXAlignment.Left;
        Visible = false;
        ZIndex = 2;
        Parent = Inner;
    });

    Library.RegistryMap[WindowLabel].Properties.TextColor3 = function()
        return Library.WindowTitleGradientEnabled and Color3.new(1, 1, 1) or Library.FontColor;
    end;
    Library.RegistryMap[WindowDomainLabel].Properties.TextColor3 = function()
        return Library.WindowTitleDomainColorEnabled
            and (Library.WindowTitleDomainColor or Library.AccentColor)
            or Library.FontColor;
    end;
    table.insert(Library.WindowTitleLabels, {
        PrefixLabel = WindowLabel;
        DotLabel = WindowDotLabel;
        DomainLabel = WindowDomainLabel;
        OffsetX = 0;
        OffsetY = 0;
        IsGlow = false;
    });
    AddWindowTitleGradient(WindowLabel);
    Library:RefreshWindowTitleDomain();

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    });
    

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        Title = tostring(Title or '');
        Library.WindowTitleText = Title;
        Library:RefreshWindowTitleDomain();
    end;

    function Window:AddTab(Name)
        local IsSettingsTab = type(Name) == 'string'
            and (Name:lower() == 'ui settings' or Name:lower() == 'settings');
        local DisplayName = IsSettingsTab and 'Settings' or Name;
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(DisplayName, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = DisplayName;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local ColumnGap = 8;
        local ColumnsContainer = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(1, -14, 1, -14);
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, ColumnGap);
            FillDirection = Enum.FillDirection.Horizontal;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ColumnsContainer;
        });

        local Sides = {};
        local ColumnWidthOffset = -((Config.Columns - 1) * ColumnGap) / Config.Columns;

        for Column = 1, Config.Columns do
            local Side = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1 / Config.Columns, ColumnWidthOffset, 1, 0);
                CanvasSize = UDim2.new(0, 0, 0, 0);
                BottomImage = '';
                TopImage = '';
                ScrollBarThickness = 0;
                LayoutOrder = Column;
                ZIndex = 2;
                Parent = ColumnsContainer;
            });

            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 8);
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                HorizontalAlignment = Enum.HorizontalAlignment.Center;
                Parent = Side;
            });

            Side.UIListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);

            Sides[Column] = Side;
        end;

        local NextDistributedColumn = math.min(2, Config.Columns);

        local function ResolveColumn(Column)
            if type(Column) ~= 'number' then
                return 1;
            end;

            return math.clamp(math.floor(Column), 1, Config.Columns);
        end;

        local function GetNextRightColumn()
            if Config.Columns < 3 or not Config.AutoDistributeRight then
                return Config.Columns;
            end;

            local Column = NextDistributedColumn;
            NextDistributedColumn = NextDistributedColumn + 1;
            if NextDistributedColumn > Config.Columns then
                NextDistributedColumn = 2;
            end;

            return Column;
        end;

        Tab.Columns = Sides;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};
            local Column = ResolveColumn(Info.Side);

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 24);
                ZIndex = 2;
                Parent = Sides[Column];
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            Groupbox.Holder = BoxOuter;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddCenterGroupbox(Name)
            return Tab:AddGroupbox({ Side = math.min(2, Config.Columns); Name = Name; });
        end;

        function Tab:AddMiddleGroupbox(Name)
            return Tab:AddCenterGroupbox(Name);
        end;

        function Tab:AddColumnGroupbox(Column, Name)
            return Tab:AddGroupbox({ Side = Column; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = GetNextRightColumn(); Name = Name; });
        end;

        function Tab:AddPlayerList(Info)
            Info = Info or {};

            ColumnsContainer.Visible = false;

            local PlayerList = { Players = {}; Items = {}; Rows = {}; };
            local SelectedName;
            local ThumbnailToken = 0;

            local Holder = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Position = UDim2.fromOffset(7, 7);
                Size = UDim2.new(1, -14, 1, -14);
                ZIndex = 3;
                Parent = TabFrame;
            });
            Library:AddToRegistry(Holder, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

            local SearchOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(6, 6);
                Size = UDim2.new(1, -84, 0, 21);
                ZIndex = 4;
                Parent = Holder;
            });
            Library:AddToRegistry(SearchOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local SearchBox = Library:Create('TextBox', {
                BackgroundTransparency = 1;
                ClearTextOnFocus = false;
                Font = Library.Font;
                PlaceholderText = 'Search here';
                PlaceholderColor3 = Color3.fromRGB(125, 125, 125);
                Position = UDim2.fromOffset(5, 0);
                Size = UDim2.new(1, -10, 1, 0);
                Text = '';
                TextColor3 = Library.FontColor;
                TextSize = 14;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = SearchOuter;
            });
            Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor'; });

            local RefreshButton = Library:Create('TextButton', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.new(1, -72, 0, 6);
                Size = UDim2.fromOffset(66, 21);
                AutoButtonColor = false;
                Font = Library.Font;
                Text = 'Refresh';
                TextColor3 = Library.FontColor;
                TextSize = 14;
                ZIndex = 5;
                Parent = Holder;
            });
            Library:AddToRegistry(RefreshButton, {
                BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor';
            });

            local Header = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(6, 32);
                Size = UDim2.new(1, -12, 0, 20);
                ZIndex = 4;
                Parent = Holder;
            });
            Library:AddToRegistry(Header, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local function AddLabel(Parent, Text, Position, Size, Alignment)
                return Library:CreateLabel({
                    Position = Position;
                    Size = Size;
                    Text = Text;
                    TextSize = 14;
                    TextTruncate = Enum.TextTruncate.AtEnd;
                    TextXAlignment = Alignment or Enum.TextXAlignment.Left;
                    ZIndex = 9;
                    Parent = Parent;
                });
            end;

            AddLabel(Header, 'Name', UDim2.fromScale(0, 0), UDim2.new(0.5, 0, 1, 0), Enum.TextXAlignment.Center);
            AddLabel(Header, 'UserId', UDim2.fromScale(0.5, 0), UDim2.new(0.25, 0, 1, 0), Enum.TextXAlignment.Center);
            AddLabel(Header, 'Priority', UDim2.fromScale(0.75, 0), UDim2.new(0.25, 0, 1, 0), Enum.TextXAlignment.Center);

            local RowsContainer = Library:Create('ScrollingFrame', {
                BackgroundColor3 = Library.BackgroundColor;
                BackgroundTransparency = 0;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(6, 52);
                Size = UDim2.new(1, -12, 1, -174);
                BottomImage = '';
                TopImage = '';
                ScrollBarThickness = 2;
                CanvasSize = UDim2.fromOffset(0, 0);
                ZIndex = 4;
                Parent = Holder;
            });
            Library:AddToRegistry(RowsContainer, {
                BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; ScrollBarImageColor3 = 'AccentColor';
            });

            local Detail = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.new(0, 6, 1, -116);
                Size = UDim2.new(1, -12, 0, 110);
                ZIndex = 7;
                Parent = Holder;
            });
            Library:AddToRegistry(Detail, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local Avatar = Library:Create('ImageLabel', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(8, 18);
                Size = UDim2.fromOffset(74, 74);
                Image = '';
                ZIndex = 8;
                Parent = Detail;
            });
            Library:AddToRegistry(Avatar, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

            local PublicDetail = AddLabel(Detail, 'Public: ???', UDim2.fromOffset(90, 26), UDim2.new(0.48, -92, 0, 18));
            local UsernameDetail = AddLabel(Detail, 'Username: ???', UDim2.fromOffset(90, 46), UDim2.new(0.48, -92, 0, 18));
            local UserIdDetail = AddLabel(Detail, 'UserId: ???', UDim2.fromOffset(90, 66), UDim2.new(0.48, -92, 0, 18));

            local function PriorityColor(Value)
                local StatusColors = Library.PlayerStatusColors;
                if Value == 'Enemy' then return StatusColors and StatusColors.Target or Color3.fromRGB(255, 220, 0); end;
                if Value == 'Friendly' then return StatusColors and StatusColors.Friendly or Color3.fromRGB(0, 255, 0); end;
                if Value == 'LocalPlayer' then return Color3.fromRGB(130, 130, 130); end;
                return Library.FontColor;
            end;

            local function UnregisterTree(Object)
                Library:RemoveFromRegistry(Object);
                for _, Descendant in ipairs(Object:GetDescendants()) do
                    Library:RemoveFromRegistry(Descendant);
                end;
            end;

            local UpdateSelection;
            local RefreshRows;
            local PriorityDropdown;
            local SyncingPriority = false;

            local function SetPriority(Name, Value)
                local Entry = Name and PlayerList.Players[Name];
                if not Entry then return; end;
                if Entry.Player == LocalPlayer then
                    UpdateSelection();
                    return;
                end;
                if Value ~= 'Neutral' and Value ~= 'Friendly' and Value ~= 'Enemy' then return; end;
                Entry.Priority.Text = Value;
                UpdateSelection();
                RefreshRows();
                if type(Info.PriorityChanged) == 'function' then
                    Library:SafeCallback(Info.PriorityChanged, Entry.Player, Value);
                end;
            end;

            local PriorityGroup = Tab:AddRightGroupbox('Priority');
            PriorityDropdown = PriorityGroup:AddDropdown('PlayerList_Priority', {
                Values = { 'Neutral', 'Friendly', 'Enemy' };
                Default = 'Neutral';
                Callback = function(Value)
                    if not SyncingPriority then SetPriority(SelectedName, Value); end;
                end;
            });
            PriorityGroup.Holder.Parent = Detail;
            PriorityGroup.Holder.Position = UDim2.new(0.55, 0, 0, 30);
            PriorityGroup.Holder.Size = UDim2.new(0.45, -8, 0, 49);
            PriorityGroup.Holder.ZIndex = 11;
            for _, Object in ipairs(PriorityGroup.Holder:GetDescendants()) do
                if Object:IsA('GuiObject') then Object.ZIndex = math.max(Object.ZIndex, 12); end;
            end;

            local LocalPlayerGroup = Tab:AddRightGroupbox('LocalPlayer');
            local LocalPlayerToggle = LocalPlayerGroup:AddToggle('PlayerList_AreWeSerious', {
                Text = 'Are we serious?';
                Default = false;
                Tooltip = 'You cannot assign a priority to the local player.';
                Callback = function() end;
            });
            LocalPlayerGroup.Holder.Parent = Detail;
            LocalPlayerGroup.Holder.Position = UDim2.new(0.55, 0, 0, 30);
            LocalPlayerGroup.Holder.Size = UDim2.new(0.45, -8, 0, 49);
            LocalPlayerGroup.Holder.Visible = false;
            LocalPlayerGroup.Holder.ZIndex = 11;
            for _, Object in ipairs(LocalPlayerGroup.Holder:GetDescendants()) do
                if Object:IsA('GuiObject') then Object.ZIndex = math.max(Object.ZIndex, 12); end;
            end;

            local function SyncPriorityDropdown(Value)
                SyncingPriority = true;
                PriorityDropdown:SetValue(Value == 'LocalPlayer' and 'Neutral' or Value);
                SyncingPriority = false;
            end;

            UpdateSelection = function()
                local Entry = SelectedName and PlayerList.Players[SelectedName];
                if not Entry then
                    PublicDetail.Text = 'Public: ???'; UsernameDetail.Text = 'Username: ???'; UserIdDetail.Text = 'UserId: ???';
                    Avatar.Image = '';
                    PriorityGroup.Holder.Visible = true;
                    LocalPlayerGroup.Holder.Visible = false;
                    SyncPriorityDropdown('Neutral');
                    return;
                end;

                local Player = Entry.Player;
                local IsLocalPlayer = Player == LocalPlayer;
                PriorityGroup.Holder.Visible = not IsLocalPlayer;
                LocalPlayerGroup.Holder.Visible = IsLocalPlayer;
                PublicDetail.Text = 'Public: ' .. Player.DisplayName;
                UsernameDetail.Text = 'Username: ' .. Player.Name;
                UserIdDetail.Text = 'UserId: ' .. tostring(Player.UserId);
                SyncPriorityDropdown(Entry.Priority.Text);

                ThumbnailToken = ThumbnailToken + 1;
                local Token = ThumbnailToken;
                Avatar.Image = '';
                task.spawn(function()
                    local Success, Image = pcall(function()
                        return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size100x100);
                    end);
                    if Success and Token == ThumbnailToken and SelectedName == Player.Name then Avatar.Image = Image; end;
                end);
            end;

            local function SelectPlayer(Name)
                if not PlayerList.Players[Name] then return; end;
                SelectedName = Name;
                UpdateSelection();
                RefreshRows();
            end;

            RefreshRows = function()
                for _, Row in ipairs(PlayerList.Rows) do UnregisterTree(Row); Row:Destroy(); end;
                table.clear(PlayerList.Rows);

                local Query = SearchBox.Text:lower();
                local Names = {};
                for Name, Entry in next, PlayerList.Players do
                    local Player = Entry.Player;
                    local Searchable = (Name .. ' ' .. Player.DisplayName .. ' ' .. tostring(Player.UserId)):lower();
                    if Query == '' or Searchable:find(Query, 1, true) then table.insert(Names, Name); end;
                end;
                table.sort(Names, function(A, B) return A:lower() < B:lower(); end);

                for Index, Name in ipairs(Names) do
                    local Entry = PlayerList.Players[Name];
                    local Row = Library:Create('Frame', {
                        BackgroundColor3 = Name == SelectedName and Library.AccentColorDark or Library.BackgroundColor;
                        BackgroundTransparency = Name == SelectedName and 0 or 1;
                        BorderSizePixel = 0;
                        Position = UDim2.fromOffset(0, (Index - 1) * 20);
                        Size = UDim2.new(1, -2, 0, 20);
                        ZIndex = 5;
                        Parent = RowsContainer;
                    });
                    Library:AddToRegistry(Row, { BackgroundColor3 = function()
                        return Name == SelectedName and Library.AccentColorDark or Library.BackgroundColor;
                    end; });
                    AddLabel(Row, Name, UDim2.fromOffset(5, 0), UDim2.new(0.5, -5, 1, 0));
                    AddLabel(Row, tostring(Entry.Player.UserId), UDim2.fromScale(0.5, 0), UDim2.new(0.25, 0, 1, 0), Enum.TextXAlignment.Center);
                    local PriorityLabel = AddLabel(Row, Entry.Priority.Text, UDim2.fromScale(0.75, 0), UDim2.new(0.25, -5, 1, 0), Enum.TextXAlignment.Right);
                    PriorityLabel.TextColor3 = PriorityColor(Entry.Priority.Text);
                    local Click = Library:Create('TextButton', {
                        BackgroundTransparency = 1; Size = UDim2.fromScale(1, 1); Text = ''; ZIndex = 10; Parent = Row;
                    });
                    Click.MouseButton1Click:Connect(function() SelectPlayer(Name); end);
                    table.insert(PlayerList.Rows, Row);
                    Entry.Background = Row;
                end;
                RowsContainer.CanvasSize = UDim2.fromOffset(0, #Names * 20);
            end;

            function PlayerList:AddPlayer(Player)
                if not Player or self.Players[Player.Name] then return; end;
                self.Players[Player.Name] = {
                    Player = Player;
                    Priority = { Text = Player == LocalPlayer and 'LocalPlayer' or 'Neutral' };
                };
                if not SelectedName then SelectedName = Player.Name; end;
                UpdateSelection(); RefreshRows();
            end;

            function PlayerList:RemovePlayer(PlayerOrName)
                local Name = type(PlayerOrName) == 'string' and PlayerOrName or PlayerOrName and PlayerOrName.Name;
                if not Name or not self.Players[Name] then return; end;
                self.Players[Name] = nil;
                if SelectedName == Name then SelectedName = next(self.Players); end;
                UpdateSelection(); RefreshRows();
            end;

            function PlayerList:Sync()
                local Present = {};
                for _, Player in ipairs(Players:GetPlayers()) do
                    Present[Player.Name] = true;
                    if not self.Players[Player.Name] then
                        self.Players[Player.Name] = {
                            Player = Player;
                            Priority = { Text = Player == LocalPlayer and 'LocalPlayer' or 'Neutral' };
                        };
                    end;
                end;
                for Name in next, self.Players do if not Present[Name] then self.Players[Name] = nil; end; end;
                if not SelectedName or not self.Players[SelectedName] then SelectedName = next(self.Players); end;
                UpdateSelection(); RefreshRows();
            end;

            function PlayerList:SetPriority(PlayerOrName, Value)
                local Name = type(PlayerOrName) == 'string' and PlayerOrName or PlayerOrName and PlayerOrName.Name;
                SetPriority(Name, Value);
            end;

            function PlayerList:GetPriority(PlayerOrName)
                local Name = type(PlayerOrName) == 'string' and PlayerOrName or PlayerOrName and PlayerOrName.Name;
                local Entry = Name and self.Players[Name];
                return Entry and Entry.Priority.Text or 'Neutral';
            end;

            function PlayerList:Refresh()
                UpdateSelection();
                RefreshRows();
            end;

            SearchBox:GetPropertyChangedSignal('Text'):Connect(RefreshRows);

            local RefreshEvent = Instance.new('BindableEvent');
            RefreshButton.MouseButton1Click:Connect(function() PlayerList:Sync(); RefreshEvent:Fire(); end);
            PlayerList.Items.Refresh = { Button = RefreshButton; MouseButton1Click = RefreshEvent.Event; };
            PlayerList.Items.Search = SearchBox;
            PlayerList.Items.Priority = PriorityDropdown;
            PlayerList.Items.LocalPlayerToggle = LocalPlayerToggle;
            PlayerList.Holder = Holder;

            PlayerList:Sync();
            Library:GiveSignal(Players.PlayerAdded:Connect(function(Player) PlayerList:AddPlayer(Player); end));
            Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player) PlayerList:RemovePlayer(Player); end));

            return PlayerList;
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };
            local Column = ResolveColumn(Info.Side);

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Sides[Column];
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- show the first tab
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddCenterTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = math.min(2, Config.Columns); });
        end;

        function Tab:AddMiddleTabbox(Name)
            return Tab:AddCenterTabbox(Name);
        end;

        function Tab:AddColumnTabbox(Column, Name)
            return Tab:AddTabbox({ Name = Name, Side = Column; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = GetNextRightColumn(); });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        -- show the first tab
        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        if IsSettingsTab then
            local Interface = Tab:AddCenterGroupbox('Interface');

            Interface:AddToggle('Settings_ShowWatermark', {
                Text = 'Show watermark';
                Default = false;
                Callback = function(Value)
                    Library:SetWatermarkVisibility(Value);
                end;
            });

            Interface:AddInput('Settings_WatermarkText', {
                Text = 'Watermark text';
                Default = Library.WatermarkTemplate;
                Callback = function(Value)
                    Library:SetWatermarkTemplate(Value);
                end;
            });

            Interface:AddInput('Settings_CustomScriptName', {
                Text = 'Script name';
                Default = Library.WindowTitleText;
                MaxLength = 64;
                Tooltip = 'Changes the title displayed at the top of the menu.';
                Callback = function(Value)
                    Window:SetWindowTitle(Value);
                end;
            });

            local WindowTitleDomainColorToggle = Interface:AddToggle('Settings_WindowTitleDomainColor', {
                Text = 'Custom domain color';
                Default = false;
                Tooltip = 'Colors the first dot and everything after it in the script name.';
                Callback = function(Value)
                    Library:SetWindowTitleDomainColorVisibility(Value);
                end;
            });

            WindowTitleDomainColorToggle:AddColorPicker('Settings_WindowTitleDomainColorValue', {
                Default = Library.WindowTitleDomainColor;
                Title = 'Domain color';
                Callback = function(Color)
                    Library:SetWindowTitleDomainColor(Color);
                end;
            });

            Interface:AddToggle('Settings_ShowKeybinds', {
                Text = 'Show keybinds';
                Default = false;
                Callback = function(Value)
                    Library:SetKeybindVisibility(Value);
                end;
            });

            Interface:AddToggle('Settings_WindowTitleGlow', {
                Text = 'Title glow';
                Default = false;
                Callback = function(Value)
                    Library:SetWindowTitleGlowVisibility(Value);
                end;
            });

            local WindowTitleGradientToggle = Interface:AddToggle('Settings_WindowTitleGradient', {
                Text = 'Title gradient';
                Default = false;
                Callback = function(Value)
                    Library:SetWindowTitleGradientVisibility(Value);
                end;
            });

            WindowTitleGradientToggle:AddColorPicker('Settings_WindowTitleGradientStart', {
                Default = Library.WindowTitleGradientStart;
                Title = 'Gradient start';
                Callback = function(Color)
                    Library:SetWindowTitleGradientStart(Color);
                end;
            });

            Interface:AddLabel('Gradient end'):AddColorPicker('Settings_WindowTitleGradientEnd', {
                Default = Library.WindowTitleGradientEnd;
                Title = 'Gradient end';
                Callback = function(Color)
                    Library:SetWindowTitleGradientEnd(Color);
                end;
            });

            local WindowTitleGradientRotationSlider = Interface:AddSlider('Settings_WindowTitleGradientRotation', {
                Text = 'Gradient rotation';
                Min = 0;
                Max = 360;
                Default = 0;
                Rounding = 0;
                Suffix = ' deg';
                Callback = function(Value)
                    Library:SetWindowTitleGradientRotation(Value);
                end;
            });

            Interface:AddToggle('Settings_WindowTitleGradientSpin', {
                Text = 'Gradient spin';
                Default = false;
                Tooltip = 'Continuously rotates the title gradient and updates the rotation slider.';
                Callback = function(Value)
                    Library:SetWindowTitleGradientSpin(Value);

                    if Value and not WindowTitleGradientToggle.Value then
                        WindowTitleGradientToggle:SetValue(true);
                    end;
                end;
            });

            Interface:AddSlider('Settings_WindowTitleGradientSpinSpeed', {
                Text = 'Spin speed';
                Min = 10;
                Max = 360;
                Default = 90;
                Rounding = 0;
                Suffix = ' deg/s';
                Callback = function(Value)
                    Library:SetWindowTitleGradientSpinSpeed(Value);
                end;
            });

            local GradientSpinElapsed = 0;
            Library:GiveSignal(RenderStepped:Connect(function(Delta)
                if not Library.WindowTitleGradientSpinEnabled then
                    GradientSpinElapsed = 0;
                    return;
                end;

                GradientSpinElapsed = GradientSpinElapsed + Delta;
                if GradientSpinElapsed < 1 / 30 then return end;

                local Rotation = math.floor(
                    ((Library.WindowTitleGradientRotation or 0)
                        + GradientSpinElapsed * Library.WindowTitleGradientSpinSpeed) % 360 + 0.5
                );
                GradientSpinElapsed = 0;
                WindowTitleGradientRotationSlider:SetValue(Rotation);
            end));

        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local Toggled = false;
    local Fading = false;
    local CursorMouseState = true;
    local Cursor = Drawing.new('Triangle');
    Cursor.Thickness = 1;
    Cursor.Filled = true;
    Cursor.Visible = false;

    local CursorOutline = Drawing.new('Triangle');
    CursorOutline.Thickness = 1;
    CursorOutline.Filled = false;
    CursorOutline.Color = Color3.new(0, 0, 0);
    CursorOutline.Visible = false;

    Library.CursorDrawings = Library.CursorDrawings or {};
    table.insert(Library.CursorDrawings, Cursor);
    table.insert(Library.CursorDrawings, CursorOutline);

    Library:GiveSignal(RenderStepped:Connect(function()
        if not Toggled then return; end
        InputService.MouseIconEnabled = false;

        local mPos = InputService:GetMouseLocation();
        Cursor.Color = Library.AccentColor;
        Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
        Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
        Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);
        CursorOutline.PointA = Cursor.PointA;
        CursorOutline.PointB = Cursor.PointB;
        CursorOutline.PointC = Cursor.PointC;
    end));

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            -- show before fading in
            Outer.Visible = true;
            CursorMouseState = InputService.MouseIconEnabled;
            InputService.MouseIconEnabled = false;
            Cursor.Visible = true;
            CursorOutline.Visible = true;
        else
            InputService.MouseIconEnabled = CursorMouseState;
            Cursor.Visible = false;
            CursorOutline.Visible = false;
        end;

        local FadeTween = TweenService:Create(
            Outer,
            TweenInfo.new(FadeTime, Enum.EasingStyle.Linear),
            { GroupTransparency = Toggled and 0 or 1 }
        );
        FadeTween:Play();

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
end)()

local ThemeManager = (function()
local httpService = game:GetService('HttpService')
local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default'] 		= { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
		['Black Cherry'] 	= { 2, httpService:JSONDecode('{"FontColor":"fff0f4","MainColor":"1a1015","AccentColor":"ff3b6b","BackgroundColor":"090609","OutlineColor":"48212f"}') },
		['BADBAD'] 			= { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"badbad","BackgroundColor":"141414","OutlineColor":"323232"}') },
	}

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]

		if not data then return end

		local scheme = data[2]
		for idx, col in next, customThemeData or scheme do
			self.Library[idx] = Color3.fromHex(col)
			
			if Options[idx] then
				Options[idx]:SetValueRGB(Color3.fromHex(col))
			end
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		-- sync theme colors
		local options = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
		for i, field in next, options do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
		self.Library:UpdateColorsUsingRegistry()
	end

	function ThemeManager:LoadDefault()		
		local theme = 'Default'
		local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

		local isDefault = true
		if content then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false;
			end
		elseif self.BuiltInThemes[self.DefaultTheme] then
		 	theme = self.DefaultTheme
		end

		if isDefault then
			Options.ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:CreateThemeManager(groupbox)
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor });
		groupbox:AddLabel('Main color')	:AddColorPicker('MainColor', { Default = self.Library.MainColor });
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor });
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor });
		groupbox:AddLabel('Font color')	:AddColorPicker('FontColor', { Default = self.Library.FontColor });

		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end

		table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		groupbox:AddDivider()
		groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })

		groupbox:AddButton('Set as default', function()
			self:SaveDefault(Options.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value))
		end)

		Options.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
		end)

		groupbox:AddDivider()
		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
		groupbox:AddDivider()
		
		groupbox:AddButton('Save theme', function() 
			self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)

			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Load theme', function() 
			self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value) 
		end)

		groupbox:AddButton('Refresh list', function()
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		groupbox:AddButton('Set as default', function()
			if Options.ThemeManager_CustomThemeList.Value ~= nil and Options.ThemeManager_CustomThemeList.Value ~= '' then
				self:SaveDefault(Options.ThemeManager_CustomThemeList.Value)
				self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_CustomThemeList.Value))
			end
		end)

		ThemeManager:LoadDefault()

		local function UpdateTheme()
			self:ThemeUpdate()
		end

		Options.BackgroundColor:OnChanged(UpdateTheme)
		Options.MainColor:OnChanged(UpdateTheme)
		Options.AccentColor:OnChanged(UpdateTheme)
		Options.OutlineColor:OnChanged(UpdateTheme)
		Options.FontColor:OnChanged(UpdateTheme)
	end

	function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file
		if not isfile(path) then
			return nil
		end

		local data = readfile(path)
		local success, decoded = pcall(httpService.JSONDecode, httpService, data)
		
		if not success then
			return nil
		end

		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end

		local theme = {}
		local fields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

		for _, field in next, fields do
			theme[field] = Options[field].Value:ToHex()
		end

		writefile(self.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(theme))
	end

	function ThemeManager:ReloadCustomThemes()
		local list = listfiles(self.Folder .. '/themes')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local char = file:sub(pos, pos)

				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1))
				end
			end
		end

		return out
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}

		-- build nested folders

		local parts = self.Folder:split('/')
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end

		table.insert(paths, self.Folder .. '/themes')
		table.insert(paths, self.Folder .. '/settings')

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local groupbox = self:CreateGroupBox(tab)
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
end)()

local SaveManager = (function()
local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- async config load
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- theme
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- theme
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end

			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end


	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddColumnGroupbox(3, 'Configuration')

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
end)()
local Toggles = getgenv().Toggles
local Options = getgenv().Options
local Playerlist

local function get_player_status(player)
    local entry = player and Playerlist and Playerlist.Players and Playerlist.Players[player.Name]
    if entry and entry.Priority then
        return entry.Priority.Text
    end
    return "Neutral"
end

local Window = Library:CreateWindow({
    Title = "drain.solutions",
    Center = true,
    AutoShow = true,
    Columns = 3,
    Size = UDim2.fromOffset(760, 520),
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local CombatPage = Window:AddTab("Combat")
local VisualsPage = Window:AddTab("Visuals")
local MiscPage = Window:AddTab("Misc")
local PlayersPage = Window:AddTab("Players")

--// sensory esp
local SensoryESP = (function()

if not LPH_OBFUSCATED then
    LPH_JIT = LPH_JIT or function(...)
        return ...
    end
    LPH_JIT_MAX = LPH_JIT_MAX or function(...)
        return ...
    end
    LPH_NO_VIRTUALIZE = LPH_NO_VIRTUALIZE or function(...)
        return ...
    end
    LPH_NO_UPVALUES = LPH_NO_UPVALUES or function(f)
        return function(...)
            return f(...)
        end
    end
    LPH_ENCSTR = LPH_ENCSTR or function(...)
        return ...
    end
    LPH_ENCNUM = LPH_ENCNUM or function(...)
        return ...
    end
    LPH_ENCFUNC = LPH_ENCFUNC or function(func, key1, key2)
        if key1 ~= key2 then
            return print("LPH_ENCFUNC mismatch")
        end
        return func
    end
    LPH_CRASH = LPH_CRASH or function()
        return print(debug.traceback())
    end
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local WtS = Camera.WorldToViewportPoint
local UIContainer = gethui and gethui() or CoreGui
local BootstrapPlayers = Players
local LPHNoVirtualize = LPH_NO_VIRTUALIZE
local ESP = {}
local ChamsContainer
local MeshChamsFolder
local ScreenGui
local PlayerRemovingConnection
local InputBeganConnection
local CurrentRunId = HttpService:GenerateGUID(false)

if getgenv().SensoryESP_Unload then
    pcall(getgenv().SensoryESP_Unload)
end

local oldChams = UIContainer:FindFirstChild("SensoryESP_Chams")
if oldChams then
    pcall(function() oldChams:Destroy() end)
end

local oldMeshFolder = Workspace:FindFirstChild("SensoryESP_MeshChams")
if oldMeshFolder then
    pcall(function() oldMeshFolder:Destroy() end)
end

local function IsMeshChamArtifact(obj)
    if not obj then
        return false
    end

    if obj:GetAttribute("SensoryESP_MeshCham") == true then
        return true
    end

    if obj:IsA("Model") and obj.Name == "ChamShells" then
        return true
    end

    if obj:IsA("BasePart") and obj.Name:match("^ChamShell_") then
        return true
    end

    if obj:IsA("Highlight") and obj.Name == "ChamShellHighlight" then
        return true
    end

    return false
end

local function CleanupMeshChams(root)
    if not root then
        return
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if IsMeshChamArtifact(obj) then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function CleanupCharacterMeshChams(character)
    if not character then
        return
    end

    for _, child in ipairs(character:GetChildren()) do
        if IsMeshChamArtifact(child) then
            pcall(function() child:Destroy() end)
        end
    end
end

CleanupMeshChams(Workspace)

for _, player in ipairs(BootstrapPlayers:GetPlayers()) do
    CleanupCharacterMeshChams(player.Character)
end

local function EnsureRootInstances()
    if not ChamsContainer or not ChamsContainer.Parent then
        ChamsContainer = Instance.new("Folder")
        ChamsContainer.Name = "SensoryESP_Chams"
        ChamsContainer.Parent = UIContainer
    end

    if not MeshChamsFolder or not MeshChamsFolder.Parent then
        MeshChamsFolder = Instance.new("Folder")
        MeshChamsFolder.Name = "SensoryESP_MeshChams"
        MeshChamsFolder.Parent = Workspace
    end

    if not ScreenGui or not ScreenGui.Parent then
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "SensoryESP"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.IgnoreGuiInset = true
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        getgenv().SensoryESP_UI = ScreenGui

        local success = pcall(function()
            ScreenGui.Parent = CoreGui
        end)
        if not success then
            ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end

local labelStrokeMap = setmetatable({}, { __mode = "k" })
local DrawLine = LPHNoVirtualize(function(line, p1, p2, thickness, color)
    local diff = p2 - p1
    local dist = diff.Magnitude
    local angle = math.deg(math.atan2(diff.Y, diff.X))

    line.Size = UDim2.new(0, math.floor(dist + 0.5), 0, thickness)
    line.Position = UDim2.new(0, math.floor(p1.X + diff.X / 2 - dist / 2 + 0.5), 0,
        math.floor(p1.Y + diff.Y / 2 - thickness / 2 + 0.5))
    line.Rotation = angle
    line.BackgroundColor3 = color
    line.Visible = true
end)

local ESPConfig = {
    --// checks
    Enabled = false,
    Keybind = {
        Enabled = false,
        Key = Enum.KeyCode.Insert,
    },
    Players = false,
    NPCs = false,
    LocalPlayer = false,
    LimitFPS = 70, -- zero disables the limit
    DynamicBoxes = true,
    DynamicBoxesCheap = false, -- tracks main parts
    DynamicBoxesIncludeAll = false, -- tracks every body part
    VisibilityCheckRate = 0.3,

    --// boxes
    Boxes = false,
    BoxType = "Normal", -- normal, corner or circle
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 1,
    Outlines = {
        Style = "Full", -- full or none
        Color = Color3.fromRGB(0, 0, 0),
        Thickness = 1,
    },

    --// box fill
    BoxFill = {
        Enabled = false,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.9,
        Gradient = {
            Enabled = false,
            Color1 = Color3.fromRGB(180, 255, 255),
            Color2 = Color3.fromRGB(0, 255, 255),
            Color3 = Color3.fromRGB(0, 120, 255),
            Rotation = 0,
            Animated = false,
            Speed = 64, -- degrees per second
            Direction = "Right", -- left or right
        }
    },

    --// health bar
    HealthBar = {
        Enabled = false,
        Position = "Left", -- left, right, top or bottom
        SideGap = 2,
        Width = 2,
        ShowText = false,
        TextFollowBar = false,
        HideWhenFullHP = false,
        FollowGradientColorText = false,
        Font = "Smallest Pixel-7",
        TextSize = 9,
        Outline = {
            Style = "Full",
            Color = Color3.fromRGB(0, 0, 0),
        },
        Gradient = {
            Enabled = false,
            Color1 = Color3.fromRGB(0, 255, 0), -- full health
            Color2 = Color3.fromRGB(255, 255, 0), -- mid health
            Color3 = Color3.fromRGB(255, 0, 0), -- low health
        }
    },

    --// names
    Names = false,
    TextSize = 12,
    TextColor = Color3.fromRGB(255, 255, 255),
    TextOutline = false,
    TextOutlineStyle = "Full", -- full or none
    TextGap = 3,
    Font = "Proggy Clean",
    PlayerStatusColors = {
        Target = Color3.fromRGB(255, 220, 0),
        Friendly = Color3.fromRGB(0, 255, 0),
    },
    TeamIndicator = {
        Enabled = false,
        Position = "Right", -- left or right
        UseTeamColor = false,
        Color = Color3.fromRGB(255, 255, 255),
        Compact = false,
        TextSize = 10,
    },
    FriendlyIndicator = {
        Enabled = false,
        Position = "Right", -- left or right
        CheckTeam = false,
        CheckFriends = false,
        Text = "[F]",
        Color = Color3.fromRGB(0, 255, 0),
    },
    Weapon = {
        Enabled = false,
        Gap = 1,
        OutlineStyle = "Full",
        Font = "Proggy Clean",
        TextSize = 12,
        Color = Color3.fromRGB(255, 255, 255),
        InventoryPath = "ReplicatedStorage.Players.%NAME%.Inventory",
        UseToolFallback = false,
    },

    --// flags
    Flags = {
        Enabled = false,
        Position = "Right",
        Gap = 2,
        SideGap = 4,
        TextGap = 2,
        OutlineStyle = "Full",
        Font = "Smallest Pixel-7",
        TextSize = 9,
        Options = {
            Idle = false,
            Moving = false,
            Jumping = false,
            Swimming = false,
        },
        Colors = {
            Idle = Color3.fromRGB(255, 255, 255),
            Moving = Color3.fromRGB(255, 255, 255),
            Jumping = Color3.fromRGB(255, 255, 255),
            Swimming = Color3.fromRGB(65, 65, 255),
        }
    },

    --// skeleton
    Skeleton = {
        Enabled = false,
        Color = Color3.fromRGB(255, 255, 255),
        Outline = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Gradient = {
            Enabled = false,
            Color1 = Color3.fromRGB(255, 255, 255),
            Color2 = Color3.fromRGB(100, 200, 255),
        },
    },

    --// offscreen arrows
    OffScreenArrows = {
        Enabled = false,
        Size = 14,
        Color = Color3.fromRGB(255, 255, 255),
        OrbitRadius = 100,
        ArrowMode = "Camera",
        Outline = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Names = {
            Enabled = false,
            Font = "Smallest Pixel-7",
            TextSize = 9,
            Color = Color3.fromRGB(255, 255, 255),
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Side = "Bottom",
            Gap = 4,
        },
        Distance = {
            Enabled = false,
            Font = "Smallest Pixel-7",
            TextSize = 9,
            Color = Color3.fromRGB(255, 255, 255),
            Outline = false,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Side = "Bottom",
            Gap = 2,
        },
    },

    --// distance
    Distance = {
        Enabled = false,
        Unit = "Meters",
        StudsPerMeter = 3,
        Ending = "m",
        Gap = 3,
        OutlineStyle = "Full",
        Font = "Proggy Clean",
        TextSize = 12,
        Color = Color3.fromRGB(255, 255, 255),
    },

    --// chams
    Chams = {
        Enabled = false,
        Type = "MeshChams", -- highlight, adornment or mesh chams

        Highlight = {
            FillColor = Color3.fromRGB(255, 255, 255),
            FillTransparency = 1,
            OutlineColor = Color3.fromRGB(255, 255, 255),
            OutlineTransparency = 0,
            VisibleCheck = false, -- occluded or always on top
        },

        Adornment = {
            Color = Color3.fromRGB(59, 144, 204),
            VisibleColor = Color3.fromRGB(59, 204, 90),
            Transparency = 0.7,
            AlwaysOnTop = false,
            VisibleCheck = false,
        },

        --// mesh chams
        MeshChams = {
            FillColor = Color3.fromRGB(59, 144, 204),
            FillTransparency = 0.6,
            OutlineColor = Color3.fromRGB(255, 255, 255),
            OutlineTransparency = 0,
            VisibleCheck = false, -- occluded or always on top
        },
    },

    --// directories
    Directories = {}
}

local function DeepCopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = DeepCopy(value)
    end
    return copy
end

local function DeepMerge(base, override)
    if type(override) ~= "table" then
        return base
    end

    for key, value in pairs(override) do
        if type(value) == "table" and type(base[key]) == "table" then
            DeepMerge(base[key], value)
        else
            base[key] = value
        end
    end

    return base
end

local DefaultESPConfig = DeepCopy(ESPConfig)

local function CompactTeamName(teamName)
    if type(teamName) ~= "string" or teamName == "" then
        return ""
    end

    local parts = {}
    for part in teamName:gmatch("[^%s%-_]+") do
        if part ~= "" then
            table.insert(parts, part)
        end
    end

    if #parts == 0 then
        return teamName
    end

    if #parts == 1 then
        local single = parts[1]
        if #single <= 4 then
            return single:upper()
        end
        return single:sub(1, 1):upper()
    end

    local compact = {}
    for _, part in ipairs(parts) do
        table.insert(compact, part:sub(1, 1):upper())
    end
    return table.concat(compact)
end

local function ColorToHex(color)
    local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
    return string.format("#%02X%02X%02X", r, g, b)
end
--// fonts
local _fontMap = {
    ["Proggy Clean"] = Enum.Font.SourceSans,
    ["Smallest Pixel-7"] = Enum.Font.SourceSans,
    ["Tahoma"] = Enum.Font.SourceSans,
    ["Minecraftia"] = Enum.Font.SourceSans,
    ["Tahoma Modern Bold"] = Enum.Font.SourceSansBold,
}

local FontsToDownload = {
    ["Tahoma"] = { TTF = "https://github.com/LuckyHub1/LuckyHub/raw/main/zekton_rg.ttf" },
    ["Minecraftia"] = { TTF = "https://github.com/LuckyHub1/LuckyHub/raw/refs/heads/main/Minecraftia.ttf" },
    ["Smallest Pixel-7"] = { TTF = "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/smallest_pixel-7.ttf" },
    ["Proggy Clean"] = { TTF = "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyClean.ttf" },
    ["Tahoma Modern Bold"] = { TTF = "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/Tahoma-Modern-Bold.ttf" },
}

local ESPFonts = { Loaded = {} }
local FontsStillLoading = true


local SKELETON_BONE_DEFS = {
    -- spine
    { "UpperTorso", "LowerTorso" },
    -- head to torso
    { "Head", "UpperTorso" },
    -- left arm
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    -- right arm
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    -- left leg
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    -- right leg
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local function GetBonePosition(character, boneName)
    local part = character:FindFirstChild(boneName)
    if part then return part.Position end

    -- r6 fallback
    if boneName == "Head" then
        part = character:FindFirstChild("Head")
    elseif boneName == "UpperTorso" then
        part = character:FindFirstChild("Torso")
    elseif boneName == "LowerTorso" then
        part = character:FindFirstChild("Torso")
        if part then return (part.CFrame * CFrame.new(0, -1.2, 0)).Position end
    elseif boneName == "LeftUpperArm" then
        part = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftArm")
    elseif boneName == "LeftLowerArm" then
        part = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftArm")
        if part then return (part.CFrame * CFrame.new(0, -0.8, 0)).Position end
    elseif boneName == "LeftHand" then
        part = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftArm")
        if part then return (part.CFrame * CFrame.new(0, -1.5, 0)).Position end
    elseif boneName == "RightUpperArm" then
        part = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightArm")
    elseif boneName == "RightLowerArm" then
        part = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightArm")
        if part then return (part.CFrame * CFrame.new(0, -0.8, 0)).Position end
    elseif boneName == "RightHand" then
        part = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightArm")
        if part then return (part.CFrame * CFrame.new(0, -1.5, 0)).Position end
    elseif boneName == "LeftUpperLeg" then
        part = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLeg")
    elseif boneName == "LeftLowerLeg" then
        part = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLeg")
        if part then return (part.CFrame * CFrame.new(0, -0.8, 0)).Position end
    elseif boneName == "LeftFoot" then
        part = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLeg")
        if part then return (part.CFrame * CFrame.new(0, -1.5, 0)).Position end
    elseif boneName == "RightUpperLeg" then
        part = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLeg")
    elseif boneName == "RightLowerLeg" then
        part = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLeg")
        if part then return (part.CFrame * CFrame.new(0, -0.8, 0)).Position end
    elseif boneName == "RightFoot" then
        part = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLeg")
        if part then return (part.CFrame * CFrame.new(0, -1.5, 0)).Position end
    end

    return part and part.Position
end
local FontLoadingCapable = writefile and isfile and getcustomasset
local function LoadCustomFont(Name, Link)
    if not FontLoadingCapable then return end
    local fn = Name:gsub("%s+", "")
    local okDL, data = pcall(function() return game:HttpGet(Link) end)
    if not okDL or not data or data == "" then return end
    local okWrite = pcall(writefile, fn .. ".ttf", data)
    if not okWrite then return end
    local okConfig = pcall(function()
        local config = {
            name = fn,
            faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(fn .. ".ttf") } }
        }
        writefile(fn .. ".ttf.json", HttpService:JSONEncode(config))
    end)
    if not okConfig then return end
    local okLoad, font = pcall(Font.new, getcustomasset(fn .. ".ttf.json"), Enum.FontWeight.Regular)
    if okLoad and font then
        ESPFonts.Loaded[Name] = font
    end
end

local function AttemptLoadFonts()
    if not FontLoadingCapable then FontsStillLoading = false; return end
    for Name, Table in pairs(FontsToDownload) do
        if ESPFonts.Loaded[Name] then continue end
        LoadCustomFont(Name, Table.TTF)
    end
    FontsStillLoading = false
    for Name in pairs(FontsToDownload) do
        if not ESPFonts.Loaded[Name] then FontsStillLoading = true; break end
    end
end

task.spawn(function()
    task.wait(1)
    AttemptLoadFonts()
end)
--// variables
local TrackedInstances = {}

--// functions
local function GetInstanceFromPath(path)
    local parts = string.split(path, ".")
    local current = game
    for _, partName in ipairs(parts) do
        if current == game and (partName == "Workspace" or partName == "workspace") then
            current = Workspace
        elseif current == game and partName == "Players" then
            current = Players
        else
            local found = current:FindFirstChild(partName)
            if found then
                current = found
            else
                return nil
            end
        end
    end
    return current ~= game and current or nil
end

local function CreateLine(parent)
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.BackgroundColor3 = ESPConfig.BoxColor
    line.Parent = parent

    local outline = Instance.new("Frame")
    outline.BorderSizePixel = 0
    outline.BackgroundColor3 = ESPConfig.Outlines.Color
    outline.ZIndex = 0
    outline.Parent = line

    return line, outline
end

local CreateESPObj = LPHNoVirtualize(function(name)
    local espObj = {
        Visible = false,
        Lines = {},
        Outlines = {},
        CornerLines = {},
        CornerOutlines = {},

        FlagLabels = {},
        LastVisCheck = 0,
        CachedModelVisible = true
    }

    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Name = "ESPObj"
    container.Parent = ScreenGui
    espObj.Container = container

    local boxFill = Instance.new("Frame")
    boxFill.BorderSizePixel = 0
    boxFill.ZIndex = 0
    boxFill.Visible = false
    boxFill.Parent = container
    espObj.BoxFill = boxFill

    local fillGradient = Instance.new("UIGradient")
    fillGradient.Parent = boxFill
    espObj.BoxFillGradient = fillGradient

    for i = 1, 4 do
        local line, outline = CreateLine(container)
        espObj.Lines[i] = line
        espObj.Outlines[i] = outline
    end

    for i = 1, 8 do
        local line, outline = CreateLine(container)
        line.Visible = false
        outline.Visible = false
        espObj.CornerLines[i] = line
        espObj.CornerOutlines[i] = outline
    end

    local function SetupLabel(label)
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0, 100, 0, ESPConfig.TextSize)
        label.Font = _fontMap[ESPConfig.Font] or Enum.Font.Code
        if ESPFonts.Loaded[ESPConfig.Font] then
            label.FontFace = ESPFonts.Loaded[ESPConfig.Font]
        end
        label.TextSize = ESPConfig.TextSize
        label.TextColor3 = ESPConfig.TextColor
        label.TextStrokeTransparency = 1
        label.ZIndex = 2
        label.Parent = container

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = ESPConfig.TextOutlineColor or ESPConfig.Outlines.Color
        stroke.LineJoinMode = Enum.LineJoinMode.Miter
        stroke.Enabled = ESPConfig.TextOutline
        stroke.Parent = label
        labelStrokeMap[label] = stroke
    end

    local nameText = Instance.new("TextLabel")
    SetupLabel(nameText)
    nameText.TextYAlignment = Enum.TextYAlignment.Bottom
    nameText.RichText = true
    nameText.Text = name
    nameText.Visible = ESPConfig.Names
    espObj.Text = nameText

    espObj.TeamText = nil
    espObj.TeamTextStroke = nil
    espObj.FriendlyText = nil
    espObj.FriendlyTextStroke = nil

    local distText = Instance.new("TextLabel")
    SetupLabel(distText)
    distText.TextYAlignment = Enum.TextYAlignment.Top
    distText.Visible = false
    espObj.DistanceText = distText

    local weaponText = Instance.new("TextLabel")
    SetupLabel(weaponText)
    weaponText.TextYAlignment = Enum.TextYAlignment.Top
    weaponText.Visible = false
    espObj.WeaponText = weaponText

    local healthBarOutline = Instance.new("Frame")
    healthBarOutline.BackgroundColor3 = ESPConfig.Outlines.Color
    healthBarOutline.BorderSizePixel = 0
    healthBarOutline.Visible = false
    healthBarOutline.ZIndex = 1
    healthBarOutline.Parent = container
    espObj.HealthBarOutline = healthBarOutline

    local healthBarContainer = Instance.new("Frame")
    healthBarContainer.BackgroundTransparency = 1
    healthBarContainer.ClipsDescendants = true
    healthBarContainer.BorderSizePixel = 0
    healthBarContainer.ZIndex = 2
    healthBarContainer.Parent = healthBarOutline
    espObj.HealthBarContainer = healthBarContainer

    local healthBar = Instance.new("Frame")
    healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    healthBar.BorderSizePixel = 0
    healthBar.ZIndex = 2
    healthBar.Parent = healthBarContainer
    espObj.HealthBar = healthBar

    local healthGradient = Instance.new("UIGradient")
    healthGradient.Enabled = ESPConfig.HealthBar.Gradient.Enabled
    healthGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ESPConfig.HealthBar.Gradient.Color1),
        ColorSequenceKeypoint.new(0.5, ESPConfig.HealthBar.Gradient.Color2),
        ColorSequenceKeypoint.new(1, ESPConfig.HealthBar.Gradient.Color3)
    })
    healthGradient.Parent = healthBar
    espObj.HealthGradient = healthGradient

    local healthText = Instance.new("TextLabel")
    SetupLabel(healthText)
    healthText.TextYAlignment = Enum.TextYAlignment.Center
    healthText.ZIndex = 3
    healthText.Visible = false
    espObj.HealthText = healthText

    for i = 1, 5 do -- max 5 flags
        local flag = Instance.new("TextLabel")
        SetupLabel(flag)
        flag.TextSize = ESPConfig.Flags.TextSize
        flag.Font = _fontMap[ESPConfig.Flags.Font] or Enum.Font.Code
        if ESPFonts.Loaded[ESPConfig.Flags.Font] then
            flag.FontFace = ESPFonts.Loaded[ESPConfig.Flags.Font]
        end
        flag.Visible = false
        espObj.FlagLabels[i] = flag
    end

    espObj.Bones = {}
    espObj.BoneOutlines = {}
    for i = 1, #SKELETON_BONE_DEFS do
        local outline = Instance.new("Frame")
        outline.BorderSizePixel = 0
        outline.Visible = false
        outline.ZIndex = 1
        outline.Parent = container
        espObj.BoneOutlines[i] = outline

        local bone = Instance.new("Frame")
        bone.BorderSizePixel = 0
        bone.Visible = false
        bone.ZIndex = 2
        bone.Parent = container
        espObj.Bones[i] = bone
    end

    local arrowInner = Instance.new("TextLabel")
    arrowInner.BackgroundTransparency = 1
    arrowInner.Text = "▲"
    arrowInner.TextColor3 = ESPConfig.OffScreenArrows.Color
    arrowInner.TextSize = ESPConfig.OffScreenArrows.Size
    arrowInner.Font = Enum.Font.SourceSans
    arrowInner.Size = UDim2.new(0, ESPConfig.OffScreenArrows.Size * 2, 0, ESPConfig.OffScreenArrows.Size * 2)
    arrowInner.ZIndex = 100
    arrowInner.Visible = false
    arrowInner.Parent = ScreenGui
    espObj.ArrowInner = arrowInner

    local arrowOutline = Instance.new("TextLabel")
    arrowOutline.BackgroundTransparency = 1
    arrowOutline.Text = "▲"
    arrowOutline.TextColor3 = ESPConfig.OffScreenArrows.OutlineColor
    arrowOutline.TextSize = ESPConfig.OffScreenArrows.Size + 2
    arrowOutline.Font = Enum.Font.SourceSans
    arrowOutline.Size = UDim2.new(0, (ESPConfig.OffScreenArrows.Size + 2) * 2, 0, (ESPConfig.OffScreenArrows.Size + 2) * 2)
    arrowOutline.ZIndex = 99
    arrowOutline.Visible = false
    arrowOutline.Parent = ScreenGui
    espObj.ArrowOutline = arrowOutline

    local function makeArrowLabel()
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(0, 150, 0, 12)
        l.TextStrokeTransparency = 1
        l.ZIndex = 110
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.Visible = false
        l.Parent = ScreenGui
        local stroke = Instance.new("UIStroke")
        stroke.Parent = l
        labelStrokeMap[l] = stroke
        return l
    end
    espObj.ArrowName = makeArrowLabel()
    espObj.ArrowDist = makeArrowLabel()

    espObj.Adornments = {}
    espObj.Highlight = nil

    espObj.Destroy = function()
        container:Destroy()
        if espObj.Highlight then espObj.Highlight:Destroy() end
        if espObj.MeshShell then espObj.MeshShell:Destroy() end
        for _, a in pairs(espObj.Adornments) do a:Destroy() end
        if espObj.ArrowInner then espObj.ArrowInner:Destroy() end
        if espObj.ArrowOutline then espObj.ArrowOutline:Destroy() end
        if espObj.ArrowName then espObj.ArrowName:Destroy() end
        if espObj.ArrowDist then espObj.ArrowDist:Destroy() end
    end

    return espObj
end)

local UpdateESPObj = LPHNoVirtualize(function(espObj, position, size, name, distanceStuds, instance, isCheap, nonHuman,
                                              noStatus,
                                              configOverride, onScreen)
    local cfgCache = {}
    local function GetCfg(path)
        local cached = cfgCache[path]
        if cached ~= nil then return cached end
        local keys = path:split(".")
        local current = configOverride
        local default = ESPConfig

        local foundOverride = true
        for _, key in ipairs(keys) do
            if type(current) == "table" and current[key] ~= nil then
                current = current[key]
            else
                foundOverride = false
                break
            end
        end

        if foundOverride then
            cfgCache[path] = current
            return current
        end

        local currentDefault = default
        for _, key in ipairs(keys) do
            currentDefault = currentDefault[key]
        end
        cfgCache[path] = currentDefault
        return currentDefault
    end

    local _now = tick()
    local humanoid = not nonHuman and instance:FindFirstChild("Humanoid") or nil

    --// chams
    local isDead = (humanoid and humanoid.Health <= 0)
    local chamsEnabled = GetCfg("Chams.Enabled")
    if chamsEnabled and not isDead then
        local chamType = GetCfg("Chams.Type")
        if chamType == "Highlight" and (instance:IsA("Model") or instance:IsA("BasePart")) then
            -- cleanup mesh chams
            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end
            if not espObj.Highlight then
                espObj.Highlight = Instance.new("Highlight")
            end
            local h = espObj.Highlight
            h.Parent = ChamsContainer
            h.Adornee = instance
            h.FillColor = GetCfg("Chams.Highlight.FillColor")
            h.FillTransparency = GetCfg("Chams.Highlight.FillTransparency")
            h.OutlineColor = GetCfg("Chams.Highlight.OutlineColor")
            h.OutlineTransparency = GetCfg("Chams.Highlight.OutlineTransparency")
            h.DepthMode = GetCfg("Chams.Highlight.VisibleCheck") and Enum.HighlightDepthMode.Occluded or
                Enum.HighlightDepthMode.AlwaysOnTop
            h.Enabled = true

            -- hide adornments
            if espObj.Adornments then
                for _, a in pairs(espObj.Adornments) do a.Visible = false end
            end
        elseif chamType == "Adornment" then
            if espObj.Highlight then
                espObj.Highlight:Destroy()
                espObj.Highlight = nil
            end
            -- cleanup mesh chams
            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end

            local parts = instance:IsA("Model") and instance:GetChildren() or { instance }
            local idx = 0

            local visCheck = GetCfg("Chams.Adornment.VisibleCheck")
            local visRate = GetCfg("VisibilityCheckRate") or 0.1
            local now = _now
            local last = espObj.LastVisCheck or 0
            local shouldUpdate = (now - last) > visRate

            if visCheck and shouldUpdate then
                espObj.LastVisCheck = now
                local ignore = { UIContainer }
                if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
                if instance:IsA("Model") then
                    for _, v in ipairs(instance:GetDescendants()) do table.insert(ignore, v) end
                else
                    table.insert(ignore, instance)
                end

                local root = instance:IsA("Model") and
                    (instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart")) or
                    instance
                if root and root:IsA("BasePart") then
                    local obscuring = Camera:GetPartsObscuringTarget({ root.Position }, ignore)
                    espObj.CachedModelVisible = (#obscuring == 0)
                end
            end

            local occludedColor = GetCfg("Chams.Adornment.Color")
            local visibleColor = GetCfg("Chams.Adornment.VisibleColor")
            local finalColor = (visCheck and espObj.CachedModelVisible) and visibleColor or occludedColor

            for _, p in ipairs(parts) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    idx = idx + 1
                    local a = espObj.Adornments[idx]
                    if not a then
                        a = Instance.new("BoxHandleAdornment")
                        a.Name = "Cham"
                        a.Parent = ChamsContainer
                        espObj.Adornments[idx] = a
                    end

                    a.Adornee = p
                    a.Size = p.Size
                    a.Color3 = finalColor
                    a.Transparency = GetCfg("Chams.Adornment.Transparency")
                    a.AlwaysOnTop = GetCfg("Chams.Adornment.AlwaysOnTop")
                    a.ZIndex = 10
                    a.Visible = true
                end
            end
            -- hide unused adornments
            for i = idx + 1, #espObj.Adornments do
                espObj.Adornments[i].Visible = false
            end
        elseif chamType == "MeshChams" then
            -- player characters only
            local playerOwner = Players:GetPlayerFromCharacter(instance)
            if not playerOwner then
                if espObj.MeshShell then
                    espObj.MeshShell:Destroy()
                    espObj.MeshShell = nil
                    espObj.MeshHighlight = nil
                end
            else
                -- hide unused chams
                if espObj.Highlight then
                    espObj.Highlight:Destroy()
                    espObj.Highlight = nil
                end
                if espObj.Adornments then
                    for _, a in pairs(espObj.Adornments) do a.Visible = false end
                end

                -- build the shell model
                if not espObj.MeshShell or not espObj.MeshShell.Parent then
                    if espObj.MeshShell then
                        espObj.MeshShell:Destroy()
                        espObj.MeshShell = nil
                        espObj.MeshHighlight = nil
                    end

                    CleanupCharacterMeshChams(instance)

                    local r6Parts      = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
                    local r15Parts     = {
                        "Head", "UpperTorso", "LowerTorso",
                        "LeftUpperArm", "LeftLowerArm", "LeftHand",
                        "RightUpperArm", "RightLowerArm", "RightHand",
                        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
                        "RightUpperLeg", "RightLowerLeg", "RightFoot",
                    }
                    local humanoidInst = instance:FindFirstChild("Humanoid")
                    local isR15        = humanoidInst and (humanoidInst.RigType == Enum.HumanoidRigType.R15)
                    local bodyParts    = isR15 and r15Parts or r6Parts

                    local shellModel   = Instance.new("Model")
                    shellModel.Name    = "ChamShells"
                    shellModel:SetAttribute("SensoryESP_MeshCham", true)
                    shellModel:SetAttribute("SensoryESP_RunId", CurrentRunId)
                    shellModel.Parent = instance

                    for _, partName in ipairs(bodyParts) do
                        local realPart = instance:FindFirstChild(partName)
                        if realPart and realPart:IsA("BasePart") then
                            local shell = Instance.new("Part")
                            shell.Name  = "ChamShell_" .. partName
                            shell:SetAttribute("SensoryESP_MeshCham", true)
                            shell:SetAttribute("SensoryESP_RunId", CurrentRunId)
                            shell.Size         = realPart.Size * 1.015
                            shell.Transparency = 0.9999999
                            shell.CastShadow   = false
                            shell.CanCollide   = false
                            shell.CanQuery     = false
                            shell.CanTouch     = false
                            shell.Anchored     = false
                            shell.Massless     = true
                            shell.CFrame       = realPart.CFrame
                            shell.Parent       = shellModel

                            local weld         = Instance.new("Weld")
                            weld.Part0         = shell
                            weld.Part1         = realPart
                            weld.C0            = CFrame.new()
                            weld.C1            = CFrame.new()
                            weld.Parent        = shell
                        end
                    end

                    -- one highlight per shell
                    local hl = Instance.new("Highlight")
                    hl.Name  = "ChamShellHighlight"
                    hl:SetAttribute("SensoryESP_MeshCham", true)
                    hl:SetAttribute("SensoryESP_RunId", CurrentRunId)
                    hl.Adornee           = shellModel
                    hl.Parent            = shellModel
                    espObj.MeshShell     = shellModel
                    espObj.MeshHighlight = hl
                end

                -- update highlight
                if espObj.MeshHighlight then
                    local hl               = espObj.MeshHighlight
                    hl.FillColor           = GetCfg("Chams.MeshChams.FillColor")
                    hl.FillTransparency    = GetCfg("Chams.MeshChams.FillTransparency")
                    hl.OutlineColor        = GetCfg("Chams.MeshChams.OutlineColor")
                    hl.OutlineTransparency = GetCfg("Chams.MeshChams.OutlineTransparency")
                    hl.DepthMode           = GetCfg("Chams.MeshChams.VisibleCheck")
                        and Enum.HighlightDepthMode.Occluded
                        or Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Enabled             = true
                end
            end
        end
    else
        -- hide inactive chams
        if espObj.Highlight then
            espObj.Highlight:Destroy()
            espObj.Highlight = nil
        end
        if espObj.Adornments then
            for _, a in pairs(espObj.Adornments) do a.Visible = false end
        end
        if espObj.MeshShell then
            espObj.MeshShell:Destroy()
            espObj.MeshShell = nil
            espObj.MeshHighlight = nil
        end
    end

    local function ApplyTextOutline(label, style, color)
        local stroke = labelStrokeMap[label] or label:FindFirstChildOfClass("UIStroke")
        if not stroke then return end
        if style == "None" then
            stroke.Enabled = false
        elseif style == "Shadow" then
            stroke.Enabled = true
            stroke.Thickness = 1
            stroke.Color = color or Color3.fromRGB(0, 0, 0)
        else
            stroke.Enabled = true
            stroke.Thickness = 1
            stroke.Color = color or Color3.fromRGB(0, 0, 0)
        end
    end

    --// offscreen arrows
    if espObj.ArrowInner and GetCfg("OffScreenArrows.Enabled") and instance:IsA("Model") then
        local rp = instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart")
        if rp then
            local sp = Camera:WorldToViewportPoint(rp.Position)
            local vp = Camera.ViewportSize
            local cx, cy = vp.X / 2, vp.Y / 2
            local onVp = sp.Z > 0 and sp.X >= 0 and sp.X <= vp.X and sp.Y >= 0 and sp.Y <= vp.Y
            if not onVp then
                local orbit = GetCfg("OffScreenArrows.OrbitRadius")
                local nx, ny, rot
                if GetCfg("OffScreenArrows.ArrowMode") == "Compass" then
                    -- compass direction
                    local playerRoot = LocalPlayer.Character and (
                        LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or
                        LocalPlayer.Character:FindFirstChild("Torso") or
                        LocalPlayer.Character:FindFirstChildWhichIsA("BasePart")
                    )
                    local fromPos = playerRoot and playerRoot.Position or Camera.CFrame.Position
                    local toTarget = (Vector3.new(rp.Position.X, 0, rp.Position.Z) - Vector3.new(fromPos.X, 0, fromPos.Z)).Unit
                    local rel = playerRoot and playerRoot.CFrame:VectorToObjectSpace(toTarget) or toTarget
                    nx, ny = rel.X, rel.Z
                    rot = math.deg(math.atan2(rel.Z, rel.X)) + 90
                else
                    -- camera direction
                    local dir = (rp.Position - Camera.CFrame.Position).Unit
                    local viewDir = Camera.CFrame:VectorToObjectSpace(dir)
                    nx, ny = viewDir.X, -viewDir.Y
                    rot = math.deg(math.atan2(-viewDir.Y, viewDir.X)) + 90
                end
                local d = math.sqrt(nx * nx + ny * ny)
                if d > 0.001 then
                    nx, ny = nx / d, ny / d
                else
                    nx, ny = 0, -1
                end
                local ax, ay = cx + nx * orbit, cy + ny * orbit
                local sz = GetCfg("OffScreenArrows.Size")
                local col = GetCfg("OffScreenArrows.Color")

                if GetCfg("OffScreenArrows.Outline") then
                    espObj.ArrowOutline.TextSize = sz + 2
                    espObj.ArrowOutline.TextColor3 = GetCfg("OffScreenArrows.OutlineColor")
                    espObj.ArrowOutline.Position = UDim2.new(0, ax - sz - 2, 0, ay - sz - 2)
                    espObj.ArrowOutline.Rotation = rot
                    espObj.ArrowOutline.Visible = true
                else
                    espObj.ArrowOutline.Visible = false
                end

                local arrowFontObj = _fontMap[GetCfg("OffScreenArrows.Font")] or Enum.Font.SourceSans
                espObj.ArrowInner.Text = "▲"
                espObj.ArrowInner.Font = arrowFontObj
                espObj.ArrowInner.TextSize = sz
                espObj.ArrowInner.TextColor3 = col
                espObj.ArrowInner.Position = UDim2.new(0, ax - sz, 0, ay - sz)
                espObj.ArrowInner.Size = UDim2.new(0, sz * 2, 0, sz * 2)
                espObj.ArrowInner.Rotation = rot
                espObj.ArrowInner.Visible = true

                -- arrow labels
                local textY = ay + sz + 4

                if GetCfg("OffScreenArrows.Names.Enabled") and name and name ~= "" then
                    local nFont = GetCfg("OffScreenArrows.Names.Font")
                    local nTxtSz = GetCfg("OffScreenArrows.Names.TextSize")
                    local nFontObj = _fontMap[nFont] or Enum.Font.Code
                    local nFontLoaded = ESPFonts.Loaded[nFont]
                    local nSide = GetCfg("OffScreenArrows.Names.Side")
                    local nGap = GetCfg("OffScreenArrows.Names.Gap") or 4
                    local nCol = GetCfg("OffScreenArrows.Names.Color")
                    local nOut = GetCfg("OffScreenArrows.Names.Outline")
                    local nOutCol = GetCfg("OffScreenArrows.Names.OutlineColor")
                    espObj.ArrowName.Font = nFontObj
                    if nFontLoaded then espObj.ArrowName.FontFace = nFontLoaded end
                    espObj.ArrowName.TextSize = nTxtSz
                    espObj.ArrowName.TextColor3 = nCol
                    espObj.ArrowName.Text = name
                    if nSide == "Top" then
                        espObj.ArrowName.Position = UDim2.new(0, ax - 75, 0, ay - sz - nGap - nTxtSz)
                    elseif nSide == "Left" then
                        espObj.ArrowName.Position = UDim2.new(0, ax - sz - nGap - 150, 0, ay - 6)
                    elseif nSide == "Right" then
                        espObj.ArrowName.Position = UDim2.new(0, ax + sz + nGap, 0, ay - 6)
                    else
                        espObj.ArrowName.Position = UDim2.new(0, ax - 75, 0, textY)
                        textY = textY + nTxtSz + 1
                    end
                    ApplyTextOutline(espObj.ArrowName, nOut and "Full" or "None", nOutCol or Color3.fromRGB(0, 0, 0))
                    espObj.ArrowName.Visible = true
                else
                    espObj.ArrowName.Visible = false
                end

                if GetCfg("OffScreenArrows.Distance.Enabled") then
                    local dFont = GetCfg("OffScreenArrows.Distance.Font")
                    local dTxtSz = GetCfg("OffScreenArrows.Distance.TextSize")
                    local dFontObj = _fontMap[dFont] or Enum.Font.Code
                    local dFontLoaded = ESPFonts.Loaded[dFont]
                    local dSide = GetCfg("OffScreenArrows.Distance.Side")
                    local dGap = GetCfg("OffScreenArrows.Distance.Gap") or 2
                    local dCol = GetCfg("OffScreenArrows.Distance.Color")
                    local dOut = GetCfg("OffScreenArrows.Distance.Outline")
                    local dOutCol = GetCfg("OffScreenArrows.Distance.OutlineColor")
                    local dUnit = GetCfg("Distance.Unit")
                    local dVal
                    if dUnit == "Meters" then
                        dVal = math.floor(distanceStuds / GetCfg("Distance.StudsPerMeter"))
                    else
                        dVal = math.floor(distanceStuds)
                    end
                    espObj.ArrowDist.Font = dFontObj
                    if dFontLoaded then espObj.ArrowDist.FontFace = dFontLoaded end
                    espObj.ArrowDist.TextSize = dTxtSz
                    espObj.ArrowDist.TextColor3 = dCol
                    espObj.ArrowDist.Text = dVal .. GetCfg("Distance.Ending")
                    if dSide == "Top" then
                        espObj.ArrowDist.Position = UDim2.new(0, ax - 75, 0, ay - sz - dGap - dTxtSz)
                    elseif dSide == "Left" then
                        espObj.ArrowDist.Position = UDim2.new(0, ax - sz - dGap - 150, 0, ay - 6)
                    elseif dSide == "Right" then
                        espObj.ArrowDist.Position = UDim2.new(0, ax + sz + dGap, 0, ay - 6)
                    else
                        espObj.ArrowDist.Position = UDim2.new(0, ax - 75, 0, textY)
                    end
                    ApplyTextOutline(espObj.ArrowDist, dOut and "Full" or "None", dOutCol or Color3.fromRGB(0, 0, 0))
                    espObj.ArrowDist.Visible = true
                else
                    espObj.ArrowDist.Visible = false
                end
            else
                espObj.ArrowInner.Visible = false
                espObj.ArrowOutline.Visible = false
                espObj.ArrowName.Visible = false
                espObj.ArrowDist.Visible = false
            end
        else
            espObj.ArrowInner.Visible = false
            espObj.ArrowOutline.Visible = false
            espObj.ArrowName.Visible = false
            espObj.ArrowDist.Visible = false
        end
    else
        if espObj.ArrowInner then
            espObj.ArrowInner.Visible = false
            espObj.ArrowOutline.Visible = false
            espObj.ArrowName.Visible = false
            espObj.ArrowDist.Visible = false
        end
    end

    if not onScreen or not position or not size then
        espObj.Container.Visible = false
        return
    end

    espObj.Container.Visible = true
    espObj.Container.ZIndex = nonHuman and 1 or 10
    if GetCfg("Names") then
        espObj.Text.Text = name
    end

    local textOutlineStyle = GetCfg("TextOutlineStyle")
    -- legacy outline value
    if GetCfg("TextOutline") == false then textOutlineStyle = "None" end
    local textOutlineColor = GetCfg("TextOutlineColor") or GetCfg("Outlines.Color")

    local t = GetCfg("BoxThickness")
    local o = GetCfg("Outlines.Thickness")
    local textSize = GetCfg("TextSize")
    local textColor = GetCfg("TextColor")
    local teamOwner = not nonHuman and instance:IsA("Model") and Players:GetPlayerFromCharacter(instance) or nil
    if teamOwner then
        local playerStatus = get_player_status(teamOwner)
        if playerStatus == "Enemy" then
            textColor = GetCfg("PlayerStatusColors.Target")
        elseif playerStatus == "Friendly" then
            textColor = GetCfg("PlayerStatusColors.Friendly")
        end
    end
    local fontName = GetCfg("Font")
    local fontObj = _fontMap[fontName] or Enum.Font.Code
    local fontLoaded = ESPFonts.Loaded[fontName]
    local boxColor = GetCfg("BoxColor")
    --// labels
    espObj.Text.TextSize = textSize
    espObj.Text.TextColor3 = textColor
    espObj.Text.Font = fontObj
    if fontLoaded then
        espObj.Text.FontFace = fontLoaded
    end
    ApplyTextOutline(espObj.Text, textOutlineStyle, textOutlineColor)

    do
        local distFont = GetCfg("Distance.Font")
        local distFontObj = _fontMap[distFont] or Enum.Font.Code
        espObj.DistanceText.TextSize = GetCfg("Distance.TextSize") or textSize
        espObj.DistanceText.TextColor3 = GetCfg("Distance.Color")
        espObj.DistanceText.Font = distFontObj
        if ESPFonts.Loaded[distFont] then
            espObj.DistanceText.FontFace = ESPFonts.Loaded[distFont]
        end
        ApplyTextOutline(espObj.DistanceText, GetCfg("Distance.OutlineStyle") or textOutlineStyle, textOutlineColor)
    end

    do
        local wepFont = GetCfg("Weapon.Font")
        local wepFontObj = _fontMap[wepFont] or Enum.Font.Code
        espObj.WeaponText.TextSize = GetCfg("Weapon.TextSize") or textSize
        espObj.WeaponText.TextColor3 = GetCfg("Weapon.Color")
        espObj.WeaponText.Font = wepFontObj
        if ESPFonts.Loaded[wepFont] then
            espObj.WeaponText.FontFace = ESPFonts.Loaded[wepFont]
        end
        ApplyTextOutline(espObj.WeaponText, GetCfg("Weapon.OutlineStyle") or textOutlineStyle, textOutlineColor)
    end

    local px, py = math.floor(position.X), math.floor(position.Y)
    local sx, sy = math.floor(size.X), math.floor(size.Y)
    local x, y = math.floor(px - sx / 2), math.floor(py - sy / 2)

    -- health layout value
    local health, maxHealth, healthPercent = 100, 100, 1
    if humanoid then
        health = humanoid.Health
        maxHealth = humanoid.MaxHealth
        healthPercent = math.clamp(health / maxHealth, 0, 1)
    end

    -- health bar offsets
    local topOffset = 0
    local bottomOffset = 0
    local leftOffset = 0
    local rightOffset = 0
    if GetCfg("HealthBar.Enabled") and instance:IsA("Model") and humanoid then
        local hpPos = GetCfg("HealthBar.Position")
        local thickness = GetCfg("HealthBar.Width") + 2 + GetCfg("HealthBar.SideGap")
        local isRight = GetCfg("Flags.Position") == "Right"
        local textExtra = (GetCfg("HealthBar.ShowText") and health < maxHealth) and 20 or 0

        if hpPos == "Top" then
            topOffset = thickness
        elseif hpPos == "Bottom" then
            bottomOffset = thickness
        elseif hpPos == "Left" then
            leftOffset = thickness + textExtra
        elseif hpPos == "Right" then
            rightOffset = thickness + textExtra
        end
    end
    if isCheap then
        for i = 1, 4 do
            espObj.Lines[i].Visible = false
            espObj.Outlines[i].Visible = false
        end
        espObj.HealthBarOutline.Visible = false
        espObj.HealthText.Visible = false
        espObj.WeaponText.Visible = false
        for _, l in ipairs(espObj.FlagLabels) do l.Visible = false end

        local distUnit = GetCfg("Distance.Unit")
        local distVal = distanceStuds
        if distUnit == "Meters" then
            distVal = math.floor(distanceStuds / GetCfg("Distance.StudsPerMeter"))
        else
            distVal = math.floor(distanceStuds)
        end

        espObj.Text.Text = name .. " " .. distVal .. GetCfg("Distance.Ending")
        espObj.Text.Position = UDim2.new(0, px - 50, 0, py - (textSize / 2))
        espObj.Text.Visible = GetCfg("Names")
        espObj.DistanceText.Visible = false
        return
    end

    -- top
    espObj.Lines[1].Position = UDim2.new(0, x, 0, y)
    espObj.Lines[1].Size = UDim2.new(0, sx, 0, t)
    -- bottom
    espObj.Lines[2].Position = UDim2.new(0, x, 0, y + sy)
    espObj.Lines[2].Size = UDim2.new(0, sx + t, 0, t)
    -- left
    espObj.Lines[3].Position = UDim2.new(0, x, 0, y)
    espObj.Lines[3].Size = UDim2.new(0, t, 0, sy)
    -- right
    espObj.Lines[4].Position = UDim2.new(0, x + sx, 0, y)
    espObj.Lines[4].Size = UDim2.new(0, t, 0, sy + t)

    local boxesEnabled = GetCfg("Boxes")
    local boxType = GetCfg("BoxType") or "Normal"
    local useCornerBoxes = boxType == "Corner"

    local outlineStyle = GetCfg("Outlines.Style")
    local outlineColor = GetCfg("Outlines.Color")
    local outlineThickness = GetCfg("Outlines.Thickness")
    -- legacy fill value
    if GetCfg("Outlines.Enabled") == false then outlineStyle = "None" end
    local outlineTransparency = 0
    local hasOutline = outlineStyle ~= "None"

    if useCornerBoxes then
        local cornerWidth = math.max(math.floor(sx * 0.25), t * 3)
        local cornerHeight = math.max(math.floor(sy * 0.25), t * 3)

        local cornerData = {
            { x,                        y,                         cornerWidth, t },
            { x,                        y,                         t,           cornerHeight },
            { x + sx - cornerWidth + t, y,                         cornerWidth, t },
            { x + sx,                   y,                         t,           cornerHeight },
            { x,                        y + sy,                    cornerWidth, t },
            { x,                        y + sy - cornerHeight + t, t,           cornerHeight },
            { x + sx - cornerWidth + t, y + sy,                    cornerWidth, t },
            { x + sx,                   y + sy - cornerHeight + t, t,           cornerHeight },
        }

        for i = 1, 8 do
            local data = cornerData[i]
            espObj.CornerLines[i].Position = UDim2.new(0, data[1], 0, data[2])
            espObj.CornerLines[i].Size = UDim2.new(0, data[3], 0, data[4])
        end
    end

    for i = 1, 4 do
        espObj.Lines[i].Visible = boxesEnabled and not useCornerBoxes
        espObj.Outlines[i].Visible = boxesEnabled and hasOutline and not useCornerBoxes

        espObj.Outlines[i].Position = UDim2.new(0, -outlineThickness, 0, -outlineThickness)
        espObj.Outlines[i].Size = UDim2.new(1, outlineThickness * 2, 1, outlineThickness * 2)
        espObj.Outlines[i].BackgroundTransparency = outlineTransparency
        espObj.Lines[i].BackgroundColor3 = boxColor
        espObj.Outlines[i].BackgroundColor3 = outlineColor
    end

    for i = 1, 8 do
        espObj.CornerLines[i].Visible = boxesEnabled and useCornerBoxes
        espObj.CornerOutlines[i].Visible = boxesEnabled and hasOutline and useCornerBoxes

        espObj.CornerOutlines[i].Position = UDim2.new(0, -outlineThickness, 0, -outlineThickness)
        espObj.CornerOutlines[i].Size = UDim2.new(1, outlineThickness * 2, 1, outlineThickness * 2)
        espObj.CornerOutlines[i].BackgroundTransparency = outlineTransparency
        espObj.CornerLines[i].BackgroundColor3 = boxColor
        espObj.CornerOutlines[i].BackgroundColor3 = outlineColor
    end

    --// box fill
    local fill = espObj.BoxFill
    local grad = espObj.BoxFillGradient
    if GetCfg("BoxFill.Enabled") and boxesEnabled then
        fill.Visible = true
        fill.Position = UDim2.new(0, x, 0, y)
        fill.Size = UDim2.new(0, sx, 0, sy)
        fill.BackgroundTransparency = GetCfg("BoxFill.Transparency")

        if GetCfg("BoxFill.Gradient.Enabled") then
            grad.Enabled = true
            local bgC1 = GetCfg("BoxFill.Gradient.Color1")
            local bgC2 = GetCfg("BoxFill.Gradient.Color2")
            local bgC3 = GetCfg("BoxFill.Gradient.Color3")
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, bgC1),
                ColorSequenceKeypoint.new(0.5, bgC2),
                ColorSequenceKeypoint.new(1, bgC3)
            })

            local rot = GetCfg("BoxFill.Gradient.Rotation")
            if GetCfg("BoxFill.Gradient.Animated") then
                local speed = GetCfg("BoxFill.Gradient.Speed")
                local dir = GetCfg("BoxFill.Gradient.Direction") == "Left" and -1 or 1
                rot = (rot + (_now * speed * dir)) % 360
            end
            grad.Rotation = rot
            fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            grad.Enabled = false
            fill.BackgroundColor3 = GetCfg("BoxFill.Color")
        end
    else
        fill.Visible = false
    end

    local nameY = y - textSize - (GetCfg("TextGap") or 0) - topOffset
    local leftTags = {}
    local rightTags = {}
    local silentTargetTag = nil

    if Library.HavocSilentTargetIndicatorEnabled and Library.HavocSilentTarget then
        local silentTarget = Library.HavocSilentTarget
        local isSilentTarget = instance == silentTarget

        if not isSilentTarget and instance:IsA("Model") and silentTarget:IsA("Model") then
            local instanceOwner = Players:GetPlayerFromCharacter(instance)
            local targetOwner = Players:GetPlayerFromCharacter(silentTarget)
            isSilentTarget = (instanceOwner and targetOwner and instanceOwner == targetOwner)
                or instance.Name == silentTarget.Name
        end

        if isSilentTarget then
            silentTargetTag = string.format(
                '<font color="%s">[TARGET]</font>',
                ColorToHex(Library.HavocSilentTargetIndicatorColor or Color3.fromRGB(255, 70, 70))
            )
            table.insert(rightTags, silentTargetTag)
        end
    end

    if GetCfg("TeamIndicator.Enabled") and teamOwner and teamOwner.Team then
        local teamColor = GetCfg("TeamIndicator.UseTeamColor") and teamOwner.TeamColor.Color or
        GetCfg("TeamIndicator.Color")
        local teamName = teamOwner.Team.Name
        local compactTeam = GetCfg("TeamIndicator.Compact") and CompactTeamName(teamName) or teamName
        local teamTag = string.format('<font color="%s">[%s]</font>', ColorToHex(teamColor), compactTeam)
        if GetCfg("TeamIndicator.Position") == "Left" then
            table.insert(leftTags, teamTag)
        else
            table.insert(rightTags, teamTag)
        end
    end

    local isFriendly = false
    if teamOwner and GetCfg("FriendlyIndicator.Enabled") then
        if GetCfg("FriendlyIndicator.CheckTeam") and LocalPlayer.Team ~= nil and teamOwner.Team == LocalPlayer.Team then
            isFriendly = true
        end
        if not isFriendly and GetCfg("FriendlyIndicator.CheckFriends") then
            local ok, result = pcall(function()
                return LocalPlayer:IsFriendsWith(teamOwner.UserId)
            end)
            if ok and result then
                isFriendly = true
            end
        end
    end

    if isFriendly then
        local friendlyTag = string.format('<font color="%s">%s</font>', ColorToHex(GetCfg("FriendlyIndicator.Color")),
            tostring(GetCfg("FriendlyIndicator.Text") or "[F]"))
        if GetCfg("FriendlyIndicator.Position") == "Left" then
            table.insert(leftTags, friendlyTag)
        else
            table.insert(rightTags, friendlyTag)
        end
    end

    local finalNameText = name
    if #leftTags > 0 then
        finalNameText = table.concat(leftTags, " ") .. " " .. finalNameText
    end
    if #rightTags > 0 then
        finalNameText = finalNameText .. " " .. table.concat(rightTags, " ")
    end

    if GetCfg("Names") then
        espObj.Text.Text = finalNameText
        espObj.Text.Position = UDim2.new(0, px - 50, 0, nameY)
        espObj.Text.Visible = true
    elseif silentTargetTag then
        espObj.Text.Text = silentTargetTag
        espObj.Text.Position = UDim2.new(0, px - 50, 0, nameY)
        espObj.Text.Visible = true
    else
        espObj.Text.Visible = false
    end

    local distGap = GetCfg("Distance.Gap") or 0
    local currentBottomY = y + sy + distGap + bottomOffset
    if GetCfg("Distance.Enabled") then
        espObj.DistanceText.Visible = true
        espObj.DistanceText.Position = UDim2.new(0, px - 50, 0, currentBottomY)

        local distUnit = GetCfg("Distance.Unit")
        local distVal = distanceStuds
        if distUnit == "Meters" then
            distVal = math.floor(distanceStuds / GetCfg("Distance.StudsPerMeter"))
        else
            distVal = math.floor(distanceStuds)
        end
        espObj.DistanceText.Text = distVal .. GetCfg("Distance.Ending")
        currentBottomY = currentBottomY + (GetCfg("Distance.TextSize") or textSize) + (GetCfg("Weapon.Gap") or 0)
    else
        espObj.DistanceText.Visible = false
    end

    --// weapon
    if GetCfg("Weapon.Enabled") then
        local weaponName = nil

        -- holding check
        local holding = instance:FindFirstChild("Holding")
        if holding then
            if holding:IsA("ValueBase") then
                if holding.Value then
                    weaponName = tostring(holding.Value)
                end
            else
                weaponName = holding.Name
            end
        end

        -- fallback
        if (not weaponName or weaponName == "" or weaponName == "nil")
            and (GetCfg("Weapon.UseToolFallback") or noStatus) then
            local tool = instance:FindFirstChildWhichIsA("Tool")
            if tool then weaponName = tool.Name end
        end

        if weaponName and weaponName ~= "" and weaponName ~= "nil" then
            espObj.WeaponText.Visible = true
            espObj.WeaponText.Text = weaponName
            espObj.WeaponText.Position = UDim2.new(0, px - 50, 0, currentBottomY)
        else
            espObj.WeaponText.Visible = false
        end
    else
        espObj.WeaponText.Visible = false
    end

    --// health bar
    if GetCfg("HealthBar.Enabled") and instance:IsA("Model") and humanoid then
        -- positioning
        local hpPos = GetCfg("HealthBar.Position")
        local isHorizontal = (hpPos == "Top" or hpPos == "Bottom")
        local hpWidth = GetCfg("HealthBar.Width")
        local hpSideGap = GetCfg("HealthBar.SideGap")
        local hpTextFollowBar = GetCfg("HealthBar.TextFollowBar")

        local hpOutlineStyle = GetCfg("HealthBar.Outline.Style")
        -- legacy bar value
        if GetCfg("HealthBar.Outline.Enabled") == false then hpOutlineStyle = "None" end
        espObj.HealthBarOutline.Visible = hpOutlineStyle ~= "None"
        espObj.HealthBarOutline.BackgroundTransparency = 0
        espObj.HealthBarOutline.BackgroundColor3 = GetCfg("HealthBar.Outline.Color")
        local barWidth

        if isHorizontal then
            barWidth = math.floor((sx + 1) * healthPercent)
            espObj.HealthBarOutline.Size = UDim2.new(0, sx + 3, 0, hpWidth + 2)

            if hpPos == "Top" then
                espObj.HealthBarOutline.Position = UDim2.new(0, x - 1, 0,
                    y - o - hpSideGap - hpWidth - 1)
            else -- bottom
                espObj.HealthBarOutline.Position = UDim2.new(0, x - 1, 0, y + sy + o + hpSideGap)
            end

            espObj.HealthBarContainer.Size = UDim2.new(0, barWidth, 0, hpWidth)
            espObj.HealthBarContainer.Position = UDim2.new(0, 1, 0, 1)

            espObj.HealthBar.Size = UDim2.new(0, sx + 1, 0, hpWidth)
            espObj.HealthBar.Position = UDim2.new(0, 0, 0, 0)
        else -- vertical
            local barHeight = math.floor((sy + 1) * healthPercent)
            espObj.HealthBarOutline.Size = UDim2.new(0, hpWidth + 2, 0, sy + 3)

            if hpPos == "Left" then
                espObj.HealthBarOutline.Position = UDim2.new(0,
                    x - o - hpSideGap - hpWidth - 1, 0, y - 1)
            else -- right
                espObj.HealthBarOutline.Position = UDim2.new(0, x + sx + o + hpSideGap, 0, y - 1)
            end

            espObj.HealthBarContainer.Size = UDim2.new(0, hpWidth, 0, barHeight)
            espObj.HealthBarContainer.Position = UDim2.new(0, 1, 0, (sy + 1) - barHeight + 1)

            espObj.HealthBar.Size = UDim2.new(0, hpWidth, 0, sy + 1)
            espObj.HealthBar.Position = UDim2.new(0, 0, 0, -(sy + 1 - barHeight))
        end

        -- color and gradient
        local gradientEnabled = GetCfg("HealthBar.Gradient.Enabled")
        espObj.HealthGradient.Enabled = gradientEnabled and not isHorizontal
        espObj.HealthGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, GetCfg("HealthBar.Gradient.Color1")),
            ColorSequenceKeypoint.new(0.5, GetCfg("HealthBar.Gradient.Color2")),
            ColorSequenceKeypoint.new(1, GetCfg("HealthBar.Gradient.Color3"))
        })
        local showText = GetCfg("HealthBar.ShowText")
        if GetCfg("HealthBar.HideWhenFullHP") and health >= maxHealth then
            showText = false
        end
        local followColorText = showText and GetCfg("HealthBar.FollowGradientColorText")
        local healthColor = Color3.fromHSV(healthPercent * 0.3, 1, 1)

        if gradientEnabled and not isHorizontal then
            espObj.HealthGradient.Rotation = 90
            espObj.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

            if followColorText then
                if healthPercent > 0.5 then
                    local ratio = (1 - healthPercent) * 2
                    healthColor = GetCfg("HealthBar.Gradient.Color1"):Lerp(GetCfg("HealthBar.Gradient.Color2"), ratio)
                else
                    local ratio = (0.5 - healthPercent) * 2
                    healthColor = GetCfg("HealthBar.Gradient.Color2"):Lerp(GetCfg("HealthBar.Gradient.Color3"), ratio)
                end
            end
        else
            espObj.HealthBar.BackgroundColor3 = healthColor
        end

        if showText then
            espObj.HealthText.Visible = true
            espObj.HealthText.Text = math.floor(health)
            espObj.HealthText.TextSize = GetCfg("HealthBar.TextSize")
            local hpFont = GetCfg("HealthBar.Font")
            local hpFontObj = _fontMap[hpFont] or Enum.Font.Code
            espObj.HealthText.Font = hpFontObj
            if ESPFonts.Loaded[hpFont] then
                espObj.HealthText.FontFace = ESPFonts.Loaded[hpFont]
            end
            espObj.HealthText.TextColor3 = followColorText and healthColor or GetCfg("TextColor")
            ApplyTextOutline(espObj.HealthText, hpOutlineStyle, textOutlineColor)

            if isHorizontal then
                barWidth = math.floor((sx + 1) * healthPercent)
                local barLeftX = x + barWidth - 1
                local textY = espObj.HealthBarOutline.Position.Y.Offset

                espObj.HealthText.TextXAlignment = Enum.TextXAlignment.Center
                espObj.HealthText.Size = UDim2.new(0, 0, 0, 0)

                if hpTextFollowBar then
                    espObj.HealthText.Position = UDim2.new(0, barLeftX, 0, textY + (hpWidth / 2) + 1)
                else
                    espObj.HealthText.Position = UDim2.new(0, x + sx, 0, textY + (hpWidth / 2) + 1)
                end
            else
                local barHeight = math.floor((sy + 1) * healthPercent)
                local barOutlineX = espObj.HealthBarOutline.Position.X.Offset
                local barTopY = y + (sy + 1) - barHeight

                espObj.HealthText.TextXAlignment = hpPos == "Left" and Enum.TextXAlignment.Right or
                    Enum.TextXAlignment.Left
                espObj.HealthText.Size = UDim2.new(0, 0, 0, 0)

                local textX = hpPos == "Left" and (barOutlineX - 2) or (barOutlineX + hpWidth + 4)
                local textY = hpTextFollowBar and barTopY or y
                espObj.HealthText.Position = UDim2.new(0, textX, 0, textY)
            end
        else
            espObj.HealthText.Visible = false
        end
    else
        espObj.HealthBarOutline.Visible = false
        espObj.HealthText.Visible = false
    end

    --// flags
    for _, label in ipairs(espObj.FlagLabels) do label.Visible = false end
    if GetCfg("Flags.Enabled") and instance:IsA("Model") and not noStatus and humanoid then
            local state = humanoid:GetState()
            local isMoving = humanoid.MoveDirection.Magnitude > 0
            local isJumping = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Freefall)
            local isSwimming = state == Enum.HumanoidStateType.Swimming
            local flagOptionsMoving = GetCfg("Flags.Options.Moving")
            local flagOptionsJumping = GetCfg("Flags.Options.Jumping")
            local flagOptionsSwimming = GetCfg("Flags.Options.Swimming")
            local flagOptionsIdle = GetCfg("Flags.Options.Idle")
            local flagColorsMoving = GetCfg("Flags.Colors.Moving")
            local flagColorsJumping = GetCfg("Flags.Colors.Jumping")
            local flagColorsSwimming = GetCfg("Flags.Colors.Swimming")
            local flagColorsIdle = GetCfg("Flags.Colors.Idle")
            local flagFont = GetCfg("Flags.Font")
            local flagTextSize = GetCfg("Flags.TextSize")
            local flagTextGap = GetCfg("Flags.TextGap")
            local flagGap = GetCfg("Flags.Gap") or 2
            local flagSideGap = GetCfg("Flags.SideGap")
            local flagPosition = GetCfg("Flags.Position")
            local flags = {}

            if isMoving and isJumping and flagOptionsMoving and flagOptionsJumping then
                table.insert(flags, { text = "Moving & Jumping", color = flagColorsMoving })
            elseif isJumping and flagOptionsJumping then
                table.insert(flags, { text = "Jumping", color = flagColorsJumping })
            elseif isMoving and flagOptionsMoving then
                table.insert(flags, { text = "Moving", color = flagColorsMoving })
            elseif isSwimming and flagOptionsSwimming then
                table.insert(flags, { text = "Swimming", color = flagColorsSwimming })
            elseif flagOptionsIdle then
                table.insert(flags, { text = "Idle", color = flagColorsIdle })
            end

            local isRight = flagPosition == "Right"
            local fx = isRight and (x + sx + flagSideGap + rightOffset) or
                (x - 100 - flagSideGap - leftOffset)
            local fy = y - flagGap

            if flagFont == "Smallest Pixel-7" then
                fy = fy - 3
            end

            local flagsFontObj = _fontMap[flagFont] or Enum.Font.Code
            local flagsFontLoaded = ESPFonts.Loaded[flagFont]
            local flagOutlineStyle = GetCfg("Flags.OutlineStyle") or textOutlineStyle

            for i, data in ipairs(flags) do
                local label = espObj.FlagLabels[i]
                if label then
                    label.Visible = true
                    label.Text = data.text
                    label.TextColor3 = data.color
                    label.Font = flagsFontObj
                    if flagsFontLoaded then
                        label.FontFace = flagsFontLoaded
                    end
                    label.TextSize = flagTextSize
                    label.TextXAlignment = isRight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
                    label.Position = UDim2.new(0, fx, 0,
                        fy + (i - 1) * (flagTextSize + flagTextGap))
                    ApplyTextOutline(label, flagOutlineStyle, textOutlineColor)
                end
        end
    end

    --// skeleton
    if GetCfg("Skeleton.Enabled") and instance:IsA("Model") then
        local skeletonOutline = GetCfg("Skeleton.Outline")
        local skeletonColor = GetCfg("Skeleton.Color")
        local skeletonOutlineColor = GetCfg("Skeleton.OutlineColor")

        local bonePositions = {}
        for _, def in ipairs(SKELETON_BONE_DEFS) do
            for _, bn in ipairs(def) do
                if bonePositions[bn] == nil then
                    local wp = GetBonePosition(instance, bn)
                    local sp, on = wp and WtS(Camera, wp)
                    bonePositions[bn] = (wp and on) and Vector2.new(sp.X, sp.Y) or false
                end
            end
        end

        for i, def in ipairs(SKELETON_BONE_DEFS) do
            local pA = bonePositions[def[1]]
            local pB = bonePositions[def[2]]

            if pA and pB then
                if skeletonOutline then
                    DrawLine(espObj.BoneOutlines[i], pA, pB, 3, skeletonOutlineColor)
                else
                    espObj.BoneOutlines[i].Visible = false
                end

                DrawLine(espObj.Bones[i], pA, pB, 1, skeletonColor)
            else
                espObj.Bones[i].Visible = false
                espObj.BoneOutlines[i].Visible = false
            end
        end
    else
        if espObj.Bones then
            for _, b in ipairs(espObj.Bones) do b.Visible = false end
            for _, b in ipairs(espObj.BoneOutlines) do b.Visible = false end
        end
    end
end)
--// logic
local Get2DBoundingBox = LPHNoVirtualize(function(instance)
    local rootPart
    if instance:IsA("Model") then
        rootPart = instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChild("Torso") or
            instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
    elseif instance:IsA("BasePart") then
        rootPart = instance
    end

    if not rootPart then return false, nil, nil end

    local position, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then return false, nil, nil end

    if not ESPConfig.DynamicBoxes then
        -- static box
        local humanoid = instance:IsA("Model") and instance:FindFirstChild("Humanoid")
        if humanoid then
            -- stable player bounds
            local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
            local topOffset = isR6 and 2.8 or 3.0
            local bottomOffset = isR6 and 3.0 or 3.5

            local topPos = rootPart.Position + Vector3.new(0, topOffset, 0)
            local bottomPos = rootPart.Position - Vector3.new(0, bottomOffset, 0)
            local top2D = Camera:WorldToViewportPoint(topPos)
            local bottom2D = Camera:WorldToViewportPoint(bottomPos)
            local height = math.abs(top2D.Y - bottom2D.Y)
            return true, Vector2.new(position.X, (top2D.Y + bottom2D.Y) / 2), Vector2.new(height * 0.65, height)
        end

        -- static object bounds
        local cf, size
        if instance:IsA("Model") then
            cf, size = instance:GetBoundingBox()
        else
            cf, size = instance.CFrame, instance.Size
        end

        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local corners = {
            cf * Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
            cf * Vector3.new(-size.X / 2, size.Y / 2, size.Z / 2),
            cf * Vector3.new(size.X / 2, -size.Y / 2, size.Z / 2),
            cf * Vector3.new(-size.X / 2, -size.Y / 2, size.Z / 2),
            cf * Vector3.new(size.X / 2, size.Y / 2, -size.Z / 2),
            cf * Vector3.new(-size.X / 2, size.Y / 2, -size.Z / 2),
            cf * Vector3.new(size.X / 2, -size.Y / 2, -size.Z / 2),
            cf * Vector3.new(-size.X / 2, -size.Y / 2, -size.Z / 2),
        }
        for _, corner in ipairs(corners) do
            local screenPos = Camera:WorldToViewportPoint(corner)
            if screenPos.X < minX then minX = screenPos.X end
            if screenPos.X > maxX then maxX = screenPos.X end
            if screenPos.Y < minY then minY = screenPos.Y end
            if screenPos.Y > maxY then maxY = screenPos.Y end
        end
        return true, Vector2.new((minX + maxX) / 2, (minY + maxY) / 2), Vector2.new(maxX - minX, maxY - minY)
    else
        -- dynamic box
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local parts = {}
        if instance:IsA("Model") then
            local includeAll = ESPConfig.DynamicBoxesIncludeAll
            for _, v in ipairs(instance:GetChildren()) do
                if v:IsA("BasePart") and (includeAll or (v.Name ~= "HumanoidRootPart" and v.Transparency ~= 1)) then
                    table.insert(parts, v)
                end
            end
        else
            table.insert(parts, instance)
        end

        if #parts == 0 then return false, nil, nil end

        if ESPConfig.DynamicBoxesCheap then
            for _, part in ipairs(parts) do
                local cf, size = part.CFrame, part.Size
                local hs = size / 2
                local p1 = cf * Vector3.new(hs.X, hs.Y, hs.Z)
                local p2 = cf * Vector3.new(-hs.X, -hs.Y, -hs.Z)
                local s1 = Camera:WorldToViewportPoint(p1)
                local s2 = Camera:WorldToViewportPoint(p2)
                if s1.X < minX then minX = s1.X end
                if s1.X > maxX then maxX = s1.X end
                if s1.Y < minY then minY = s1.Y end
                if s1.Y > maxY then maxY = s1.Y end
                if s2.X < minX then minX = s2.X end
                if s2.X > maxX then maxX = s2.X end
                if s2.Y < minY then minY = s2.Y end
                if s2.Y > maxY then maxY = s2.Y end
            end
        else
            for _, part in ipairs(parts) do
                local cf, size = part.CFrame, part.Size
                local corners = {
                    cf * Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
                    cf * Vector3.new(-size.X / 2, size.Y / 2, size.Z / 2),
                    cf * Vector3.new(size.X / 2, -size.Y / 2, size.Z / 2),
                    cf * Vector3.new(-size.X / 2, -size.Y / 2, size.Z / 2),
                    cf * Vector3.new(size.X / 2, size.Y / 2, -size.Z / 2),
                    cf * Vector3.new(-size.X / 2, size.Y / 2, -size.Z / 2),
                    cf * Vector3.new(size.X / 2, -size.Y / 2, -size.Z / 2),
                    cf * Vector3.new(-size.X / 2, -size.Y / 2, -size.Z / 2),
                }
                for _, corner in ipairs(corners) do
                    local screenPos = Camera:WorldToViewportPoint(corner)
                    if screenPos.X < minX then minX = screenPos.X end
                    if screenPos.X > maxX then maxX = screenPos.X end
                    if screenPos.Y < minY then minY = screenPos.Y end
                    if screenPos.Y > maxY then maxY = screenPos.Y end
                end
            end
        end
        return true, Vector2.new((minX + maxX) / 2, (minY + maxY) / 2), Vector2.new(maxX - minX, maxY - minY)
    end
end)
--// scan
local function CheckContains(instance, containsList)
    if type(containsList) ~= "table" or #containsList == 0 then return true end
    if #containsList == 1 and containsList[1] == "" then return true end
    for _, containName in ipairs(containsList) do
        local found = false
        for _, child in ipairs(instance:GetChildren()) do
            if child.Name == containName then
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end

local function CheckNames(instance, namesList)
    if type(namesList) ~= "table" or #namesList == 0 then return true end
    if #namesList == 1 and namesList[1] == "" then return true end
    for _, name in ipairs(namesList) do
        if instance.Name == name then
            return true
        end
    end
    return false
end

local function CheckBlockNames(inst, blockList)
    if not blockList or #blockList == 0 then return false end
    local current = inst
    while current and current ~= game do
        for _, name in ipairs(blockList) do
            if name ~= "" and current.Name:find(name) then
                return true
            end
        end
        current = current.Parent
    end
    return false
end

local ScanDirectories = LPHNoVirtualize(function()
    local newTracked = {}

    if ESPConfig.Players then
        for _, player in ipairs(Players:GetPlayers()) do
            if not ESPConfig.LocalPlayer and player == LocalPlayer then continue end
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    newTracked[player.Character] = { name = player.Name, Cheap = false }
                end
            end
        end
    end

    if ESPConfig.NPCs then
        local npcContainer = nil
        for _, candidate in ipairs(Workspace:GetChildren()) do
            if candidate:FindFirstChild("NPCs") then
                npcContainer = candidate
                break
            end
        end

        if npcContainer then
            for _, model in ipairs(npcContainer:GetChildren()) do
                if not model:IsA("Model") then continue end

                local humanoid = model:FindFirstChildOfClass("Humanoid")
                local root = model:FindFirstChild("HumanoidRootPart")
                local player = Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name)
                if humanoid and humanoid.Health > 0 and root and not player then
                    newTracked[model] = {
                        name = model.Name,
                        Cheap = false,
                        NonHuman = false,
                        NoStatus = true,
                        Config = {},
                    }
                end
            end
        end
    end

    for key, config in pairs(ESPConfig.Directories) do
        local displayName = nil
        if type(config) == "table" and config.DisplayName and config.DisplayName ~= "" then
            displayName = config.DisplayName
        elseif type(key) == "string" then
            displayName = key
        end

        if type(config) == "string" then
            local inst = GetInstanceFromPath(config)
            if inst then
                newTracked[inst] = { name = displayName or inst.Name, Cheap = false }
            end
        elseif type(config) == "table" then
            local path = config.Path
            if not path then continue end
            local inst = GetInstanceFromPath(path)
            if not inst then continue end

            local isCheap = config.Cheap or false
            local nonHuman = config.NonHuman or false
            local noStatus = config.NoStatus or false
            local customConfig = config.Config or {}
            local isRecursive = config.Recursive or false

            if config.Multiple then
                local children = isRecursive and inst:GetDescendants() or inst:GetChildren()
                for _, child in ipairs(children) do
                    if (child:IsA("Model") or child:IsA("BasePart")) then
                        -- skip nested tracked objects
                        local hasTrackedAncestor = false
                        local p = child.Parent
                        while p and p ~= inst and p ~= game do
                            if newTracked[p] then
                                hasTrackedAncestor = true
                                break
                            end
                            p = p.Parent
                        end

                        if not hasTrackedAncestor and CheckNames(child, config.Names) and CheckContains(child, config.Contains) and not CheckBlockNames(child, config.BlockNames) then
                            local humanoid = child:FindFirstChild("Humanoid")
                            if nonHuman or (not humanoid or humanoid.Health > 0) then
                                local actualName = (displayName and displayName ~= "") and displayName or child.Name
                                newTracked[child] = {
                                    name = actualName,
                                    Cheap = isCheap,
                                    NonHuman = nonHuman,
                                    NoStatus = noStatus,
                                    Config = customConfig
                                }
                            end
                        end
                    end
                end
            else
                if CheckNames(inst, config.Names) and CheckContains(inst, config.Contains) and not CheckBlockNames(inst, config.BlockNames) then
                    local humanoid = inst:FindFirstChild("Humanoid")
                    if nonHuman or (not humanoid or humanoid.Health > 0) then
                        local actualName = (displayName and displayName ~= "") and displayName or inst.Name
                        newTracked[inst] = {
                            name = actualName,
                            Cheap = isCheap,
                            NonHuman = nonHuman,
                            NoStatus = noStatus,
                            Config = customConfig
                        }
                    end
                end
            end
        end
    end

    for inst, data in pairs(newTracked) do
        if not TrackedInstances[inst] then
            TrackedInstances[inst] = {
                espObj = CreateESPObj(data.name),
                name = data.name,
                Cheap = data.Cheap,
                NonHuman = data.NonHuman,
                NoStatus = data.NoStatus,
                Config = data.Config
            }
        else
            TrackedInstances[inst].name = data.name
            TrackedInstances[inst].Cheap = data.Cheap
            TrackedInstances[inst].NonHuman = data.NonHuman
            TrackedInstances[inst].NoStatus = data.NoStatus
            TrackedInstances[inst].Config = data.Config
        end
    end

    for inst, data in pairs(TrackedInstances) do
        if not newTracked[inst] or not inst.Parent then
            data.espObj:Destroy()
            TrackedInstances[inst] = nil
        end
    end
end)

local lastScan = 0
local lastRender = 0
local lastFontRetry = 0
local function RuntimeStep()
    if not ESPConfig.Enabled then
        for inst, data in pairs(TrackedInstances) do
            if data.espObj then
                local disabledConfig = DeepCopy(data.Config or {})
                disabledConfig.Chams = disabledConfig.Chams or {}
                disabledConfig.Chams.Enabled = false
                UpdateESPObj(data.espObj, nil, nil, "", 0, inst, data.Cheap, data.NonHuman, data.NoStatus, disabledConfig,
                    false)
            end
        end
        return
    end

    local now = tick()

    if FontsStillLoading and now - lastFontRetry > 5 then
        lastFontRetry = now
        AttemptLoadFonts()
    end

    if ESPConfig.LimitFPS and ESPConfig.LimitFPS > 0 then
        if now - lastRender < (1 / ESPConfig.LimitFPS) then return end
        lastRender = now
    end

    if now - lastScan > 1 then
        lastScan = now
        ScanDirectories()
    end

    for inst, data in pairs(TrackedInstances) do
        if not inst or not inst.Parent then
            data.espObj:Destroy()
            TrackedInstances[inst] = nil
            continue
        end

        local humanoid = not data.NonHuman and inst:FindFirstChild("Humanoid") or nil
        if humanoid and humanoid.Health <= 0 then
            data.espObj:Destroy()
            TrackedInstances[inst] = nil
            continue
        end

        local rootPart = inst:IsA("Model") and
            (inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart")) or
            (inst:IsA("BasePart") and inst)

        if rootPart then
            local onscreen, pos2d, size2d = Get2DBoundingBox(inst)
            local distanceStuds = (Camera.CFrame.Position - rootPart.Position).Magnitude
            UpdateESPObj(data.espObj, pos2d, size2d, data.name, distanceStuds, inst, data.Cheap, data.NonHuman,
                data.NoStatus, data.Config, onscreen)
        else
            UpdateESPObj(data.espObj, nil, nil, data.name, 0, inst, data.Cheap, data.NonHuman, data.NoStatus, data
                .Config, false)
        end
    end
end

function ESP:Unload()
    for inst, data in pairs(TrackedInstances) do
        if data.espObj then
            data.espObj:Destroy()
        end
        TrackedInstances[inst] = nil
    end

    if PlayerRemovingConnection then
        PlayerRemovingConnection:Disconnect()
        PlayerRemovingConnection = nil
    end
    if InputBeganConnection then
        InputBeganConnection:Disconnect()
        InputBeganConnection = nil
    end
    if getgenv().SensoryESP_Loop then
        getgenv().SensoryESP_Loop:Disconnect()
        getgenv().SensoryESP_Loop = nil
    end
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
    if ChamsContainer then
        ChamsContainer:Destroy()
        ChamsContainer = nil
    end
    if MeshChamsFolder then
        MeshChamsFolder:Destroy()
        MeshChamsFolder = nil
    end

    CleanupMeshChams(Workspace)
    for _, player in ipairs(BootstrapPlayers:GetPlayers()) do
        CleanupCharacterMeshChams(player.Character)
    end

    getgenv().SensoryESP_UI = nil
end

function ESP:Load(config)
    self:Unload()

    ESPConfig = DeepMerge(DeepCopy(DefaultESPConfig), config or {})
    EnsureRootInstances()
    CurrentRunId = HttpService:GenerateGUID(false)
    lastScan = 0
    lastRender = 0

    PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        for inst, data in pairs(TrackedInstances) do
            if Players:GetPlayerFromCharacter(inst) == player then
                data.espObj:Destroy()
                TrackedInstances[inst] = nil
            end
        end
    end)

    InputBeganConnection = UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and ESPConfig.Keybind.Enabled and input.KeyCode == ESPConfig.Keybind.Key then
            ESPConfig.Enabled = not ESPConfig.Enabled
        end
    end)

    getgenv().SensoryESP_Loop = RunService.RenderStepped:Connect(RuntimeStep)
    ScanDirectories()
    return self
end

function ESP:GetConfig()
    return ESPConfig
end

getgenv().SensoryESP_Unload = function()
    ESP:Unload()
end

return ESP

end)()
SensoryESP:Load()
local SensoryESPConfig = SensoryESP:GetConfig()
Library.PlayerStatusColors = SensoryESPConfig.PlayerStatusColors
Playerlist = PlayersPage:AddPlayerList({})

Library:OnUnload(function()
    SensoryESP:Unload()
end)

--// havoc features
local HavocWorkspace = game:GetService("Workspace")
local HavocRunService = game:GetService("RunService")
local HavocPlayers = game:GetService("Players")
local HavocLighting = game:GetService("Lighting")
local HavocLocalPlayer = HavocPlayers.LocalPlayer

local HavocFlags = {
    SilentAim = false,
    TargetNPCs = false,
    RandomizeAim = false,
    PriorityOnly = false,
    AutoShoot = false,
    FireRateMs = 100,
    ShowFov = false,
    FovRadius = 300,
    FovColor = Color3.fromRGB(255, 255, 255),
    TargetIndicator = false,
    TargetIndicatorColor = Color3.fromRGB(255, 70, 70),
    NoRecoil = false,
    Invisible = false,
    InvisibleTransparency = 0.5,
    ThirdPerson = false,
    ThirdPersonDistance = 8,
    InfinityStamina = false,
    NoFog = false,
    NoGrass = false,
}

local HavocState = {
    Unloaded = false,
    Camera = HavocWorkspace.CurrentCamera,
    Characters = {},
    Target = nil,
    TargetPosition = nil,
    TargetVisible = false,
    LastTarget = nil,
    LastShotAt = 0,
    Connections = {},
    CharacterFolder = nil,
    NPCContainer = nil,
    LastNPCScanAt = 0,
    LastCharacterScanAt = 0,
    LastSilentWeapon = nil,
    SilentDirectHooks = {},
    SilentHookedFunctions = {},
    LastNoRecoilWeapon = nil,
    NoRecoilGeneration = 0,
    NoRecoilOriginals = {},
    InvisibleGeneration = 0,
    InvisibleCharacter = nil,
    InvisibleHumanoid = nil,
    InvisibleRootPart = nil,
    InvisibleTrack = nil,
    InvisibleAnimation = nil,
    InvisibleDescendantConnection = nil,
    InvisibleOriginalTransparency = {},
    InvisibleOriginalCameraOffset = nil,
    ThirdPersonApplied = false,
    ThirdPersonOriginalMinZoom = nil,
    ThirdPersonOriginalMaxZoom = nil,
    ThirdPersonOriginalCameraMode = nil,
    StaminaState = nil,
    FogApplied = false,
    GrassApplied = false,
    FogOriginals = nil,
    GrassOriginal = nil,
}

local HavocFovCircle = Drawing.new("Circle")
HavocFovCircle.Thickness = 1
HavocFovCircle.NumSides = 64
HavocFovCircle.Filled = false
HavocFovCircle.Transparency = 1
HavocFovCircle.Visible = false

Library.HavocSilentTarget = nil
Library.HavocSilentTargetIndicatorEnabled = false
Library.HavocSilentTargetIndicatorColor = HavocFlags.TargetIndicatorColor

local function havoc_add_connection(connection)
    HavocState.Connections[#HavocState.Connections + 1] = connection
    return connection
end

local function havoc_add_character(character)
    if not character or character == HavocLocalPlayer.Character then return end
    if not character:FindFirstChildOfClass("Humanoid") then return end
    if table.find(HavocState.Characters, character) then return end
    HavocState.Characters[#HavocState.Characters + 1] = character
end

local function havoc_scan_players()
    for _, player in ipairs(HavocPlayers:GetPlayers()) do
        if player ~= HavocLocalPlayer and player.Character then
            havoc_add_character(player.Character)
        end
    end
end

local function havoc_remove_character(character)
    local index = table.find(HavocState.Characters, character)
    if index then
        table.remove(HavocState.Characters, index)
    end
    if HavocState.Target == character then
        HavocState.Target = nil
        HavocState.TargetPosition = nil
        HavocState.TargetVisible = false
        Library.HavocSilentTarget = nil
    end
end

local function havoc_get_character_folder()
    if not getrenv then return nil end

    local success, environment = pcall(getrenv)
    if not success then return nil end

    local sharedEnvironment = environment and environment.shared
    local folderName = sharedEnvironment and sharedEnvironment.charactersFolderName
    return folderName and HavocWorkspace:FindFirstChild(folderName)
end

local function havoc_get_npc_container()
    if HavocState.NPCContainer and HavocState.NPCContainer.Parent then
        return HavocState.NPCContainer
    end

    HavocState.NPCContainer = nil
    for _, candidate in ipairs(HavocWorkspace:GetChildren()) do
        if candidate:FindFirstChild("NPCs") then
            HavocState.NPCContainer = candidate
            break
        end
    end

    return HavocState.NPCContainer
end

local function havoc_scan_npcs()
    local container = havoc_get_npc_container()
    if not container then return end

    for _, model in ipairs(container:GetChildren()) do
        local player = HavocPlayers:GetPlayerFromCharacter(model) or HavocPlayers:FindFirstChild(model.Name)
        if model:IsA("Model")
            and model:FindFirstChildOfClass("Humanoid")
            and model:FindFirstChild("HumanoidRootPart")
            and not (player and player:IsA("Player")) then
            havoc_add_character(model)
        end
    end
end

local function havoc_attach_character_folder(folder)
    if HavocState.CharacterFolder == folder then return end
    HavocState.CharacterFolder = folder
    table.clear(HavocState.Characters)

    for _, character in ipairs(folder:GetChildren()) do
        havoc_add_character(character)
    end

    havoc_add_connection(folder.ChildAdded:Connect(havoc_add_character))
    havoc_add_connection(folder.ChildRemoved:Connect(havoc_remove_character))
end

local function havoc_get_character_player(character)
    if not character then return nil end

    local player = HavocPlayers:GetPlayerFromCharacter(character)
    if player then return player end

    local namedPlayer = HavocPlayers:FindFirstChild(character.Name)
    return namedPlayer and namedPlayer:IsA("Player") and namedPlayer or nil
end

local function havoc_find_target()
    if not HavocFlags.SilentAim then return nil, nil end

    local camera = HavocState.Camera
    if not camera then return nil, nil end

    local viewportSize = camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local bestPriority = math.huge
    local bestDistance = math.huge
    local bestPosition = nil
    local bestCharacter = nil

    for index = #HavocState.Characters, 1, -1 do
        local character = HavocState.Characters[index]
        if not character or not character.Parent then
            table.remove(HavocState.Characters, index)
            continue
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        if not humanoid or humanoid.Health <= 0 or not head then continue end

        local player = havoc_get_character_player(character)
        local isNPC = player == nil
        local priority

        if isNPC then
            if not HavocFlags.TargetNPCs or HavocFlags.PriorityOnly then continue end
            priority = 2
        else
            local status = get_player_status(player)
            if status == "Friendly" then continue end
            if HavocFlags.PriorityOnly and status ~= "Enemy" then continue end
            priority = status == "Enemy" and 0 or 1
        end

        local viewportPoint, onScreen = camera:WorldToViewportPoint(head.Position)
        if not onScreen or viewportPoint.Z <= 0 then continue end

        local screenDistance = (Vector2.new(viewportPoint.X, viewportPoint.Y) - screenCenter).Magnitude
        if screenDistance <= HavocFlags.FovRadius and (
            priority < bestPriority
            or (priority == bestPriority and screenDistance < bestDistance)
        ) then
            bestPriority = priority
            bestDistance = screenDistance
            bestPosition = head.Position
            bestCharacter = character
        end
    end

    return bestPosition, bestCharacter
end

local function havoc_get_equipped_weapon()
    local character = HavocLocalPlayer.Character
    return character and character:FindFirstChildOfClass("Tool") or nil
end

local function havoc_get_shot_origin(weapon)
    local camera = HavocState.Camera
    local muzzle = weapon and (
        weapon:FindFirstChild("MuzzleFX", true)
        or weapon:FindFirstChild("Muzzle", true)
        or weapon:FindFirstChild("FirePoint", true)
        or weapon:FindFirstChild("Handle", true)
    )

    if muzzle and muzzle:IsA("Attachment") then
        return muzzle.WorldPosition
    end

    if muzzle and muzzle:IsA("BasePart") then
        return muzzle.Position
    end

    if muzzle and muzzle:IsA("Model") and muzzle.PrimaryPart then
        return muzzle.PrimaryPart.Position
    end

    return camera and camera.CFrame.Position or nil
end

local function havoc_is_target_visible(target, targetPosition, origin)
    if not target or not targetPosition or not origin then return false end

    local direction = targetPosition - origin
    if direction.Magnitude <= 0 then return false end

    local ignoredInstances = {}
    if HavocLocalPlayer.Character then
        table.insert(ignoredInstances, HavocLocalPlayer.Character)
    end
    if HavocState.Camera then
        table.insert(ignoredInstances, HavocState.Camera)
    end
    local ignoredFolder = HavocWorkspace:FindFirstChild("Ignored")
    if ignoredFolder then
        table.insert(ignoredInstances, ignoredFolder)
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoredInstances
    raycastParams.IgnoreWater = true

    local result = HavocWorkspace:Raycast(origin, direction, raycastParams)
    return result == nil or (result.Instance and result.Instance:IsDescendantOf(target))
end

local function havoc_get_aim_position(targetPosition)
    if not HavocFlags.RandomizeAim then return targetPosition end
    return targetPosition + Vector3.new(
        math.random() * 0.35 - 0.25,
        math.random() * 0.65 - 0.25,
        0
    )
end

local function havoc_get_silent_direction(origin, scale)
    if not HavocFlags.SilentAim
        or typeof(HavocState.TargetPosition) ~= "Vector3"
        or typeof(origin) ~= "Vector3" then
        return nil
    end

    local aimPosition = havoc_get_aim_position(HavocState.TargetPosition)
    local direction = aimPosition - origin
    if direction.Magnitude <= 0 then return nil end

    return direction.Unit * (scale or 1)
end

local function havoc_is_get_hit_pos_call()
    if not debug or not debug.info then return false end

    for level = 2, 8 do
        local success, callerName = pcall(debug.info, level, "n")
        if success and callerName == "getHitPos" then
            return true
        end
    end

    return false
end

local function havoc_fire_visible_target()
    if not HavocFlags.SilentAim or not HavocFlags.AutoShoot or not HavocState.TargetVisible then return end

    local weapon = havoc_get_equipped_weapon()
    local activateEvent = weapon and weapon:FindFirstChild("activateEvent", true)
    if not activateEvent or not activateEvent:IsA("BindableEvent") then return end

    local now = os.clock()
    local interval = math.max(HavocFlags.FireRateMs, 0) / 1000
    if now - HavocState.LastShotAt < interval then return end

    HavocState.LastShotAt = now
    pcall(function()
        activateEvent:Fire(Enum.UserInputType.MouseButton1, "began", "bypass")
        task.defer(function()
            task.wait()
            if activateEvent.Parent then
                pcall(function()
                    activateEvent:Fire(Enum.UserInputType.MouseButton1, "ended")
                end)
            end
        end)
    end)
end

local function havoc_update_silent_aim()
    HavocState.Camera = HavocWorkspace.CurrentCamera or HavocState.Camera

    local camera = HavocState.Camera
    local viewportSize = camera and camera.ViewportSize or Vector2.zero
    HavocFovCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    HavocFovCircle.Radius = HavocFlags.FovRadius
    HavocFovCircle.Color = HavocFlags.FovColor
    HavocFovCircle.Visible = HavocFlags.ShowFov

    HavocState.TargetPosition, HavocState.Target = havoc_find_target()

    if HavocState.LastTarget ~= HavocState.Target then
        HavocState.LastTarget = HavocState.Target
        HavocState.LastShotAt = 0
    end

    local weapon = havoc_get_equipped_weapon()
    local origin = havoc_get_shot_origin(weapon)
    HavocState.TargetVisible = havoc_is_target_visible(
        HavocState.Target,
        HavocState.TargetPosition,
        origin
    )

    Library.HavocSilentTarget = HavocState.Target
    Library.HavocSilentTargetIndicatorEnabled = HavocFlags.TargetIndicator
    Library.HavocSilentTargetIndicatorColor = HavocFlags.TargetIndicatorColor
end

local function havoc_install_silent_aim_hook()
    if not (hookmetamethod and newcclosure and getnamecallmethod) then
        Library:Notify('Havoc silent aim: hookmetamethod is unavailable', 5)
        return
    end

    local originalNamecall
    local success, message = pcall(function()
        originalNamecall = hookmetamethod(Vector3.zero, "__namecall", newcclosure(function(self, ...)
            if not HavocState.Unloaded
                and HavocFlags.SilentAim
                and HavocState.TargetPosition
                and getnamecallmethod() == "Lerp" then
                if havoc_is_get_hit_pos_call() and HavocState.Camera then
                    local direction = havoc_get_silent_direction(HavocState.Camera.CFrame.Position, 1000)
                    if direction then return direction end
                end
            end

            return originalNamecall(self, ...)
        end))
    end)

    if not success then
        Library:Notify('Havoc silent aim: ' .. tostring(message), 5)
    end
end

local function havoc_install_direct_silent_hooks()
    if not (getgc and hookfunction and newcclosure and debug and debug.info) then return end

    local success, objects = pcall(getgc)
    if not success or type(objects) ~= "table" then
        success, objects = pcall(getgc, true)
    end
    if not success or type(objects) ~= "table" then return end

    for _, candidate in ipairs(objects) do
        if type(candidate) == "function" and not HavocState.SilentHookedFunctions[candidate] then
            local nameSuccess, functionName = pcall(debug.info, candidate, "n")
            if nameSuccess and functionName == "getHitPos" then
                local original
                local hookSuccess = pcall(function()
                    original = hookfunction(candidate, newcclosure(function(...)
                        local origin, direction = original(...)
                        if not HavocState.Unloaded then
                            local redirectedDirection = havoc_get_silent_direction(origin, 1)
                            if redirectedDirection then
                                return origin, redirectedDirection
                            end
                        end
                        return origin, direction
                    end))
                end)

                if hookSuccess and original then
                    HavocState.SilentHookedFunctions[candidate] = true
                    HavocState.SilentDirectHooks[#HavocState.SilentDirectHooks + 1] = {
                        Target = candidate,
                        Original = original,
                    }
                end
            end
        end
    end
end

local HavocNoRecoilKeys = {
    "vPunchBase",
    "hPunchBase",
}

local HavocNoRecoilValues = {
    vPunchBase = 0,
    hPunchBase = 0,
}

local function havoc_get_no_recoil_cache()
    if not getgc then return nil end

    local success, objects = pcall(getgc, true)
    if not success or type(objects) ~= "table" then return nil end

    local cache = {}
    for _, object in ipairs(objects) do
        if type(object) == "table" then
            for _, key in ipairs(HavocNoRecoilKeys) do
                if rawget(object, key) ~= nil then
                    cache[#cache + 1] = object
                    break
                end
            end
        end
    end

    return cache
end

local function havoc_apply_no_recoil()
    local cache = havoc_get_no_recoil_cache()
    if not cache then return end

    for _, object in ipairs(cache) do
        local originals = HavocState.NoRecoilOriginals[object]
        if not originals then
            originals = {}
            HavocState.NoRecoilOriginals[object] = originals
        end

        for key, value in pairs(HavocNoRecoilValues) do
            if rawget(object, key) ~= nil then
                if originals[key] == nil then
                    originals[key] = rawget(object, key)
                end
                pcall(rawset, object, key, value)
            end
        end
    end
end

local function havoc_restore_no_recoil()
    HavocState.NoRecoilGeneration = HavocState.NoRecoilGeneration + 1
    local generation = HavocState.NoRecoilGeneration
    local originalCache = HavocState.NoRecoilOriginals
    HavocState.NoRecoilOriginals = {}

    local function restoreCache()
        for object, originals in pairs(originalCache) do
            if type(object) == "table" then
                for key, value in pairs(originals) do
                    pcall(rawset, object, key, value)
                end
            end
        end
    end

    restoreCache()
    task.delay(0.25, function()
        if not HavocFlags.NoRecoil and HavocState.NoRecoilGeneration == generation then
            restoreCache()
        end
    end)

    HavocState.LastNoRecoilWeapon = nil
end

local function havoc_release_invisible_character()
    if HavocState.InvisibleDescendantConnection then
        HavocState.InvisibleDescendantConnection:Disconnect()
    end
    if HavocState.InvisibleTrack then
        pcall(function() HavocState.InvisibleTrack:Stop() end)
    end
    if HavocState.InvisibleAnimation then
        pcall(function() HavocState.InvisibleAnimation:Destroy() end)
    end

    for part, transparency in pairs(HavocState.InvisibleOriginalTransparency) do
        if part and part.Parent then
            part.LocalTransparencyModifier = transparency
        end
    end
    table.clear(HavocState.InvisibleOriginalTransparency)

    local humanoid = HavocState.InvisibleHumanoid
    if humanoid and humanoid.Parent and HavocState.InvisibleOriginalCameraOffset then
        humanoid.CameraOffset = HavocState.InvisibleOriginalCameraOffset
    end

    HavocState.InvisibleCharacter = nil
    HavocState.InvisibleHumanoid = nil
    HavocState.InvisibleRootPart = nil
    HavocState.InvisibleTrack = nil
    HavocState.InvisibleAnimation = nil
    HavocState.InvisibleDescendantConnection = nil
    HavocState.InvisibleOriginalCameraOffset = nil
end

local function havoc_capture_invisible_character(character)
    if not character or not character:FindFirstChild("Torso") then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return false end

    if HavocState.InvisibleCharacter ~= character then
        havoc_release_invisible_character()
    end

    HavocState.InvisibleCharacter = character
    HavocState.InvisibleHumanoid = humanoid
    HavocState.InvisibleRootPart = rootPart

    HavocState.InvisibleOriginalCameraOffset = humanoid.CameraOffset

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and not descendant:FindFirstAncestorOfClass("Tool") then
            HavocState.InvisibleOriginalTransparency[descendant] = descendant.LocalTransparencyModifier
        end
    end

    HavocState.InvisibleDescendantConnection = character.DescendantAdded:Connect(function(descendant)
        if HavocFlags.Invisible
            and descendant:IsA("BasePart")
            and not descendant:FindFirstAncestorOfClass("Tool") then
            HavocState.InvisibleOriginalTransparency[descendant] = descendant.LocalTransparencyModifier
        end
    end)

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://215384594"
    HavocState.InvisibleAnimation = animation

    local success, track = pcall(function()
        local animator = humanoid:FindFirstChildOfClass("Animator")
        return animator and animator:LoadAnimation(animation) or humanoid:LoadAnimation(animation)
    end)
    if success then
        HavocState.InvisibleTrack = track
    end

    return true
end

local function havoc_apply_invisible_transparency()
    for descendant, original in pairs(HavocState.InvisibleOriginalTransparency) do
        if not descendant or not descendant.Parent then
            HavocState.InvisibleOriginalTransparency[descendant] = nil
        elseif descendant:FindFirstAncestorOfClass("Tool") then
            descendant.LocalTransparencyModifier = original
            HavocState.InvisibleOriginalTransparency[descendant] = nil
        elseif original < 1 then
            descendant.LocalTransparencyModifier = math.max(original, HavocFlags.InvisibleTransparency)
        end
    end
end

local function havoc_restore_invisibility()
    HavocState.InvisibleGeneration = HavocState.InvisibleGeneration + 1
    havoc_release_invisible_character()
end

local function havoc_set_zoom_bounds(minimum, maximum)
    local temporaryMaximum = math.max(maximum, minimum, 0.5)
    HavocLocalPlayer.CameraMinZoomDistance = 0.5
    HavocLocalPlayer.CameraMaxZoomDistance = temporaryMaximum
    HavocLocalPlayer.CameraMinZoomDistance = minimum
    HavocLocalPlayer.CameraMaxZoomDistance = maximum
end

local function havoc_apply_third_person()
    if not HavocState.ThirdPersonApplied then
        HavocState.ThirdPersonApplied = true
        HavocState.ThirdPersonOriginalMinZoom = HavocLocalPlayer.CameraMinZoomDistance
        HavocState.ThirdPersonOriginalMaxZoom = HavocLocalPlayer.CameraMaxZoomDistance
        HavocState.ThirdPersonOriginalCameraMode = HavocLocalPlayer.CameraMode
    end

    HavocLocalPlayer.CameraMode = Enum.CameraMode.Classic
    havoc_set_zoom_bounds(HavocFlags.ThirdPersonDistance, HavocFlags.ThirdPersonDistance)
end

local function havoc_restore_third_person()
    if not HavocState.ThirdPersonApplied then return end
    HavocState.ThirdPersonApplied = false

    local minimum = HavocState.ThirdPersonOriginalMinZoom
    local maximum = HavocState.ThirdPersonOriginalMaxZoom
    if minimum and maximum then
        havoc_set_zoom_bounds(minimum, maximum)
    end
    if HavocState.ThirdPersonOriginalCameraMode then
        HavocLocalPlayer.CameraMode = HavocState.ThirdPersonOriginalCameraMode
    end

    HavocState.ThirdPersonOriginalMinZoom = nil
    HavocState.ThirdPersonOriginalMaxZoom = nil
    HavocState.ThirdPersonOriginalCameraMode = nil
end

local function havoc_start_invisibility()
    HavocState.InvisibleGeneration = HavocState.InvisibleGeneration + 1
    local generation = HavocState.InvisibleGeneration

    task.spawn(function()
        while HavocFlags.Invisible
            and not HavocState.Unloaded
            and HavocState.InvisibleGeneration == generation do
            HavocRunService.Heartbeat:Wait()

            local character = HavocLocalPlayer.Character
            if HavocState.InvisibleCharacter ~= character then
                if not havoc_capture_invisible_character(character) then
                    Library:Notify('Invisible requires an R6 character', 5)
                    HavocFlags.Invisible = false
                    if Toggles.HavocInvisibleEnabled then
                        Toggles.HavocInvisibleEnabled:SetValue(false)
                    end
                    break
                end
            end

            local camera = HavocWorkspace.CurrentCamera
            local humanoid = HavocState.InvisibleHumanoid
            local rootPart = HavocState.InvisibleRootPart
            local track = HavocState.InvisibleTrack
            if not camera or not humanoid or not humanoid.Parent or not rootPart or not rootPart.Parent then
                continue
            end

            local _, yaw = camera.CFrame:ToOrientation()
            rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromOrientation(0, yaw, 0)
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
            humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

            if track then
                pcall(function()
                    track.Priority = Enum.AnimationPriority.Action4
                    track:Play()
                    track:AdjustSpeed(0)
                    track.TimePosition = 0.3
                end)
            end

            HavocRunService.RenderStepped:Wait()

            if track then
                pcall(function() track:Stop() end)
            end

            local lookVector = camera.CFrame.LookVector
            local horizontal = Vector3.new(lookVector.X, 0, lookVector.Z)
            if horizontal.Magnitude > 0 then
                rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + horizontal.Unit)
            end

            havoc_apply_invisible_transparency()
        end

        if HavocState.InvisibleGeneration == generation and not HavocFlags.Invisible then
            havoc_restore_invisibility()
        end
    end)
end

local function havoc_resolve_stamina_state()
    local environment = getrenv and getrenv()
    local sharedEnvironment = environment and environment.shared
    local staminaFunction = sharedEnvironment and sharedEnvironment.staminaFunction
    if type(staminaFunction) ~= "function" or not debug or not debug.getupvalue then return nil end

    local success, firstValue, secondValue = pcall(debug.getupvalue, staminaFunction, 1)
    if not success then return nil end
    if type(firstValue) == "table" then return firstValue end
    if type(secondValue) == "table" then return secondValue end
    return nil
end

local function havoc_capture_fog()
    local atmosphere = HavocLighting:FindFirstChildOfClass("Atmosphere")
    HavocState.FogOriginals = {
        FogEnd = HavocLighting.FogEnd,
        FogStart = HavocLighting.FogStart,
        Atmosphere = atmosphere,
        Density = atmosphere and atmosphere.Density,
        Glare = atmosphere and atmosphere.Glare,
        Haze = atmosphere and atmosphere.Haze,
        Offset = atmosphere and atmosphere.Offset,
    }
end

local function havoc_apply_no_fog()
    if not HavocState.FogApplied then
        havoc_capture_fog()
        HavocState.FogApplied = true
    end

    HavocLighting.FogEnd = 1e9
    HavocLighting.FogStart = 1e9
    local atmosphere = HavocLighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        atmosphere.Density = 0
        atmosphere.Glare = 0
        atmosphere.Haze = 0
        atmosphere.Offset = 0
    end
end

local function havoc_restore_fog()
    if not HavocState.FogApplied then return end
    HavocState.FogApplied = false

    local originals = HavocState.FogOriginals
    if originals then
        HavocLighting.FogEnd = originals.FogEnd
        HavocLighting.FogStart = originals.FogStart
        local atmosphere = originals.Atmosphere
        if atmosphere and atmosphere.Parent then
            atmosphere.Density = originals.Density
            atmosphere.Glare = originals.Glare
            atmosphere.Haze = originals.Haze
            atmosphere.Offset = originals.Offset
        end
    end
    HavocState.FogOriginals = nil
end

local function havoc_apply_no_grass()
    local terrain = HavocWorkspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    if not HavocState.GrassApplied then
        HavocState.GrassOriginal = terrain.Decoration
        HavocState.GrassApplied = true
    end
    terrain.Decoration = false
end

local function havoc_restore_grass()
    if not HavocState.GrassApplied then return end
    HavocState.GrassApplied = false

    local terrain = HavocWorkspace:FindFirstChildOfClass("Terrain")
    if terrain and HavocState.GrassOriginal ~= nil then
        terrain.Decoration = HavocState.GrassOriginal
    end
    HavocState.GrassOriginal = nil
end

task.spawn(function()
    while not HavocState.Unloaded do
        if not HavocState.CharacterFolder or not HavocState.CharacterFolder.Parent then
            local folder = havoc_get_character_folder()
            if folder then havoc_attach_character_folder(folder) end
        end

        if os.clock() - HavocState.LastCharacterScanAt >= 0.5 then
            HavocState.LastCharacterScanAt = os.clock()
            havoc_scan_players()
        end

        if HavocFlags.TargetNPCs and os.clock() - HavocState.LastNPCScanAt >= 0.5 then
            HavocState.LastNPCScanAt = os.clock()
            havoc_scan_npcs()
        end

        if HavocFlags.SilentAim then
            local equippedWeapon = havoc_get_equipped_weapon()
            if equippedWeapon ~= HavocState.LastSilentWeapon then
                HavocState.LastSilentWeapon = equippedWeapon
                task.delay(0.25, function()
                    if HavocFlags.SilentAim and havoc_get_equipped_weapon() == equippedWeapon then
                        havoc_install_direct_silent_hooks()
                    end
                end)
            end
        else
            HavocState.LastSilentWeapon = nil
        end


        if HavocFlags.NoRecoil then
            local equippedWeapon = havoc_get_equipped_weapon()
            if equippedWeapon ~= HavocState.LastNoRecoilWeapon then
                HavocState.LastNoRecoilWeapon = equippedWeapon
                task.delay(0.25, function()
                    if HavocFlags.NoRecoil and havoc_get_equipped_weapon() == equippedWeapon then
                        havoc_apply_no_recoil()
                    end
                end)
            end
        end

        if HavocFlags.InfinityStamina then
            HavocState.StaminaState = HavocState.StaminaState or havoc_resolve_stamina_state()
            if HavocState.StaminaState then
                pcall(function()
                    HavocState.StaminaState.current = 204
                end)
            end
        end

        task.wait(0.05)
    end
end)

havoc_add_connection(HavocWorkspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    HavocState.Camera = HavocWorkspace.CurrentCamera or HavocState.Camera
end))

havoc_add_connection(HavocRunService.PreRender:Connect(function()
    if HavocState.Unloaded then return end
    havoc_update_silent_aim()
    havoc_fire_visible_target()

    if HavocFlags.ThirdPerson then
        havoc_apply_third_person()
    else
        havoc_restore_third_person()
    end

    pcall(function()
        if HavocFlags.NoFog then havoc_apply_no_fog() else havoc_restore_fog() end
        if HavocFlags.NoGrass then havoc_apply_no_grass() else havoc_restore_grass() end
    end)
end))

havoc_install_silent_aim_hook()

local HavocSilentAimSection = CombatPage:AddLeftGroupbox('Silent Aim')
local HavocNoRecoilSection = CombatPage:AddRightGroupbox('No Recoil')
local HavocWorldSection = VisualsPage:AddColumnGroupbox(3, 'World')
local HavocMovementSection = MiscPage:AddLeftGroupbox('Movement')
local HavocInvisibleSection = MiscPage:AddRightGroupbox('Invisible')

HavocSilentAimSection:AddToggle('HavocSilentAimEnabled', {
    Text = 'Enabled',
    Default = false,
    Callback = function(value)
        HavocFlags.SilentAim = value
        HavocState.LastSilentWeapon = nil
        if not value then
            HavocState.Target = nil
            HavocState.TargetPosition = nil
            HavocState.TargetVisible = false
            Library.HavocSilentTarget = nil
        else
            havoc_install_direct_silent_hooks()
        end
    end,
})

HavocNoRecoilSection:AddToggle('HavocNoRecoilEnabled', {
    Text = 'Enabled',
    Default = false,
    Tooltip = 'Removes vertical and horizontal weapon recoil.',
    Callback = function(value)
        HavocFlags.NoRecoil = value
        if value then
            HavocState.NoRecoilGeneration = HavocState.NoRecoilGeneration + 1
            HavocState.LastNoRecoilWeapon = havoc_get_equipped_weapon()
            havoc_apply_no_recoil()
        else
            havoc_restore_no_recoil()
        end
    end,
})

HavocInvisibleSection:AddToggle('HavocInvisibleEnabled', {
    Text = 'Enabled',
    Default = false,
    Tooltip = 'R6 only.',
    Callback = function(value)
        HavocFlags.Invisible = value
        if value then
            havoc_start_invisibility()
        else
            havoc_restore_invisibility()
        end
    end,
}):AddKeyPicker('HavocInvisibleKeybind', {
    Default = 'None',
    Mode = 'Toggle',
    SyncToggleState = true,
    Text = 'Invisible',
})

HavocInvisibleSection:AddSlider('HavocInvisibleTransparency', {
    Text = 'Local Transparency',
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = '%',
    Callback = function(value)
        HavocFlags.InvisibleTransparency = value / 100
        if HavocFlags.Invisible then
            havoc_apply_invisible_transparency()
        end
    end,
})

HavocInvisibleSection:AddToggle('HavocThirdPersonEnabled', {
    Text = 'Third Person',
    Default = false,
    Callback = function(value)
        HavocFlags.ThirdPerson = value
        if value then
            havoc_apply_third_person()
        else
            havoc_restore_third_person()
        end
    end,
})

HavocInvisibleSection:AddSlider('HavocThirdPersonDistance', {
    Text = 'Third Person Distance',
    Default = HavocFlags.ThirdPersonDistance,
    Min = 2,
    Max = 30,
    Rounding = 1,
    Suffix = ' studs',
    Callback = function(value)
        HavocFlags.ThirdPersonDistance = value
        if HavocFlags.ThirdPerson then
            havoc_apply_third_person()
        end
    end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimNPCs', {
    Text = 'Target NPCs',
    Default = false,
    Tooltip = 'Includes visible NPC models after Enemy and Neutral player targets.',
    Callback = function(value)
        HavocFlags.TargetNPCs = value
        HavocState.LastNPCScanAt = 0
        if value then havoc_scan_npcs() end
    end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimRandomize', {
    Text = 'Randomize Aim',
    Default = false,
    Callback = function(value) HavocFlags.RandomizeAim = value end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimPriorityOnly', {
    Text = 'Priority Only',
    Default = false,
    Tooltip = 'Only targets players marked as Enemy in the player list.',
    Callback = function(value) HavocFlags.PriorityOnly = value end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimAutoShoot', {
    Text = 'Auto Shoot',
    Default = false,
    Tooltip = 'Triggers the equipped weapon through its native activateEvent while the target is visible.',
    Callback = function(value)
        HavocFlags.AutoShoot = value
        HavocState.LastShotAt = 0
    end,
})

HavocSilentAimSection:AddSlider('HavocSilentAimFireRate', {
    Text = 'Fire Rate',
    Default = HavocFlags.FireRateMs,
    Min = 0,
    Max = 1000,
    Rounding = 0,
    Suffix = ' ms',
    Callback = function(value) HavocFlags.FireRateMs = value end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimFov', {
    Text = 'Show FOV Circle',
    Default = false,
    Callback = function(value) HavocFlags.ShowFov = value end,
}):AddColorPicker('HavocSilentAimFovColor', {
    Default = HavocFlags.FovColor,
    Title = 'FOV color',
    Callback = function(color) HavocFlags.FovColor = color end,
})

HavocSilentAimSection:AddSlider('HavocSilentAimFovRadius', {
    Text = 'FOV Radius',
    Default = HavocFlags.FovRadius,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = 'px',
    Callback = function(value) HavocFlags.FovRadius = value end,
})

HavocSilentAimSection:AddToggle('HavocSilentAimTargetIndicator', {
    Text = 'Target Indicator',
    Default = false,
    Callback = function(value)
        HavocFlags.TargetIndicator = value
        Library.HavocSilentTargetIndicatorEnabled = value
    end,
}):AddColorPicker('HavocSilentAimTargetIndicatorColor', {
    Default = HavocFlags.TargetIndicatorColor,
    Title = 'Target indicator color',
    Callback = function(color)
        HavocFlags.TargetIndicatorColor = color
        Library.HavocSilentTargetIndicatorColor = color
    end,
})

HavocWorldSection:AddToggle('HavocNoFog', {
    Text = 'No Fog',
    Default = false,
    Callback = function(value) HavocFlags.NoFog = value end,
})

HavocWorldSection:AddToggle('HavocNoGrass', {
    Text = 'No Grass',
    Default = false,
    Callback = function(value) HavocFlags.NoGrass = value end,
})

HavocMovementSection:AddToggle('HavocInfinityStamina', {
    Text = 'Infinity Stamina',
    Default = false,
    Callback = function(value) HavocFlags.InfinityStamina = value end,
})

local function cleanup_havoc_features()
    if HavocState.Unloaded then return end
    HavocState.Unloaded = true
    HavocFlags.SilentAim = false
    HavocFlags.TargetNPCs = false
    HavocFlags.AutoShoot = false
    HavocFlags.NoRecoil = false
    HavocFlags.Invisible = false
    HavocFlags.ThirdPerson = false
    HavocFlags.InfinityStamina = false
    HavocFlags.NoFog = false
    HavocFlags.NoGrass = false
    Library.HavocSilentTarget = nil
    Library.HavocSilentTargetIndicatorEnabled = false

    havoc_restore_invisibility()
    havoc_restore_third_person()
    havoc_restore_no_recoil()
    havoc_restore_fog()
    havoc_restore_grass()

    for _, hookData in ipairs(HavocState.SilentDirectHooks) do
        pcall(hookfunction, hookData.Target, hookData.Original)
    end
    table.clear(HavocState.SilentDirectHooks)
    table.clear(HavocState.SilentHookedFunctions)

    for _, connection in ipairs(HavocState.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(HavocState.Connections)

    HavocFovCircle.Visible = false
    pcall(function() HavocFovCircle:Remove() end)

    Environment.DrainHavocCleanup = nil
end

Environment.DrainHavocCleanup = cleanup_havoc_features
Library:OnUnload(cleanup_havoc_features)

--// esp controls
local SensoryGeneral = VisualsPage:AddLeftGroupbox('General')
local SensoryBoxes = VisualsPage:AddRightGroupbox('Boxes & Fill')
local SensoryText = VisualsPage:AddLeftGroupbox('Text & Indicators')
local SensoryHealth = VisualsPage:AddRightGroupbox('Healthbar')
local SensoryFlags = VisualsPage:AddLeftGroupbox('Flags & Skeleton')
local SensoryOffscreen = VisualsPage:AddRightGroupbox('Offscreen')
local SensoryChams = VisualsPage:AddRightGroupbox('Player Chams')

local SensoryFonts = {
    'Proggy Clean',
    'Smallest Pixel-7',
    'Tahoma',
    'Minecraftia',
    'Tahoma Modern Bold',
}

local SensoryKeybindEnabled = false
local SensoryMaster = SensoryGeneral:AddToggle('SensoryEnabled', {
    Text = 'Enable ESP',
    Default = false,
    Callback = function(value) SensoryESPConfig.Enabled = value end,
})

SensoryMaster:AddKeyPicker('SensoryToggleKey', {
    Default = 'None',
    Mode = 'Toggle',
    Text = 'ESP toggle',
    NoUI = true,
    Callback = function(value)
        if SensoryKeybindEnabled and Toggles.SensoryEnabled then
            Toggles.SensoryEnabled:SetValue(value)
        end
    end,
})

SensoryGeneral:AddToggle('SensoryKeybindEnabled', {
    Text = 'Enable ESP keybind',
    Default = false,
    Callback = function(value) SensoryKeybindEnabled = value end,
})

SensoryGeneral:AddToggle('SensoryPlayers', {
    Text = 'Players',
    Default = false,
    Callback = function(value) SensoryESPConfig.Players = value end,
})

SensoryGeneral:AddToggle('SensoryNPCs', {
    Text = 'NPCs',
    Default = false,
    Callback = function(value) SensoryESPConfig.NPCs = value end,
})

SensoryGeneral:AddToggle('SensoryLocalPlayer', {
    Text = 'Include local player',
    Default = false,
    Callback = function(value) SensoryESPConfig.LocalPlayer = value end,
})

SensoryGeneral:AddSlider('SensoryLimitFPS', {
    Text = 'ESP FPS limit',
    Default = 70,
    Min = 0,
    Max = 240,
    Rounding = 0,
    Suffix = ' FPS',
    Callback = function(value) SensoryESPConfig.LimitFPS = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicBoxes', {
    Text = 'Dynamic boxes',
    Default = true,
    Callback = function(value) SensoryESPConfig.DynamicBoxes = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicCheap', {
    Text = 'Cheap dynamic boxes',
    Default = false,
    Callback = function(value) SensoryESPConfig.DynamicBoxesCheap = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicAll', {
    Text = 'Include all body parts',
    Default = false,
    Callback = function(value) SensoryESPConfig.DynamicBoxesIncludeAll = value end,
})

SensoryGeneral:AddSlider('SensoryVisibilityRate', {
    Text = 'Visibility check rate',
    Default = 0.3,
    Min = 0.05,
    Max = 2,
    Rounding = 2,
    Suffix = 's',
    Callback = function(value) SensoryESPConfig.VisibilityCheckRate = value end,
})

local SensoryBoxesToggle = SensoryBoxes:AddToggle('SensoryBoxes', {
    Text = 'Boxes',
    Default = false,
    Callback = function(value) SensoryESPConfig.Boxes = value end,
})
SensoryBoxesToggle:AddColorPicker('SensoryBoxColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Box color',
    Callback = function(color) SensoryESPConfig.BoxColor = color end,
})

SensoryBoxes:AddDropdown('SensoryBoxType', {
    Text = 'Box type',
    Values = {'Normal', 'Corner', 'Circle'},
    Default = 'Normal',
    Callback = function(value) SensoryESPConfig.BoxType = value end,
})

SensoryBoxes:AddSlider('SensoryBoxThickness', {
    Text = 'Box thickness',
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Callback = function(value) SensoryESPConfig.BoxThickness = value end,
})

SensoryBoxes:AddDropdown('SensoryOutlineStyle', {
    Text = 'Outline style',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.Outlines.Style = value end,
})

SensoryBoxes:AddLabel('Outline color'):AddColorPicker('SensoryOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Outline color',
    Callback = function(color) SensoryESPConfig.Outlines.Color = color end,
})

SensoryBoxes:AddSlider('SensoryOutlineThickness', {
    Text = 'Outline thickness',
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Callback = function(value) SensoryESPConfig.Outlines.Thickness = value end,
})

local SensoryFillToggle = SensoryBoxes:AddToggle('SensoryBoxFill', {
    Text = 'Box fill',
    Default = false,
    Callback = function(value) SensoryESPConfig.BoxFill.Enabled = value end,
})
SensoryFillToggle:AddColorPicker('SensoryFillColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Transparency = 0.9,
    Title = 'Fill color',
    Callback = function(color, alpha)
        SensoryESPConfig.BoxFill.Color = color
        SensoryESPConfig.BoxFill.Transparency = alpha
    end,
})

SensoryBoxes:AddToggle('SensoryFillGradient', {
    Text = 'Fill gradient',
    Default = false,
    Callback = function(value) SensoryESPConfig.BoxFill.Gradient.Enabled = value end,
})

SensoryBoxes:AddLabel('Gradient top'):AddColorPicker('SensoryFillGradient1', {
    Default = Color3.fromRGB(180, 255, 255),
    Title = 'Gradient top',
    Callback = function(color) SensoryESPConfig.BoxFill.Gradient.Color1 = color end,
})
SensoryBoxes:AddLabel('Gradient middle'):AddColorPicker('SensoryFillGradient2', {
    Default = Color3.fromRGB(0, 255, 255),
    Title = 'Gradient middle',
    Callback = function(color) SensoryESPConfig.BoxFill.Gradient.Color2 = color end,
})
SensoryBoxes:AddLabel('Gradient bottom'):AddColorPicker('SensoryFillGradient3', {
    Default = Color3.fromRGB(0, 120, 255),
    Title = 'Gradient bottom',
    Callback = function(color) SensoryESPConfig.BoxFill.Gradient.Color3 = color end,
})

SensoryBoxes:AddSlider('SensoryFillRotation', {
    Text = 'Gradient rotation',
    Default = 0,
    Min = 0,
    Max = 360,
    Rounding = 0,
    Suffix = '°',
    Callback = function(value) SensoryESPConfig.BoxFill.Gradient.Rotation = value end,
})
SensoryBoxes:AddToggle('SensoryFillAnimated', {
    Text = 'Animate gradient',
    Default = false,
    Callback = function(value) SensoryESPConfig.BoxFill.Gradient.Animated = value end,
})
SensoryBoxes:AddSlider('SensoryFillSpeed', {
    Text = 'Gradient speed',
    Default = 64,
    Min = 1,
    Max = 360,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.BoxFill.Gradient.Speed = value end,
})
SensoryBoxes:AddDropdown('SensoryFillDirection', {
    Text = 'Gradient direction',
    Values = {'Left', 'Right'},
    Default = 'Right',
    Callback = function(value) SensoryESPConfig.BoxFill.Gradient.Direction = value end,
})

local SensoryNamesToggle = SensoryText:AddToggle('SensoryNames', {
    Text = 'Names',
    Default = false,
    Callback = function(value) SensoryESPConfig.Names = value end,
})
SensoryNamesToggle:AddColorPicker('SensoryTextColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Text color',
    Callback = function(color) SensoryESPConfig.TextColor = color end,
})

SensoryText:AddSlider('SensoryTextSize', {
    Text = 'Text size',
    Default = 12,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.TextSize = value end,
})
SensoryText:AddDropdown('SensoryFont', {
    Text = 'Font',
    Values = SensoryFonts,
    Default = 'Proggy Clean',
    Callback = function(value) SensoryESPConfig.Font = value end,
})
SensoryText:AddToggle('SensoryTextOutline', {
    Text = 'Text outline',
    Default = false,
    Callback = function(value) SensoryESPConfig.TextOutline = value end,
})
SensoryText:AddDropdown('SensoryTextOutlineStyle', {
    Text = 'Text outline style',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.TextOutlineStyle = value end,
})
SensoryText:AddSlider('SensoryTextGap', {
    Text = 'Text gap',
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.TextGap = value end,
})

local SensoryTeamToggle = SensoryText:AddToggle('SensoryTeamIndicator', {
    Text = 'Team indicator',
    Default = false,
    Callback = function(value) SensoryESPConfig.TeamIndicator.Enabled = value end,
})
SensoryTeamToggle:AddColorPicker('SensoryTeamColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Team color',
    Callback = function(color) SensoryESPConfig.TeamIndicator.Color = color end,
})
SensoryText:AddDropdown('SensoryTeamPosition', {
    Text = 'Team position',
    Values = {'Left', 'Right'},
    Default = 'Right',
    Callback = function(value) SensoryESPConfig.TeamIndicator.Position = value end,
})
SensoryText:AddToggle('SensoryUseTeamColor', {
    Text = 'Use Roblox team color',
    Default = false,
    Callback = function(value) SensoryESPConfig.TeamIndicator.UseTeamColor = value end,
})
SensoryText:AddToggle('SensoryCompactTeam', {
    Text = 'Compact team name',
    Default = false,
    Callback = function(value) SensoryESPConfig.TeamIndicator.Compact = value end,
})
SensoryText:AddSlider('SensoryTeamTextSize', {
    Text = 'Team text size',
    Default = 10,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.TeamIndicator.TextSize = value end,
})

local SensoryFriendlyToggle = SensoryText:AddToggle('SensoryFriendlyIndicator', {
    Text = 'Friendly indicator',
    Default = false,
    Callback = function(value) SensoryESPConfig.FriendlyIndicator.Enabled = value end,
})
SensoryFriendlyToggle:AddColorPicker('SensoryFriendlyColor', {
    Default = Color3.fromRGB(0, 255, 0),
    Title = 'Friendly color',
    Callback = function(color) SensoryESPConfig.FriendlyIndicator.Color = color end,
})
SensoryText:AddToggle('SensoryFriendlyTeam', {
    Text = 'Friendly by team',
    Default = false,
    Callback = function(value) SensoryESPConfig.FriendlyIndicator.CheckTeam = value end,
})
SensoryText:AddToggle('SensoryFriendlyFriends', {
    Text = 'Friendly by friends',
    Default = false,
    Callback = function(value) SensoryESPConfig.FriendlyIndicator.CheckFriends = value end,
})
SensoryText:AddDropdown('SensoryFriendlyPosition', {
    Text = 'Friendly position',
    Values = {'Left', 'Right'},
    Default = 'Right',
    Callback = function(value) SensoryESPConfig.FriendlyIndicator.Position = value end,
})
SensoryText:AddInput('SensoryFriendlyText', {
    Text = 'Friendly tag',
    Default = '[F]',
    Callback = function(value) SensoryESPConfig.FriendlyIndicator.Text = value end,
})

local SensoryWeaponToggle = SensoryText:AddToggle('SensoryWeapon', {
    Text = 'Weapon text',
    Default = false,
    Callback = function(value) SensoryESPConfig.Weapon.Enabled = value end,
})
SensoryWeaponToggle:AddColorPicker('SensoryWeaponColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Weapon text color',
    Callback = function(color) SensoryESPConfig.Weapon.Color = color end,
})
SensoryText:AddSlider('SensoryWeaponGap', {
    Text = 'Weapon gap',
    Default = 1,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Weapon.Gap = value end,
})
SensoryText:AddDropdown('SensoryWeaponFont', {
    Text = 'Weapon font',
    Values = SensoryFonts,
    Default = 'Proggy Clean',
    Callback = function(value) SensoryESPConfig.Weapon.Font = value end,
})
SensoryText:AddDropdown('SensoryWeaponOutline', {
    Text = 'Weapon outline',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.Weapon.OutlineStyle = value end,
})
SensoryText:AddSlider('SensoryWeaponTextSize', {
    Text = 'Weapon text size',
    Default = 12,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Weapon.TextSize = value end,
})
SensoryText:AddToggle('SensoryWeaponFallback', {
    Text = 'Use equipped tool fallback',
    Default = false,
    Callback = function(value) SensoryESPConfig.Weapon.UseToolFallback = value end,
})

local SensoryDistanceToggle = SensoryText:AddToggle('SensoryDistance', {
    Text = 'Distance',
    Default = false,
    Callback = function(value) SensoryESPConfig.Distance.Enabled = value end,
})
SensoryDistanceToggle:AddColorPicker('SensoryDistanceColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Distance color',
    Callback = function(color) SensoryESPConfig.Distance.Color = color end,
})
SensoryText:AddDropdown('SensoryDistanceUnit', {
    Text = 'Distance unit',
    Values = {'Meters', 'Studs'},
    Default = 'Meters',
    Callback = function(value)
        SensoryESPConfig.Distance.Unit = value
        SensoryESPConfig.Distance.Ending = value == 'Meters' and 'm' or 'st'
    end,
})
SensoryText:AddSlider('SensoryStudsPerMeter', {
    Text = 'Studs per meter',
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(value) SensoryESPConfig.Distance.StudsPerMeter = value end,
})
SensoryText:AddSlider('SensoryDistanceGap', {
    Text = 'Distance gap',
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Distance.Gap = value end,
})
SensoryText:AddDropdown('SensoryDistanceOutline', {
    Text = 'Distance outline',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.Distance.OutlineStyle = value end,
})
SensoryText:AddDropdown('SensoryDistanceFont', {
    Text = 'Distance font',
    Values = SensoryFonts,
    Default = 'Proggy Clean',
    Callback = function(value) SensoryESPConfig.Distance.Font = value end,
})
SensoryText:AddSlider('SensoryDistanceTextSize', {
    Text = 'Distance text size',
    Default = 12,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Distance.TextSize = value end,
})

local SensoryHealthToggle = SensoryHealth:AddToggle('SensoryHealthbar', {
    Text = 'Healthbar',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.Enabled = value end,
})
SensoryHealthToggle:AddColorPicker('SensoryHealthHigh', {
    Default = Color3.fromRGB(0, 255, 0),
    Title = 'High health',
    Callback = function(color) SensoryESPConfig.HealthBar.Gradient.Color1 = color end,
})
SensoryHealth:AddLabel('Middle health'):AddColorPicker('SensoryHealthMiddle', {
    Default = Color3.fromRGB(255, 255, 0),
    Title = 'Middle health',
    Callback = function(color) SensoryESPConfig.HealthBar.Gradient.Color2 = color end,
})
SensoryHealth:AddLabel('Low health'):AddColorPicker('SensoryHealthLow', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'Low health',
    Callback = function(color) SensoryESPConfig.HealthBar.Gradient.Color3 = color end,
})
SensoryHealth:AddDropdown('SensoryHealthPosition', {
    Text = 'Position',
    Values = {'Left', 'Right', 'Top', 'Bottom'},
    Default = 'Left',
    Callback = function(value) SensoryESPConfig.HealthBar.Position = value end,
})
SensoryHealth:AddSlider('SensoryHealthSideGap', {
    Text = 'Side gap',
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.HealthBar.SideGap = value end,
})
SensoryHealth:AddSlider('SensoryHealthWidth', {
    Text = 'Width',
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.HealthBar.Width = value end,
})
SensoryHealth:AddToggle('SensoryHealthText', {
    Text = 'Show health text',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.ShowText = value end,
})
SensoryHealth:AddToggle('SensoryHealthFollow', {
    Text = 'Text follows bar',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.TextFollowBar = value end,
})
SensoryHealth:AddToggle('SensoryHealthHideFull', {
    Text = 'Hide at full health',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.HideWhenFullHP = value end,
})
SensoryHealth:AddToggle('SensoryHealthTextGradient', {
    Text = 'Gradient health text',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.FollowGradientColorText = value end,
})
SensoryHealth:AddToggle('SensoryHealthGradient', {
    Text = 'Health gradient',
    Default = false,
    Callback = function(value) SensoryESPConfig.HealthBar.Gradient.Enabled = value end,
})
SensoryHealth:AddDropdown('SensoryHealthOutline', {
    Text = 'Health outline',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.HealthBar.Outline.Style = value end,
})
SensoryHealth:AddLabel('Health outline color'):AddColorPicker('SensoryHealthOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Health outline color',
    Callback = function(color) SensoryESPConfig.HealthBar.Outline.Color = color end,
})
SensoryHealth:AddDropdown('SensoryHealthFont', {
    Text = 'Health font',
    Values = SensoryFonts,
    Default = 'Smallest Pixel-7',
    Callback = function(value) SensoryESPConfig.HealthBar.Font = value end,
})
SensoryHealth:AddSlider('SensoryHealthTextSize', {
    Text = 'Health text size',
    Default = 9,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.HealthBar.TextSize = value end,
})

local SensoryFlagsToggle = SensoryFlags:AddToggle('SensoryFlags', {
    Text = 'Movement flags',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Enabled = value end,
})
SensoryFlagsToggle:AddColorPicker('SensoryFlagIdleColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Idle flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.Idle = color end,
})
SensoryFlags:AddToggle('SensoryFlagIdle', {
    Text = 'Idle flag',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Options.Idle = value end,
})
SensoryFlags:AddToggle('SensoryFlagMoving', {
    Text = 'Moving flag',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Options.Moving = value end,
}):AddColorPicker('SensoryFlagMovingColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Moving flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.Moving = color end,
})
SensoryFlags:AddToggle('SensoryFlagJumping', {
    Text = 'Jumping flag',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Options.Jumping = value end,
}):AddColorPicker('SensoryFlagJumpingColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Jumping flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.Jumping = color end,
})
SensoryFlags:AddToggle('SensoryFlagSwimming', {
    Text = 'Swimming flag',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Options.Swimming = value end,
}):AddColorPicker('SensoryFlagSwimmingColor', {
    Default = Color3.fromRGB(65, 65, 255),
    Title = 'Swimming flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.Swimming = color end,
})
SensoryFlags:AddDropdown('SensoryFlagsPosition', {
    Text = 'Flags position',
    Values = {'Left', 'Right'},
    Default = 'Right',
    Callback = function(value) SensoryESPConfig.Flags.Position = value end,
})
SensoryFlags:AddDropdown('SensoryFlagsFont', {
    Text = 'Flags font',
    Values = SensoryFonts,
    Default = 'Smallest Pixel-7',
    Callback = function(value) SensoryESPConfig.Flags.Font = value end,
})
SensoryFlags:AddSlider('SensoryFlagsSize', {
    Text = 'Flags text size',
    Default = 9,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Flags.TextSize = value end,
})
SensoryFlags:AddSlider('SensoryFlagsGap', {
    Text = 'Flag row gap',
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Flags.Gap = value end,
})
SensoryFlags:AddSlider('SensoryFlagsSideGap', {
    Text = 'Flag side gap',
    Default = 4,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Flags.SideGap = value end,
})
SensoryFlags:AddSlider('SensoryFlagsTextGap', {
    Text = 'Flag text gap',
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.Flags.TextGap = value end,
})
SensoryFlags:AddDropdown('SensoryFlagsOutline', {
    Text = 'Flags outline',
    Values = {'Full', 'None'},
    Default = 'Full',
    Callback = function(value) SensoryESPConfig.Flags.OutlineStyle = value end,
})

local SensorySkeletonToggle = SensoryFlags:AddToggle('SensorySkeleton', {
    Text = 'Skeleton',
    Default = false,
    Callback = function(value) SensoryESPConfig.Skeleton.Enabled = value end,
})
SensorySkeletonToggle:AddColorPicker('SensorySkeletonColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Skeleton color',
    Callback = function(color) SensoryESPConfig.Skeleton.Color = color end,
})
SensoryFlags:AddToggle('SensorySkeletonOutline', {
    Text = 'Skeleton outline',
    Default = false,
    Callback = function(value) SensoryESPConfig.Skeleton.Outline = value end,
}):AddColorPicker('SensorySkeletonOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Skeleton outline',
    Callback = function(color) SensoryESPConfig.Skeleton.OutlineColor = color end,
})
SensoryFlags:AddToggle('SensorySkeletonGradient', {
    Text = 'Skeleton gradient',
    Default = false,
    Callback = function(value) SensoryESPConfig.Skeleton.Gradient.Enabled = value end,
})
SensoryFlags:AddLabel('Skeleton gradient start'):AddColorPicker('SensorySkeletonGradient1', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Skeleton gradient start',
    Callback = function(color) SensoryESPConfig.Skeleton.Gradient.Color1 = color end,
})
SensoryFlags:AddLabel('Skeleton gradient end'):AddColorPicker('SensorySkeletonGradient2', {
    Default = Color3.fromRGB(100, 200, 255),
    Title = 'Skeleton gradient end',
    Callback = function(color) SensoryESPConfig.Skeleton.Gradient.Color2 = color end,
})

local SensoryArrowToggle = SensoryOffscreen:AddToggle('SensoryArrows', {
    Text = 'Offscreen arrows',
    Default = false,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Enabled = value end,
})
SensoryArrowToggle:AddColorPicker('SensoryArrowColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Arrow color',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.Color = color end,
})
SensoryOffscreen:AddSlider('SensoryArrowSize', {
    Text = 'Arrow size',
    Default = 14,
    Min = 5,
    Max = 40,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Size = value end,
})
SensoryOffscreen:AddSlider('SensoryArrowRadius', {
    Text = 'Orbit radius',
    Default = 100,
    Min = 30,
    Max = 500,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.OrbitRadius = value end,
})
SensoryOffscreen:AddDropdown('SensoryArrowMode', {
    Text = 'Arrow mode',
    Values = {'Camera', 'Center'},
    Default = 'Camera',
    Callback = function(value) SensoryESPConfig.OffScreenArrows.ArrowMode = value end,
})
SensoryOffscreen:AddToggle('SensoryArrowOutline', {
    Text = 'Arrow outline',
    Default = false,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Outline = value end,
}):AddColorPicker('SensoryArrowOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Arrow outline',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.OutlineColor = color end,
})
SensoryOffscreen:AddToggle('SensoryArrowNames', {
    Text = 'Arrow names',
    Default = false,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.Enabled = value end,
})
SensoryOffscreen:AddLabel('Arrow name color'):AddColorPicker('SensoryArrowNameColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Arrow name color',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.Names.Color = color end,
})
SensoryOffscreen:AddDropdown('SensoryArrowNameFont', {
    Text = 'Arrow name font',
    Values = SensoryFonts,
    Default = 'Smallest Pixel-7',
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.Font = value end,
})
SensoryOffscreen:AddSlider('SensoryArrowNameSize', {
    Text = 'Arrow name size',
    Default = 9,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.TextSize = value end,
})
SensoryOffscreen:AddToggle('SensoryArrowNameOutline', {
    Text = 'Arrow name outline',
    Default = true,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.Outline = value end,
}):AddColorPicker('SensoryArrowNameOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Arrow name outline',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.Names.OutlineColor = color end,
})
SensoryOffscreen:AddDropdown('SensoryArrowNameSide', {
    Text = 'Arrow name side',
    Values = {'Top', 'Bottom', 'Left', 'Right'},
    Default = 'Bottom',
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.Side = value end,
})
SensoryOffscreen:AddSlider('SensoryArrowNameGap', {
    Text = 'Arrow name gap',
    Default = 4,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Names.Gap = value end,
})
SensoryOffscreen:AddToggle('SensoryArrowDistance', {
    Text = 'Arrow distance',
    Default = false,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.Enabled = value end,
})
SensoryOffscreen:AddLabel('Arrow distance color'):AddColorPicker('SensoryArrowDistanceColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Arrow distance color',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.Distance.Color = color end,
})
SensoryOffscreen:AddDropdown('SensoryArrowDistanceFont', {
    Text = 'Arrow distance font',
    Values = SensoryFonts,
    Default = 'Smallest Pixel-7',
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.Font = value end,
})
SensoryOffscreen:AddSlider('SensoryArrowDistanceSize', {
    Text = 'Arrow distance size',
    Default = 9,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.TextSize = value end,
})
SensoryOffscreen:AddToggle('SensoryArrowDistanceOutline', {
    Text = 'Arrow distance outline',
    Default = false,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.Outline = value end,
}):AddColorPicker('SensoryArrowDistanceOutlineColor', {
    Default = Color3.fromRGB(0, 0, 0),
    Title = 'Arrow distance outline',
    Callback = function(color) SensoryESPConfig.OffScreenArrows.Distance.OutlineColor = color end,
})
SensoryOffscreen:AddDropdown('SensoryArrowDistanceSide', {
    Text = 'Arrow distance side',
    Values = {'Top', 'Bottom', 'Left', 'Right'},
    Default = 'Bottom',
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.Side = value end,
})
SensoryOffscreen:AddSlider('SensoryArrowDistanceGap', {
    Text = 'Arrow distance gap',
    Default = 2,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) SensoryESPConfig.OffScreenArrows.Distance.Gap = value end,
})

SensoryChams:AddToggle('SensoryChams', {
    Text = 'Chams',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Enabled = value end,
})
SensoryChams:AddDropdown('SensoryChamsType', {
    Text = 'Chams type',
    Values = {'Highlight', 'Adornment', 'MeshChams'},
    Default = 'MeshChams',
    Callback = function(value) SensoryESPConfig.Chams.Type = value end,
})

SensoryChams:AddLabel('Highlight fill'):AddColorPicker('SensoryHighlightFill', {
    Default = Color3.fromRGB(255, 255, 255),
    Transparency = 1,
    Title = 'Highlight fill',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.Highlight.FillColor = color
        SensoryESPConfig.Chams.Highlight.FillTransparency = alpha
    end,
})
SensoryChams:AddLabel('Highlight outline'):AddColorPicker('SensoryHighlightOutline', {
    Default = Color3.fromRGB(255, 255, 255),
    Transparency = 0,
    Title = 'Highlight outline',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.Highlight.OutlineColor = color
        SensoryESPConfig.Chams.Highlight.OutlineTransparency = alpha
    end,
})
SensoryChams:AddToggle('SensoryHighlightVisible', {
    Text = 'Highlight visible check',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Highlight.VisibleCheck = value end,
})

SensoryChams:AddLabel('Adornment hidden'):AddColorPicker('SensoryAdornmentColor', {
    Default = Color3.fromRGB(59, 144, 204),
    Transparency = 0.7,
    Title = 'Adornment hidden',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.Adornment.Color = color
        if alpha ~= nil then SensoryESPConfig.Chams.Adornment.Transparency = alpha end
    end,
})
SensoryChams:AddLabel('Adornment visible'):AddColorPicker('SensoryAdornmentVisible', {
    Default = Color3.fromRGB(59, 204, 90),
    Title = 'Adornment visible',
    Callback = function(color) SensoryESPConfig.Chams.Adornment.VisibleColor = color end,
})
SensoryChams:AddToggle('SensoryAdornmentTop', {
    Text = 'Adornment always on top',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Adornment.AlwaysOnTop = value end,
})
SensoryChams:AddToggle('SensoryAdornmentVisibleCheck', {
    Text = 'Adornment visible check',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Adornment.VisibleCheck = value end,
})

SensoryChams:AddLabel('Mesh fill'):AddColorPicker('SensoryMeshFill', {
    Default = Color3.fromRGB(59, 144, 204),
    Transparency = 0.6,
    Title = 'Mesh fill',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.MeshChams.FillColor = color
        SensoryESPConfig.Chams.MeshChams.FillTransparency = alpha
    end,
})
SensoryChams:AddLabel('Mesh outline'):AddColorPicker('SensoryMeshOutline', {
    Default = Color3.fromRGB(255, 255, 255),
    Transparency = 0,
    Title = 'Mesh outline',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.MeshChams.OutlineColor = color
        SensoryESPConfig.Chams.MeshChams.OutlineTransparency = alpha
    end,
})
SensoryChams:AddToggle('SensoryMeshVisible', {
    Text = 'Mesh visible check',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.MeshChams.VisibleCheck = value end,
})

local SettingsPage = Window:AddTab('Settings')
local PlayerStatusColorsSection = SettingsPage:AddCenterGroupbox('Player Status Colors')
local MenuSection = SettingsPage:AddColumnGroupbox(3, 'Menu')

PlayerStatusColorsSection:AddLabel('Target name'):AddColorPicker('Settings_TargetNameColor', {
    Default = Color3.fromRGB(255, 220, 0),
    Title = 'Target name color',
    Callback = function(color)
        SensoryESPConfig.PlayerStatusColors.Target = color
        if Playerlist and Playerlist.Refresh then Playerlist:Refresh() end
    end,
})

PlayerStatusColorsSection:AddLabel('Friendly name'):AddColorPicker('Settings_FriendlyNameColor', {
    Default = Color3.fromRGB(0, 255, 0),
    Title = 'Friendly name color',
    Callback = function(color)
        SensoryESPConfig.PlayerStatusColors.Friendly = color
        if Playerlist and Playerlist.Refresh then Playerlist:Refresh() end
    end,
})

MenuSection:AddLabel('Menu keybind'):AddKeyPicker('Settings_MenuKeybind', {
    Default = 'RightControl',
    NoUI = true,
    Text = 'Menu keybind',
})
Library.ToggleKeybind = Options.Settings_MenuKeybind

MenuSection:AddButton({
    Text = 'Unload script',
    DoubleClick = true,
    Func = function()
        getgenv().drain_loaded = false
        getgenv().drain_build = nil
        if type(getgenv().DrainHavocCleanup) == 'function' then
            pcall(getgenv().DrainHavocCleanup)
            getgenv().DrainHavocCleanup = nil
        end
        SensoryESP:Unload()
        Library:Unload()
    end,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder('drain.solutions')
SaveManager:SetFolder('drain.solutions/Havoc')
SaveManager:IgnoreThemeSettings()
ThemeManager:ApplyToTab(SettingsPage)
SaveManager:BuildConfigSection(SettingsPage)
SaveManager:LoadAutoloadConfig()

Library:Notify('drain.solutions loaded successfully', 5)
Environment.drain_build = DRAIN_BUILD
Environment.drain_loaded = true
end, function(Message)
    local Text = tostring(Message)
    if debug and type(debug.traceback) == 'function' then
        return debug.traceback(Text, 2)
    end
    return Text
end)

if not LoadSuccess then
    Environment.drain_loaded = false
    Environment.drain_build = nil
    warn('[drain.solutions] load failed:\n' .. tostring(LoadError))
end
