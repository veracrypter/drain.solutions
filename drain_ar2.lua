-- esp only may could be unopdated

local DRAIN_BOOT_LINES = {}

local function drain_boot_dump(text)
    DRAIN_BOOT_LINES[#DRAIN_BOOT_LINES + 1] = text
    if type(writefile) == "function" then
        pcall(writefile, "drain_boot.txt", table.concat(DRAIN_BOOT_LINES, "\n"))
    end
end

local function drain_report_fail(tag, err)
    local text = tostring(err)
    warn(string.format("[drain] %s failed: %s", tostring(tag), text))
    drain_boot_dump(string.format("FAIL %s: %s", tostring(tag), text))

    local line = text:gsub("%s+", " ")
    if #line > 180 then
        line = line:sub(1, 180) .. "..."
    end

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "drain: " .. tostring(tag) .. " failed",
            Text = line,
            Duration = 15,
        })
    end)
end

local function RunDrain()
pcall(function()
    local inputService = game:GetService("UserInputService")
    if setfflag and not inputService.TouchEnabled then
        setfflag("AdornShadingAPI", "true")
    end
end)

local DRAIN_BOOT_START = os.clock()
local DRAIN_LAST_STAGE = "start"

local function drain_boot_log(stage)
    DRAIN_LAST_STAGE = stage
    local elapsed = os.clock() - DRAIN_BOOT_START
    local text = string.format("drain boot: %s (%.1fs)", stage, elapsed)
    print(text)
    drain_boot_dump(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "drain boot",
            Text = string.format("%s (%.1fs)", stage, elapsed),
            Duration = 1,
        })
    end)
end

local function drain_wait_player_gui(timeout)
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil end
    local existing = player:FindFirstChildOfClass("PlayerGui")
    if existing then return existing end
    return player:WaitForChild("PlayerGui", timeout or 10)
end

drain_boot_log("start")

if not game:IsLoaded() then
    drain_boot_log("waiting for game.Loaded")
    game.Loaded:Wait()
end

drain_boot_log("game loaded")

local drain_ac_state = { Done = false, Patched = 0, Variant = "none", KickHits = { count = 0 } }
getgenv().drain_ac_state = drain_ac_state
getgenv().drain_ac_kick_hits = drain_ac_state.KickHits

local anticheat_ok, anticheat_err = pcall(function()
    if getgenv().drain_skip_anticheat then
        drain_boot_log("anticheat skipped by flag")
        return
    end

    if type(getgc) ~= "function" then
        drain_boot_log("anticheat skipped: executor has no getgc")
        return
    end

    local isMobile = game:GetService("UserInputService").TouchEnabled

    if isMobile then
        drain_boot_log("anticheat skipped: mobile")
        return
    end

    drain_boot_log("anticheat: calling getgc")
    local objects = getgc(true)
    local total = #objects
    drain_boot_log("getgc returned " .. tostring(total))

    local slice = isMobile and 0.004 or 0.008
    local deadline = os.clock() + (isMobile and 20 or 10)
    local sliceStart = os.clock()
    local patched = 0
    local stoppedAt = 0

    local kickHits = drain_ac_state.KickHits
    local function swallow_kick()
        kickHits.count += 1
    end
    local function park_kick()
        kickHits.count += 1
        return task.wait(9e9)
    end

    local kick_handler = isMobile and swallow_kick or park_kick
    drain_ac_state.Variant = isMobile and "return" or "park"

    for index = 1, total do
        local v1 = objects[index]
        if typeof(v1) == "table" then
            if rawget(v1, "indexInstance") or rawget(v1, "newindexInstance") or rawget(v1, "newIndexInstance") then
                local written = pcall(function()
                    v1.tvk = { "kick", kick_handler }
                end)
                if written then patched += 1 end
            end
        end

        if index % 512 == 0 then
            local now = os.clock()
            if now >= deadline then
                stoppedAt = index
                break
            end
            if now - sliceStart >= slice then
                task.wait()
                sliceStart = os.clock()
            end
            if index % 20480 == 0 then
                drain_boot_dump(string.format("anticheat scan %d/%d patched %d (%.1fs)",
                    index, total, patched, now - DRAIN_BOOT_START))
            end
        end
    end

    objects = nil
    drain_ac_state.Patched = patched

    if stoppedAt > 0 then
        drain_boot_log(string.format("anticheat hit the time cap at %d/%d, patched %d (%s)",
            stoppedAt, total, patched, drain_ac_state.Variant))
    else
        drain_boot_log(string.format("anticheat done, patched %d of %d (%s)",
            patched, total, drain_ac_state.Variant))
    end
end)

if not anticheat_ok then
    drain_report_fail("anticheat", anticheat_err)
end

drain_ac_state.Done = true
drain_boot_log(string.format("anticheat block exited (%s, ac hits %d)",
    drain_ac_state.Variant, drain_ac_state.KickHits.count))

drain_boot_log("entering main")

local DRAIN_BUILD = 'singlefile-2026-08-19-esp-backend-v2.1'
local Environment = getgenv()

if Environment.drain_loaded and Environment.drain_build == DRAIN_BUILD then
    local ExistingLibrary = Environment.Library
    if ExistingLibrary and type(ExistingLibrary.Notify) == 'function' then
        pcall(function()
            ExistingLibrary:Notify('drain.solutions is already loaded', 5)
        end)
    end
    return
end

if type(Environment.DrainCursorDrawings) == 'table' then
    for _, DrawingObject in ipairs(Environment.DrainCursorDrawings) do
        pcall(function()
            DrawingObject.Visible = false
            DrawingObject:Remove()
        end)
    end
end
Environment.DrainCursorDrawings = nil

if Environment.drain_loaded then

    if type(Environment.DrainRagebotCleanup) == 'function' then
        pcall(Environment.DrainRagebotCleanup)
        Environment.DrainRagebotCleanup = nil
    end

    if type(Environment.DrainLegitAimbotCleanup) == 'function' then
        pcall(Environment.DrainLegitAimbotCleanup)
        Environment.DrainLegitAimbotCleanup = nil
    end

    if type(Environment.DrainSilentAimCleanup) == 'function' then
        pcall(Environment.DrainSilentAimCleanup)
        Environment.DrainSilentAimCleanup = nil
    end

    if type(Environment.DrainBulletTracerCleanup) == 'function' then
        pcall(Environment.DrainBulletTracerCleanup)
        Environment.DrainBulletTracerCleanup = nil
    end

    if type(Environment.DrainProjectileControlCleanup) == 'function' then
        pcall(Environment.DrainProjectileControlCleanup)
        Environment.DrainProjectileControlCleanup = nil
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
local Workspace = game:GetService('Workspace');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'drain.solutions'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local PlayerGui = drain_wait_player_gui(10)
local ScreenGuiParented = false
if PlayerGui then
    ScreenGuiParented = pcall(function() ScreenGui.Parent = PlayerGui end)
end
if not ScreenGuiParented then
    drain_boot_log("PlayerGui unavailable, falling back to CoreGui")
    ScreenGuiParented = pcall(function() ScreenGui.Parent = CoreGui end)
end
if not ScreenGuiParented then
    drain_boot_log("FATAL: nowhere to parent the ui")
    error('drain: could not parent the ui to PlayerGui or CoreGui', 0)
end
drain_boot_log("ui root ready")

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
    WarnColor = Color3.fromRGB(255, 200, 0),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    UnloadCallbacks = {};
    ScreenGui = ScreenGui;

    NotifyOnError = true;
    WatermarkEnabled = false;
    WatermarkTemplate = 'drain.solutions | {fps} FPS | {ping} ms';
    CurrentFPS = 0;
    CurrentPing = 0;
    DragUpdateRate = 1 / 60;
    MenuOpen = false;
    MobileBindButtons = {};
    MobileBindButtonCount = 0;
    ActivePointerOwner = nil;
    ActivePointerInput = nil;
    TouchMoveThreshold = 10;
    CustomBackgroundEnabled = false;
    CustomBackgroundAsset = '';
    CustomBackgroundTransparency = 0.35;
    CustomBackgroundPanelTransparency = 0.2;
    CustomBackgroundScaleType = 'Crop';
    CustomBackgroundPanels = setmetatable({}, { __mode = 'k' });
    CustomBackgroundImage = nil;
};

local Platform;
pcall(function()
    Platform = InputService:GetPlatform();
end);

local IsNativeMobilePlatform = Platform == Enum.Platform.Android or Platform == Enum.Platform.IOS;
Library.IsTouchDevice = InputService.TouchEnabled;
Library.IsMobile = Library.IsTouchDevice and (IsNativeMobilePlatform or not InputService.KeyboardEnabled);
Library.Platform = Platform;
Library.MobileControlHeight = 28;

if Library.IsMobile then
    local MobileFovGui = Instance.new('ScreenGui');
    MobileFovGui.Name = 'DrainMobileFov';
    MobileFovGui.IgnoreGuiInset = true;
    MobileFovGui.ResetOnSpawn = false;
    MobileFovGui.DisplayOrder = 999;
    MobileFovGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
    local MobilePlayerGui = drain_wait_player_gui(10)
    local ParentSuccess = false
    if MobilePlayerGui then
        ParentSuccess = pcall(function() MobileFovGui.Parent = MobilePlayerGui end)
    end
    if not ParentSuccess then
        ParentSuccess = pcall(function() MobileFovGui.Parent = CoreGui end)
    end
    if not ParentSuccess then
        drain_boot_log("mobile fov gui could not be parented, skipping")
        MobileFovGui:Destroy()
        MobileFovGui = nil
    end;

    Library.MobileFovGui = MobileFovGui;
end;

function Library:GetViewportSize()
    local Camera = Workspace.CurrentCamera;
    return Camera and Camera.ViewportSize or Vector2.new(1920, 1080);
end;

function Library:RefreshDeviceClass()
    if not Library.IsMobile then
        Library.DeviceClass = 'Desktop';
        return Library.DeviceClass;
    end;

    local Viewport = Library:GetViewportSize();
    local ShortSide = math.min(Viewport.X, Viewport.Y);
    local LongSide = math.max(Viewport.X, Viewport.Y);
    local AspectRatio = LongSide / math.max(ShortSide, 1);
    Library.DeviceClass = (ShortSide <= 760 or AspectRatio >= 1.75) and 'Phone' or 'Tablet';
    return Library.DeviceClass;
end;

function Library:RegisterCustomBackgroundPanel(Object)
    if typeof(Object) ~= 'Instance' or not Object:IsA('GuiObject') then
        return;
    end;

    if Library.CustomBackgroundPanels[Object] == nil then
        Library.CustomBackgroundPanels[Object] = Object.BackgroundTransparency;
    end;

    Object.BackgroundTransparency = Library.CustomBackgroundEnabled
        and Library.CustomBackgroundPanelTransparency
        or Library.CustomBackgroundPanels[Object];
end;

function Library:RefreshCustomBackground()
    local BackgroundImage = Library.CustomBackgroundImage;
    local HasAsset = type(Library.CustomBackgroundAsset) == 'string'
        and Library.CustomBackgroundAsset ~= '';

    if BackgroundImage and BackgroundImage.Parent then
        BackgroundImage.Image = HasAsset and Library.CustomBackgroundAsset or '';
        BackgroundImage.ImageTransparency = math.clamp(Library.CustomBackgroundTransparency or 0.35, 0, 1);
        BackgroundImage.ScaleType = Enum.ScaleType[Library.CustomBackgroundScaleType] or Enum.ScaleType.Crop;
        BackgroundImage.Visible = Library.CustomBackgroundEnabled and HasAsset;
    end;

    for Object, OriginalTransparency in pairs(Library.CustomBackgroundPanels) do
        if Object and Object.Parent then
            Object.BackgroundTransparency = Library.CustomBackgroundEnabled and HasAsset
                and math.clamp(Library.CustomBackgroundPanelTransparency or 0.2, 0, 1)
                or OriginalTransparency;
        else
            Library.CustomBackgroundPanels[Object] = nil;
        end;
    end;
end;

function Library:SetCustomBackgroundAsset(Asset)
    Library.CustomBackgroundAsset = type(Asset) == 'string' and Asset or '';
    Library:RefreshCustomBackground();
end;

function Library:SetCustomBackgroundEnabled(State)
    Library.CustomBackgroundEnabled = State == true;
    Library:RefreshCustomBackground();
end;

function Library:SetCustomBackgroundTransparency(Value)
    Library.CustomBackgroundTransparency = math.clamp(tonumber(Value) or 0.35, 0, 1);
    Library:RefreshCustomBackground();
end;

function Library:SetCustomBackgroundPanelTransparency(Value)
    Library.CustomBackgroundPanelTransparency = math.clamp(tonumber(Value) or 0.2, 0, 1);
    Library:RefreshCustomBackground();
end;

function Library:SetCustomBackgroundScaleType(Value)
    Library.CustomBackgroundScaleType = Enum.ScaleType[tostring(Value)] and tostring(Value) or 'Crop';
    Library:RefreshCustomBackground();
end;

function Library:IsPrimaryInput(Input)
    if not Input then return false; end;

    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or (Library.IsTouchDevice and Input.UserInputType == Enum.UserInputType.Touch);
end;

function Library:GetRawPointerPosition(Input)
    if Input and Input.UserInputType == Enum.UserInputType.Touch and Input.Position then
        return Vector2.new(Input.Position.X, Input.Position.Y);
    end;

    return InputService:GetMouseLocation();
end;

function Library:GetInputPosition(Input)
    local Position = Library:GetRawPointerPosition(Input);
    if Input and Input.UserInputType == Enum.UserInputType.Touch then
        return Position;
    end;

    if not ScreenGui.IgnoreGuiInset then
        local TopLeftInset = game:GetService('GuiService'):GetGuiInset();
        Position = Position - Vector2.new(TopLeftInset.X, TopLeftInset.Y);
    end;

    return Position;
end;

function Library:IsInputActive(Input)
    if not Input then return false; end;

    if Input.UserInputType == Enum.UserInputType.Touch then
        return Input.UserInputState ~= Enum.UserInputState.End
            and Input.UserInputState ~= Enum.UserInputState.Cancel;
    end;

    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
    end;

    return false;
end;

function Library:IsSameInput(Input, ActiveInput)
    if not Input or not ActiveInput then return false; end;
    if Input == ActiveInput then return true; end;

    return Input.UserInputType == Enum.UserInputType.MouseButton1
        and ActiveInput.UserInputType == Enum.UserInputType.MouseButton1;
end;

function Library:ClaimPointer(Owner, Input)
    if not Owner or not Library:IsPrimaryInput(Input) then return false; end;

    if Library.ActivePointerOwner then
        if Library.ActivePointerOwner == Owner
            and Library:IsSameInput(Input, Library.ActivePointerInput) then
            return true;
        end;

        if Library:IsInputActive(Library.ActivePointerInput) then
            return false;
        end;
    end;

    Library.ActivePointerOwner = Owner;
    Library.ActivePointerInput = Input;
    return true;
end;

function Library:ReleasePointer(Owner, Input)
    if Library.ActivePointerOwner ~= Owner then return; end;
    if Input and not Library:IsSameInput(Input, Library.ActivePointerInput) then return; end;

    Library.ActivePointerOwner = nil;
    Library.ActivePointerInput = nil;
end;

function Library:BindClick(Instance, Callback)
    Instance.Active = true;

    local Owner = {};
    local PressInput;
    local PressPosition;

    Instance.InputBegan:Connect(function(Input)
        if not Library:IsPrimaryInput(Input) then return; end;
        if not Library:ClaimPointer(Owner, Input) then return; end;

        PressInput = Input;
        PressPosition = Library:GetInputPosition(Input);

        if Input.UserInputType ~= Enum.UserInputType.Touch then
            Library:SafeCallback(Callback, Input);
        end;
    end);

    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if not Library:IsSameInput(Input, PressInput) then return; end;

        if Input.UserInputType == Enum.UserInputType.Touch
            and Library.ActivePointerOwner == Owner then

            local EndPosition = Library:GetInputPosition(Input);
            local Travel = (EndPosition - PressPosition).Magnitude;
            if Travel <= Library.TouchMoveThreshold and Library:IsMouseOverFrame(Instance, Input) then
                Library:SafeCallback(Callback, Input);
            end;
        end;

        PressInput = nil;
        PressPosition = nil;
        Library:ReleasePointer(Owner, Input);
    end));

    return Owner;
end;

function Library:ClampPopupPosition(Frame, X, Y, Padding)
    local Viewport = Library:GetViewportSize();
    local FrameSize = Frame.AbsoluteSize;
    local Width = FrameSize.X > 0 and FrameSize.X or Frame.Size.X.Offset;
    local Height = FrameSize.Y > 0 and FrameSize.Y or Frame.Size.Y.Offset;
    local Edge = Padding or 6;

    return UDim2.fromOffset(
        math.clamp(X, Edge, math.max(Edge, Viewport.X - Width - Edge)),
        math.clamp(Y, Edge, math.max(Edge, Viewport.Y - Height - Edge))
    );
end;

Library:RefreshDeviceClass();

local RainbowStep = 0
local Hue = 0

Library.AnimatedColorPickers = setmetatable({}, { __mode = 'k' });
local AnimatedColorPickerStep = 0;

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

    AnimatedColorPickerStep = AnimatedColorPickerStep + Delta;
    if AnimatedColorPickerStep >= (1 / 30) then
        AnimatedColorPickerStep = 0;
        local Now = os.clock();

        for ColorPicker in next, Library.AnimatedColorPickers do
            if ColorPicker.AnimationMode ~= 'Static' and ColorPicker.AnimationTick then
                if not ColorPicker.DisplayFrame or not ColorPicker.DisplayFrame.Parent then
                    Library.AnimatedColorPickers[ColorPicker] = nil;
                else
                    local Success = pcall(ColorPicker.AnimationTick, ColorPicker, Now);
                    if not Success then
                        Library.AnimatedColorPickers[ColorPicker] = nil;
                    end;
                end;
            end;
        end;
    end;
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
        local message = tostring(event);
        warn('[drain] callback errored: ' .. message);

        local _, i = message:find(":%d+: ");
        if i then
            message = message:sub(i + 1);
        end;

        pcall(function()
            Library:Notify(message, 6);
        end);
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

    local DragHeight = Cutoff or 40;
    local DragOwner = {};
    local Dragging = false;
    local DragElapsed = 0;
    local DragStart;
    local StartPosition;
    local LastDelta;
    local DragInput;

    local DragHandle = Library:Create('TextButton', {
        Name = 'DragHandle';
        Active = true;
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Modal = false;
        Selectable = false;
        Size = UDim2.new(1, 0, 0, DragHeight);
        Text = '';
        TextTransparency = 1;
        ZIndex = Instance.ZIndex + 10;
        Parent = Instance;
    });

    DragHandle.InputBegan:Connect(function(Input)
        if not Library:IsPrimaryInput(Input) then return; end;
        if not Library:ClaimPointer(DragOwner, Input) then return; end;

        DragStart = Library:GetInputPosition(Input);
        StartPosition = Instance.AbsolutePosition;
        DragElapsed = Library.DragUpdateRate;
        LastDelta = nil;
        DragInput = Input;
        Dragging = true;
    end);

    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if Library:IsSameInput(Input, DragInput) then
            Dragging = false;
            DragInput = nil;
            Library:ReleasePointer(DragOwner, Input);
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

        local Pointer = Library:GetInputPosition(DragInput);
        local Delta = Vector2.new(
            math.floor(Pointer.X - DragStart.X + 0.5),
            math.floor(Pointer.Y - DragStart.Y + 0.5)
        );

        if Delta == LastDelta then
            return;
        end;

        LastDelta = Delta;
        local Viewport = Library:GetViewportSize();
        local Size = Instance.AbsoluteSize;
        local X = math.clamp(StartPosition.X + Delta.X, 0, math.max(0, Viewport.X - Size.X));
        local Y = math.clamp(StartPosition.Y + Delta.Y, 0, math.max(0, Viewport.Y - Size.Y));
        local Anchor = Instance.AnchorPoint;

        Instance.Position = UDim2.fromOffset(
            math.floor(X + Size.X * Anchor.X + 0.5),
            math.floor(Y + Size.Y * Anchor.Y + 0.5)
        );
    end));

    return DragHandle;
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    if Library.IsMobile then
        return;
    end;

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

function Library:MouseIsOverOpenedFrame(Input)
    local Pointer = Library:GetInputPosition(Input);

    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Pointer.X >= AbsPos.X and Pointer.X <= AbsPos.X + AbsSize.X
            and Pointer.Y >= AbsPos.Y and Pointer.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:CloseOpenedFrames(Except)
    local Pending = {};

    for Frame, CloseCallback in next, Library.OpenedFrames do
        if Frame ~= Except then
            table.insert(Pending, { Frame, CloseCallback });
        end;
    end;

    for _, Entry in next, Pending do
        local Frame = Entry[1];
        local CloseCallback = Entry[2];

        if type(CloseCallback) == 'function' then
            Library:SafeCallback(CloseCallback);
        else
            Frame.Visible = false;
            Library.OpenedFrames[Frame] = nil;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame, Input)
    local Pointer = Library:GetInputPosition(Input);
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Pointer.X >= AbsPos.X and Pointer.X <= AbsPos.X + AbsSize.X
        and Pointer.Y >= AbsPos.Y and Pointer.Y <= AbsPos.Y + AbsSize.Y then

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
    table.insert(Library.Signals, Signal)
end

function Library:ClampMobileBindButton(Button, Position)
    local Viewport = Library:GetViewportSize();
    local Size = Button.AbsoluteSize;
    local Width = Size.X > 0 and Size.X or Button.Size.X.Offset;
    local Height = Size.Y > 0 and Size.Y or Button.Size.Y.Offset;
    local X = Position and Position.X.Offset or Button.Position.X.Offset;
    local Y = Position and Position.Y.Offset or Button.Position.Y.Offset;
    local Edge = 8;

    Button.Position = UDim2.fromOffset(
        math.clamp(X, Edge, math.max(Edge, Viewport.X - Width - Edge)),
        math.clamp(Y, Edge, math.max(Edge, Viewport.Y - Height - Edge))
    );
end;

function Library:RefreshMobileBindButtonBounds()
    if Library.LoadedMobileBindLayouts then
        Library:ApplyCurrentMobileBindLayout();
        return;
    end;

    for _, BindButton in ipairs(Library.MobileBindButtons) do
        Library:ClampMobileBindButton(BindButton.Outer);
    end;
end;

function Library:GetMobileBindResolution()
    local Viewport = Library:GetViewportSize();
    local Width = math.floor(Viewport.X + 0.5);
    local Height = math.floor(Viewport.Y + 0.5);
    return Width, Height, string.format('%dx%d', Width, Height);
end;

function Library:CaptureMobileBindLayout()
    if not Library.IsMobile then return nil; end;

    local Width, Height, Resolution = Library:GetMobileBindResolution();
    local Buttons = {};

    for _, BindButton in ipairs(Library.MobileBindButtons) do
        local Position = BindButton.Outer.Position;
        Buttons[tostring(BindButton.Idx)] = {
            x = math.floor(Position.X.Offset + 0.5);
            y = math.floor(Position.Y.Offset + 0.5);
        };
    end;

    return Resolution, {
        schema = 1;
        width = Width;
        height = Height;
        deviceClass = Library.DeviceClass;
        buttons = Buttons;
    };
end;

function Library:ResetMobileBindButtonPositions()
    for _, BindButton in ipairs(Library.MobileBindButtons) do
        if BindButton.DefaultPosition then
            Library:ClampMobileBindButton(BindButton.Outer, BindButton.DefaultPosition);
        else
            Library:ClampMobileBindButton(BindButton.Outer);
        end;
    end;
end;

function Library:ApplyCurrentMobileBindLayout()
    if not Library.IsMobile or type(Library.LoadedMobileBindLayouts) ~= 'table' then
        return false;
    end;

    local Width, Height, Resolution = Library:GetMobileBindResolution();
    local Layout = Library.LoadedMobileBindLayouts[Resolution];

    if type(Layout) ~= 'table'
        or tonumber(Layout.width) ~= Width
        or tonumber(Layout.height) ~= Height
        or type(Layout.buttons) ~= 'table' then

        Library:ResetMobileBindButtonPositions();
        return false;
    end;

    Library:ResetMobileBindButtonPositions();

    for _, BindButton in ipairs(Library.MobileBindButtons) do
        local Position = Layout.buttons[tostring(BindButton.Idx)];
        if type(Position) == 'table'
            and type(Position.x) == 'number'
            and type(Position.y) == 'number' then

            Library:ClampMobileBindButton(
                BindButton.Outer,
                UDim2.fromOffset(Position.x, Position.y)
            );
        end;
    end;

    return true;
end;

function Library:SetMobileBindLayouts(Layouts)
    Library.LoadedMobileBindLayouts = type(Layouts) == 'table' and Layouts or nil;
    if Library.LoadedMobileBindLayouts then
        return Library:ApplyCurrentMobileBindLayout();
    end;
    return false;
end;

function Library:SaveCurrentMobileBindLayout()
    if not Library.IsMobile then return; end;

    local Manager = Library.MobileLayoutSaveManager;
    local ConfigName = Manager and Manager.CurrentConfig;
    if ConfigName then
        Manager:Save(ConfigName);
    end;
end;

function Library:GetMobileBindOptions()
    local Values = {};
    for _, BindButton in ipairs(Library.MobileBindButtons) do
        table.insert(Values, BindButton.OptionName);
    end;
    return Values;
end;

function Library:SetVisibleMobileBinds(Selected)
    Selected = type(Selected) == 'table' and Selected or {};

    for _, BindButton in ipairs(Library.MobileBindButtons) do
        BindButton:SetVisible(Selected[BindButton.OptionName] == true);
    end;
end;

function Library:SetMobileBindEditing(Editing)
    Library.MenuOpen = not not Editing;

    for _, BindButton in ipairs(Library.MobileBindButtons) do
        BindButton:SetEditing(Library.MenuOpen);
    end;
end;

function Library:CreateMobileBindButton(Idx, KeyPicker, Info)
    if not Library.IsMobile or Info.NoUI or Info.MobileButton == false then
        return nil;
    end;

    Library.MobileBindButtonCount = Library.MobileBindButtonCount + 1;
    local ButtonIndex = Library.MobileBindButtonCount;
    local TargetButtonWidth = 160;
    local ButtonHeight = 34;
    local Gap = 8;
    local Viewport = Library:GetViewportSize();
    local Columns = Viewport.X >= 540 and 3 or (Viewport.X >= 350 and 2 or 1);
    local ButtonWidth = math.min(
        TargetButtonWidth,
        math.max(112, math.floor((Viewport.X - 24 - (Columns - 1) * Gap) / Columns))
    );
    local Column = (ButtonIndex - 1) % Columns;
    local Row = math.floor((ButtonIndex - 1) / Columns);
    local ButtonName = tostring(Info.Text or Idx or 'Bind');
    local ButtonData = {};
    local DragOwner = {};

    local Outer = Library:Create('Frame', {
        Name = 'MobileBind_' .. tostring(Idx);
        Active = true;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.fromOffset(12 + Column * (ButtonWidth + Gap), 58 + Row * (ButtonHeight + Gap));
        Size = UDim2.fromOffset(ButtonWidth, ButtonHeight);
        ZIndex = 230;
        Parent = ScreenGui;
    });

    local Button = Library:Create('TextButton', {
        AutoButtonColor = false;
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Font = Library.Font;
        Position = UDim2.fromOffset(1, 1);
        Size = UDim2.new(1, -2, 1, -2);
        Text = ButtonName;
        TextColor3 = Library.FontColor;
        TextSize = 14;
        TextStrokeTransparency = 0;
        TextTruncate = Enum.TextTruncate.AtEnd;
        ZIndex = 231;
        Parent = Outer;
    });
    Library:ApplyTextStroke(Button);

    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1));
            ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212));
        });
        Rotation = 90;
        Parent = Button;
    });

    local Accent = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 232;
        Parent = Button;
    });

    local State = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.OutlineColor;
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 7, 0.5, 1);
        Size = UDim2.fromOffset(6, 6);
        ZIndex = 233;
        Parent = Button;
    });

    local MoveLabel = Library:CreateLabel({
        Position = UDim2.new(1, -18, 0, 2);
        Size = UDim2.new(0, 16, 1, -2);
        Text = '<>';
        TextSize = 13;
        Visible = Library.MenuOpen;
        ZIndex = 233;
        Parent = Button;
    });

    local ModeLabel = Library:CreateLabel({
        Position = UDim2.new(1, -43, 0, 2);
        Size = UDim2.new(0, 22, 1, -2);
        Text = 'T';
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Center;
        ZIndex = 233;
        Parent = Button;
    });

    Library:AddToRegistry(Button, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
        TextColor3 = 'FontColor';
    });
    Library:AddToRegistry(Accent, { BackgroundColor3 = 'AccentColor'; });
    Library:AddToRegistry(State, { BackgroundColor3 = 'OutlineColor'; });

    local Dragging = false;
    local DragInput;
    local DragStart;
    local StartPosition;
    local PressedInput;

    local function ReleaseBind()
        if not PressedInput then return; end;
        PressedInput = nil;

        if KeyPicker.Mode == 'Hold' and KeyPicker.Toggled then
            KeyPicker.Toggled = false;
            KeyPicker:DoClick();
            KeyPicker:Update();
        end;
    end;

    function ButtonData:Update()
        local Active = KeyPicker:GetDisplayState();
        local Editing = Library.MenuOpen;
        local BorderKey = Editing and 'AccentColor' or (Active and 'AccentColorDark' or 'OutlineColor');
        local StateKey = Active and 'AccentColor' or 'OutlineColor';

        Button.BorderColor3 = Library[BorderKey];
        State.BackgroundColor3 = Library[StateKey];
        MoveLabel.Visible = Editing;
        ModeLabel.Text = KeyPicker.Mode == 'Hold' and 'H'
            or (KeyPicker.Mode == 'Always' and 'A' or 'T');
        ModeLabel.TextColor3 = Editing and Library.AccentColor or Library.FontColor;
        Library.RegistryMap[Button].Properties.BorderColor3 = BorderKey;
        Library.RegistryMap[State].Properties.BackgroundColor3 = StateKey;
        Library.RegistryMap[ModeLabel].Properties.TextColor3 = Editing and 'AccentColor' or 'FontColor';
    end;

    function ButtonData:CycleMode()
        local NextMode = KeyPicker.Mode == 'Hold' and 'Toggle' or 'Hold';
        if type(KeyPicker.SetMode) == 'function' then
            KeyPicker:SetMode(NextMode, true);
        else
            KeyPicker.Mode = NextMode;
            KeyPicker:Update();
            Library:AttemptSave();
        end;
    end;

    function ButtonData:SetEditing(Editing)
        if Editing then
            ReleaseBind();
        else
            Dragging = false;
            DragInput = nil;
        end;

        ButtonData:Update();
    end;

    function ButtonData:SetVisible(Visible)
        ButtonData.UserVisible = not not Visible;
        Outer.Visible = ButtonData.UserVisible;
        if not ButtonData.UserVisible then
            ReleaseBind();
            Dragging = false;
            DragInput = nil;
            Library:ReleasePointer(DragOwner);
        end;
    end;

    Button.InputBegan:Connect(function(Input)
        if not Library:IsPrimaryInput(Input) then return; end;
        if not Library:ClaimPointer(DragOwner, Input) then return; end;

        if Library.MenuOpen then
            Dragging = true;
            DragInput = Input;
            DragStart = Library:GetInputPosition(Input);
            StartPosition = Outer.Position;
            return;
        end;

        PressedInput = Input;
        if KeyPicker.Mode == 'Hold' then
            if not KeyPicker.Toggled then
                KeyPicker.Toggled = true;
                KeyPicker:DoClick();
            end;
        elseif KeyPicker.Mode ~= 'Always' then
            KeyPicker.Toggled = not KeyPicker.Toggled;
            KeyPicker:DoClick();
            PressedInput = nil;
        end;

        KeyPicker:Update();
    end);

    Library:GiveSignal(RenderStepped:Connect(function()
        if not Dragging then return; end;
        if not Library.MenuOpen or not Library:IsInputActive(DragInput) then
            Dragging = false;
            DragInput = nil;
            return;
        end;

        local Pointer = Library:GetInputPosition(DragInput);
        local Delta = Pointer - DragStart;
        Library:ClampMobileBindButton(Outer, UDim2.fromOffset(
            StartPosition.X.Offset + Delta.X,
            StartPosition.Y.Offset + Delta.Y
        ));
    end));

    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if Library:IsSameInput(Input, DragInput) then
            local Travel = (Library:GetInputPosition(Input) - DragStart).Magnitude;
            Dragging = false;
            DragInput = nil;
            if Library.MenuOpen and Travel <= Library.TouchMoveThreshold then
                ButtonData:CycleMode();
            end;
            if Library.MenuOpen then
                task.defer(Library.SaveCurrentMobileBindLayout);
            end;
        end;

        if Library:IsSameInput(Input, PressedInput) then
            ReleaseBind();
        end;

        Library:ReleasePointer(DragOwner, Input);
    end));

    ButtonData.Outer = Outer;
    ButtonData.Button = Button;
    ButtonData.State = State;
    ButtonData.ModeLabel = ModeLabel;
    ButtonData.KeyPicker = KeyPicker;
    ButtonData.Idx = Idx;
    ButtonData.Name = ButtonName;
    ButtonData.OptionName = string.format('%s [%s]', ButtonName, tostring(Idx));
    ButtonData.DefaultPosition = Outer.Position;
    ButtonData.UserVisible = true;
    table.insert(Library.MobileBindButtons, ButtonData);
    task.defer(function()
        if Library.LoadedMobileBindLayouts then
            Library:ApplyCurrentMobileBindLayout();
        else
            Library:ClampMobileBindButton(Outer);
        end;
        ButtonData:Update();
    end);

    return ButtonData;
end;

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    for Idx = #Library.UnloadCallbacks, 1, -1 do
        local Callback = table.remove(Library.UnloadCallbacks, Idx)
        pcall(Callback)
    end

    for _, DrawingObject in ipairs(Library.CursorDrawings or {}) do
        pcall(function()
            DrawingObject.Visible = false
            DrawingObject:Remove()
        end)
    end
    Library.CursorDrawings = nil
    Environment.DrainCursorDrawings = nil

    if Library.MobileFovGui then
        Library.MobileFovGui:Destroy()
        Library.MobileFovGui = nil
    end

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

        local SupportsTransparency = Info.Transparency ~= nil;

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Color1 = Info.Default;
            Transparency1 = Info.Transparency or 0;
            Color2 = Info.SecondColor or Info.Default;
            Transparency2 = Info.SecondTransparency or Info.Transparency or 0;
            AnimationMode = 'Static';
            AnimationSpeed = 1;
            EditingAnimationColor = 1;
            EditorTransparency = Info.Transparency or 0;
            SupportsTransparency = SupportsTransparency;
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

        local PickerMapSize = Library.IsMobile and 170 or 200;
        local HueSelectorWidth = Library.IsMobile and 22 or 15;
        local PickerControlHeight = Library.IsMobile and Library.MobileControlHeight or 20;
        local PickerSliderHeight = Library.IsMobile and 22 or 13;
        local PickerMapY = 25 + PickerControlHeight + 3;
        local PickerFieldsY = PickerMapY + PickerMapSize + 3;
        local PickerWidth = 4 + PickerMapSize + 4 + HueSelectorWidth + 7;
        local BasePickerHeight = PickerFieldsY + (SupportsTransparency and 43 or 25);
        local AnimationControlGap = 4;
        local AnimationPanelPadding = 4;
        local AnimationPanelHeight = 12 + (PickerControlHeight * 3)
            + (AnimationControlGap * 3) + PickerSliderHeight;

        local DisplayFrame = Library:Create('TextButton', {
            Active = true;
            AutoButtonColor = false;
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            LayoutOrder = 20;
            Size = Library.IsMobile and UDim2.new(0, 44, 0, 18) or UDim2.new(0, 28, 0, 14);
            Text = '';
            ZIndex = 10;
            Parent = ToggleLabel;
        });


        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(1, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 11;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = SupportsTransparency;
            Parent = DisplayFrame;
        });

        local ColorPreview = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BackgroundTransparency = ColorPicker.Transparency;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(1, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 12;
            Parent = DisplayFrame;
        });


        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            Active = true;
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(PickerWidth, BasePickerHeight);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        local function UpdatePickerPosition()
            PickerFrameOuter.Position = Library:ClampPopupPosition(
                PickerFrameOuter,
                DisplayFrame.AbsolutePosition.X,
                DisplayFrame.AbsolutePosition.Y + DisplayFrame.AbsoluteSize.Y + 4
            );
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
            Active = true;
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
            Position = UDim2.new(0, 4, 0, PickerMapY);
            Size = UDim2.fromOffset(PickerMapSize, PickerMapSize);
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
            Active = true;
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
            Position = UDim2.fromOffset(8 + PickerMapSize, PickerMapY);
            Size = UDim2.fromOffset(HueSelectorWidth, PickerMapSize);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            Active = true;
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
            Size = UDim2.new(1, 0, 0, Library.IsMobile and 3 or 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, PickerFieldsY),
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
            Position = UDim2.new(0.5, 2, 0, PickerFieldsY),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;

        if SupportsTransparency then
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, PickerFieldsY + 23);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                Active = true;
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
            Size = UDim2.new(1, -10, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title;
            TextTruncate = Enum.TextTruncate.AtEnd;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });

        local PickerPage = 'Color';
        local AnimationModeButtons = {};
        local AnimationSlotButtons = {};
        local AnimationSlotPreviews = {};

        local function CreatePickerStyleButton(Text, Parent, Position, Size, TextSize)
            local Button = {
                Selected = false;
                Hovering = false;
            };

            Button.Outer = Library:Create('Frame', {
                Active = true;
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                BorderSizePixel = 1;
                Position = Position;
                Size = Size;
                ZIndex = 19;
                Parent = Parent;
            });

            Button.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                BorderSizePixel = 1;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 20;
                Parent = Button.Outer;
            });

            Button.Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                Text = Text;
                TextSize = TextSize or 14;
                TextXAlignment = Enum.TextXAlignment.Center;
                TextYAlignment = Enum.TextYAlignment.Center;
                ZIndex = 21;
                Parent = Button.Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Button.Inner;
            });

            Library:AddToRegistry(Button.Outer, { BorderColor3 = 'Black'; });
            Library:AddToRegistry(Button.Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            function Button:RefreshBorder()
                local ColorKey = (Button.Selected or Button.Hovering) and 'AccentColor' or 'Black';
                Button.Outer.BorderColor3 = Library[ColorKey];

                local Registry = Library.RegistryMap[Button.Outer];
                if Registry then
                    Registry.Properties.BorderColor3 = ColorKey;
                end;
            end;

            function Button:SetSelected(Selected)
                Button.Selected = Selected == true;
                Button.Inner.BackgroundColor3 = Library.MainColor;
                Button.Label.TextColor3 = Library.FontColor;

                local InnerRegistry = Library.RegistryMap[Button.Inner];
                if InnerRegistry then
                    InnerRegistry.Properties.BackgroundColor3 = 'MainColor';
                end;

                local LabelRegistry = Library.RegistryMap[Button.Label];
                if LabelRegistry then
                    LabelRegistry.Properties.TextColor3 = 'FontColor';
                end;

                Button:RefreshBorder();
            end;

            Button.Outer.MouseEnter:Connect(function()
                Button.Hovering = true;
                Button:RefreshBorder();
            end);

            Button.Outer.MouseLeave:Connect(function()
                Button.Hovering = false;
                Button:RefreshBorder();
            end);

            return Button;
        end;

        local PageButtonHolder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(4, 24);
            Size = UDim2.fromOffset(PickerWidth - 8, PickerControlHeight);
            ZIndex = 18;
            Parent = PickerFrameInner;
        });

        local PageGap = ((PickerWidth - 8) % 2 == 0) and 4 or 5;
        local PageAvailableWidth = PickerWidth - 8 - PageGap;
        local ColorPageWidth = math.floor(PageAvailableWidth / 2);
        local AnimationPageWidth = PageAvailableWidth - ColorPageWidth;
        local ColorPageButton = CreatePickerStyleButton(
            'Color',
            PageButtonHolder,
            UDim2.fromOffset(0, 0),
            UDim2.fromOffset(ColorPageWidth, PickerControlHeight),
            14
        );
        local AnimationPageButton = CreatePickerStyleButton(
            'Animation',
            PageButtonHolder,
            UDim2.fromOffset(ColorPageWidth + PageGap, 0),
            UDim2.fromOffset(AnimationPageWidth, PickerControlHeight),
            14
        );

        local AnimationPanel = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(0, BasePickerHeight - 1);
            Size = UDim2.new(1, 0, 0, AnimationPanelHeight - 4);
            Visible = false;
            ZIndex = 18;
            Parent = PickerFrameInner;
        });

        local AnimationModes = { 'Static', 'Rainbow', 'Fading', 'Flash' };
        local TwoColumnWidth = math.floor((PickerWidth - 8 - PageGap) / 2);

        for ModeIndex, Mode in ipairs(AnimationModes) do
            local ModeName = Mode;
            local Column = (ModeIndex - 1) % 2;
            local Row = math.floor((ModeIndex - 1) / 2);
            local Button = CreatePickerStyleButton(
                ModeName,
                AnimationPanel,
                UDim2.fromOffset(
                    AnimationPanelPadding + (Column * (TwoColumnWidth + PageGap)),
                    AnimationPanelPadding + (Row * (PickerControlHeight + AnimationControlGap))
                ),
                UDim2.fromOffset(TwoColumnWidth, PickerControlHeight),
                14
            );
            AnimationModeButtons[ModeName] = Button;

            Library:BindClick(Button.Outer, function()
                ColorPicker:SetAnimationMode(ModeName, true);
            end);
        end;

        local SlotY = AnimationPanelPadding + ((PickerControlHeight + AnimationControlGap) * 2);

        for Slot = 1, 2 do
            local SlotIndex = Slot;
            local Button = CreatePickerStyleButton(
                'Color ' .. tostring(SlotIndex),
                AnimationPanel,
                UDim2.fromOffset(
                    AnimationPanelPadding + ((SlotIndex - 1) * (TwoColumnWidth + PageGap)),
                    SlotY
                ),
                UDim2.fromOffset(TwoColumnWidth, PickerControlHeight),
                14
            );
            Button.Label.Position = UDim2.fromOffset(0, 0);
            Button.Label.Size = UDim2.new(1, 0, 1, 0);

            local SwatchOuter = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                BorderMode = Enum.BorderMode.Inset;
                BorderSizePixel = 1;
                Position = UDim2.fromOffset(4, math.floor((PickerControlHeight - 12) / 2));
                Size = UDim2.fromOffset(12, 12);
                ZIndex = 22;
                Parent = Button.Inner;
            });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Position = UDim2.fromOffset(1, 1);
                Size = UDim2.new(1, -2, 1, -2);
                Image = 'http://www.roblox.com/asset/?id=12977615774';
                Visible = SupportsTransparency;
                ZIndex = 23;
                Parent = SwatchOuter;
            });

            local Preview = Library:Create('Frame', {
                BackgroundColor3 = SlotIndex == 1 and ColorPicker.Color1 or ColorPicker.Color2;
                BackgroundTransparency = SlotIndex == 1 and ColorPicker.Transparency1 or ColorPicker.Transparency2;
                BorderSizePixel = 0;
                Position = UDim2.fromOffset(1, 1);
                Size = UDim2.new(1, -2, 1, -2);
                ZIndex = 24;
                Parent = SwatchOuter;
            });

            AnimationSlotButtons[SlotIndex] = Button;
            AnimationSlotPreviews[SlotIndex] = Preview;

            Library:BindClick(Button.Outer, function()
                ColorPicker:SetEditingAnimationColor(SlotIndex);
            end);
        end;

        local SpeedBarOuter = Library:Create('Frame', {
            Active = true;
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(
                AnimationPanelPadding,
                SlotY + PickerControlHeight + AnimationControlGap
            );
            Size = UDim2.new(1, -(AnimationPanelPadding * 2), 0, PickerSliderHeight);
            ZIndex = 19;
            Parent = AnimationPanel;
        });
        Library:AddToRegistry(SpeedBarOuter, { BorderColor3 = 'Black'; });

        local SpeedBarInner = Library:Create('Frame', {
            Active = true;
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 20;
            Parent = SpeedBarOuter;
        });
        Library:AddToRegistry(SpeedBarInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local SpeedBarFill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 21;
            Parent = SpeedBarInner;
        });
        Library:AddToRegistry(SpeedBarFill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local SpeedBarHideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 22;
            Parent = SpeedBarFill;
        });
        Library:AddToRegistry(SpeedBarHideBorderRight, { BackgroundColor3 = 'AccentColor'; });

        local SpeedLabel = Library:CreateLabel({
            Active = false;
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Text = 'Speed: 1.00x';
            TextSize = 14;
            ZIndex = 23;
            Parent = SpeedBarInner;
        });

        Library:OnHighlight(SpeedBarOuter, SpeedBarOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        local function SetButtonSelected(Button, Selected)
            Button:SetSelected(Selected);
        end;

        local function UpdateSpeedVisual()
            local MaxSize = math.max(SpeedBarInner.AbsoluteSize.X, 1);
            local Percent = math.clamp((ColorPicker.AnimationSpeed - 0.1) / 4.9, 0, 1);
            local FillWidth = math.clamp(math.ceil(Percent * MaxSize), 0, MaxSize);
            SpeedBarFill.Size = UDim2.new(0, FillWidth, 1, 0);
            SpeedBarHideBorderRight.Visible = not (FillWidth == 0 or FillWidth == MaxSize);
            SpeedLabel.Text = string.format('Speed: %.2fx', ColorPicker.AnimationSpeed);
        end;

        local function UpdateAnimationControls()
            for Mode, Button in pairs(AnimationModeButtons) do
                SetButtonSelected(Button, ColorPicker.AnimationMode == Mode);
            end;

            for Slot, Button in pairs(AnimationSlotButtons) do
                SetButtonSelected(Button, ColorPicker.EditingAnimationColor == Slot);
            end;

            AnimationSlotPreviews[1].BackgroundColor3 = ColorPicker.Color1;
            AnimationSlotPreviews[1].BackgroundTransparency = SupportsTransparency and ColorPicker.Transparency1 or 0;
            AnimationSlotPreviews[2].BackgroundColor3 = ColorPicker.Color2;
            AnimationSlotPreviews[2].BackgroundTransparency = SupportsTransparency and ColorPicker.Transparency2 or 0;

            UpdateSpeedVisual();

            local IsAnimationPage = PickerPage == 'Animation';
            AnimationPanel.Visible = IsAnimationPage;
            PickerFrameOuter.Size = UDim2.fromOffset(
                PickerWidth,
                BasePickerHeight + (IsAnimationPage and AnimationPanelHeight or 0)
            );

            SetButtonSelected(ColorPageButton, not IsAnimationPage);
            SetButtonSelected(AnimationPageButton, IsAnimationPage);

            if PickerFrameOuter.Visible then
                UpdatePickerPosition();
            end;
        end;

        SpeedBarInner:GetPropertyChangedSignal('AbsoluteSize'):Connect(UpdateSpeedVisual);

        Library:BindClick(ColorPageButton.Outer, function()
            ColorPicker:SetPickerPage('Color');
        end);

        Library:BindClick(AnimationPageButton.Outer, function()
            ColorPicker:SetPickerPage('Animation');
        end);


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
                ContextMenu.Container.Position = Library:ClampPopupPosition(
                    ContextMenu.Container,
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                );
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
                    Active = true;
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

                Library:BindClick(Button, function()
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
                ColorPicker:SetEditorValueRGB(Library.ColorClipboard)
                Library:AttemptSave();
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
            Library:AttemptSave();
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
            Library:AttemptSave();
        end)

        local function ResolveAnimationColor(Value, Fallback)
            if typeof(Value) == 'Color3' then
                return Value;
            end;

            if type(Value) == 'string' then
                local Success, Result = pcall(Color3.fromHex, Value);
                if Success and typeof(Result) == 'Color3' then
                    return Result;
                end;
            end;

            return Fallback;
        end;

        local function ClampTransparency(Value, Fallback)
            if not SupportsTransparency then
                return 0;
            end;

            return math.clamp(tonumber(Value) or Fallback or 0, 0, 1);
        end;

        function ColorPicker:GetEditorSlot()
            return PickerPage == 'Animation' and ColorPicker.EditingAnimationColor or 1;
        end;

        function ColorPicker:UpdateEditorVisuals()
            local EditorColor = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = EditorColor;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.EditorTransparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);
            HueBox.Text = '#' .. EditorColor:ToHex();
            RgbBox.Text = table.concat({
                math.floor(EditorColor.R * 255),
                math.floor(EditorColor.G * 255),
                math.floor(EditorColor.B * 255)
            }, ', ');
        end;

        function ColorPicker:LoadEditorFromSlot()
            local Slot = ColorPicker:GetEditorSlot();
            local Color = Slot == 2 and ColorPicker.Color2 or ColorPicker.Color1;
            local Transparency = Slot == 2 and ColorPicker.Transparency2 or ColorPicker.Transparency1;

            ColorPicker.EditorTransparency = ClampTransparency(Transparency, 0);
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:UpdateEditorVisuals();
        end;

        function ColorPicker:GetAnimationOutput(Now)
            local Mode = ColorPicker.AnimationMode;
            local Color1 = ColorPicker.Color1;
            local Color2 = ColorPicker.Color2;
            local Alpha1 = ColorPicker.Transparency1;
            local Alpha2 = ColorPicker.Transparency2;

            if Mode == 'Static' then
                return Color1, Alpha1;
            end;

            local Phase = (((Now or os.clock()) * ColorPicker.AnimationSpeed) % 1);
            local Smooth = 0.5 - (math.cos(Phase * math.pi * 2) * 0.5);

            if Mode == 'Rainbow' then
                local Hue1, Saturation1, Value1 = Color3.toHSV(Color1);
                local _, Saturation2, Value2 = Color3.toHSV(Color2);
                local Saturation = math.max(0.65, Saturation1 + ((Saturation2 - Saturation1) * Smooth));
                local Value = math.max(0.15, Value1 + ((Value2 - Value1) * Smooth));
                local Color = Color3.fromHSV((Hue1 + Phase) % 1, Saturation, Value);
                return Color, Alpha1 + ((Alpha2 - Alpha1) * Smooth);
            end;

            if Mode == 'Flash' then
                if Phase < 0.5 then
                    return Color1, Alpha1;
                end;

                return Color2, Alpha2;
            end;

            return Color1:Lerp(Color2, Smooth), Alpha1 + ((Alpha2 - Alpha1) * Smooth);
        end;

        function ColorPicker:ApplyOutput(Color, Transparency, FireCallback)
            ColorPicker.Value = Color;
            ColorPicker.Transparency = ClampTransparency(Transparency, 0);

            DisplayFrame.BackgroundColor3 = Color3.new(0, 0, 0);
            DisplayFrame.BackgroundTransparency = 0;
            DisplayFrame.BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            ColorPreview.BackgroundColor3 = ColorPicker.Value;
            ColorPreview.BackgroundTransparency = ColorPicker.Transparency;

            if FireCallback ~= false then
                Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency);
                Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency);
            end;
        end;

        function ColorPicker:RefreshOutput(FireCallback, Now)
            local Color, Transparency = ColorPicker:GetAnimationOutput(Now);
            ColorPicker:ApplyOutput(Color, Transparency, FireCallback);
        end;

        function ColorPicker:Display()
            local EditorColor = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            local Slot = ColorPicker:GetEditorSlot();

            if Slot == 2 then
                ColorPicker.Color2 = EditorColor;
                ColorPicker.Transparency2 = ClampTransparency(ColorPicker.EditorTransparency, ColorPicker.Transparency2);
            else
                ColorPicker.Color1 = EditorColor;
                ColorPicker.Transparency1 = ClampTransparency(ColorPicker.EditorTransparency, ColorPicker.Transparency1);
            end;

            ColorPicker:UpdateEditorVisuals();
            ColorPicker:RefreshOutput(true);
            UpdateAnimationControls();
        end;

        function ColorPicker:AnimationTick(Now)
            ColorPicker:RefreshOutput(true, Now);
        end;

        function ColorPicker:SetPickerPage(Page)
            PickerPage = Page == 'Animation' and 'Animation' or 'Color';
            ColorPicker:LoadEditorFromSlot();
            UpdateAnimationControls();
        end;

        function ColorPicker:SetEditingAnimationColor(Slot)
            ColorPicker.EditingAnimationColor = Slot == 2 and 2 or 1;
            ColorPicker:LoadEditorFromSlot();
            UpdateAnimationControls();
        end;

        function ColorPicker:SetAnimationMode(Mode, Save)
            if Mode ~= 'Static' and Mode ~= 'Rainbow' and Mode ~= 'Fading' and Mode ~= 'Flash' then
                Mode = 'Static';
            end;

            ColorPicker.AnimationMode = Mode;
            ColorPicker:RefreshOutput(true);
            UpdateAnimationControls();

            if Save then
                Library:AttemptSave();
            end;
        end;

        function ColorPicker:SetAnimationSpeed(Speed, Save)
            ColorPicker.AnimationSpeed = math.clamp(tonumber(Speed) or 1, 0.1, 5);
            ColorPicker:RefreshOutput(true);
            UpdateAnimationControls();

            if Save then
                Library:AttemptSave();
            end;
        end;

        function ColorPicker:GetAnimationState()
            return {
                Mode = ColorPicker.AnimationMode;
                Speed = ColorPicker.AnimationSpeed;
                Color1 = ColorPicker.Color1;
                Transparency1 = ColorPicker.Transparency1;
                Color2 = ColorPicker.Color2;
                Transparency2 = ColorPicker.Transparency2;
            };
        end;

        function ColorPicker:SetAnimationState(State)
            State = type(State) == 'table' and State or {};

            ColorPicker.Color1 = ResolveAnimationColor(State.Color1 or State.color1 or State.Value or State.value, ColorPicker.Color1);
            ColorPicker.Color2 = ResolveAnimationColor(State.Color2 or State.color2, ColorPicker.Color2);
            ColorPicker.Transparency1 = ClampTransparency(
                State.Transparency1 or State.transparency1 or State.Alpha1 or State.alpha1 or State.Transparency or State.transparency,
                ColorPicker.Transparency1
            );
            ColorPicker.Transparency2 = ClampTransparency(
                State.Transparency2 or State.transparency2 or State.Alpha2 or State.alpha2,
                ColorPicker.Transparency2
            );
            ColorPicker.AnimationSpeed = math.clamp(tonumber(State.Speed or State.speed) or ColorPicker.AnimationSpeed, 0.1, 5);

            local Mode = State.Mode or State.mode or 'Static';
            if Mode ~= 'Static' and Mode ~= 'Rainbow' and Mode ~= 'Fading' and Mode ~= 'Flash' then
                Mode = 'Static';
            end;
            ColorPicker.AnimationMode = Mode;

            ColorPicker:LoadEditorFromSlot();
            ColorPicker:RefreshOutput(true);
            UpdateAnimationControls();
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value, ColorPicker.Transparency)
        end;

        function ColorPicker:Show()
            Library:CloseOpenedFrames(PickerFrameOuter);
            UpdatePickerPosition();
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = function()
                ColorPicker:Hide();
            end;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);
            ColorPicker:SetValueRGB(Color, Transparency);
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            if typeof(Color) ~= 'Color3' then return; end;

            ColorPicker.Color1 = Color;
            ColorPicker.Transparency1 = ClampTransparency(Transparency, 0);

            if ColorPicker:GetEditorSlot() == 1 then
                ColorPicker:LoadEditorFromSlot();
            end;

            ColorPicker:RefreshOutput(true);
            UpdateAnimationControls();
        end;

        function ColorPicker:SetEditorValueRGB(Color, Transparency)
            if typeof(Color) ~= 'Color3' then return; end;

            ColorPicker:SetHSVFromRGB(Color);
            if Transparency ~= nil then
                ColorPicker.EditorTransparency = ClampTransparency(Transparency, ColorPicker.EditorTransparency);
            end;
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Library:IsPrimaryInput(Input) then
                repeat
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local Pointer = Library:GetInputPosition(Input);
                    local MouseX = math.clamp(Pointer.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Pointer.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                until not Library:IsInputActive(Input);

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Library:IsPrimaryInput(Input) then
                repeat
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local Pointer = Library:GetInputPosition(Input);
                    local MouseY = math.clamp(Pointer.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                until not Library:IsInputActive(Input);

                Library:AttemptSave();
            end;
        end);

        Library:BindClick(DisplayFrame, function(Input)
            if not Library:MouseIsOverOpenedFrame(Input) then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame(Input) then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Library:IsPrimaryInput(Input) then
                    repeat
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local Pointer = Library:GetInputPosition(Input);
                        local MouseX = math.clamp(Pointer.X, MinX, MaxX);

                        ColorPicker.EditorTransparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    until not Library:IsInputActive(Input);

                    Library:AttemptSave();
                end;
            end);
        end;

        SpeedBarInner.InputBegan:Connect(function(Input)
            if Library:IsPrimaryInput(Input) then
                repeat
                    local MinX = SpeedBarInner.AbsolutePosition.X;
                    local MaxX = MinX + SpeedBarInner.AbsoluteSize.X;
                    local Pointer = Library:GetInputPosition(Input);
                    local MouseX = math.clamp(Pointer.X, MinX, MaxX);
                    local Percent = (MouseX - MinX) / math.max(MaxX - MinX, 1);
                    local Speed = 0.1 + (Percent * 4.9);
                    Speed = math.floor((Speed * 100) + 0.5) / 100;

                    ColorPicker:SetAnimationSpeed(Speed, false);
                    RenderStepped:Wait();
                until not Library:IsInputActive(Input);

                Library:AttemptSave();
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Library:IsPrimaryInput(Input) then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                local Pointer = Library:GetInputPosition(Input);

                if (Pointer.X < AbsPos.X or Pointer.X > AbsPos.X + AbsSize.X
                    or Pointer.Y < (AbsPos.Y - 20 - 1) or Pointer.Y > AbsPos.Y + AbsSize.Y)
                    and not Library:IsMouseOverFrame(DisplayFrame, Input) then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container, Input) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container, Input) and not Library:IsMouseOverFrame(DisplayFrame, Input) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker.DisplayFrame = DisplayFrame;
        ColorPicker:LoadEditorFromSlot();
        ColorPicker:RefreshOutput(true);
        UpdateAnimationControls();
        Library.AnimatedColorPickers[ColorPicker] = true;

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
            Mode = Info.Mode or 'Toggle';
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
            Active = true;
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = Library.IsMobile and UDim2.new(0, 38, 0, 20) or UDim2.new(0, 28, 0, 15);
            LayoutOrder = 30;
            ZIndex = 10;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 11;
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
            ZIndex = 12;
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
            ModeSelectOuter.Position = Library:ClampPopupPosition(
                ModeSelectOuter,
                ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4,
                ToggleLabel.AbsolutePosition.Y + 1
            );
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
                Active = true;
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
                if KeyPicker.MobileButton then KeyPicker.MobileButton:Update(); end;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Library:BindClick(Label, function()
                ModeButton:Select();
                Library:AttemptSave();
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:GetDisplayState()
            return ParentObj.Type == 'Toggle' and ParentObj.Value or KeyPicker:GetState();
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetDisplayState();

            local DisplayKey = Library.IsMobile and KeyPicker.MobileButton and 'Touch' or KeyPicker.Value;
            DisplayLabel.Text = DisplayKey;
            ContainerLabel.Text = string.format('[%s] %s (%s)', DisplayKey, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = State;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';
            if Library.RefreshKeybindFrame then Library:RefreshKeybindFrame(); end;
            if KeyPicker.MobileButton then KeyPicker.MobileButton:Update(); end;
        end;

        function KeyPicker:SetMode(Mode, Save)
            local ModeButton = ModeButtons[Mode];
            if not ModeButton then return false; end;

            ModeButton:Select();
            KeyPicker:Update();
            if Save then Library:AttemptSave(); end;
            return true;
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
            if not KeyPicker:SetMode(Mode) then
                KeyPicker:SetMode('Toggle');
            end;
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

        Library:BindClick(PickOuter, function(Input)
            if Library.IsMobile and Input.UserInputType == Enum.UserInputType.Touch then
                UpdateModeSelectPosition();
                ModeSelectOuter.Visible = not ModeSelectOuter.Visible;
                return;
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame(Input) then
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

                    if not Key then return; end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            end;
        end);

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame(Input) then
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

            if Library:IsPrimaryInput(Input) then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                local Pointer = Library:GetInputPosition(Input);

                if (Pointer.X < AbsPos.X or Pointer.X > AbsPos.X + AbsSize.X
                    or Pointer.Y < (AbsPos.Y - 20 - 1) or Pointer.Y > AbsPos.Y + AbsSize.Y)
                    and not Library:IsMouseOverFrame(PickOuter, Input) then

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

        KeyPicker.MobileButton = Library:CreateMobileBindButton(Idx, KeyPicker, Info);
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
            Size = UDim2.new(1, -4, 0, Library.IsMobile and 22 or 15);
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
                Active = true;
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, Library.IsMobile and Library.MobileControlHeight or 20);
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
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame(Input) then
                    return false
                end

                if not Library:IsPrimaryInput(Input) then
                    return false
                end

                return true
            end

            local ConfirmToken = 0
            local function ResetConfirmation()
                Library:RemoveFromRegistry(Button.Label)
                Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                Button.Label.TextColor3 = Library.FontColor
                Button.Label.Text = Button.Text
                Button.Locked = false
            end

            Library:BindClick(Button.Outer, function(Input)
                if not ValidateClick(Input) then return end

                if Button.DoubleClick then
                    if Button.Locked then
                        ConfirmToken += 1
                        ResetConfirmation()
                        Library:SafeCallback(Button.Func)
                        return
                    end

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    ConfirmToken += 1
                    local CurrentToken = ConfirmToken
                    task.delay(0.5, function()
                        if Button.Locked and ConfirmToken == CurrentToken then
                            ResetConfirmation()
                        end
                    end)

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


        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then

                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else

                local cursor = Box.CursorPosition
                if cursor ~= -1 then

                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X


                    local currentCursorPos = Box.Position.X.Offset + width


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
            Warn = Info.Warn,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;
        local ToggleSize = Library.IsMobile and 20 or 13;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, ToggleSize, 0, ToggleSize);
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
            Size = UDim2.new(0, math.max(Container.AbsoluteSize.X - ToggleSize - 10, 0), 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 9;
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
            Active = true;
            BackgroundTransparency = 1;
            Size = UDim2.new(0, math.max(Container.AbsoluteSize.X, ToggleSize), 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        local function UpdateToggleLayout()
            ToggleLabel.Size = UDim2.new(0, math.max(Container.AbsoluteSize.X - ToggleSize - 10, 0), 1, 0);
            ToggleRegion.Size = UDim2.new(0, math.max(Container.AbsoluteSize.X, ToggleSize), 1, 0);
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

        Library:BindClick(ToggleRegion, function(Input)
            if not Library:MouseIsOverOpenedFrame(Input) then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        elseif Toggle.Warn then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.WarnColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'WarnColor' })
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
            Size = UDim2.new(1, -4, 0, Library.IsMobile and 22 or 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            Active = true;
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

        local SliderOwner = {};
        local function UpdateSliderFromInput(Input)
            local Pointer = Library:GetInputPosition(Input);
            local nX = math.clamp(Pointer.X - SliderInner.AbsolutePosition.X, 0, Slider:GetMaxSize());
            local nValue = Slider:GetValueFromXOffset(nX);
            local OldValue = Slider.Value;
            Slider.Value = nValue;
            Slider:Display();

            if nValue ~= OldValue then
                Library:SafeCallback(Slider.Callback, Slider.Value);
                Library:SafeCallback(Slider.Changed, Slider.Value);
            end;
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if not Library:IsPrimaryInput(Input) or Library:MouseIsOverOpenedFrame(Input) then return; end;
            if not Library:ClaimPointer(SliderOwner, Input) then return; end;

            if Input.UserInputType == Enum.UserInputType.Touch then
                local Start = Library:GetInputPosition(Input);
                local Gesture;

                while Library:IsInputActive(Input) do
                    local Delta = Library:GetInputPosition(Input) - Start;
                    if Delta.Magnitude >= Library.TouchMoveThreshold then
                        Gesture = math.abs(Delta.X) >= math.abs(Delta.Y) and 'Slider' or 'Scroll';
                        break;
                    end;
                    RenderStepped:Wait();
                end;

                if Gesture == 'Scroll' then
                    Library:ReleasePointer(SliderOwner, Input);
                    return;
                elseif not Library:IsInputActive(Input) then
                    UpdateSliderFromInput(Input);
                    Library:AttemptSave();
                    Library:ReleasePointer(SliderOwner, Input);
                    return;
                end;
            end;

            repeat
                UpdateSliderFromInput(Input);
                RenderStepped:Wait();
            until not Library:IsInputActive(Input);

            Library:AttemptSave();
            Library:ReleasePointer(SliderOwner, Input);
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

    function Library:ActivateMobileDropdownScroll(ListOuter, Scrolling)
        if not Library.IsMobile then return; end;

        Library.ActiveMobileDropdownScroll = {
            ListOuter = ListOuter;
            Scrolling = Scrolling;
            Input = nil;
            Start = nil;
            CanvasStart = nil;
            Velocity = 0;
            LastCanvasY = Scrolling.CanvasPosition.Y;
            LastTime = 0;
        };
    end;

    function Library:DeactivateMobileDropdownScroll(ListOuter)
        local State = Library.ActiveMobileDropdownScroll;
        if State and (ListOuter == nil or State.ListOuter == ListOuter) then
            Library.ActiveMobileDropdownScroll = nil;
        end;
    end;

    if Library.IsMobile and not Library.MobileDropdownScrollInitialized then
        Library.MobileDropdownScrollInitialized = true;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            local State = Library.ActiveMobileDropdownScroll;
            if not State
                or Input.UserInputType ~= Enum.UserInputType.Touch
                or not State.ListOuter.Visible
                or not Library:IsMouseOverFrame(State.Scrolling, Input) then
                return;
            end;

            State.Input = Input;
            State.Start = Library:GetInputPosition(Input);
            State.CanvasStart = State.Scrolling.CanvasPosition;
            State.Velocity = 0;
            State.LastCanvasY = State.Scrolling.CanvasPosition.Y;
            State.LastTime = os.clock();
        end));

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            local State = Library.ActiveMobileDropdownScroll;
            if State and Library:IsSameInput(Input, State.Input) then
                State.Input = nil;
            end;
        end));

        Library:GiveSignal(RenderStepped:Connect(function()
            local State = Library.ActiveMobileDropdownScroll;
            if not State then return; end;
            if not State.ListOuter.Visible or not State.Scrolling.Parent then
                Library.ActiveMobileDropdownScroll = nil;
                return;
            end;
            if not State.Input and math.abs(State.Velocity) <= 2 then
                State.Velocity = 0;
                return;
            end;

            local Scrolling = State.Scrolling;
            local MaxY = math.max(0, Scrolling.CanvasSize.Y.Offset - Scrolling.AbsoluteSize.Y);
            local Now = os.clock();
            local Dt = math.clamp(Now - (State.LastTime > 0 and State.LastTime or Now), 1 / 240, 0.05);

            if State.Input and Library:IsInputActive(State.Input) then
                local Pointer = Library:GetInputPosition(State.Input);
                local DeltaY = Pointer.Y - State.Start.Y;
                local TargetY = math.clamp(State.CanvasStart.Y - DeltaY * 1.15, 0, MaxY);
                State.Velocity = (TargetY - State.LastCanvasY) / Dt;
                State.LastCanvasY = TargetY;
                State.LastTime = Now;
                Scrolling.CanvasPosition = Vector2.new(0, TargetY);
            else
                State.Input = nil;
                local CurrentY = Scrolling.CanvasPosition.Y;
                local TargetY = math.clamp(CurrentY + State.Velocity * Dt, 0, MaxY);
                Scrolling.CanvasPosition = Vector2.new(0, TargetY);
                State.LastCanvasY = TargetY;
                State.LastTime = Now;
                if TargetY == 0 or TargetY == MaxY then
                    State.Velocity = 0;
                else
                    State.Velocity = State.Velocity * math.exp(-9 * Dt);
                end;
            end;
        end));
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
            SpecialType = Info.SpecialType;
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
            Active = true;
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, Library.IsMobile and Library.MobileControlHeight or 20);
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

		local DropdownHitbox = Library:Create('TextButton', {
            Active = true;
            AutoButtonColor = false;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Modal = false;
            Selectable = false;
            Size = UDim2.new(1, 0, 1, 0);
            Text = '';
            TextTransparency = 1;
            ZIndex = 9;
			Parent = DropdownOuter;
		});
		local ClosedHitboxZIndex = DropdownHitbox.ZIndex;

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;
        local DropdownItemHeight = Library.IsMobile and Library.MobileControlHeight or 20;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local DismissLayer = Library:Create('TextButton', {
            Active = true;
            AutoButtonColor = false;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Modal = false;
            Position = UDim2.fromScale(0, 0);
            Selectable = false;
            Size = UDim2.fromScale(1, 1);
            Text = '';
            TextTransparency = 1;
            Visible = false;
            ZIndex = 19;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = Library:ClampPopupPosition(
                ListOuter,
                DropdownOuter.AbsolutePosition.X,
                DropdownOuter.AbsolutePosition.Y + DropdownOuter.AbsoluteSize.Y + 1
            );
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * DropdownItemHeight + 2))
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
            Active = true;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            ElasticBehavior = Library.IsMobile and Enum.ElasticBehavior.Never or Enum.ElasticBehavior.WhenScrollable;
            ScrollingDirection = Enum.ScrollingDirection.Y;
            ScrollingEnabled = not Library.IsMobile;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = Library.IsMobile and 5 or 3,
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
                    Size = UDim2.new(1, -1, 0, DropdownItemHeight);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = true;
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

                Library:BindClick(ButtonLabel, function()
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
                        if not Info.Multi then
                            Dropdown:CloseDropdown();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * DropdownItemHeight) + 1);
            local MaxY = math.max(0, Scrolling.CanvasSize.Y.Offset - Scrolling.AbsoluteSize.Y);
            Scrolling.CanvasPosition = Vector2.new(0, math.clamp(Scrolling.CanvasPosition.Y, 0, MaxY));

            local Y = math.clamp(Count * DropdownItemHeight, 0, MAX_DROPDOWN_ITEMS * DropdownItemHeight) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

		function Dropdown:OpenDropdown()
			Library:CloseOpenedFrames(ListOuter);
			RecalculateListPosition();
			ClosedHitboxZIndex = DropdownHitbox.ZIndex;
			DismissLayer.Visible = true;
			DropdownHitbox.ZIndex = math.max(ClosedHitboxZIndex, 22);
			ListOuter.Visible = true;
            Library:ActivateMobileDropdownScroll(ListOuter, Scrolling);
            if not ListPositionConnection then
                ListPositionConnection = DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);
            end;
            Library.OpenedFrames[ListOuter] = function()
                Dropdown:CloseDropdown();
            end;
            DropdownArrow.Rotation = 180;
        end;

		function Dropdown:CloseDropdown()
			Library:DeactivateMobileDropdownScroll(ListOuter);
			ListOuter.Visible = false;
			DismissLayer.Visible = false;
			DropdownHitbox.ZIndex = ClosedHitboxZIndex;
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

        Library:BindClick(DropdownHitbox, function()
            if ListOuter.Visible then
                Dropdown:CloseDropdown();
            else
                Dropdown:OpenDropdown();
            end;
        end);

        Library:BindClick(DismissLayer, function()
            Dropdown:CloseDropdown();
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
        Position = UDim2.new(0, 100, 0, 10);
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
    Library:MakeDraggable(Library.Watermark, 20);


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
    Library:MakeDraggable(KeybindOuter, 20);
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

local function NormalizeHorizontalAlignment(Value, Default)
    Value = tostring(Value or '');
    if Value == 'Left' or Value == 'Center' or Value == 'Right' then
        return Value;
    end;
    return Default or 'Center';
end;

local function GetHorizontalAlignmentEnum(Value)
    Value = NormalizeHorizontalAlignment(Value, 'Center');
    return Value == 'Left' and Enum.HorizontalAlignment.Left
        or Value == 'Right' and Enum.HorizontalAlignment.Right
        or Enum.HorizontalAlignment.Center;
end;

function Library:SetTabSpacing(Value)
    Library.TabSpacing = math.clamp(math.floor((tonumber(Value) or 0) + 0.5), 0, 50);
    if Library.TabListLayout then
        Library.TabListLayout.Padding = UDim.new(0, Library.TabSpacing);
    end;
    if type(Library.RefreshTabLayout) == 'function' then
        Library:RefreshTabLayout();
    end;
end;

function Library:SetTabAlignment(Value)
    Library.TabAlignment = NormalizeHorizontalAlignment(Value, 'Center');
    if type(Library.RefreshTabLayout) == 'function' then
        Library:RefreshTabLayout();
    elseif Library.TabListLayout then
        Library.TabListLayout.HorizontalAlignment = GetHorizontalAlignmentEnum(Library.TabAlignment);
    end;
end;

function Library:SetWindowTitleAlignment(Value)
    Library.WindowTitleAlignment = NormalizeHorizontalAlignment(Value, 'Center');
    Library:RefreshWindowTitleDomain();
end;

function Library:RefreshWindowTitleDomain()
    local Title = tostring(Library.WindowTitleText or '');
    local DotPosition = Title:find('.', 1, true);
    local HasDomain = DotPosition ~= nil and DotPosition < #Title;
    local PrefixText = HasDomain and Title:sub(1, DotPosition - 1) or Title;
    local DotText = HasDomain and '.' or '';
    local TextAfterDot = HasDomain and Title:sub(DotPosition + 1) or '';
    local SuffixPosition = HasDomain and TextAfterDot:find('%s') or nil;
    local DomainText = SuffixPosition and TextAfterDot:sub(1, SuffixPosition - 1) or TextAfterDot;
    local SuffixText = SuffixPosition and TextAfterDot:sub(SuffixPosition) or '';
    local PrefixWidth = Library:GetTextBounds(PrefixText, Library.Font, 16);
    local DotWidth = Library:GetTextBounds(DotText, Library.Font, 16);
    local DomainWidth = Library:GetTextBounds(DomainText, Library.Font, 16);
    local SuffixWidth = Library:GetTextBounds(SuffixText, Library.Font, 16);
    local TotalWidth = PrefixWidth + DotWidth + DomainWidth + SuffixWidth;
    local Alignment = NormalizeHorizontalAlignment(Library.WindowTitleAlignment, 'Center');
    local PositionScale = 0.5;
    local StartOffset = math.floor(-TotalWidth * 0.5 + 0.5);
    if Alignment == 'Left' then
        PositionScale = 0;
        StartOffset = 7;
    elseif Alignment == 'Right' then
        PositionScale = 1;
        StartOffset = -TotalWidth - 7;
    end;
    local DomainColor = Library.WindowTitleDomainColorEnabled
        and (Library.WindowTitleDomainColor or Library.AccentColor)
        or Library.FontColor;

    for _, Entry in ipairs(Library.WindowTitleLabels or {}) do
        local LayerVisible = not Entry.IsGlow or Library.WindowTitleGlowEnabled;

        Entry.PrefixLabel.Text = PrefixText;
        Entry.PrefixLabel.Position = UDim2.new(PositionScale, StartOffset + Entry.OffsetX, 0, Entry.OffsetY);
        Entry.PrefixLabel.Size = UDim2.new(0, PrefixWidth, 0, 25);
        Entry.PrefixLabel.Visible = LayerVisible;

        Entry.DotLabel.Text = DotText;
        Entry.DotLabel.TextColor3 = DomainColor;
        Entry.DotLabel.Position = UDim2.new(PositionScale, StartOffset + PrefixWidth + Entry.OffsetX, 0, Entry.OffsetY);
        Entry.DotLabel.Size = UDim2.new(0, DotWidth, 0, 25);
        Entry.DotLabel.Visible = HasDomain and LayerVisible;

        Entry.DomainLabel.Text = DomainText;
        Entry.DomainLabel.TextColor3 = DomainColor;
        Entry.DomainLabel.Position = UDim2.new(
            PositionScale,
            StartOffset + PrefixWidth + DotWidth + Entry.OffsetX,
            0,
            Entry.OffsetY
        );
        Entry.DomainLabel.Size = UDim2.new(0, DomainWidth, 0, 25);
        Entry.DomainLabel.Visible = HasDomain and LayerVisible;

        Entry.SuffixLabel.Text = SuffixText;
        Entry.SuffixLabel.TextColor3 = Library.FontColor;
        Entry.SuffixLabel.Position = UDim2.new(
            PositionScale,
            StartOffset + PrefixWidth + DotWidth + DomainWidth + Entry.OffsetX,
            0,
            Entry.OffsetY
        );
        Entry.SuffixLabel.Size = UDim2.new(0, SuffixWidth, 0, 25);
        Entry.SuffixLabel.Visible = SuffixText ~= '' and LayerVisible;
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
        if not Library.WatermarkEnabled then
            Frames = 0;
            Elapsed = 0;
            return;
        end;

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
        Library:RefreshWatermark();
    end));
end;

local function ColorToRichHex(Color)
    return string.format('#%02X%02X%02X',
        math.floor(Color.R * 255 + 0.5),
        math.floor(Color.G * 255 + 0.5),
        math.floor(Color.B * 255 + 0.5)
    );
end;

local function EscapeRichText(Text)
    return (tostring(Text)
        :gsub('&', '&amp;')
        :gsub('<', '&lt;')
        :gsub('>', '&gt;')
        :gsub('"', '&quot;')
        :gsub("'", '&apos;'));
end;

function Library:BuildRichText(Segments)
    local Parts = {};
    local Plain = {};

    for _, Segment in ipairs(Segments) do
        local Body = EscapeRichText(Segment[1]);
        Plain[#Plain + 1] = tostring(Segment[1]);

        local Key = Segment[2];
        local Color = typeof(Key) == 'Color3' and Key or (Key and Library[Key]);

        if Color then
            Parts[#Parts + 1] = string.format('<font color="%s">%s</font>', ColorToRichHex(Color), Body);
        else
            Parts[#Parts + 1] = Body;
        end;
    end;

    return table.concat(Parts), table.concat(Plain);
end;

function Library:NotifyRich(Segments, Time)
    if type(Segments) ~= 'table' then
        return Library:Notify(tostring(Segments), Time);
    end;

    local Rich, Plain = Library:BuildRichText(Segments);
    return Library:Notify(Plain, Time, Rich);
end;

function Library:Notify(Text, Time, RichText)
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

    if RichText then
        NotifyLabel.RichText = true;
        NotifyLabel.Text = RichText;
    end;

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

    local MobileMode = Library.IsMobile and Config.Mobile ~= false;
    Library.MobileMode = MobileMode;

    local ColumnCount = Config.Columns or Config.ColumnCount;
    if type(ColumnCount) ~= 'number' then ColumnCount = 3 end
    Config.Columns = MobileMode
        and (Library.DeviceClass == 'Tablet' and math.clamp(math.floor(ColumnCount), 2, 3) or 1)
        or math.clamp(math.floor(ColumnCount), 2, 3);
    if Config.AutoDistributeRight == nil then Config.AutoDistributeRight = Config.Columns == 3 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then
        Config.Size = Config.Columns == 3 and UDim2.fromOffset(760, 520) or UDim2.fromOffset(550, 600)
    end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    if MobileMode then
        Config.AnchorPoint = Vector2.new(0.5, 0.5);
        Config.Position = UDim2.fromScale(0.5, 0.5);
        Config.AutoDistributeRight = Library.DeviceClass == 'Tablet' and Config.Columns == 3;
        Config.TabPadding = math.min(Config.TabPadding, 4);
    end;

    Library.TabSpacing = math.clamp(math.floor(Config.TabPadding + 0.5), 0, 50);
    Library.TabAlignment = NormalizeHorizontalAlignment(Config.TabAlignment or Library.TabAlignment, 'Center');
    Library.WindowTitleAlignment = NormalizeHorizontalAlignment(
        Config.TitleAlignment or Library.WindowTitleAlignment,
        'Center'
    );

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

    local LastMobileViewport;
    local function UpdateMobileWindowSize()
        if not MobileMode then return; end;

        local Viewport = Library:GetViewportSize();
        if Viewport == LastMobileViewport then return; end;
        LastMobileViewport = Viewport;
        Library:RefreshDeviceClass();
        Window.DeviceClass = Library.DeviceClass;

        local WidthRatio = 0.85;
        local HeightRatio = 0.72;
        local AvailableWidth = math.max(1, Viewport.X - 16);
        local AvailableHeight = math.max(1, Viewport.Y - 24);
        local MinWidth = math.min(240, AvailableWidth);
        local MinHeight = math.min(260, AvailableHeight);
        local Width = math.max(MinWidth, math.min(math.floor(Viewport.X * WidthRatio), AvailableWidth));
        local Height = math.max(MinHeight, math.min(math.floor(Viewport.Y * HeightRatio), AvailableHeight));
        Outer.AnchorPoint = Vector2.new(0.5, 0.5);
        Outer.Position = UDim2.fromScale(0.5, 0.5);
        Outer.Size = UDim2.fromOffset(Width, Height);
        Library:RefreshMobileBindButtonBounds();
    end;

    local MobileViewportConnection;
    local function BindMobileViewport()
        if MobileViewportConnection then
            MobileViewportConnection:Disconnect();
            MobileViewportConnection = nil;
        end;

        local Camera = Workspace.CurrentCamera;
        if Camera then
            MobileViewportConnection = Camera:GetPropertyChangedSignal('ViewportSize'):Connect(UpdateMobileWindowSize);
        end;
        UpdateMobileWindowSize();
    end;

    if MobileMode then
        Library:GiveSignal(Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(BindMobileViewport));
        Library:OnUnload(function()
            if MobileViewportConnection then
                MobileViewportConnection:Disconnect();
                MobileViewportConnection = nil;
            end;
        end);
        BindMobileViewport();
    end;

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

    local CustomBackgroundImage = Library:Create('ImageLabel', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Image = '';
        ImageColor3 = Color3.new(1, 1, 1);
        ImageTransparency = Library.CustomBackgroundTransparency;
        Position = UDim2.new(0, 8, 0, 25);
        ScaleType = Enum.ScaleType[Library.CustomBackgroundScaleType] or Enum.ScaleType.Crop;
        Size = UDim2.new(1, -16, 1, -33);
        Visible = false;
        ZIndex = 1;
        Parent = Inner;
    });

    Library.CustomBackgroundImage = CustomBackgroundImage;
    Library:RegisterCustomBackgroundPanel(Inner);

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

        local WindowSuffixGlow = Library:Create('TextLabel', {
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

        Library:AddToRegistry(WindowGlow, {
            TextColor3 = function()
                return Library.WindowTitleGradientEnabled and Color3.new(1, 1, 1) or Library.FontColor;
            end;
            TextStrokeColor3 = function()
                return Library.WindowTitleGradientEnabled and Color3.new(1, 1, 1) or Library.FontColor;
            end;
        });

        Library:AddToRegistry(WindowDotGlow, {
            TextColor3 = function()
                return Library.WindowTitleDomainColorEnabled
                    and (Library.WindowTitleDomainColor or Library.AccentColor)
                    or Library.FontColor;
            end;
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

        Library:AddToRegistry(WindowSuffixGlow, {
            TextColor3 = 'FontColor';
            TextStrokeColor3 = 'FontColor';
        });

        table.insert(Library.WindowTitleGlowLabels, WindowGlow);
        table.insert(Library.WindowTitleGlowLabels, WindowDotGlow);
        table.insert(Library.WindowTitleGlowLabels, WindowDomainGlow);
        table.insert(Library.WindowTitleGlowLabels, WindowSuffixGlow);
        table.insert(Library.WindowTitleLabels, {
            PrefixLabel = WindowGlow;
            DotLabel = WindowDotGlow;
            DomainLabel = WindowDomainGlow;
            SuffixLabel = WindowSuffixGlow;
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

    local WindowSuffixLabel = Library:CreateLabel({
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
    Library.RegistryMap[WindowDotLabel].Properties.TextColor3 = function()
        return Library.WindowTitleDomainColorEnabled
            and (Library.WindowTitleDomainColor or Library.AccentColor)
            or Library.FontColor;
    end;
    table.insert(Library.WindowTitleLabels, {
        PrefixLabel = WindowLabel;
        DotLabel = WindowDotLabel;
        DomainLabel = WindowDomainLabel;
        SuffixLabel = WindowSuffixLabel;
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
    Library:RegisterCustomBackgroundPanel(MainSectionOuter);

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
    Library:RegisterCustomBackgroundPanel(MainSectionInner);

    local TabAreaHeight = MobileMode and 28 or 21;
    local TabArea = Library:Create(MobileMode and 'ScrollingFrame' or 'Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, TabAreaHeight);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    if MobileMode then
        Library:Create(TabArea, {
            Active = true;
            BorderSizePixel = 0;
            BottomImage = '';
            CanvasSize = UDim2.fromOffset(0, 0);
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable;
            ScrollBarImageColor3 = Library.AccentColor;
            ScrollBarThickness = 2;
            ScrollingDirection = Enum.ScrollingDirection.X;
            TopImage = '';
        });
        Library:AddToRegistry(TabArea, { ScrollBarImageColor3 = 'AccentColor'; });
    end;

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Library.TabSpacing);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = GetHorizontalAlignmentEnum(Library.TabAlignment);
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    Library.TabArea = TabArea;
    Library.TabListLayout = TabListLayout;

    local function RefreshTabLayout()
        if not TabArea.Parent or not TabListLayout.Parent then return; end;

        TabListLayout.Padding = UDim.new(0, Library.TabSpacing or 0);
        local ContentWidth = TabListLayout.AbsoluteContentSize.X;
        local AvailableWidth = TabArea.AbsoluteSize.X;
        local Alignment = GetHorizontalAlignmentEnum(Library.TabAlignment);

        if MobileMode and ContentWidth > AvailableWidth then
            Alignment = Enum.HorizontalAlignment.Left;
        end;
        TabListLayout.HorizontalAlignment = Alignment;

        if MobileMode then
            TabArea.CanvasSize = UDim2.fromOffset(math.max(ContentWidth + 4, AvailableWidth), 0);
        end;
    end;

    Library.RefreshTabLayout = RefreshTabLayout;

    if MobileMode then
        TabListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(RefreshTabLayout);
        TabArea:GetPropertyChangedSignal('AbsoluteSize'):Connect(RefreshTabLayout);
    end;
    task.defer(RefreshTabLayout);

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, TabAreaHeight + 9);
        Size = UDim2.new(1, -16, 1, -(TabAreaHeight + 17));
        ZIndex = 2;
        Parent = MainSectionInner;
    });


    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });
    Library:RegisterCustomBackgroundPanel(TabContainer);

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

        local TabTextSize = MobileMode and 14 or 16;
        local TabButtonWidth = Library:GetTextBounds(DisplayName, Library.Font, TabTextSize);

        local TabButton = Library:Create('Frame', {
            Active = true;
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
            TextSize = TabTextSize;
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
                ScrollBarThickness = MobileMode and 3 or 0;
                ScrollBarImageColor3 = Library.AccentColor;
                LayoutOrder = Column;
                ZIndex = 2;
                Parent = ColumnsContainer;
            });

            if MobileMode then
                Library:AddToRegistry(Side, { ScrollBarImageColor3 = 'AccentColor'; });
            end;

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
            Library:RegisterCustomBackgroundPanel(BoxOuter);

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
            Library:RegisterCustomBackgroundPanel(BoxInner);

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
            local CompactPhoneLayout = MobileMode and Library.DeviceClass == 'Phone';
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

            if CompactPhoneLayout then
                SearchBox.Text = '';
                SearchOuter.Visible = false;
            end;

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
            if CompactPhoneLayout then
                RefreshButton.Position = UDim2.fromOffset(6, 6);
                RefreshButton.Size = UDim2.new(1, -12, 0, 25);
            end;
            Library:AddToRegistry(RefreshButton, {
                BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor';
            });

            local Header = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(6, CompactPhoneLayout and 35 or 32);
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

            local NameHeader = AddLabel(
                Header,
                'Name',
                UDim2.fromScale(0, 0),
                CompactPhoneLayout and UDim2.new(0.7, 0, 1, 0) or UDim2.new(0.5, 0, 1, 0),
                Enum.TextXAlignment.Center
            );
            local UserIdHeader = AddLabel(Header, 'UserId', UDim2.fromScale(0.5, 0), UDim2.new(0.25, 0, 1, 0), Enum.TextXAlignment.Center);
            local PriorityHeader = AddLabel(
                Header,
                'Priority',
                CompactPhoneLayout and UDim2.fromScale(0.7, 0) or UDim2.fromScale(0.75, 0),
                CompactPhoneLayout and UDim2.new(0.3, 0, 1, 0) or UDim2.new(0.25, 0, 1, 0),
                Enum.TextXAlignment.Center
            );
            UserIdHeader.Visible = not CompactPhoneLayout;

            local RowsContainer = Library:Create('ScrollingFrame', {
                BackgroundColor3 = Library.BackgroundColor;
                BackgroundTransparency = 0;
                BorderColor3 = Library.OutlineColor;
                Position = UDim2.fromOffset(6, CompactPhoneLayout and 55 or 52);
                Size = CompactPhoneLayout
                    and UDim2.new(1, -12, 1, -133)
                    or UDim2.new(1, -12, 1, -174);
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
                Position = CompactPhoneLayout
                    and UDim2.new(0, 6, 1, -70)
                    or UDim2.new(0, 6, 1, -116);
                Size = CompactPhoneLayout
                    and UDim2.new(1, -12, 0, 64)
                    or UDim2.new(1, -12, 0, 110);
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
                Visible = not CompactPhoneLayout;
                ZIndex = 8;
                Parent = Detail;
            });
            Library:AddToRegistry(Avatar, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

            local DetailTextX = CompactPhoneLayout and 8 or 90;
            local DetailTextWidth = CompactPhoneLayout
                and UDim2.new(0.53, -12, 0, 18)
                or UDim2.new(0.48, -92, 0, 18);
            local PublicDetail = AddLabel(Detail, 'Public: ???', UDim2.fromOffset(DetailTextX, CompactPhoneLayout and 4 or 26), DetailTextWidth);
            local UsernameDetail = AddLabel(Detail, 'Username: ???', UDim2.fromOffset(DetailTextX, CompactPhoneLayout and 22 or 46), DetailTextWidth);
            local UserIdDetail = AddLabel(Detail, 'UserId: ???', UDim2.fromOffset(DetailTextX, CompactPhoneLayout and 40 or 66), DetailTextWidth);

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
            local DetailGroupY = CompactPhoneLayout and 7
                or ((MobileMode and Library.DeviceClass == 'Tablet') and 24 or 30);
            PriorityDropdown = PriorityGroup:AddDropdown('PlayerList_Priority', {
                Values = { 'Neutral', 'Friendly', 'Enemy' };
                Default = 'Neutral';
                Callback = function(Value)
                    if not SyncingPriority then SetPriority(SelectedName, Value); end;
                end;
            });
            PriorityGroup.Holder.Parent = Detail;
            PriorityGroup.Holder.Position = UDim2.new(0.55, 0, 0, DetailGroupY);
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
            LocalPlayerGroup.Holder.Position = UDim2.new(0.55, 0, 0, DetailGroupY);
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

                local Query = CompactPhoneLayout and '' or SearchBox.Text:lower();
                local Names = {};
                for Name, Entry in next, PlayerList.Players do
                    local Player = Entry.Player;
                    local Searchable = (Name .. ' ' .. Player.DisplayName .. ' ' .. tostring(Player.UserId)):lower();
                    if Query == '' or Searchable:find(Query, 1, true) then table.insert(Names, Name); end;
                end;
                table.sort(Names, function(A, B) return A:lower() < B:lower(); end);

                local RowHeight = CompactPhoneLayout and 26 or 20;
                for Index, Name in ipairs(Names) do
                    local Entry = PlayerList.Players[Name];
                    local Row = Library:Create('Frame', {
                        BackgroundColor3 = Name == SelectedName and Library.AccentColorDark or Library.BackgroundColor;
                        BackgroundTransparency = Name == SelectedName and 0 or 1;
                        BorderSizePixel = 0;
                        Position = UDim2.fromOffset(0, (Index - 1) * RowHeight);
                        Size = UDim2.new(1, -2, 0, RowHeight);
                        ZIndex = 5;
                        Parent = RowsContainer;
                    });
                    Library:AddToRegistry(Row, { BackgroundColor3 = function()
                        return Name == SelectedName and Library.AccentColorDark or Library.BackgroundColor;
                    end; });
                    local NameLabel = AddLabel(
                        Row,
                        Name,
                        UDim2.fromOffset(5, 0),
                        CompactPhoneLayout and UDim2.new(0.7, -5, 1, 0) or UDim2.new(0.5, -5, 1, 0)
                    );
                    local ExploitFlags = Library.ExploitFlags;
                    if ExploitFlags and ExploitFlags[Entry.Player.UserId] then
                        NameLabel.RichText = true;
                        NameLabel.Text = Name .. ' <font color="#ff2d2d">(!)</font>';
                    end;
                    if not CompactPhoneLayout then
                        AddLabel(Row, tostring(Entry.Player.UserId), UDim2.fromScale(0.5, 0), UDim2.new(0.25, 0, 1, 0), Enum.TextXAlignment.Center);
                    end;
                    local PriorityLabel = AddLabel(
                        Row,
                        Entry.Priority.Text,
                        CompactPhoneLayout and UDim2.fromScale(0.7, 0) or UDim2.fromScale(0.75, 0),
                        CompactPhoneLayout and UDim2.new(0.3, -5, 1, 0) or UDim2.new(0.25, -5, 1, 0),
                        Enum.TextXAlignment.Right
                    );
                    PriorityLabel.TextColor3 = PriorityColor(Entry.Priority.Text);
                    local Click = Library:Create('TextButton', {
                        Active = true;
                        AutoButtonColor = false;
                        BackgroundTransparency = 1;
                        Size = UDim2.fromScale(1, 1);
                        Text = '';
                        ZIndex = 10;
                        Parent = Row;
                    });
                    if CompactPhoneLayout then
                        Library:GiveSignal(Click.Activated:Connect(function()
                            SelectPlayer(Name);
                        end));
                    else
                        Library:BindClick(Click, function() SelectPlayer(Name); end);
                    end;
                    table.insert(PlayerList.Rows, Row);
                    Entry.Background = Row;
                end;
                RowsContainer.CanvasSize = UDim2.fromOffset(0, #Names * RowHeight);
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

            function PlayerList:GetSelectedPlayer()
                local Entry = SelectedName and self.Players[SelectedName];
                return Entry and Entry.Player or nil;
            end;

            function PlayerList:Refresh()
                UpdateSelection();
                RefreshRows();
            end;

            SearchBox:GetPropertyChangedSignal('Text'):Connect(RefreshRows);

            local RefreshEvent = Instance.new('BindableEvent');
            Library:BindClick(RefreshButton, function() PlayerList:Sync(); RefreshEvent:Fire(); end);
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
            Library:RegisterCustomBackgroundPanel(BoxOuter);

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
            Library:RegisterCustomBackgroundPanel(BoxInner);

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
                    Active = true;
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

                Library:BindClick(Button, function(Input)
                    if not Library:MouseIsOverOpenedFrame(Input) then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();


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

        Library:BindClick(TabButton, function()
            Tab:ShowTab();
        end);


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

            Interface:AddDropdown('Settings_WindowTitleAlignment', {
                Text = 'Title alignment';
                Values = { 'Left', 'Center', 'Right' };
                Default = Library.WindowTitleAlignment;
                Multi = false;
                Tooltip = 'Aligns the complete window title, including domain color, glow and gradient layers.';
                Callback = function(Value)
                    Library:SetWindowTitleAlignment(Value);
                end;
            });

            Interface:AddDropdown('Settings_TabAlignment', {
                Text = 'Tab alignment';
                Values = { 'Left', 'Center', 'Right' };
                Default = Library.TabAlignment;
                Multi = false;
                Tooltip = 'Aligns the row of page-selection tabs.';
                Callback = function(Value)
                    Library:SetTabAlignment(Value);
                end;
            });

            Interface:AddSlider('Settings_TabSpacing', {
                Text = 'Tab spacing';
                Min = 0;
                Max = 30;
                Default = Library.TabSpacing;
                Rounding = 0;
                Suffix = ' px';
                Tooltip = 'Sets the distance between page-selection tabs.';
                Callback = function(Value)
                    Library:SetTabSpacing(Value);
                end;
            });

            local WindowTitleDomainColorToggle = Interface:AddToggle('Settings_WindowTitleDomainColor', {
                Text = 'Custom domain color';
                Default = false;
                Tooltip = 'Colors only the first dot and domain token, stopping at whitespace.';
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

            if MobileMode then
                local MobileBindValues = Library:GetMobileBindOptions();
                if #MobileBindValues > 0 then
                    Interface:AddDropdown('Settings_VisibleMobileBinds', {
                        Text = 'Visible touch binds';
                        Values = MobileBindValues;
                        Default = MobileBindValues;
                        Multi = true;
                        AllowNull = true;
                        Callback = function(Value)
                            Library:SetVisibleMobileBinds(Value);
                        end;
                    });
                end;

                Interface:AddDropdown('Settings_MobileMenuButtonStyle', {
                    Text = 'Mobile menu button';
                    Values = { 'Compact D', 'Text button' };
                    Default = 'Compact D';
                    Multi = false;
                    Callback = function(Value)
                        Library:SetMobileToggleStyle(Value);
                    end;
                });
            end;

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

    local MobileToggleOuter;
    local MobileToggleButton;
    if MobileMode then
        MobileToggleOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(1, 0);
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(1, -12, 0, 12);
            Size = UDim2.fromOffset(38, 38);
            ZIndex = 250;
            Parent = ScreenGui;
        });

        MobileToggleButton = Library:Create('TextButton', {
            AutoButtonColor = false;
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Font = Library.Font;
            Position = UDim2.fromOffset(1, 1);
            Size = UDim2.new(1, -2, 1, -2);
            Text = 'd';
            TextColor3 = Library.FontColor;
            TextSize = 18;
            TextStrokeTransparency = 0;
            ZIndex = 251;
            Parent = MobileToggleOuter;
        });
        Library:ApplyTextStroke(MobileToggleButton);

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1));
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212));
            });
            Rotation = 90;
            Parent = MobileToggleButton;
        });

        local MobileAccent = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 252;
            Parent = MobileToggleButton;
        });

        Library:AddToRegistry(MobileToggleButton, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
            TextColor3 = 'FontColor';
        });
        Library:AddToRegistry(MobileAccent, { BackgroundColor3 = 'AccentColor'; });
        Library.MobileToggle = MobileToggleOuter;
    end;

    local Toggled = false;
    local Fading = false;
    local CursorMouseState = true;
    local Cursor;
    local CursorOutline;
    Library.WindowFocused = true;

    Library.MobileToggleStyle = Library.MobileToggleStyle or 'Compact D';
    function Library:SetMobileToggleStyle(Value)
        if not MobileToggleOuter or not MobileToggleButton then return; end;

        local Compact = Value ~= 'Text button';
        Library.MobileToggleStyle = Compact and 'Compact D' or 'Text button';
        MobileToggleOuter.Size = Compact and UDim2.fromOffset(38, 38) or UDim2.fromOffset(92, 32);
        MobileToggleButton.TextSize = Compact and 18 or 14;
        MobileToggleButton.Text = Compact
            and 'd'
            or (Toggled and 'drain | hide' or 'drain | menu');
    end;

    Library:SetMobileToggleStyle(Library.MobileToggleStyle);

    if not MobileMode then
        Cursor = Drawing.new('Triangle');
        Cursor.Thickness = 1;
        Cursor.Filled = true;
        Cursor.Visible = false;

        CursorOutline = Drawing.new('Triangle');
        CursorOutline.Thickness = 1;
        CursorOutline.Filled = false;
        CursorOutline.Color = Color3.new(0, 0, 0);
        CursorOutline.Visible = false;

        Library.CursorDrawings = Library.CursorDrawings or {};
        table.insert(Library.CursorDrawings, Cursor);
        table.insert(Library.CursorDrawings, CursorOutline);
        Environment.DrainCursorDrawings = Library.CursorDrawings;

        Library:GiveSignal(InputService.WindowFocusReleased:Connect(function()
            Library.WindowFocused = false;
            Cursor.Visible = false;
            CursorOutline.Visible = false;
            InputService.MouseIconEnabled = CursorMouseState;
        end));

        Library:GiveSignal(InputService.WindowFocused:Connect(function()
            Library.WindowFocused = true;
        end));
    end;

    local CursorHidden = false;
    Library:GiveSignal(RenderStepped:Connect(function()
        if MobileMode then return; end

        if not Toggled or not Outer.Visible or not Library.WindowFocused then
            if not CursorHidden then
                CursorHidden = true;
                Cursor.Visible = false;
                CursorOutline.Visible = false;
            end;
            return;
        end
        CursorHidden = false;

        Cursor.Visible = true;
        CursorOutline.Visible = true;
        InputService.MouseIconEnabled = false;
        local mPos = Library:GetRawPointerPosition();
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
		if not Toggled then
			Library:CloseOpenedFrames();
			Library.ActivePointerOwner = nil;
			Library.ActivePointerInput = nil;
		end;
		Library:SetMobileBindEditing(Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then

            Outer.Visible = true;
            if not MobileMode then
                CursorMouseState = InputService.MouseIconEnabled;
                InputService.MouseIconEnabled = false;
                Cursor.Visible = true;
                CursorOutline.Visible = true;
            end;
        else
            if not MobileMode then
                InputService.MouseIconEnabled = CursorMouseState;
                Cursor.Visible = false;
                CursorOutline.Visible = false;
            end;
        end;

        if MobileToggleButton then
            MobileToggleButton.Text = Library.MobileToggleStyle == 'Text button'
                and (Toggled and 'drain | hide' or 'drain | menu')
                or 'd';
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

    if MobileToggleButton then
        Library:GiveSignal(MobileToggleButton.Activated:Connect(function()
            task.spawn(Library.Toggle);
        end));
    end;

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
    Window.MobileMode = MobileMode;
    Window.DeviceClass = Library.DeviceClass;
    Window.MobileToggle = MobileToggleOuter;

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
				return { type = 'Slider', idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then

					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				local state = object.GetAnimationState and object:GetAnimationState() or nil
				local primaryColor = state and state.Color1 or object.Value
				local primaryTransparency = state and state.Transparency1 or object.Transparency

				local result = {
					type = 'ColorPicker',
					idx = idx,
					value = primaryColor:ToHex(),
					transparency = primaryTransparency
				}

				if state then
					result.animation = {
						mode = state.Mode,
						speed = state.Speed,
						color1 = state.Color1:ToHex(),
						transparency1 = state.Transparency1,
						color2 = state.Color2:ToHex(),
						transparency2 = state.Transparency2
					}
				end

				return result
			end,
			Load = function(idx, data)
				if Options[idx] then
					local option = Options[idx]
					local animation = type(data.animation) == 'table' and data.animation or nil

					if animation and option.SetAnimationState then
						option:SetAnimationState({
							Mode = animation.mode,
							Speed = animation.speed,
							Color1 = Color3.fromHex(animation.color1 or data.value),
							Transparency1 = animation.transparency1 ~= nil and animation.transparency1 or data.transparency,
							Color2 = Color3.fromHex(animation.color2 or animation.color1 or data.value),
							Transparency2 = animation.transparency2 ~= nil and animation.transparency2 or data.transparency
						})
					elseif option.SetAnimationState then
						option:SetAnimationState({
							Mode = 'Static',
							Color1 = Color3.fromHex(data.value),
							Transparency1 = data.transparency,
							Color2 = Color3.fromHex(data.value),
							Transparency2 = data.transparency
						})
					else
						option:SetValueRGB(Color3.fromHex(data.value), data.transparency)
					end
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

		local objects = {}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end
			if not self.Parser[toggle.Type] then continue end

			table.insert(objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(objects, self.Parser[option.Type].Save(idx, option))
		end

		local data = {}
		if isfile(fullPath) then
			local existingReadSuccess, existingRaw = pcall(readfile, fullPath)
			if existingReadSuccess then
				local existingDecodeSuccess, existingData = pcall(httpService.JSONDecode, httpService, existingRaw)
				if existingDecodeSuccess and type(existingData) == 'table' then
					data = existingData
				end
			end
		end

		if type(data.objects) == 'table' then
			local currentObjectIds = {}
			for _, object in ipairs(objects) do
				currentObjectIds[tostring(object.idx)] = true
			end

			for _, existingObject in ipairs(data.objects) do
				if type(existingObject) == 'table' and existingObject.idx ~= nil then
					local existingIdx = tostring(existingObject.idx)
					if not currentObjectIds[existingIdx] and not self.Ignore[existingIdx] then
						table.insert(objects, existingObject)
						currentObjectIds[existingIdx] = true
					end
				end
			end
		end

		table.sort(objects, function(a, b)
			local aIdx = tostring(a.idx or '')
			local bIdx = tostring(b.idx or '')

			if aIdx == bIdx then
				return tostring(a.type or '') < tostring(b.type or '')
			end

			return aIdx < bIdx
		end)

		data.version = math.max(tonumber(data.version) or 0, 2)
		data.objects = objects

		if self.Library and self.Library.IsMobile then
			local uiLayouts = type(data.uiLayouts) == 'table' and data.uiLayouts or {}
			local mobileLayouts = type(uiLayouts.mobile) == 'table' and uiLayouts.mobile or {}

			local legacyLayout = type(data.mobileBindLayout) == 'table' and data.mobileBindLayout
				or (type(data.mobile_bind_layout) == 'table' and data.mobile_bind_layout or nil)
			if legacyLayout and type(legacyLayout.width) == 'number' and type(legacyLayout.height) == 'number' then
				local legacyKey = string.format('%dx%d', legacyLayout.width, legacyLayout.height)
				if mobileLayouts[legacyKey] == nil then
					mobileLayouts[legacyKey] = legacyLayout
				end
			end

			local resolution, layout = self.Library:CaptureMobileBindLayout()
			if resolution and layout then
				mobileLayouts[resolution] = layout
			end

			uiLayouts.mobile = mobileLayouts
			data.uiLayouts = uiLayouts
			self.Library.LoadedMobileBindLayouts = mobileLayouts
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		local writeSuccess, writeError = pcall(writefile, fullPath, encoded)
		if not writeSuccess then
			return false, 'failed to write config: ' .. tostring(writeError)
		end

		self.CurrentConfig = name
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local readSuccess, raw = pcall(readfile, file)
		if not readSuccess then
			return false, 'read error'
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, raw)
		if not success then return false, 'decode error' end

		if type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then
			return false, 'invalid config structure'
		end

		local optionObjects = {}
		local toggleObjects = {}

		for _, object in ipairs(decoded.objects) do
			if type(object) == 'table'
				and type(object.idx) == 'string'
				and type(object.type) == 'string'
				and self.Parser[object.type] then

				if object.type == 'Toggle' then
					table.insert(toggleObjects, object)
				else
					table.insert(optionObjects, object)
				end
			end
		end

		local function stableSort(list)
			table.sort(list, function(a, b)
				local aIdx = tostring(a.idx or '')
				local bIdx = tostring(b.idx or '')

				if aIdx == bIdx then
					return tostring(a.type or '') < tostring(b.type or '')
				end

				return aIdx < bIdx
			end)
		end

		stableSort(optionObjects)
		stableSort(toggleObjects)

		local errors = {}

		local function applyObjects(list)
			for _, object in ipairs(list) do
				local parser = self.Parser[object.type]

				if parser and parser.Load then
					local ok, err = pcall(parser.Load, object.idx, object)
					if not ok then
						table.insert(errors, tostring(object.idx) .. ': ' .. tostring(err))
					end
				end
			end
		end


		applyObjects(optionObjects)
		applyObjects(toggleObjects)

		if self.Library and self.Library.IsMobile then
			local mobileLayouts = type(decoded.uiLayouts) == 'table'
				and type(decoded.uiLayouts.mobile) == 'table'
				and decoded.uiLayouts.mobile or nil

			if not mobileLayouts then
				local legacyLayout = type(decoded.mobileBindLayout) == 'table' and decoded.mobileBindLayout
					or (type(decoded.mobile_bind_layout) == 'table' and decoded.mobile_bind_layout or nil)
				if legacyLayout and type(legacyLayout.width) == 'number' and type(legacyLayout.height) == 'number' then
					local legacyKey = string.format('%dx%d', legacyLayout.width, legacyLayout.height)
					mobileLayouts = { [legacyKey] = legacyLayout }
				end
			end

			self.Library:SetMobileBindLayouts(mobileLayouts)
		end

		if #errors > 0 then
			warn('[drain.solutions] config load warnings:\n' .. table.concat(errors, '\n'))
			return false, string.format('config partially loaded (%d errors)', #errors)
		end

		self.CurrentConfig = name
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
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
		library.MobileLayoutSaveManager = self
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
			if type(name) ~= 'string' or name:gsub('%s+', '') == '' then
				return self.Library:Notify('Select a config first', 2)
			end

			local success, err = pcall(writefile, self.Folder .. '/settings/autoload.txt', name)
			if not success then
				return self.Library:Notify('Failed to set autoload: ' .. tostring(err), 3)
			end

			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Clear autoload', function()
			local path = self.Folder .. '/settings/autoload.txt'

			if isfile(path) then
				if type(delfile) ~= 'function' then
					return self.Library:Notify('Failed to clear autoload: delfile is unavailable', 3)
				end

				local success, err = pcall(delfile, path)
				if not success then
					return self.Library:Notify('Failed to clear autoload: ' .. tostring(err), 3)
				end
			end

			SaveManager.AutoloadLabel:SetText('Current autoload config: none')
			self.Library:Notify('Autoload config cleared')
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
if false then
local Notifications; do
    local tweenService, coreGui = game:GetService("TweenService"), game:GetService("CoreGui");

    local insert, find, remove = table.insert, table.find, table.remove
    local format = string.format

    local newInstance = Instance.new
    local fromRGB = Color3.fromRGB

    local notificationPositions = {
        ["Middle"] = UDim2.new(0.445, 0, 0.7, 0),
        ["MiddleRight"] = UDim2.new(0.85, 0, 0.7, 0),
        ["MiddleLeft"] = UDim2.new(0.01, 0, 0.7, 0),

        ["Top"] = UDim2.new(0.445, 0, 0.007, 0),
        ["TopLeft"] = UDim2.new(0.06, 0, 0.001, 0),
        ["TopRight"] = UDim2.new(0.8, 0, 0.001, 0),
    };

    local function protectScreenGui(screenGui)
        if syn and syn.protect_gui then
            syn.protect_gui(screenGui);
            screenGui.Parent = coreGui
        elseif gethui then
            screenGui.Parent = gethui();
        else
            screenGui.Parent = coreGui();
        end
    end

    local function createObject(className, properties)
        local instance = newInstance(className);

        for index, value in next, properties do
            instance[index] = value
        end

        return instance
    end

    local function fadeObject(object, onTweenCompleted)
        local tweenInformation = tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        });

        tweenInformation.Completed:Connect(onTweenCompleted);
        tweenInformation:Play();
    end

    local notifications = {}; do
        function notifications.new(settings)
            assert(settings, "missing argument #1 in function notifications.new(settings)");
            assert(typeof(settings) == "table", format("expected table for argument #1 in function notifications.new(settings), got %s", typeof(settings)));

            local notificationSettings = {ui = {notificationsFrame = nil, notificationsFrame_UIListLayout = nil}};

            for setting, value in next, settings do
                notificationSettings[setting] = value
            end

            setmetatable(notificationSettings, {__index = notifications});
            return notificationSettings
        end

        function notifications:SetNotificationLifetime(number)
            assert(number, "missing argument #1 in function SetNotificationLifetime(number)");
            assert(typeof(number) == "number",  format("expected number for argument #1 in function SetNotificationLifetime, got %s", typeof(number)));

            self.NotificationLifetime = number
        end

        function notifications:SetTextColor(color3)
            assert(color3, "missing argument #1 in function SetTextColor(Color3)");
            assert(typeof(color3) == "Color3", format("expected Color3 for argument #1 in function SetTextColor3, got %s", typeof(color3)));

            self.TextColor = color3
        end

        function notifications:SetTextSize(number)
            assert(number, "missing argument #1 in function SetTextSize(number)");
            assert(typeof(number) == "number",  format("expected number for argument #1 in function SetTextSize, got %s", typeof(number)));

            self.TextSize = number
        end

        function notifications:SetTextStrokeTransparency(number)
            assert(number, "missing argument #1 in function SetTextStrokeTransparency(number)");
            assert(typeof(number) == "number",  format("expected number for argument #1 in function SetTextStrokeTransparency, got %s", typeof(number)));

            self.TextStrokeTransparency = number
        end

        function notifications:SetTextStrokeColor(color3)
            assert(color3, "missing argument #1 in function SetTextStrokeColor(Color3)");
            assert(typeof(color3) == "Color3", format("expected Color3 for argument #1 in function SetTextStrokeColor, got %s", typeof(color3)));

            self.TextStrokeColor = color3
        end

        function notifications:SetTextFont(font)
            assert(font, "missing argument #1 in function SetTextFont(Font)");
            assert((typeof(font) == "string" or typeof(font) == "EnumItem"))

            self.TextFont = Enum.Font[font];
        end

        function notifications:SetTextFontFace(fontFace)
            self.TextFontFace = fontFace
        end

        function notifications:BuildNotificationUI()
            if notifications_screenGui then
                notifications_screenGui:Destroy();
            end

            getgenv().notifications_screenGui = createObject("ScreenGui", {
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            }); protectScreenGui(notifications_screenGui);

            self.ui.notificationsFrame = createObject("Frame", {
                Name = "notificationsFrame",
                Parent = notifications_screenGui,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1.000,
                Position = notificationPositions[self.NotificationPosition],
                Size = UDim2.new(0, 236, 0, 215)
            });

            self.ui.notificationsFrame_UIListLayout = createObject("UIListLayout", {
                Name = "notificationsFrame_UIListLayout",
                Parent = self.ui.notificationsFrame,
                Padding = UDim.new(0, 1),
                SortOrder = Enum.SortOrder.LayoutOrder
            });
        end

        function notifications:Notify(text)
            local notification = createObject("TextLabel", {
                Name = "notification",
                Parent = self.ui.notificationsFrame,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1.000,
                Size = UDim2.new(1, 0, 0, 14),
                Text = text,

                Font = self.TextFont,
                TextColor3 = self.TextColor,
                TextSize = self.TextSize,
                TextStrokeColor3 = self.TextStrokeColor,
                TextStrokeTransparency = self.TextStrokeTransparency,
                TextXAlignment = Enum.TextXAlignment.Center,
            });

            if self.TextFontFace then
                notification.FontFace = self.TextFontFace
            end

            task.delay(self.NotificationLifetime, function()
                fadeObject(notification, function()
                    notification:Destroy();
                end);
            end);
        end
    end

    Notifications = notifications
end

local HitLog = Notifications.new({ NotificationPosition = "Middle" })
HitLog:SetNotificationLifetime(1.5)
HitLog:SetTextColor(Color3.fromRGB(255, 255, 255))
HitLog:SetTextSize(12)
HitLog:SetTextStrokeColor(Color3.new(0, 0, 0))
HitLog:SetTextStrokeTransparency(0)
HitLog:SetTextFont("SourceSansBold")
HitLog:BuildNotificationUI()

task.wait(0.1)

if HitLog.ui and HitLog.ui.notificationsFrame then
    local frame = HitLog.ui.notificationsFrame
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 0.85, 0)
    frame.Size = UDim2.new(0, 600, 0, 200)
    frame.ClipsDescendants = true
end

local HitLogSett = { On = false, LastLogTime = 0, MinInterval = 0.15 }
end

local Plrs  = game:GetService("Players")
local RepSt = game:GetService("ReplicatedStorage")
local RS    = game:GetService("RunService")
local UIS   = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local LP    = Plrs.LocalPlayer
local Cam   = workspace.CurrentCamera

local function get_aim_screen_position(forceCenter)
    local camera = workspace.CurrentCamera or Cam
    if Library.IsMobile or forceCenter then
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    end
    return UIS:GetMouseLocation()
end

local function create_mobile_fov_circle(name, filled, zIndex)
    if not Library.IsMobile or not Library.MobileFovGui then return nil end

    local frame = Instance.new("Frame")
    frame.Name = name
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = filled and 0.15 or 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = zIndex or 10
    frame.Parent = Library.MobileFovGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame

    local stroke
    if not filled then
        stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Parent = frame
    end

    return {
        Frame = frame,
        Stroke = stroke,
        Filled = filled,
    }
end

local function update_mobile_fov_circle(circle, center, radius, color, visible, backgroundTransparency)
    if not circle or not circle.Frame then return end

    local frame = circle.Frame
    frame.Visible = visible == true
    if not frame.Visible then return end

    local diameter = math.max(2, (tonumber(radius) or 1) * 2)
    frame.Position = UDim2.fromOffset(math.floor(center.X + 0.5), math.floor(center.Y + 0.5))
    frame.Size = UDim2.fromOffset(diameter, diameter)

    if circle.Filled then
        frame.BackgroundColor3 = color
        frame.BackgroundTransparency = math.clamp(backgroundTransparency or 0.15, 0, 1)
    elseif circle.Stroke then
        circle.Stroke.Color = color
    end
end

local function remove_fov_circle(circle)
    if not circle then return end

    if type(circle) == "table" and circle.Frame then
        circle.Frame:Destroy()
    else
        pcall(function()
            circle:Remove()
        end)
    end
end

local Playerlist

local function get_player_status(player)
    local entry = Playerlist and Playerlist.Players and Playerlist.Players[player.Name]
    if entry and entry.Priority then
        return entry.Priority.Text
    end
    return "Neutral"
end

drain_boot_log("library built")

local Window = Library:CreateWindow({
    Title = "drain.solutions",
    Center = true,
    AutoShow = true,
    Columns = 3,
    Size = UDim2.fromOffset(760, 520),
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local function Notify(title, text, time)
    Library:Notify(title .. ": " .. text, time)
end

local VisualsPage = Window:AddTab("Visuals")

drain_boot_log("window built")
local ReplicateWeaponNames = {}
local SensoryESP = (function()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local UIContainer = gethui and gethui() or CoreGui
local BootstrapPlayers = Players
local ESP = {}
local ChamsContainer
local MeshChamsFolder
local ScreenGui
local PlayerRemovingConnection
local PlayerAddedConnection
local InputBeganConnection
local CameraConnection
local CharacterConnections = {}
local ESPActive = false
local ESPRenderEnabled = false
local CurrentRunId = HttpService:GenerateGUID(false)

if getgenv().SensoryESP_Unload then
    pcall(getgenv().SensoryESP_Unload)
end

local oldChams = UIContainer:FindFirstChild("SensoryESP_Chams")
    or Workspace:FindFirstChild("SensoryESP_Chams")
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
        ChamsContainer.Parent = Library.IsMobile and Workspace or UIContainer
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
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                or LocalPlayer:WaitForChild("PlayerGui", 10)
            if playerGui then
                pcall(function() ScreenGui.Parent = playerGui end)
            end
        end
    end
end

local labelStrokeMap = setmetatable({}, { __mode = "k" })
local function SetPropertyIfChanged(object, property, value)
    if object and object[property] ~= value then
        object[property] = value
    end
end

local function ApplyTextOutline(label, style, color)
    local stroke = labelStrokeMap[label] or label:FindFirstChildOfClass("UIStroke")
    if not stroke then return end

    local enabled = style ~= "None"
    SetPropertyIfChanged(stroke, "Enabled", enabled)
    if enabled then
        SetPropertyIfChanged(stroke, "Thickness", 1)
        SetPropertyIfChanged(stroke, "Color", color or Color3.fromRGB(0, 0, 0))
    end
end

local function SetThreeColorGradient(espObj, key, gradient, color1, color2, color3)
    local cache = espObj.StyleCache[key]
    if not cache then
        cache = {}
        espObj.StyleCache[key] = cache
    end

    if cache.Color1 ~= color1 or cache.Color2 ~= color2 or cache.Color3 ~= color3 then
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color1),
            ColorSequenceKeypoint.new(0.5, color2),
            ColorSequenceKeypoint.new(1, color3),
        })
        cache.Color1 = color1
        cache.Color2 = color2
        cache.Color3 = color3
    end
end

local DrawLine = (function(line, p1, p2, thickness, color)
    local diff = p2 - p1
    local dist = diff.Magnitude
    local angle = math.deg(math.atan2(diff.Y, diff.X))

    line.Size = UDim2.new(0, math.floor(dist + 0.5), 0, thickness)
    line.Position = UDim2.new(0, math.floor(p1.X + diff.X / 2 - dist / 2 + 0.5), 0,
        math.floor(p1.Y + diff.Y / 2 - thickness / 2 + 0.5))
    line.Rotation = angle
    SetPropertyIfChanged(line, "BackgroundColor3", color)
    SetPropertyIfChanged(line, "Visible", true)
end)

local function SetCornerGeometry(line, x, y, width, height)
    line.Position = UDim2.new(0, x, 0, y)
    line.Size = UDim2.new(0, width, 0, height)
end

local function ShowESPFlag(espObj, index, text, color, font, fontFace, textSize, isRight, x, y, textGap,
                           outlineStyle, outlineColor)
    local label = espObj.FlagLabels[index]
    if not label then return end

    SetPropertyIfChanged(label, "Visible", true)
    SetPropertyIfChanged(label, "Text", text)
    SetPropertyIfChanged(label, "TextColor3", color)
    SetPropertyIfChanged(label, "Font", font)
    if fontFace then
        SetPropertyIfChanged(label, "FontFace", fontFace)
    end
    SetPropertyIfChanged(label, "TextSize", textSize)
    SetPropertyIfChanged(label, "TextXAlignment", isRight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right)
    label.Position = UDim2.new(0, x, 0, y + (index - 1) * (textSize + textGap))
    ApplyTextOutline(label, outlineStyle, outlineColor)
end

local function IsIgnoredColliderPart(part)
    local name = part.Name
    if #name >= 8 and name:sub(-8) == "Collider" then return true end
    if #name >= 9 and name:sub(-9) == "Collision" then return true end
    if #name >= 9 and name:sub(1, 9) == "XCollider" then return true end
    return false
end

local ESPConfig = {
    Enabled = false,
    Keybind = {
        Enabled = false,
        Key = Enum.KeyCode.Insert,
    },
    Players = false,
    LocalPlayer = false,
    LimitFPS = 0,
    MaxDistance = 0,
    DynamicBoxes = true,
    DynamicBoxesCheap = true,
    DynamicBoxesIncludeAll = false,

    Boxes = false,
    BoxType = "Normal",
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 1,
    Outlines = {
        Style = "Full",
        Color = Color3.fromRGB(0, 0, 0),
        Thickness = 1,
    },

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
            Speed = 64,
            Direction = "Right",
        }
    },

    HealthBar = {
        Enabled = false,
        Position = "Left",
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
            Color1 = Color3.fromRGB(0, 255, 0),
            Color2 = Color3.fromRGB(255, 255, 0),
            Color3 = Color3.fromRGB(255, 0, 0),
        }
    },

    DrawingMode = false,

    Names = false,
    TextSize = 12,
    TextColor = Color3.fromRGB(255, 255, 255),
    TextOutline = false,
    TextOutlineStyle = "Full",
    TextGap = 3,
    Font = "Proggy Clean",
    PlayerStatusColors = {
        Target = Color3.fromRGB(255, 220, 0),
        Friendly = Color3.fromRGB(0, 255, 0),
    },
    TeamIndicator = {
        Enabled = false,
        Position = "Right",
        UseTeamColor = false,
        Color = Color3.fromRGB(255, 255, 255),
        Compact = false,
        TextSize = 10,
    },
    FriendlyIndicator = {
        Enabled = false,
        Position = "Right",
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
        UseToolFallback = true,
        UseRemoteFallback = true,
        RemoteMaxAge = 120,
    },

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
            ForceField = false,
            Exploiting = false,
        },
        Colors = {
            Idle = Color3.fromRGB(255, 255, 255),
            Moving = Color3.fromRGB(255, 255, 255),
            Jumping = Color3.fromRGB(255, 255, 255),
            Swimming = Color3.fromRGB(65, 65, 255),
            ForceField = Color3.fromRGB(0, 140, 255),
            Exploiting = Color3.fromRGB(255, 45, 45),
        }
    },

    Skeleton = {
        Enabled = false,
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1.5,
        Joints = true,
        JointScale = 1,
        Outline = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Gradient = {
            Enabled = false,
            Color1 = Color3.fromRGB(255, 255, 255),
            Color2 = Color3.fromRGB(100, 200, 255),
        },
    },

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

    Chams = {
        Enabled = false,
        Type = "Highlight",
        RefreshRate = 0.1,

        Highlight = {
            FillColor = Color3.fromRGB(255, 255, 255),
            FillTransparency = 1,
            OutlineColor = Color3.fromRGB(255, 255, 255),
            OutlineTransparency = 0,
            VisibleCheck = false,
        },

        Adornment = {
            VisibleSize = 0.1,
            RoundHead = false,
            R6HeadScale = 0.86,

            Glow = {
                Enabled = false,
                Color = Color3.fromRGB(59, 144, 204),
                Intensity = 5,
                Size = 0.03,
                FallbackTransparency = 0.72,
            },

            Invisible = {
                Color = Color3.fromRGB(59, 144, 204),
                Transparency = 0.7,
                Highlight = {
                    Enabled = false,
                    FillColor = Color3.fromRGB(59, 144, 204),
                    FillTransparency = 1,
                    OutlineColor = Color3.fromRGB(59, 144, 204),
                    OutlineTransparency = 0,
                },
            },

            Visible = {
                Enabled = true,
                Color = Color3.fromRGB(59, 204, 90),
                Transparency = 0.35,
                Highlight = {
                    Enabled = false,
                    FillColor = Color3.fromRGB(59, 204, 90),
                    FillTransparency = 1,
                    OutlineColor = Color3.fromRGB(59, 204, 90),
                    OutlineTransparency = 0,
                },
            },
        },

        CharacterClone = {
            Color = Color3.fromRGB(190, 195, 205),
            Transparency = 0.55,
            Material = "SmoothPlastic",
            KeepTextures = false,
            IncludeAccessories = true,
            SizeScale = 1.015,
            Highlight = {
                Enabled = true,
                FillColor = Color3.fromRGB(190, 195, 205),
                FillTransparency = 0.75,
                OutlineColor = Color3.fromRGB(255, 255, 255),
                OutlineTransparency = 0.25,
                VisibleCheck = false,
            },
        },

        MeshChams = {
            FillColor = Color3.fromRGB(59, 144, 204),
            FillTransparency = 0.6,
            OutlineColor = Color3.fromRGB(255, 255, 255),
            OutlineTransparency = 0,
            VisibleCheck = false,
        },
    },

    Directories = {
        Zombies = {
            Path = "workspace.Zombies",
            Multiple = true,
        },
        Corpses = {
            Path = "workspace.Corpses",
            Multiple = true,
            DisplayName = "Corpse",
            NoStatus = true,
        },
        Vehicles = {
            Path = "workspace.Vehicles",
            Multiple = true,
            NoStatus = true,
        },
    },
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

local ConfigPathKeys = {}
local CONFIG_NIL = {}

local ConfigRevision = 0
local BaseConfigCache = {}

local function BumpConfigRevision()
    ConfigRevision += 1
    table.clear(BaseConfigCache)
end

local function GetConfigPathKeys(path)
    local keys = ConfigPathKeys[path]
    if not keys then
        keys = string.split(path, ".")
        ConfigPathKeys[path] = keys
    end
    return keys
end

local function ResolveESPConfigValue(configOverride, path)
    local keys = GetConfigPathKeys(path)
    local current = configOverride
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
        return current
    end

    local cached = BaseConfigCache[path]
    if cached ~= nil then
        if cached == CONFIG_NIL then
            return nil
        end
        return cached
    end

    current = ESPConfig
    for _, key in ipairs(keys) do
        current = current[key]
    end

    BaseConfigCache[path] = current == nil and CONFIG_NIL or current
    return current
end

local function Needs2DGeometry(configOverride, isCheap, instance, noStatus, runtime)
    if ResolveESPConfigValue(configOverride, "Names") then
        return true
    end
    if isCheap then
        return false
    end
    if ResolveESPConfigValue(configOverride, "Boxes")
        or ResolveESPConfigValue(configOverride, "Distance.Enabled")
        or ResolveESPConfigValue(configOverride, "Weapon.Enabled") then
        return true
    end

    local humanoidModel = instance:IsA("Model") and ((runtime and runtime.Humanoid) or instance:FindFirstChild("Humanoid")) ~= nil
    if humanoidModel and ResolveESPConfigValue(configOverride, "HealthBar.Enabled") then
        return true
    end

    if humanoidModel and not noStatus and ResolveESPConfigValue(configOverride, "Flags.Enabled") then
        return ResolveESPConfigValue(configOverride, "Flags.Options.Idle")
            or ResolveESPConfigValue(configOverride, "Flags.Options.Moving")
            or ResolveESPConfigValue(configOverride, "Flags.Options.Jumping")
            or ResolveESPConfigValue(configOverride, "Flags.Options.Swimming")
            or ResolveESPConfigValue(configOverride, "Flags.Options.ForceField")
            or ResolveESPConfigValue(configOverride, "Flags.Options.Exploiting")
    end
    return false
end

local function NeedsDistanceValue(configOverride, isCheap)
    return (isCheap and ResolveESPConfigValue(configOverride, "Names"))
        or ResolveESPConfigValue(configOverride, "Distance.Enabled")
        or (ResolveESPConfigValue(configOverride, "OffScreenArrows.Enabled")
            and ResolveESPConfigValue(configOverride, "OffScreenArrows.Distance.Enabled"))
end

local CompactTeamNameCache = {}
local function CompactTeamName(teamName)
    if type(teamName) ~= "string" or teamName == "" then
        return ""
    end

    local cached = CompactTeamNameCache[teamName]
    if cached then return cached end

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
            cached = single:upper()
            CompactTeamNameCache[teamName] = cached
            return cached
        end
        cached = single:sub(1, 1):upper()
        CompactTeamNameCache[teamName] = cached
        return cached
    end

    local compact = {}
    for _, part in ipairs(parts) do
        table.insert(compact, part:sub(1, 1):upper())
    end
    cached = table.concat(compact)
    CompactTeamNameCache[teamName] = cached
    return cached
end

local function ColorToHex(color)
    local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
    return string.format("#%02X%02X%02X", r, g, b)
end
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
    { "Head", "Neck" },
    { "Neck", "LeftShoulder" },
    { "LeftShoulder", "LeftElbow" },
    { "LeftElbow", "LeftHand" },
    { "Neck", "RightShoulder" },
    { "RightShoulder", "RightElbow" },
    { "RightElbow", "RightHand" },
    { "Neck", "Chest" },
    { "Chest", "Pelvis" },
    { "Pelvis", "LeftHip" },
    { "LeftHip", "LeftKnee" },
    { "LeftKnee", "LeftFoot" },
    { "Pelvis", "RightHip" },
    { "RightHip", "RightKnee" },
    { "RightKnee", "RightFoot" },
}

local SKELETON_JOINT_KEYS = {
    "Neck",
    "LeftShoulder",
    "LeftElbow",
    "RightShoulder",
    "RightElbow",
    "Chest",
    "Pelvis",
    "LeftHip",
    "LeftKnee",
    "RightHip",
    "RightKnee",
}

local function SkeletonFindPart(character, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function SkeletonAttachmentPosition(part, ...)
    if not part then return nil end

    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local attachment = part:FindFirstChild(name)
        if attachment and attachment:IsA("Attachment") then
            return attachment.WorldPosition
        end
    end

    return nil
end

local function SkeletonPartEnd(part, direction)
    if not part then return nil end
    return (part.CFrame * CFrame.new(0, part.Size.Y * 0.5 * direction, 0)).Position
end

local function Get3DSkeletonPoints(character)
    if not character or not character.Parent then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6

    if isR6 then
        local torso = SkeletonFindPart(character, "Torso", "UpperTorso", "LowerTorso")
        local head = SkeletonFindPart(character, "Head")
        local leftArm = SkeletonFindPart(character, "Left Arm", "LeftArm")
        local rightArm = SkeletonFindPart(character, "Right Arm", "RightArm")
        local leftLeg = SkeletonFindPart(character, "Left Leg", "LeftLeg")
        local rightLeg = SkeletonFindPart(character, "Right Leg", "RightLeg")

        if not torso then return nil end

        local leftShoulder = SkeletonPartEnd(leftArm, 1)
            or (torso.CFrame * CFrame.new(-torso.Size.X * 0.5, torso.Size.Y * 0.25, 0)).Position

        local rightShoulder = SkeletonPartEnd(rightArm, 1)
            or (torso.CFrame * CFrame.new(torso.Size.X * 0.5, torso.Size.Y * 0.25, 0)).Position

        local leftHand = SkeletonPartEnd(leftArm, -1) or leftShoulder
        local rightHand = SkeletonPartEnd(rightArm, -1) or rightShoulder
        local leftElbow = leftArm and leftArm.Position or ((leftShoulder + leftHand) * 0.5)
        local rightElbow = rightArm and rightArm.Position or ((rightShoulder + rightHand) * 0.5)

        local leftHip = SkeletonPartEnd(leftLeg, 1)
            or (torso.CFrame * CFrame.new(-torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0)).Position

        local rightHip = SkeletonPartEnd(rightLeg, 1)
            or (torso.CFrame * CFrame.new(torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0)).Position

        local leftFoot = SkeletonPartEnd(leftLeg, -1)
            or (torso.CFrame * CFrame.new(-0.5, -torso.Size.Y * 1.5, 0)).Position

        local rightFoot = SkeletonPartEnd(rightLeg, -1)
            or (torso.CFrame * CFrame.new(0.5, -torso.Size.Y * 1.5, 0)).Position

        local leftKnee = leftLeg and leftLeg.Position or ((leftHip + leftFoot) * 0.5)
        local rightKnee = rightLeg and rightLeg.Position or ((rightHip + rightFoot) * 0.5)
        local pelvis = (leftHip + rightHip) * 0.5
        local neck = SkeletonAttachmentPosition(torso, "NeckAttachment", "NeckRigAttachment")
            or (torso.CFrame * CFrame.new(0, torso.Size.Y * 0.5, 0)).Position
        local headPoint = head and head.Position or (neck + (torso.CFrame.UpVector * 0.65))

        return {
            Head = headPoint,
            Neck = neck,
            LeftShoulder = leftShoulder,
            RightShoulder = rightShoulder,
            LeftElbow = leftElbow,
            RightElbow = rightElbow,
            LeftHand = leftHand,
            RightHand = rightHand,
            Chest = (neck + pelvis) * 0.5,
            Pelvis = pelvis,
            LeftHip = leftHip,
            RightHip = rightHip,
            LeftKnee = leftKnee,
            RightKnee = rightKnee,
            LeftFoot = leftFoot,
            RightFoot = rightFoot,
        }
    end

    local head = SkeletonFindPart(character, "Head")
    local upperTorso = SkeletonFindPart(character, "UpperTorso", "Torso")
    local lowerTorso = SkeletonFindPart(character, "LowerTorso", "Torso", "HumanoidRootPart")

    local leftUpperArm = SkeletonFindPart(character, "LeftUpperArm", "Left Arm", "LeftArm")
    local rightUpperArm = SkeletonFindPart(character, "RightUpperArm", "Right Arm", "RightArm")
    local leftLowerArm = SkeletonFindPart(character, "LeftLowerArm", "LeftUpperArm", "Left Arm", "LeftArm")
    local rightLowerArm = SkeletonFindPart(character, "RightLowerArm", "RightUpperArm", "Right Arm", "RightArm")
    local leftHand = SkeletonFindPart(character, "LeftHand")
    local rightHand = SkeletonFindPart(character, "RightHand")

    local leftUpperLeg = SkeletonFindPart(character, "LeftUpperLeg", "Left Leg", "LeftLeg")
    local rightUpperLeg = SkeletonFindPart(character, "RightUpperLeg", "Right Leg", "RightLeg")
    local leftLowerLeg = SkeletonFindPart(character, "LeftLowerLeg", "LeftUpperLeg", "Left Leg", "LeftLeg")
    local rightLowerLeg = SkeletonFindPart(character, "RightLowerLeg", "RightUpperLeg", "Right Leg", "RightLeg")
    local leftFoot = SkeletonFindPart(character, "LeftFoot")
    local rightFoot = SkeletonFindPart(character, "RightFoot")

    if not upperTorso or not lowerTorso then return nil end

    local leftShoulder =
        SkeletonAttachmentPosition(upperTorso, "LeftShoulderRigAttachment")
        or SkeletonAttachmentPosition(leftUpperArm, "LeftShoulderRigAttachment")
        or (leftUpperArm and SkeletonPartEnd(leftUpperArm, 1))
        or (upperTorso.CFrame * CFrame.new(-upperTorso.Size.X * 0.5, upperTorso.Size.Y * 0.2, 0)).Position

    local rightShoulder =
        SkeletonAttachmentPosition(upperTorso, "RightShoulderRigAttachment")
        or SkeletonAttachmentPosition(rightUpperArm, "RightShoulderRigAttachment")
        or (rightUpperArm and SkeletonPartEnd(rightUpperArm, 1))
        or (upperTorso.CFrame * CFrame.new(upperTorso.Size.X * 0.5, upperTorso.Size.Y * 0.2, 0)).Position

    local leftHip =
        SkeletonAttachmentPosition(lowerTorso, "LeftHipRigAttachment")
        or SkeletonAttachmentPosition(leftUpperLeg, "LeftHipRigAttachment")
        or (leftUpperLeg and SkeletonPartEnd(leftUpperLeg, 1))
        or (lowerTorso.CFrame * CFrame.new(-lowerTorso.Size.X * 0.25, -lowerTorso.Size.Y * 0.35, 0)).Position

    local rightHip =
        SkeletonAttachmentPosition(lowerTorso, "RightHipRigAttachment")
        or SkeletonAttachmentPosition(rightUpperLeg, "RightHipRigAttachment")
        or (rightUpperLeg and SkeletonPartEnd(rightUpperLeg, 1))
        or (lowerTorso.CFrame * CFrame.new(lowerTorso.Size.X * 0.25, -lowerTorso.Size.Y * 0.35, 0)).Position

    local pelvis = (leftHip + rightHip) * 0.5
    local neck = SkeletonAttachmentPosition(upperTorso, "NeckRigAttachment", "NeckAttachment")
        or SkeletonAttachmentPosition(head, "NeckRigAttachment", "NeckAttachment")
        or (upperTorso.CFrame * CFrame.new(0, upperTorso.Size.Y * 0.5, 0)).Position

    local headPoint = head and head.Position or (neck + (upperTorso.CFrame.UpVector * 0.6))
    local leftHandPoint = leftHand and leftHand.Position
        or SkeletonPartEnd(leftLowerArm, -1)
        or SkeletonPartEnd(leftUpperArm, -1)
        or leftShoulder

    local rightHandPoint = rightHand and rightHand.Position
        or SkeletonPartEnd(rightLowerArm, -1)
        or SkeletonPartEnd(rightUpperArm, -1)
        or rightShoulder

    local leftElbow = SkeletonAttachmentPosition(leftUpperArm, "LeftElbowRigAttachment")
        or SkeletonAttachmentPosition(leftLowerArm, "LeftElbowRigAttachment")
        or SkeletonPartEnd(leftUpperArm, -1)
        or (leftShoulder + leftHandPoint) * 0.5

    local rightElbow = SkeletonAttachmentPosition(rightUpperArm, "RightElbowRigAttachment")
        or SkeletonAttachmentPosition(rightLowerArm, "RightElbowRigAttachment")
        or SkeletonPartEnd(rightUpperArm, -1)
        or (rightShoulder + rightHandPoint) * 0.5

    local leftFootPoint = leftFoot and leftFoot.Position
        or SkeletonPartEnd(leftLowerLeg, -1)
        or SkeletonPartEnd(leftUpperLeg, -1)
        or leftHip

    local rightFootPoint = rightFoot and rightFoot.Position
        or SkeletonPartEnd(rightLowerLeg, -1)
        or SkeletonPartEnd(rightUpperLeg, -1)
        or rightHip

    local leftKnee = SkeletonAttachmentPosition(leftUpperLeg, "LeftKneeRigAttachment")
        or SkeletonAttachmentPosition(leftLowerLeg, "LeftKneeRigAttachment")
        or SkeletonPartEnd(leftUpperLeg, -1)
        or (leftHip + leftFootPoint) * 0.5

    local rightKnee = SkeletonAttachmentPosition(rightUpperLeg, "RightKneeRigAttachment")
        or SkeletonAttachmentPosition(rightLowerLeg, "RightKneeRigAttachment")
        or SkeletonPartEnd(rightUpperLeg, -1)
        or (rightHip + rightFootPoint) * 0.5

    return {
        Head = headPoint,
        Neck = neck,
        LeftShoulder = leftShoulder,
        RightShoulder = rightShoulder,
        LeftElbow = leftElbow,
        RightElbow = rightElbow,
        LeftHand = leftHandPoint,
        RightHand = rightHandPoint,
        Chest = upperTorso.Position,
        Pelvis = pelvis,
        LeftHip = leftHip,
        RightHip = rightHip,
        LeftKnee = leftKnee,
        RightKnee = rightKnee,
        LeftFoot = leftFootPoint,
        RightFoot = rightFootPoint,
    }
end

local function Destroy3DSkeleton(espObj)
    if espObj.Skeleton3DSegments then
        for _, segment in ipairs(espObj.Skeleton3DSegments) do
            if segment.Part then
                pcall(function() segment.Part:Destroy() end)
            end
        end
    end

    if espObj.Skeleton3DJoints then
        for _, joint in ipairs(espObj.Skeleton3DJoints) do
            if joint.Part then
                pcall(function() joint.Part:Destroy() end)
            end
        end
    end

    if espObj.Skeleton3DFolder then
        pcall(function() espObj.Skeleton3DFolder:Destroy() end)
    end

    espObj.Skeleton3DSegments = nil
    espObj.Skeleton3DJoints = nil
    espObj.Skeleton3DFolder = nil
    espObj.Skeleton3DRoot = nil
end

local function Ensure3DSkeleton(espObj, root)
    if not root or not root.Parent then
        Destroy3DSkeleton(espObj)
        return nil
    end

    local needsRebuild =
        espObj.Skeleton3DRoot ~= root
        or not espObj.Skeleton3DFolder
        or not espObj.Skeleton3DFolder.Parent
        or not espObj.Skeleton3DSegments
        or #espObj.Skeleton3DSegments ~= #SKELETON_BONE_DEFS
        or not espObj.Skeleton3DJoints
        or #espObj.Skeleton3DJoints ~= #SKELETON_JOINT_KEYS

    if needsRebuild then
        Destroy3DSkeleton(espObj)

        local folder = Instance.new("Folder")
        folder.Name = "SensorySkeleton3D"
        folder.Parent = workspace

        local segments = {}

        for index = 1, #SKELETON_BONE_DEFS do
            local part = Instance.new("Part")
            part.Name = "SensorySkeletonSegment"
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.CastShadow = false
            part.Transparency = 1
            part.Size = Vector3.new(0.05, 0.05, 0.05)
            part.CFrame = CFrame.new(root.Position)
            part.Parent = folder

            local outline = Instance.new("BoxHandleAdornment")
            outline.Name = "SensorySkeletonOutline"
            outline.Adornee = part
            outline.CFrame = CFrame.identity
            outline.AlwaysOnTop = true
            outline.ZIndex = 7
            outline.Transparency = 0
            outline.Visible = false
            outline.Parent = part

            local main = Instance.new("BoxHandleAdornment")
            main.Name = "SensorySkeleton"
            main.Adornee = part
            main.CFrame = CFrame.identity
            main.AlwaysOnTop = true
            main.ZIndex = 8
            main.Transparency = 0
            main.Visible = false
            main.Parent = part

            segments[index] = {
                Part = part,
                Main = main,
                Outline = outline,
            }
        end

        local joints = {}

        for index = 1, #SKELETON_JOINT_KEYS do
            local part = Instance.new("Part")
            part.Name = "SensorySkeletonJoint"
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.CastShadow = false
            part.Transparency = 1
            part.Size = Vector3.new(0.03, 0.03, 0.03)
            part.CFrame = CFrame.new(root.Position)
            part.Parent = folder

            local outline = Instance.new("SphereHandleAdornment")
            outline.Name = "SensorySkeletonJointOutline"
            outline.Adornee = part
            outline.CFrame = CFrame.identity
            outline.AlwaysOnTop = true
            outline.ZIndex = 7
            outline.Transparency = 0
            outline.Radius = 0.03
            outline.Visible = false
            outline.Parent = part

            local main = Instance.new("SphereHandleAdornment")
            main.Name = "SensorySkeletonJoint"
            main.Adornee = part
            main.CFrame = CFrame.identity
            main.AlwaysOnTop = true
            main.ZIndex = 9
            main.Transparency = 0
            main.Radius = 0.02
            main.Visible = false
            main.Parent = part

            joints[index] = {
                Key = SKELETON_JOINT_KEYS[index],
                Part = part,
                Main = main,
                Outline = outline,
            }
        end

        espObj.Skeleton3DFolder = folder
        espObj.Skeleton3DSegments = segments
        espObj.Skeleton3DJoints = joints
        espObj.Skeleton3DRoot = root
    end

    return espObj.Skeleton3DSegments, espObj.Skeleton3DJoints
end

local function GetSkeletonWorldScale(worldPosition, pixelThickness)
    local activeCamera = Camera
    if not activeCamera or not worldPosition then
        return 0.045, 0.02
    end

    local distance = math.max((activeCamera.CFrame.Position - worldPosition).Magnitude, 0.1)
    local viewportHeight = math.max(activeCamera.ViewportSize.Y, 1)
    local worldPerPixel = (2 * distance * math.tan(math.rad(activeCamera.FieldOfView) * 0.5)) / viewportHeight
    local thickness = math.clamp(worldPerPixel * math.clamp(tonumber(pixelThickness) or 1.5, 0.5, 5), 0.018, 0.22)
    return thickness, worldPerPixel
end

local function Set3DSkeletonSegment(
    segment,
    worldA,
    worldB,
    color,
    outlineEnabled,
    outlineColor,
    thickness,
    outlineThickness
)
    if not segment or not segment.Part or not worldA or not worldB then
        return
    end

    local delta = worldB - worldA
    local length = delta.Magnitude

    if length <= 0.001 then
        SetPropertyIfChanged(segment.Main, "Visible", false)
        SetPropertyIfChanged(segment.Outline, "Visible", false)
        return
    end

    local midpoint = (worldA + worldB) * 0.5


    SetPropertyIfChanged(segment.Part, "CFrame", CFrame.lookAt(midpoint, worldB))
    SetPropertyIfChanged(segment.Part, "Size", Vector3.new(0.03, 0.03, math.max(length, 0.03)))

    SetPropertyIfChanged(segment.Main, "Size", Vector3.new(thickness, thickness, length + (thickness * 0.35)))
    SetPropertyIfChanged(segment.Main, "Color3", color)
    SetPropertyIfChanged(segment.Main, "Transparency", 0)
    SetPropertyIfChanged(segment.Main, "AlwaysOnTop", true)
    SetPropertyIfChanged(segment.Main, "Visible", true)

    SetPropertyIfChanged(segment.Outline, "Size", Vector3.new(
        outlineThickness,
        outlineThickness,
        length + (outlineThickness * 0.45)
    ))
    SetPropertyIfChanged(segment.Outline, "Color3", outlineColor)
    SetPropertyIfChanged(segment.Outline, "Transparency", 0)
    SetPropertyIfChanged(segment.Outline, "AlwaysOnTop", true)
    SetPropertyIfChanged(segment.Outline, "Visible", outlineEnabled)
end

local function Set3DSkeletonJoint(
    joint,
    worldPosition,
    color,
    visible,
    outlineEnabled,
    outlineColor,
    thickness,
    outlineThickness,
    jointScale
)
    if not joint or not joint.Part or not worldPosition then
        return
    end

    if not visible then
        SetPropertyIfChanged(joint.Main, "Visible", false)
        SetPropertyIfChanged(joint.Outline, "Visible", false)
        return
    end

    local scale = math.clamp(tonumber(jointScale) or 1, 0.5, 2)
    SetPropertyIfChanged(joint.Part, "CFrame", CFrame.new(worldPosition))
    SetPropertyIfChanged(joint.Main, "Radius", thickness * 0.72 * scale)
    SetPropertyIfChanged(joint.Main, "Color3", color)
    SetPropertyIfChanged(joint.Main, "Transparency", 0)
    SetPropertyIfChanged(joint.Main, "AlwaysOnTop", true)
    SetPropertyIfChanged(joint.Main, "Visible", true)

    SetPropertyIfChanged(joint.Outline, "Radius", outlineThickness * 0.72 * scale)
    SetPropertyIfChanged(joint.Outline, "Color3", outlineColor)
    SetPropertyIfChanged(joint.Outline, "Transparency", 0)
    SetPropertyIfChanged(joint.Outline, "AlwaysOnTop", true)
    SetPropertyIfChanged(joint.Outline, "Visible", outlineEnabled)
end

local FontLoadingCapable = writefile and isfile and getcustomasset

local function RegisterCachedFont(Name, fileStem, rewriteConfig)
    local ttfPath = fileStem .. ".ttf"
    local jsonPath = fileStem .. ".ttf.json"
    local okTTF, hasTTF = pcall(isfile, ttfPath)
    if not okTTF or not hasTTF then return false end

    local okJSON, hasJSON = pcall(isfile, jsonPath)
    if rewriteConfig or not okJSON or not hasJSON then
        local okConfig = pcall(function()
            local config = {
                name = fileStem,
                faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(ttfPath) } }
            }
            writefile(jsonPath, HttpService:JSONEncode(config))
        end)
        if not okConfig then return false end
    end

    local okLoad, font = pcall(Font.new, getcustomasset(jsonPath), Enum.FontWeight.Regular)
    if okLoad and font then
        ESPFonts.Loaded[Name] = font
        return true
    end
    return false
end

local function LoadCustomFont(Name, Link)
    if not FontLoadingCapable then return false end
    local fileStem = Name:gsub("%s+", "")

    if RegisterCachedFont(Name, fileStem, false) or RegisterCachedFont(Name, fileStem, true) then
        return true
    end

    local okDL, data = pcall(function() return game:HttpGet(Link) end)
    if not okDL or not data or data == "" then return false end
    if not pcall(writefile, fileStem .. ".ttf", data) then return false end
    return RegisterCachedFont(Name, fileStem, true)
end

local function AttemptLoadFonts()
    if not FontLoadingCapable then
        FontsStillLoading = false
        return
    end

    for Name, fontInfo in pairs(FontsToDownload) do
        if not ESPFonts.Loaded[Name] then
            task.spawn(LoadCustomFont, Name, fontInfo.TTF)
        end
    end

    FontsStillLoading = false
end

task.spawn(function()
    task.wait(1)
    if FontsStillLoading then
        AttemptLoadFonts()
    end
end)
local TrackedInstances = {}

local function NewTrackedRuntime(instance, data)
    local runtime = {
        Instance = instance,
        Player = data and data.Player or nil,
        Humanoid = nil,
        RootPart = nil,
        Tool = nil,
        Holding = nil,
        Connections = {},
    }

    local function addConnection(connection)
        runtime.Connections[#runtime.Connections + 1] = connection
        return connection
    end

    local function acceptChild(child)
        if not child then return end
        if child:IsA("Humanoid") then
            runtime.Humanoid = child
        elseif child:IsA("Tool") then
            runtime.Tool = child
        elseif child:IsA("BasePart") then
            if child.Name == "HumanoidRootPart" then
                runtime.RootPart = child
            elseif not runtime.RootPart and (child.Name == "Torso" or child.Name == "UpperTorso") then
                runtime.RootPart = child
            end
        elseif child.Name == "Holding" then
            runtime.Holding = child
        end
    end

    local function resolveModelRefs()
        if not instance.Parent or not instance:IsA("Model") then return end
        runtime.RootPart = instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart")
            or instance:FindFirstChild("Torso")
            or instance:FindFirstChild("UpperTorso")
            or instance:FindFirstChildWhichIsA("BasePart")
        runtime.Humanoid = instance:FindFirstChildOfClass("Humanoid")
        runtime.Tool = instance:FindFirstChildWhichIsA("Tool")
        runtime.Holding = instance:FindFirstChild("Holding")
    end

    if instance:IsA("Model") then
        if not runtime.Player then
            runtime.Player = Players:GetPlayerFromCharacter(instance)
        end

        for _, child in ipairs(instance:GetChildren()) do
            acceptChild(child)
        end
        resolveModelRefs()

        addConnection(instance.ChildAdded:Connect(function(child)
            acceptChild(child)
            if child:IsA("BasePart") and data and data.espObj then
                data.espObj.BoundingPartsDirty = true
            end
        end))

        addConnection(instance.ChildRemoved:Connect(function(child)
            local needsResolve = false
            if child == runtime.Humanoid then runtime.Humanoid = nil; needsResolve = true end
            if child == runtime.RootPart then runtime.RootPart = nil; needsResolve = true end
            if child == runtime.Tool then runtime.Tool = nil; needsResolve = true end
            if child == runtime.Holding then runtime.Holding = nil; needsResolve = true end
            if child:IsA("BasePart") and data and data.espObj then
                data.espObj.BoundingPartsDirty = true
            end
            if needsResolve then
                task.defer(resolveModelRefs)
            end
        end))

        addConnection(instance:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
            runtime.RootPart = instance.PrimaryPart or runtime.RootPart
        end))
    elseif instance:IsA("BasePart") then
        runtime.RootPart = instance
    end


    return runtime
end

local function DestroyTrackedRuntime(data)
    local runtime = data and data.Runtime
    if not runtime then return end
    for i = #runtime.Connections, 1, -1 do
        local connection = runtime.Connections[i]
        runtime.Connections[i] = nil
        pcall(function() connection:Disconnect() end)
    end
    data.Runtime = nil
end

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

local function DestroyAdornmentRecordLayer(record, layerName)
    if not record then
        return
    end

    local adornment = record[layerName]
    if adornment then
        adornment:Destroy()
        record[layerName] = nil
    end

    record[layerName .. "Color"] = nil
    record[layerName .. "Transparency"] = nil
    record[layerName .. "PartSize"] = nil
    record[layerName .. "SizeIncrease"] = nil
    record[layerName .. "HeadScale"] = nil
    record[layerName .. "Visible"] = nil
    record[layerName .. "Intensity"] = nil
    record[layerName .. "XRay"] = nil
end

local function DestroyAdornmentRecord(record)
    if typeof(record) == "Instance" then
        record:Destroy()
        return
    end

    if not record then
        return
    end

    DestroyAdornmentRecordLayer(record, "Invisible")
    DestroyAdornmentRecordLayer(record, "Visible")
    DestroyAdornmentRecordLayer(record, "Glow")
end

local function DestroyAdornmentRecords(espObj)
    for part, record in pairs(espObj.Adornments or {}) do
        DestroyAdornmentRecord(record)
        espObj.Adornments[part] = nil
    end
end

local function SetAdornmentRecordsVisible(espObj, state)
    for _, record in pairs(espObj.Adornments or {}) do
        if typeof(record) == "Instance" then
            record.Visible = state
        else
            if record.Invisible and record.InvisibleVisible ~= state then
                record.Invisible.Visible = state
                record.InvisibleVisible = state
            end
            if record.Visible and record.VisibleVisible ~= state then
                record.Visible.Visible = state
                record.VisibleVisible = state
            end
            if record.Glow and record.GlowVisible ~= state then
                record.Glow.Visible = state
                record.GlowVisible = state
            end
        end
    end
end

local function DestroyAdornmentProxyPart(record)
    if record and record.Proxy then
        record.Proxy:Destroy()
    end
end

local function DestroyAdornmentProxyLayer(espObj, key)
    local layer = espObj.AdornmentProxyLayers and espObj.AdornmentProxyLayers[key]
    if not layer then
        return
    end

    if layer.Model then
        layer.Model:Destroy()
    end
    espObj.AdornmentProxyLayers[key] = nil
end

local function DestroyAdornmentProxyLayers(espObj)
    for key in pairs(espObj.AdornmentProxyLayers or {}) do
        DestroyAdornmentProxyLayer(espObj, key)
    end
end

local function CreateHighlightRasterizer(parent)
    local rasterizer = Instance.new("Humanoid")
    rasterizer.Name = "ChamProxyRasterizer"
    rasterizer.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    rasterizer.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    rasterizer.NameDisplayDistance = 0
    rasterizer.HealthDisplayDistance = 0
    rasterizer.BreakJointsOnDeath = false
    rasterizer.RequiresNeck = false
    rasterizer.AutoRotate = false
    rasterizer.PlatformStand = true
    pcall(function()
        rasterizer.EvaluateStateMachine = false
    end)
    rasterizer.Parent = parent
    return rasterizer
end

local function EnsureAdornmentProxyLayer(espObj, key)
    local layer = espObj.AdornmentProxyLayers[key]
    if layer and (not layer.Model or not layer.Model.Parent) then
        DestroyAdornmentProxyLayer(espObj, key)
        layer = nil
    end

    if layer then
        return layer
    end

    local model = Instance.new("Model")
    model.Name = "Cham" .. key .. "Proxy"
    model:SetAttribute("SensoryESP_MeshCham", true)
    model:SetAttribute("SensoryESP_RunId", CurrentRunId)

    local rasterizer = CreateHighlightRasterizer(model)

    local highlight = Instance.new("Highlight")
    highlight.Name = "ChamProxyHighlight"
    highlight:SetAttribute("SensoryESP_MeshCham", true)
    highlight:SetAttribute("SensoryESP_RunId", CurrentRunId)
    highlight.Adornee = model
    highlight.Parent = model
    model.Parent = MeshChamsFolder

    layer = {
        Model = model,
        Highlight = highlight,
        Rasterizer = rasterizer,
        Parts = {},
    }
    espObj.AdornmentProxyLayers[key] = layer
    return layer
end

local function GetCylinderDimensions(partSize, sizeIncrease, headScale)
    headScale = math.clamp(tonumber(headScale) or 1, 0.5, 1.25)
    local radius = math.max(partSize.X, partSize.Z) * 0.5 * headScale + sizeIncrease * 0.5
    local height = partSize.Y + sizeIncrease
    return radius, height
end

local function ApplyAdornmentProxyPart(layer, part, partInfo, sizeIncrease)
    local record = layer.Parts[part]
    local isCylinder = partInfo.IsCylinder

    if record and (record.IsCylinder ~= isCylinder or not record.Proxy or not record.Proxy.Parent) then
        DestroyAdornmentProxyPart(record)
        record = nil
    end

    if not record then
        local proxy = Instance.new("Part")
        proxy.Name = "ChamProxy_" .. part.Name
        proxy:SetAttribute("SensoryESP_MeshCham", true)
        proxy:SetAttribute("SensoryESP_RunId", CurrentRunId)
        proxy.Shape = isCylinder and Enum.PartType.Cylinder or Enum.PartType.Block
        proxy.Transparency = 0.99
        proxy.CastShadow = false
        proxy.CanCollide = false
        proxy.CanQuery = false
        proxy.CanTouch = false
        proxy.Anchored = false
        proxy.Massless = true
        proxy.RootPriority = -127
        proxy.CFrame = isCylinder
            and (part.CFrame * CFrame.Angles(0, 0, math.pi / 2))
            or part.CFrame
        proxy.Parent = layer.Model

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = proxy
        weld.Part1 = part
        weld.Parent = proxy

        record = {
            Proxy = proxy,
            IsCylinder = isCylinder,
        }
        layer.Parts[part] = record
    end

    local targetSize
    if isCylinder then
        local radius, height = GetCylinderDimensions(partInfo.PartSize, sizeIncrease, partInfo.HeadScale)
        targetSize = Vector3.new(height, radius * 2, radius * 2)
    else
        targetSize = partInfo.PartSize + Vector3.new(sizeIncrease, sizeIncrease, sizeIncrease)
    end

    if record.Size ~= targetSize then
        record.Proxy.Size = targetSize
        record.Size = targetSize
    end
end

local function CreateBodyAdornment(part, isCylinder, name, alwaysOnTop, zIndex)
    local adornment = Instance.new(isCylinder and "CylinderHandleAdornment" or "BoxHandleAdornment")
    adornment.Name = name
    adornment.Adornee = part
    adornment.CFrame = isCylinder and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.identity
    adornment.AlwaysOnTop = alwaysOnTop
    adornment.ZIndex = zIndex
    adornment.Parent = ChamsContainer
    return adornment
end

local AdornmentXRayShading
pcall(function()
    AdornmentXRayShading = Enum.AdornShading.XRayShaded
end)

local function CreateAdornmentGlow(part, isCylinder)
    local glow = CreateBodyAdornment(part, isCylinder, "ChamGlow", true, 7)
    local xrayEnabled = false
    if AdornmentXRayShading then
        xrayEnabled = pcall(function()
            glow.Shading = AdornmentXRayShading
            glow.Transparency = -1
        end)
    end
    return glow, xrayEnabled
end

local function ApplyAdornmentGlowLayer(record, partSize, sizeIncrease, color, intensity, fallbackTransparency, headScale)
    local glow = record.Glow
    if not glow then
        return
    end

    intensity = math.clamp(tonumber(intensity) or 5, 1, 10)
    fallbackTransparency = math.clamp(tonumber(fallbackTransparency) or 0.72, 0, 1)
    local xrayEnabled = record.GlowXRay == true
    local glowColor = xrayEnabled
        and Color3.new(color.R * intensity, color.G * intensity, color.B * intensity)
        or color

    if record.GlowColor ~= glowColor then
        glow.Color3 = glowColor
        record.GlowColor = glowColor
    end
    if record.GlowIntensity ~= intensity then
        record.GlowIntensity = intensity
    end

    local targetTransparency = xrayEnabled and -1 or fallbackTransparency
    if record.GlowTransparency ~= targetTransparency then
        local applied = pcall(function()
            glow.Transparency = targetTransparency
        end)
        if not applied and xrayEnabled then
            record.GlowXRay = false
            glow.Color3 = color
            record.GlowColor = color
            targetTransparency = fallbackTransparency
            glow.Transparency = targetTransparency
        end
        record.GlowTransparency = targetTransparency
    end

    sizeIncrease = math.max(tonumber(sizeIncrease) or 0.03, 0)
    if record.GlowPartSize ~= partSize
        or record.GlowSizeIncrease ~= sizeIncrease
        or record.GlowHeadScale ~= headScale then
        if record.IsCylinder then
            local radius, height = GetCylinderDimensions(partSize, sizeIncrease, headScale)
            glow.Radius = radius
            glow.Height = height
        else
            glow.Size = partSize + Vector3.new(sizeIncrease, sizeIncrease, sizeIncrease)
        end

        record.GlowPartSize = partSize
        record.GlowSizeIncrease = sizeIncrease
        record.GlowHeadScale = headScale
    end

    if record.GlowVisible ~= true then
        glow.Visible = true
        record.GlowVisible = true
    end
end

local function ApplyAdornmentLayer(record, layerName, partSize, sizeIncrease, color, transparency, headScale)
    local adornment = record[layerName]
    if not adornment then
        return
    end

    if record[layerName .. "Color"] ~= color then
        adornment.Color3 = color
        record[layerName .. "Color"] = color
    end

    transparency = math.clamp(tonumber(transparency) or 0, 0, 1)
    if record[layerName .. "Transparency"] ~= transparency then
        adornment.Transparency = transparency
        record[layerName .. "Transparency"] = transparency
    end

    sizeIncrease = math.max(tonumber(sizeIncrease) or 0, 0)
    if record[layerName .. "PartSize"] ~= partSize
        or record[layerName .. "SizeIncrease"] ~= sizeIncrease
        or record[layerName .. "HeadScale"] ~= headScale then
        if record.IsCylinder then
            local radius, height = GetCylinderDimensions(partSize, sizeIncrease, headScale)
            adornment.Radius = radius
            adornment.Height = height
        else
            adornment.Size = partSize + Vector3.new(sizeIncrease, sizeIncrease, sizeIncrease)
        end

        record[layerName .. "PartSize"] = partSize
        record[layerName .. "SizeIncrease"] = sizeIncrease
        record[layerName .. "HeadScale"] = headScale
    end

    if record[layerName .. "Visible"] ~= true then
        adornment.Visible = true
        record[layerName .. "Visible"] = true
    end
end

local AdornmentHighlightLayers = {
    {
        Key = "Invisible",
        EnabledPath = "Chams.Adornment.Invisible.Highlight.Enabled",
        FillColorPath = "Chams.Adornment.Invisible.Highlight.FillColor",
        FillTransparencyPath = "Chams.Adornment.Invisible.Highlight.FillTransparency",
        OutlineColorPath = "Chams.Adornment.Invisible.Highlight.OutlineColor",
        OutlineTransparencyPath = "Chams.Adornment.Invisible.Highlight.OutlineTransparency",
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    },
    {
        Key = "Visible",
        EnabledPath = "Chams.Adornment.Visible.Highlight.Enabled",
        FillColorPath = "Chams.Adornment.Visible.Highlight.FillColor",
        FillTransparencyPath = "Chams.Adornment.Visible.Highlight.FillTransparency",
        OutlineColorPath = "Chams.Adornment.Visible.Highlight.OutlineColor",
        OutlineTransparencyPath = "Chams.Adornment.Visible.Highlight.OutlineTransparency",
        DepthMode = Enum.HighlightDepthMode.Occluded,
    },
}

local CharacterCloneMaterials = {
    SmoothPlastic = Enum.Material.SmoothPlastic,
    ForceField = Enum.Material.ForceField,
    Neon = Enum.Material.Neon,
    Glass = Enum.Material.Glass,
}

local function DestroyCharacterClonePart(record)
    if record and record.Proxy then
        record.Proxy:Destroy()
    end
end

local function DestroyCharacterCloneParts(layer)
    for source, record in pairs(layer and layer.Parts or {}) do
        DestroyCharacterClonePart(record)
        layer.Parts[source] = nil
    end
end

local function DestroyCharacterClone(espObj)
    local layer = espObj.CharacterClone
    if not layer then
        return
    end

    if layer.AddedConnection then
        layer.AddedConnection:Disconnect()
    end
    if layer.RemovingConnection then
        layer.RemovingConnection:Disconnect()
    end
    if layer.Model then
        layer.Model:Destroy()
    end
    espObj.CharacterClone = nil
end

local function IsCharacterCloneSource(character, source, includeAccessories)
    if not source:IsA("BasePart")
        or source.Name == "HumanoidRootPart"
        or IsIgnoredColliderPart(source)
        or source:GetAttribute("SensoryESP_MeshCham") == true then
        return false
    end

    if source.Parent == character then
        return true
    end

    if not includeAccessories then
        return false
    end

    local ancestor = source.Parent
    while ancestor and ancestor ~= character do
        if ancestor:IsA("Accessory") then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function CloneCharacterVisualPart(source, layer, style)
    local proxy
    local wasArchivable = source.Archivable
    if not wasArchivable then
        pcall(function() source.Archivable = true end)
    end
    pcall(function()
        proxy = source:Clone()
    end)
    if not wasArchivable then
        pcall(function() source.Archivable = false end)
    end

    if not proxy then
        proxy = Instance.new(source:IsA("MeshPart") and "MeshPart" or "Part")
        if source:IsA("Part") then
            proxy.Shape = source.Shape
        elseif source:IsA("MeshPart") then
            pcall(function() proxy.MeshId = source.MeshId end)
            pcall(function() proxy.TextureID = source.TextureID end)
        end
    end

    for _, child in ipairs(proxy:GetChildren()) do
        local keepChild = child:IsA("DataModelMesh")
            or (style.KeepTextures and (child:IsA("Decal")
                or child:IsA("Texture")
                or child:IsA("SurfaceAppearance")))

        if keepChild then
            if child:IsA("SpecialMesh") and not style.KeepTextures then
                child.TextureId = ""
            end
        else
            child:Destroy()
        end
    end

    if proxy:IsA("MeshPart") and not style.KeepTextures then
        pcall(function() proxy.TextureID = "" end)
    end

    proxy.Name = "ChamClone_" .. source.Name
    proxy:SetAttribute("SensoryESP_MeshCham", true)
    proxy:SetAttribute("SensoryESP_RunId", CurrentRunId)
    proxy.CastShadow = false
    proxy.CanCollide = false
    proxy.CanQuery = false
    proxy.CanTouch = false
    proxy.Anchored = false
    proxy.Massless = true
    proxy.RootPriority = -127
    proxy.LocalTransparencyModifier = 0
    proxy.CFrame = source.CFrame
    proxy.Parent = layer.Model

    local weld = Instance.new("WeldConstraint")
    weld.Name = "ChamCloneWeld"
    weld.Part0 = proxy
    weld.Part1 = source
    weld.Parent = proxy

    local record = {
        Proxy = proxy,
        Weld = weld,
    }
    layer.Parts[source] = record
    return record
end

local function ApplyCharacterClonePartStyle(source, record, style)
    local proxy = record.Proxy
    if not proxy or not proxy.Parent then
        return false
    end

    local targetSize = source.Size * style.SizeScale
    if record.Size ~= targetSize then
        proxy.Size = targetSize
        record.Size = targetSize
    end
    if record.Color ~= style.Color then
        proxy.Color = style.Color
        record.Color = style.Color
    end
    if record.Material ~= style.Material then
        proxy.Material = style.Material
        record.Material = style.Material
    end

    local targetTransparency = style.Transparency
    if style.HighlightEnabled then
        targetTransparency = math.min(targetTransparency, 0.99)
    end
    if record.Transparency ~= targetTransparency then
        proxy.Transparency = targetTransparency
        record.Transparency = targetTransparency
    end
    return true
end

local function SyncCharacterCloneParts(layer, character, style)
    local topologyChanged = layer.KeepTextures ~= style.KeepTextures
        or layer.IncludeAccessories ~= style.IncludeAccessories
    if layer.RebuildAll or topologyChanged then
        DestroyCharacterCloneParts(layer)
    else
        for source in pairs(layer.PendingSources) do
            local record = layer.Parts[source]
            if record then
                DestroyCharacterClonePart(record)
                layer.Parts[source] = nil
            end
        end
    end

    layer.KeepTextures = style.KeepTextures
    layer.IncludeAccessories = style.IncludeAccessories
    layer.RebuildAll = false
    for source in pairs(layer.PendingSources) do
        layer.PendingSources[source] = nil
    end

    layer.ScanRevision = (layer.ScanRevision or 0) + 1
    local scanRevision = layer.ScanRevision
    for _, source in ipairs(character:GetDescendants()) do
        if IsCharacterCloneSource(character, source, style.IncludeAccessories) then
            local record = layer.Parts[source]
            if not record or not record.Proxy or not record.Proxy.Parent then
                if record then
                    DestroyCharacterClonePart(record)
                end
                record = CloneCharacterVisualPart(source, layer, style)
            end
            record.ScanRevision = scanRevision
        end
    end

    for source, record in pairs(layer.Parts) do
        if record.ScanRevision ~= scanRevision or not source.Parent then
            DestroyCharacterClonePart(record)
            layer.Parts[source] = nil
        end
    end
    layer.Dirty = false
end

local function FindCharacterCloneSource(character, descendant)
    local current = descendant
    while current and current ~= character do
        if current:IsA("BasePart") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function EnsureCharacterClone(espObj, character)
    local layer = espObj.CharacterClone
    if layer and (layer.Source ~= character or not layer.Model or not layer.Model.Parent) then
        DestroyCharacterClone(espObj)
        layer = nil
    end

    if layer then
        return layer
    end

    local model = Instance.new("Model")
    model.Name = "ChamCharacterClone"
    model:SetAttribute("SensoryESP_MeshCham", true)
    model:SetAttribute("SensoryESP_RunId", CurrentRunId)
    model.Parent = MeshChamsFolder

    layer = {
        Source = character,
        Model = model,
        Parts = {},
        PendingSources = {},
        Dirty = true,
        RebuildAll = true,
    }
    layer.AddedConnection = character.DescendantAdded:Connect(function(descendant)
        local source = FindCharacterCloneSource(character, descendant)
        if source then
            layer.PendingSources[source] = true
        end
        layer.Dirty = true
    end)
    layer.RemovingConnection = character.DescendantRemoving:Connect(function(descendant)
        local source = FindCharacterCloneSource(character, descendant)
        if source then
            layer.PendingSources[source] = true
        end
        layer.Dirty = true
    end)
    espObj.CharacterClone = layer
    return layer
end

local function ApplyCharacterCloneHighlight(layer, style)
    if not style.HighlightEnabled then
        if layer.Highlight then
            layer.Highlight:Destroy()
            layer.Highlight = nil
        end
        if layer.Rasterizer then
            layer.Rasterizer:Destroy()
            layer.Rasterizer = nil
        end
        return
    end

    if not layer.Rasterizer or not layer.Rasterizer.Parent then
        layer.Rasterizer = CreateHighlightRasterizer(layer.Model)
    end
    if not layer.Highlight or not layer.Highlight.Parent then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ChamCharacterHighlight"
        highlight:SetAttribute("SensoryESP_MeshCham", true)
        highlight:SetAttribute("SensoryESP_RunId", CurrentRunId)
        highlight.Adornee = layer.Model
        highlight.Parent = layer.Model
        layer.Highlight = highlight
    end

    local highlight = layer.Highlight
    SetPropertyIfChanged(highlight, "FillColor", style.HighlightFillColor)
    SetPropertyIfChanged(highlight, "FillTransparency", style.HighlightFillTransparency)
    SetPropertyIfChanged(highlight, "OutlineColor", style.HighlightOutlineColor)
    SetPropertyIfChanged(highlight, "OutlineTransparency", style.HighlightOutlineTransparency)
    SetPropertyIfChanged(highlight, "DepthMode", style.HighlightVisibleCheck
        and Enum.HighlightDepthMode.Occluded
        or Enum.HighlightDepthMode.AlwaysOnTop)
    SetPropertyIfChanged(highlight, "Enabled", true)
end

local function UpdateCharacterClone(espObj, character, style, forceRebuild)
    local layer = EnsureCharacterClone(espObj, character)
    local topologyChanged = layer.KeepTextures ~= style.KeepTextures
        or layer.IncludeAccessories ~= style.IncludeAccessories
    if forceRebuild or layer.Dirty or topologyChanged then
        SyncCharacterCloneParts(layer, character, style)
    end

    for source, record in pairs(layer.Parts) do
        if not source.Parent or not ApplyCharacterClonePartStyle(source, record, style) then
            DestroyCharacterClonePart(record)
            layer.Parts[source] = nil
            layer.Dirty = true
        end
    end
    ApplyCharacterCloneHighlight(layer, style)
end

local HideDrawings, DestroyDrawings

local ESPObjectSequence = 0
local CreateESPObj = (function(name)
    ESPObjectSequence += 1
    local espObj = {
        RefreshPhase = (ESPObjectSequence % 16) / 16,
        Visible = false,
        Lines = {},
        Outlines = {},
        CornerLines = {},
        CornerOutlines = {},
        StyleCache = {},
        FrameConfigCache = {},
        ConfigRevisionRef = -1,
        BoundingParts = {},
        BoundingPartsDirty = true,
        BoundingSource = nil,
        BoundingAddedConnection = nil,
        BoundingRemovedConnection = nil,
        CharacterCloneStyle = {},
        ActiveAdornmentParts = {},
        AdornmentPartInfo = {},
        FlagLabels = {},
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

    for i = 1, 5 do
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


    espObj.Skeleton3DSegments = nil
    espObj.Skeleton3DJoints = nil
    espObj.Skeleton3DFolder = nil
    espObj.Skeleton3DRoot = nil

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
    espObj.AdornmentProxyLayers = {}
    espObj.CharacterClone = nil
    espObj.Highlight = nil

    espObj.Destroy = function()
        Destroy3DSkeleton(espObj)
        DestroyDrawings(espObj)
        if espObj.BoundingAddedConnection then
            espObj.BoundingAddedConnection:Disconnect()
            espObj.BoundingAddedConnection = nil
        end
        if espObj.BoundingRemovedConnection then
            espObj.BoundingRemovedConnection:Disconnect()
            espObj.BoundingRemovedConnection = nil
        end
        container:Destroy()
        if espObj.Highlight then espObj.Highlight:Destroy() end
        if espObj.MeshShell then espObj.MeshShell:Destroy() end
        DestroyAdornmentRecords(espObj)
        DestroyAdornmentProxyLayers(espObj)
        DestroyCharacterClone(espObj)
        if espObj.ArrowInner then espObj.ArrowInner:Destroy() end
        if espObj.ArrowOutline then espObj.ArrowOutline:Destroy() end
        if espObj.ArrowName then espObj.ArrowName:Destroy() end
        if espObj.ArrowDist then espObj.ArrowDist:Destroy() end
    end

    return espObj
end)

local function IsESPPlayerExploiting(player)
    if not player then return false end
    local flags = Library.ExploitFlags
    return flags ~= nil and flags[player.UserId] == true
end

local FriendStatusCache = {}
local function IsCachedFriend(player)
    if not player then return false end

    local userId = player.UserId
    local cached = FriendStatusCache[userId]
    if cached ~= nil then
        return cached
    end

    local ok, result = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, userId)
    cached = ok and result == true
    FriendStatusCache[userId] = cached
    return cached
end

local function GetSkeletonGradientColor(enabled, color1, color2, fallback, topY, verticalRange, worldY)
    if not enabled then
        return fallback
    end
    local alpha = math.clamp((topY - worldY) / verticalRange, 0, 1)
    return color1:Lerp(color2, alpha)
end

local function Update3DSkeleton(espObj, instance, GetCfg, runtime)
    if not GetCfg("Skeleton.Enabled") or not instance:IsA("Model") then
        Destroy3DSkeleton(espObj)
        return
    end

    local humanoid = runtime and runtime.Humanoid or instance:FindFirstChildOfClass("Humanoid")
    local root = runtime and runtime.RootPart or instance:FindFirstChild("HumanoidRootPart")
        or instance:FindFirstChild("Torso")
        or instance.PrimaryPart
        or instance:FindFirstChildWhichIsA("BasePart")
    local points = humanoid and root and Get3DSkeletonPoints(instance)

    if not points or not root then
        Destroy3DSkeleton(espObj)
        return
    end

    local segments, joints = Ensure3DSkeleton(espObj, root)
    if not segments then return end

    local skeletonOutline = GetCfg("Skeleton.Outline")
    local skeletonColor = GetCfg("Skeleton.Color")
    local skeletonOutlineColor = GetCfg("Skeleton.OutlineColor")
    local skeletonThickness = GetCfg("Skeleton.Thickness") or 1.5
    local skeletonJoints = GetCfg("Skeleton.Joints") ~= false
    local skeletonJointScale = GetCfg("Skeleton.JointScale") or 1
    local skeletonGradient = GetCfg("Skeleton.Gradient.Enabled")
    local skeletonGradient1 = GetCfg("Skeleton.Gradient.Color1")
    local skeletonGradient2 = GetCfg("Skeleton.Gradient.Color2")
    local topY = -math.huge
    local bottomY = math.huge

    for _, worldPoint in pairs(points) do
        if typeof(worldPoint) == "Vector3" then
            topY = math.max(topY, worldPoint.Y)
            bottomY = math.min(bottomY, worldPoint.Y)
        end
    end

    local verticalRange = math.max(topY - bottomY, 0.001)
    local thickness, worldPerPixel = GetSkeletonWorldScale(root.Position, skeletonThickness)
    local outlineThickness = thickness + (worldPerPixel * 1.5)

    for index, def in ipairs(SKELETON_BONE_DEFS) do
        local worldA = points[def[1]]
        local worldB = points[def[2]]
        local segment = segments[index]

        if worldA and worldB and segment then
            Set3DSkeletonSegment(
                segment,
                worldA,
                worldB,
                GetSkeletonGradientColor(skeletonGradient, skeletonGradient1, skeletonGradient2, skeletonColor,
                    topY, verticalRange, (worldA.Y + worldB.Y) * 0.5),
                skeletonOutline,
                skeletonOutlineColor,
                thickness,
                outlineThickness
            )
        elseif segment then
            SetPropertyIfChanged(segment.Main, "Visible", false)
            SetPropertyIfChanged(segment.Outline, "Visible", false)
        end
    end

    for _, joint in ipairs(joints or {}) do
        local worldPoint = points[joint.Key]
        if worldPoint then
            Set3DSkeletonJoint(
                joint,
                worldPoint,
                GetSkeletonGradientColor(skeletonGradient, skeletonGradient1, skeletonGradient2, skeletonColor,
                    topY, verticalRange, worldPoint.Y),
                skeletonJoints,
                skeletonOutline,
                skeletonOutlineColor,
                thickness,
                outlineThickness,
                skeletonJointScale
            )
        else
            SetPropertyIfChanged(joint.Main, "Visible", false)
            SetPropertyIfChanged(joint.Outline, "Visible", false)
        end
    end
end

local EnsureBoundingPartCache

local function ShouldRunStaggeredRefresh(espObj, field, now, interval, reschedule)
    local nextAt = espObj[field]
    if reschedule or not nextAt then
        nextAt = now + interval * (espObj.RefreshPhase or 0)
        espObj[field] = nextAt
    end
    if now < nextAt then
        return false
    end
    espObj[field] = now + interval
    return true
end

local DrawingAvailable = type(Drawing) == "table" or typeof(Drawing) == "table"
local DrawDefaultFont = 2
if DrawingAvailable then
    local fonts = Drawing.Fonts
    if type(fonts) == "table" then
        DrawDefaultFont = fonts.Plex or fonts.Monospace or fonts.UI or fonts.System or 2
    end
end

local function SafeSetDraw(obj, prop, value)
    pcall(function() obj[prop] = value end)
end

local function NewDrawSquare(filled, thickness, zindex)
    local obj = Drawing.new("Square")
    obj.Visible = false
    obj.Filled = filled and true or false
    obj.Thickness = thickness or 1
    obj.Transparency = 1
    SafeSetDraw(obj, "ZIndex", zindex or 1)
    return obj
end

local function NewDrawLine(thickness, zindex)
    local obj = Drawing.new("Line")
    obj.Visible = false
    obj.Thickness = thickness or 1
    obj.Transparency = 1
    SafeSetDraw(obj, "ZIndex", zindex or 1)
    return obj
end

local function NewDrawText(size, centered, zindex)
    local obj = Drawing.new("Text")
    obj.Visible = false
    obj.Transparency = 1
    obj.Size = size or 12
    SafeSetDraw(obj, "Font", DrawDefaultFont)
    SafeSetDraw(obj, "Center", centered and true or false)
    SafeSetDraw(obj, "Centered", centered and true or false)
    SafeSetDraw(obj, "Outline", true)
    SafeSetDraw(obj, "Outlined", true)
    SafeSetDraw(obj, "OutlineColor", Color3.fromRGB(0, 0, 0))
    SafeSetDraw(obj, "ZIndex", zindex or 5)
    return obj
end

local function EnsureDrawings(espObj)
    if espObj.Draw then return espObj.Draw end
    if not DrawingAvailable then return nil end

    local d = {
        BoxOutline = NewDrawSquare(false, 3, 1),
        Box        = NewDrawSquare(false, 1, 2),
        Fill       = NewDrawSquare(true, 1, 0),
        Corners    = {},
        CornerOutlines = {},
        Name       = NewDrawText(12, true, 6),
        Dist       = NewDrawText(12, true, 6),
        Weapon     = NewDrawText(12, true, 6),
        HpBg       = NewDrawSquare(true, 1, 3),
        HpBar      = NewDrawSquare(true, 1, 4),
        HpText     = NewDrawText(9, true, 6),
        Flags      = {},
    }
    for i = 1, 8 do
        d.CornerOutlines[i] = NewDrawLine(3, 1)
        d.Corners[i] = NewDrawLine(1, 2)
    end
    for i = 1, 5 do
        d.Flags[i] = NewDrawText(9, true, 6)
    end

    espObj.Draw = d
    return d
end

function HideDrawings(espObj)
    local d = espObj and espObj.Draw
    if not d then return end

    d.BoxOutline.Visible = false
    d.Box.Visible = false
    d.Fill.Visible = false
    d.Name.Visible = false
    d.Dist.Visible = false
    d.Weapon.Visible = false
    d.HpBg.Visible = false
    d.HpBar.Visible = false
    d.HpText.Visible = false
    for i = 1, 8 do
        d.Corners[i].Visible = false
        d.CornerOutlines[i].Visible = false
    end
    for i = 1, 5 do
        d.Flags[i].Visible = false
    end
end

function DestroyDrawings(espObj)
    local d = espObj and espObj.Draw
    if not d then return end

    local function kill(obj)
        if obj then pcall(function() obj:Remove() end) end
    end

    kill(d.BoxOutline); kill(d.Box); kill(d.Fill)
    kill(d.Name); kill(d.Dist); kill(d.Weapon)
    kill(d.HpBg); kill(d.HpBar); kill(d.HpText)
    for i = 1, 8 do kill(d.Corners[i]); kill(d.CornerOutlines[i]) end
    for i = 1, 5 do kill(d.Flags[i]) end

    espObj.Draw = nil
end

local function DrawDistanceValue(GetCfg, distanceStuds)
    if GetCfg("Distance.Unit") == "Meters" then
        return math.floor(distanceStuds / (GetCfg("Distance.StudsPerMeter") or 3))
    end
    return math.floor(distanceStuds)
end

local function RenderDrawingESP(espObj, GetCfg, runtime, instance, name, distanceStuds, isCheap, noStatus,
                                humanoid, x, y, sx, sy, px, py, textSize, textColor, boxColor,
                                health, maxHealth, healthPercent,
                                topOffset, bottomOffset, leftOffset, rightOffset)
    local d = EnsureDrawings(espObj)
    if not d then return end
    HideDrawings(espObj)

    local outlineColor = GetCfg("Outlines.Color") or Color3.fromRGB(0, 0, 0)
    local hasOutline = GetCfg("Outlines.Style") ~= "None" and GetCfg("Outlines.Enabled") ~= false

    if isCheap then
        if GetCfg("Names") then
            d.Name.Text = name .. " " .. DrawDistanceValue(GetCfg, distanceStuds)
                .. tostring(GetCfg("Distance.Ending") or "")
            d.Name.Size = textSize
            d.Name.Color = textColor
            d.Name.Position = Vector2.new(px, py - textSize / 2)
            d.Name.Visible = true
        end
        return
    end

    local boxesEnabled = GetCfg("Boxes")
    local thickness = GetCfg("BoxThickness") or 1
    local cornerMode = (GetCfg("BoxType") or "Normal") == "Corner"

    if boxesEnabled and not cornerMode then
        if hasOutline then
            d.BoxOutline.Position = Vector2.new(x - 1, y - 1)
            d.BoxOutline.Size = Vector2.new(sx + 2, sy + 2)
            d.BoxOutline.Thickness = thickness + 2
            d.BoxOutline.Color = outlineColor
            d.BoxOutline.Visible = true
        end
        d.Box.Position = Vector2.new(x, y)
        d.Box.Size = Vector2.new(sx, sy)
        d.Box.Thickness = thickness
        d.Box.Color = boxColor
        d.Box.Visible = true
    elseif boxesEnabled and cornerMode then
        local cw = math.max(math.floor(sx * 0.25), thickness * 3)
        local ch = math.max(math.floor(sy * 0.25), thickness * 3)
        local segments = {
            { x, y, x + cw, y },
            { x, y, x, y + ch },
            { x + sx - cw, y, x + sx, y },
            { x + sx, y, x + sx, y + ch },
            { x, y + sy, x + cw, y + sy },
            { x, y + sy - ch, x, y + sy },
            { x + sx - cw, y + sy, x + sx, y + sy },
            { x + sx, y + sy - ch, x + sx, y + sy },
        }
        for i = 1, 8 do
            local s = segments[i]
            local from = Vector2.new(s[1], s[2])
            local to = Vector2.new(s[3], s[4])
            if hasOutline then
                local ol = d.CornerOutlines[i]
                ol.From, ol.To = from, to
                ol.Thickness = thickness + 2
                ol.Color = outlineColor
                ol.Visible = true
            end
            local ln = d.Corners[i]
            ln.From, ln.To = from, to
            ln.Thickness = thickness
            ln.Color = boxColor
            ln.Visible = true
        end
    end

    if boxesEnabled and GetCfg("BoxFill.Enabled") then
        d.Fill.Position = Vector2.new(x, y)
        d.Fill.Size = Vector2.new(sx, sy)
        d.Fill.Color = GetCfg("BoxFill.Color")
        d.Fill.Transparency = 1 - (tonumber(GetCfg("BoxFill.Transparency")) or 0.9)
        d.Fill.Visible = true
    end

    if GetCfg("Names") then
        d.Name.Text = name
        d.Name.Size = textSize
        d.Name.Color = textColor
        d.Name.Position = Vector2.new(px, y - textSize - (GetCfg("TextGap") or 0) - topOffset)
        d.Name.Visible = true
    end

    local bottomY = y + sy + (GetCfg("Distance.Gap") or 0) + bottomOffset

    if GetCfg("Distance.Enabled") then
        local size = GetCfg("Distance.TextSize") or textSize
        d.Dist.Text = DrawDistanceValue(GetCfg, distanceStuds) .. tostring(GetCfg("Distance.Ending") or "")
        d.Dist.Size = size
        d.Dist.Color = GetCfg("Distance.Color")
        d.Dist.Position = Vector2.new(px, bottomY)
        d.Dist.Visible = true
        bottomY = bottomY + size + (GetCfg("Weapon.Gap") or 0)
    end

    if GetCfg("Weapon.Enabled") then
        local weaponName
        local holding = (runtime and runtime.Holding) or instance:FindFirstChild("Holding")
        if holding then
            if holding:IsA("ValueBase") then
                if holding.Value then weaponName = tostring(holding.Value) end
            else
                weaponName = holding.Name
            end
        end
        if (not weaponName or weaponName == "" or weaponName == "nil") and GetCfg("Weapon.UseToolFallback") then
            local tool = (runtime and runtime.Tool) or instance:FindFirstChildWhichIsA("Tool")
            if tool then weaponName = tool.Name end
        end

        if (not weaponName or weaponName == "" or weaponName == "nil") and GetCfg("Weapon.UseRemoteFallback") then
            local entry = ReplicateWeaponNames[(runtime and runtime.Player) or instance]
            local maxAge = GetCfg("Weapon.RemoteMaxAge") or 120
            if type(entry) == "table" and (maxAge <= 0 or (entry.T and os.clock() - entry.T <= maxAge)) then
                weaponName = entry.Name
            end
        end
        if weaponName and weaponName ~= "" and weaponName ~= "nil" then
            d.Weapon.Text = weaponName
            d.Weapon.Size = GetCfg("Weapon.TextSize") or textSize
            d.Weapon.Color = GetCfg("Weapon.Color")
            d.Weapon.Position = Vector2.new(px, bottomY)
            d.Weapon.Visible = true
        end
    end

    local function drawBar(bg, bar, text, prefix, value, maxValue, percent, barColor)
        local pos = GetCfg(prefix .. ".Position")
        local width = GetCfg(prefix .. ".Width") or 2
        local sideGap = GetCfg(prefix .. ".SideGap") or 2
        local horizontal = pos == "Top" or pos == "Bottom"
        local outlineOn = GetCfg(prefix .. ".Outline.Style") ~= "None"

        local bx, by, bw, bh
        if horizontal then
            bw, bh = sx, width
            bx = x
            by = pos == "Top" and (y - sideGap - width) or (y + sy + sideGap)
        else
            bw, bh = width, sy
            by = y
            bx = pos == "Left" and (x - sideGap - width) or (x + sx + sideGap)
        end

        if outlineOn then
            bg.Position = Vector2.new(bx - 1, by - 1)
            bg.Size = Vector2.new(bw + 2, bh + 2)
            bg.Color = GetCfg(prefix .. ".Outline.Color") or outlineColor
            bg.Visible = true
        end

        if horizontal then
            local filled = math.floor(bw * percent)
            bar.Position = Vector2.new(bx, by)
            bar.Size = Vector2.new(filled, bh)
        else
            local filled = math.floor(bh * percent)
            bar.Position = Vector2.new(bx, by + bh - filled)
            bar.Size = Vector2.new(bw, filled)
        end
        bar.Color = barColor
        bar.Visible = true

        local showText = GetCfg(prefix .. ".ShowText")
        if showText and GetCfg(prefix .. ".HideWhenFullHP") and value >= maxValue then
            showText = false
        end
        if showText then
            local size = GetCfg(prefix .. ".TextSize") or 9
            text.Text = tostring(math.floor(value))
            text.Size = size
            text.Color = textColor
            if horizontal then
                text.Position = Vector2.new(bx + bw / 2, by - size - 1)
            else
                text.Position = Vector2.new(bx + bw / 2, by - size - 1)
            end
            text.Visible = true
        end
    end

    if GetCfg("HealthBar.Enabled") and instance:IsA("Model") and humanoid then
        drawBar(d.HpBg, d.HpBar, d.HpText, "HealthBar", health, maxHealth, healthPercent,
            Color3.fromHSV(healthPercent * 0.3, 1, 1))
    end

    if GetCfg("Flags.Enabled") and instance:IsA("Model") and humanoid and not noStatus then
        local state = humanoid:GetState()
        local isMoving = humanoid.MoveDirection.Magnitude > 0
        local isJumping = state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Freefall
        local isSwimming = state == Enum.HumanoidStateType.Swimming

        local flagSize = GetCfg("Flags.TextSize") or 9
        local flagGap = GetCfg("Flags.Gap") or 2
        local flagSideGap = GetCfg("Flags.SideGap") or 4
        local flagTextGap = GetCfg("Flags.TextGap") or 2
        local isRight = GetCfg("Flags.Position") == "Right"
        local fx = isRight and (x + sx + flagSideGap + rightOffset) or (x - flagSideGap - leftOffset)
        local fy = y - flagGap
        local index = 0

        local function addFlag(text, color)
            index = index + 1
            local label = d.Flags[index]
            if not label then return end
            label.Text = text
            label.Size = flagSize
            label.Color = color
            label.Position = Vector2.new(fx, fy + (index - 1) * (flagSize + flagTextGap))
            label.Visible = true
        end

        if isMoving and isJumping and GetCfg("Flags.Options.Moving") and GetCfg("Flags.Options.Jumping") then
            addFlag("Moving & Jumping", GetCfg("Flags.Colors.Moving"))
        elseif isJumping and GetCfg("Flags.Options.Jumping") then
            addFlag("Jumping", GetCfg("Flags.Colors.Jumping"))
        elseif isMoving and GetCfg("Flags.Options.Moving") then
            addFlag("Moving", GetCfg("Flags.Colors.Moving"))
        elseif isSwimming and GetCfg("Flags.Options.Swimming") then
            addFlag("Swimming", GetCfg("Flags.Colors.Swimming"))
        elseif GetCfg("Flags.Options.Idle") then
            addFlag("Idle", GetCfg("Flags.Colors.Idle"))
        end

        if GetCfg("Flags.Options.ForceField") and instance:FindFirstChildOfClass("ForceField") then
            addFlag("FF", GetCfg("Flags.Colors.ForceField"))
        end

        if GetCfg("Flags.Options.Exploiting") then
            local owner = (runtime and runtime.Player) or Players:GetPlayerFromCharacter(instance)
            if IsESPPlayerExploiting(owner) then
                addFlag("exp", GetCfg("Flags.Colors.Exploiting"))
            end
        end
    end
end

local UpdateESPObj = (function(espObj, position, size, name, distanceStuds, instance, isCheap, nonHuman,
                                              noStatus,
                                              configOverride, onScreen, runtime)
    local cfgCache = espObj.FrameConfigCache
    if espObj.ConfigOverrideRef ~= configOverride or espObj.ConfigRevisionRef ~= ConfigRevision then
        espObj.ConfigOverrideRef = configOverride
        espObj.ConfigRevisionRef = ConfigRevision
        table.clear(cfgCache)
    end
    local GetCfg = espObj.GetCfgFn
    if not GetCfg or espObj.GetCfgOverrideRef ~= configOverride then
        espObj.GetCfgOverrideRef = configOverride
        GetCfg = function(path)
            local cached = cfgCache[path]
            if cached ~= nil then
                if cached == CONFIG_NIL then
                    return nil
                end
                return cached
            end
            local value = ResolveESPConfigValue(configOverride, path)
            cfgCache[path] = value == nil and CONFIG_NIL or value
            return value
        end
        espObj.GetCfgFn = GetCfg
    end

    local humanoid = not nonHuman and ((runtime and runtime.Humanoid) or instance:FindFirstChild("Humanoid")) or nil

    local chamsEnabled = GetCfg("Chams.Enabled")
    if chamsEnabled then
        local chamType = GetCfg("Chams.Type")
        if chamType == "Adornment" then
            chamType = "BoxHandleAdornment"
        end
        if Library.IsMobile and (chamType == "CharacterClone" or chamType == "MeshChams") then
            chamType = "Highlight"
        end
        local chamTypeChanged = espObj.ActiveChamType ~= chamType
        espObj.ActiveChamType = chamType

        if chamType == "Highlight" and (instance:IsA("Model") or instance:IsA("BasePart")) then
            DestroyCharacterClone(espObj)
            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end

            SetAdornmentRecordsVisible(espObj, false)
            DestroyAdornmentProxyLayers(espObj)

            if not espObj.Highlight or not espObj.Highlight.Parent then
                if espObj.Highlight then
                    espObj.Highlight:Destroy()
                end
                espObj.Highlight = Instance.new("Highlight")
            end

            local h = espObj.Highlight
            SetPropertyIfChanged(h, "Parent", ChamsContainer)
            SetPropertyIfChanged(h, "Adornee", instance)
            SetPropertyIfChanged(h, "FillColor", GetCfg("Chams.Highlight.FillColor"))
            SetPropertyIfChanged(h, "FillTransparency", GetCfg("Chams.Highlight.FillTransparency"))
            SetPropertyIfChanged(h, "OutlineColor", GetCfg("Chams.Highlight.OutlineColor"))
            SetPropertyIfChanged(h, "OutlineTransparency", GetCfg("Chams.Highlight.OutlineTransparency"))
            SetPropertyIfChanged(h, "DepthMode", GetCfg("Chams.Highlight.VisibleCheck")
                and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop)
            SetPropertyIfChanged(h, "Enabled", true)
        elseif chamType == "BoxHandleAdornment" then
            DestroyCharacterClone(espObj)
            if espObj.Highlight then
                SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
            end

            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end

            local now = tick()
            local refreshRate = math.clamp(tonumber(GetCfg("Chams.RefreshRate")) or 0.1, 0.05, 1)
            local refreshAdornment = ShouldRunStaggeredRefresh(
                espObj,
                "NextAdornmentRefresh",
                now,
                refreshRate,
                chamTypeChanged
            )
            if refreshAdornment then

            local parts = EnsureBoundingPartCache(espObj, instance)
            local activeParts = espObj.ActiveAdornmentParts
            table.clear(activeParts)
            local roundHead = GetCfg("Chams.Adornment.RoundHead")
            local isR6Rig = humanoid and humanoid.RigType == Enum.HumanoidRigType.R6
            local r6HeadScale = math.clamp(tonumber(GetCfg("Chams.Adornment.R6HeadScale")) or 0.86, 0.5, 1)
            local visibleSize = math.max(tonumber(GetCfg("Chams.Adornment.VisibleSize")) or 0, 0)
            local visibleEnabled = GetCfg("Chams.Adornment.Visible.Enabled")
            local glowEnabled = not Library.IsMobile and GetCfg("Chams.Adornment.Glow.Enabled") == true
            local glowColor = GetCfg("Chams.Adornment.Glow.Color")
            local glowIntensity = GetCfg("Chams.Adornment.Glow.Intensity")
            local glowSize = GetCfg("Chams.Adornment.Glow.Size")
            local glowFallbackTransparency = GetCfg("Chams.Adornment.Glow.FallbackTransparency")
            local invisibleColor = GetCfg("Chams.Adornment.Invisible.Color")
            local invisibleTransparency = GetCfg("Chams.Adornment.Invisible.Transparency")
            local visibleColor = GetCfg("Chams.Adornment.Visible.Color")
            local visibleTransparency = GetCfg("Chams.Adornment.Visible.Transparency")

            for _, p in ipairs(parts) do
                if p.Parent and p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    local isHead = p.Name == "Head" or p.Name == "FakeHead"
                    local isCylinder = roundHead and isHead
                    local headScale = isCylinder and isR6Rig and r6HeadScale or 1
                    local partInfo = espObj.AdornmentPartInfo[p]
                    if not partInfo then
                        partInfo = {}
                        espObj.AdornmentPartInfo[p] = partInfo
                    end
                    partInfo.IsCylinder = isCylinder
                    partInfo.PartSize = p.Size
                    partInfo.HeadScale = headScale
                    activeParts[p] = partInfo
                    local record = espObj.Adornments[p]

                    if record
                        and (typeof(record) == "Instance"
                            or record.IsCylinder ~= isCylinder
                            or not record.Invisible
                            or not record.Invisible.Parent
                            or (record.Visible and not record.Visible.Parent)
                            or (record.Glow and not record.Glow.Parent)) then
                        DestroyAdornmentRecord(record)
                        record = nil
                    end

                    if not record then
                        record = {
                            IsCylinder = isCylinder,
                            Invisible = CreateBodyAdornment(p, isCylinder, "ChamInvisible", true, 8),
                        }
                        espObj.Adornments[p] = record
                    end

                    if visibleEnabled and not record.Visible then
                        record.Visible = CreateBodyAdornment(p, isCylinder, "ChamVisible", false, 9)
                    elseif not visibleEnabled and record.Visible then
                        DestroyAdornmentRecordLayer(record, "Visible")
                    end

                    if glowEnabled and not record.Glow then
                        local glow, xrayEnabled = CreateAdornmentGlow(p, isCylinder)
                        record.Glow = glow
                        record.GlowXRay = xrayEnabled
                    elseif not glowEnabled and record.Glow then
                        DestroyAdornmentRecordLayer(record, "Glow")
                    end

                    if glowEnabled then
                        ApplyAdornmentGlowLayer(
                            record,
                            p.Size,
                            glowSize,
                            glowColor,
                            glowIntensity,
                            glowFallbackTransparency,
                            headScale
                        )
                    end
                    ApplyAdornmentLayer(record, "Invisible", p.Size, 0, invisibleColor, invisibleTransparency, headScale)
                    if visibleEnabled then
                        ApplyAdornmentLayer(record, "Visible", p.Size, visibleSize, visibleColor, visibleTransparency, headScale)
                    end
                end
            end

            for part, record in pairs(espObj.Adornments) do
                if not activeParts[part] or not part.Parent then
                    DestroyAdornmentRecord(record)
                    espObj.Adornments[part] = nil
                    espObj.AdornmentPartInfo[part] = nil
                end
            end

            for _, layer in ipairs(AdornmentHighlightLayers) do
                local enabled = GetCfg(layer.EnabledPath)
                if layer.Key == "Visible" then
                    enabled = enabled and visibleEnabled
                end

                if enabled then
                    local proxyLayer = EnsureAdornmentProxyLayer(espObj, layer.Key)
                    local highlight = proxyLayer.Highlight
                    local sizeIncrease = layer.Key == "Visible" and visibleSize or 0

                    for part, partInfo in pairs(activeParts) do
                        ApplyAdornmentProxyPart(proxyLayer, part, partInfo, sizeIncrease)
                    end

                    for part, proxyRecord in pairs(proxyLayer.Parts) do
                        if not activeParts[part] or not part.Parent then
                            DestroyAdornmentProxyPart(proxyRecord)
                            proxyLayer.Parts[part] = nil
                        end
                    end

                    SetPropertyIfChanged(highlight, "FillColor", GetCfg(layer.FillColorPath))
                    SetPropertyIfChanged(highlight, "FillTransparency", GetCfg(layer.FillTransparencyPath))
                    SetPropertyIfChanged(highlight, "OutlineColor", GetCfg(layer.OutlineColorPath))
                    SetPropertyIfChanged(highlight, "OutlineTransparency", GetCfg(layer.OutlineTransparencyPath))
                    SetPropertyIfChanged(highlight, "DepthMode", layer.DepthMode)
                    SetPropertyIfChanged(highlight, "Enabled", true)
                else
                    DestroyAdornmentProxyLayer(espObj, layer.Key)
                end
            end
            end
        elseif chamType == "CharacterClone" then
            if espObj.Highlight then
                    SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
            end
            SetAdornmentRecordsVisible(espObj, false)
            DestroyAdornmentProxyLayers(espObj)
            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end

            if instance:IsA("Model") then
                local now = tick()
                local refreshRate = math.clamp(tonumber(GetCfg("Chams.RefreshRate")) or 0.1, 0.05, 1)
                local cloneLayer = espObj.CharacterClone
                local refreshClone = ShouldRunStaggeredRefresh(
                    espObj,
                    "NextCharacterCloneRefresh",
                    now,
                    refreshRate,
                    chamTypeChanged
                )

                if refreshClone then
                    local materialName = GetCfg("Chams.CharacterClone.Material")
                    local style = espObj.CharacterCloneStyle
                    style.Color = GetCfg("Chams.CharacterClone.Color")
                    style.Transparency = math.clamp(tonumber(GetCfg("Chams.CharacterClone.Transparency")) or 0.55, 0, 1)
                    style.Material = CharacterCloneMaterials[materialName] or Enum.Material.SmoothPlastic
                    style.KeepTextures = GetCfg("Chams.CharacterClone.KeepTextures") == true
                    style.IncludeAccessories = GetCfg("Chams.CharacterClone.IncludeAccessories") ~= false
                    style.SizeScale = math.clamp(tonumber(GetCfg("Chams.CharacterClone.SizeScale")) or 1.015, 1, 1.1)
                    style.HighlightEnabled = GetCfg("Chams.CharacterClone.Highlight.Enabled") == true
                    style.HighlightFillColor = GetCfg("Chams.CharacterClone.Highlight.FillColor")
                    style.HighlightFillTransparency = math.clamp(tonumber(GetCfg("Chams.CharacterClone.Highlight.FillTransparency")) or 0.75, 0, 1)
                    style.HighlightOutlineColor = GetCfg("Chams.CharacterClone.Highlight.OutlineColor")
                    style.HighlightOutlineTransparency = math.clamp(tonumber(GetCfg("Chams.CharacterClone.Highlight.OutlineTransparency")) or 0.25, 0, 1)
                    style.HighlightVisibleCheck = GetCfg("Chams.CharacterClone.Highlight.VisibleCheck") == true
                    UpdateCharacterClone(espObj, instance, style, chamTypeChanged)
                end
            else
                DestroyCharacterClone(espObj)
            end
        elseif chamType == "MeshChams" then
            DestroyCharacterClone(espObj)
            if espObj.Highlight then
                SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
            end
            SetAdornmentRecordsVisible(espObj, false)
            DestroyAdornmentProxyLayers(espObj)

            local playerOwner = Players:GetPlayerFromCharacter(instance)
            if not playerOwner then
                if espObj.MeshShell then
                    espObj.MeshShell:Destroy()
                    espObj.MeshShell = nil
                    espObj.MeshHighlight = nil
                end
            else
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

                    local hl = Instance.new("Highlight")
                    hl.Name  = "ChamShellHighlight"
                    hl:SetAttribute("SensoryESP_MeshCham", true)
                    hl:SetAttribute("SensoryESP_RunId", CurrentRunId)
                    hl.Adornee           = shellModel
                    hl.Parent            = shellModel
                    espObj.MeshShell     = shellModel
                    espObj.MeshHighlight = hl
                end

                if espObj.MeshHighlight then
                    local hl               = espObj.MeshHighlight
                    SetPropertyIfChanged(hl, "FillColor", GetCfg("Chams.MeshChams.FillColor"))
                    SetPropertyIfChanged(hl, "FillTransparency", GetCfg("Chams.MeshChams.FillTransparency"))
                    SetPropertyIfChanged(hl, "OutlineColor", GetCfg("Chams.MeshChams.OutlineColor"))
                    SetPropertyIfChanged(hl, "OutlineTransparency", GetCfg("Chams.MeshChams.OutlineTransparency"))
                    SetPropertyIfChanged(hl, "DepthMode", GetCfg("Chams.MeshChams.VisibleCheck")
                        and Enum.HighlightDepthMode.Occluded
                        or Enum.HighlightDepthMode.AlwaysOnTop)
                    SetPropertyIfChanged(hl, "Enabled", true)
                end
            end
        else
            if espObj.Highlight then
                SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
            end
            SetAdornmentRecordsVisible(espObj, false)
            DestroyAdornmentProxyLayers(espObj)
            DestroyCharacterClone(espObj)
            if espObj.MeshShell then
                espObj.MeshShell:Destroy()
                espObj.MeshShell = nil
                espObj.MeshHighlight = nil
            end
        end
    else
        espObj.ActiveChamType = nil
        if espObj.Highlight then
            SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
        end
        SetAdornmentRecordsVisible(espObj, false)
        DestroyAdornmentProxyLayers(espObj)
        DestroyCharacterClone(espObj)
        if espObj.MeshShell then
            espObj.MeshShell:Destroy()
            espObj.MeshShell = nil
            espObj.MeshHighlight = nil
        end
    end

    if espObj.ArrowInner and GetCfg("OffScreenArrows.Enabled") and instance:IsA("Model") then
        local rp = (runtime and runtime.RootPart) or instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChildWhichIsA("BasePart")
        if rp then
            local sp = Camera:WorldToViewportPoint(rp.Position)
            local vp = Camera.ViewportSize
            local cx, cy = vp.X / 2, vp.Y / 2
            local onVp = sp.Z > 0 and sp.X >= 0 and sp.X <= vp.X and sp.Y >= 0 and sp.Y <= vp.Y
            if not onVp then
                local orbit = GetCfg("OffScreenArrows.OrbitRadius")
                local nx, ny, rot
                if GetCfg("OffScreenArrows.ArrowMode") == "Compass" then

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
                    SetPropertyIfChanged(espObj.ArrowOutline, "TextSize", sz + 2)
                    SetPropertyIfChanged(espObj.ArrowOutline, "TextColor3", GetCfg("OffScreenArrows.OutlineColor"))
                    espObj.ArrowOutline.Position = UDim2.new(0, ax - sz - 2, 0, ay - sz - 2)
                    espObj.ArrowOutline.Rotation = rot
                    SetPropertyIfChanged(espObj.ArrowOutline, "Visible", true)
                else
                    SetPropertyIfChanged(espObj.ArrowOutline, "Visible", false)
                end

                local arrowFontObj = _fontMap[GetCfg("OffScreenArrows.Font")] or Enum.Font.SourceSans
                SetPropertyIfChanged(espObj.ArrowInner, "Text", "▲")
                SetPropertyIfChanged(espObj.ArrowInner, "Font", arrowFontObj)
                SetPropertyIfChanged(espObj.ArrowInner, "TextSize", sz)
                SetPropertyIfChanged(espObj.ArrowInner, "TextColor3", col)
                espObj.ArrowInner.Position = UDim2.new(0, ax - sz, 0, ay - sz)
                espObj.ArrowInner.Size = UDim2.new(0, sz * 2, 0, sz * 2)
                espObj.ArrowInner.Rotation = rot
                espObj.ArrowInner.Visible = true


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
                    SetPropertyIfChanged(espObj.ArrowName, "Font", nFontObj)
                    if nFontLoaded then SetPropertyIfChanged(espObj.ArrowName, "FontFace", nFontLoaded) end
                    SetPropertyIfChanged(espObj.ArrowName, "TextSize", nTxtSz)
                    SetPropertyIfChanged(espObj.ArrowName, "TextColor3", nCol)
                    SetPropertyIfChanged(espObj.ArrowName, "Text", name)
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
                    SetPropertyIfChanged(espObj.ArrowDist, "Font", dFontObj)
                    if dFontLoaded then SetPropertyIfChanged(espObj.ArrowDist, "FontFace", dFontLoaded) end
                    SetPropertyIfChanged(espObj.ArrowDist, "TextSize", dTxtSz)
                    SetPropertyIfChanged(espObj.ArrowDist, "TextColor3", dCol)
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

    if GetCfg("Skeleton.Enabled") then
        if onScreen and not isCheap then
            Update3DSkeleton(espObj, instance, GetCfg, runtime)
        end
    else
        Destroy3DSkeleton(espObj)
    end

    if not onScreen or not position or not size then
        SetPropertyIfChanged(espObj.Container, "Visible", false)
        HideDrawings(espObj)
        return
    end

    SetPropertyIfChanged(espObj.Container, "Visible", true)
    SetPropertyIfChanged(espObj.Container, "ZIndex", nonHuman and 1 or 10)
    if GetCfg("Names") then
        espObj.Text.Text = name
    end

    local textOutlineStyle = GetCfg("TextOutlineStyle")

    if GetCfg("TextOutline") == false then textOutlineStyle = "None" end
    local textOutlineColor = GetCfg("TextOutlineColor") or GetCfg("Outlines.Color")

    local t = GetCfg("BoxThickness")
    local o = GetCfg("Outlines.Thickness")
    local textSize = GetCfg("TextSize")
    local textColor = GetCfg("TextColor")
    local teamOwner = not nonHuman and instance:IsA("Model") and ((runtime and runtime.Player) or Players:GetPlayerFromCharacter(instance)) or nil
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
    SetPropertyIfChanged(espObj.Text, "TextSize", textSize)
    SetPropertyIfChanged(espObj.Text, "TextColor3", textColor)
    SetPropertyIfChanged(espObj.Text, "Font", fontObj)
    if fontLoaded then
        SetPropertyIfChanged(espObj.Text, "FontFace", fontLoaded)
    end
    ApplyTextOutline(espObj.Text, textOutlineStyle, textOutlineColor)

    do
        local distFont = GetCfg("Distance.Font")
        local distFontObj = _fontMap[distFont] or Enum.Font.Code
        SetPropertyIfChanged(espObj.DistanceText, "TextSize", GetCfg("Distance.TextSize") or textSize)
        SetPropertyIfChanged(espObj.DistanceText, "TextColor3", GetCfg("Distance.Color"))
        SetPropertyIfChanged(espObj.DistanceText, "Font", distFontObj)
        if ESPFonts.Loaded[distFont] then
            SetPropertyIfChanged(espObj.DistanceText, "FontFace", ESPFonts.Loaded[distFont])
        end
        ApplyTextOutline(espObj.DistanceText, GetCfg("Distance.OutlineStyle") or textOutlineStyle, textOutlineColor)
    end

    do
        local wepFont = GetCfg("Weapon.Font")
        local wepFontObj = _fontMap[wepFont] or Enum.Font.Code
        SetPropertyIfChanged(espObj.WeaponText, "TextSize", GetCfg("Weapon.TextSize") or textSize)
        SetPropertyIfChanged(espObj.WeaponText, "TextColor3", GetCfg("Weapon.Color"))
        SetPropertyIfChanged(espObj.WeaponText, "Font", wepFontObj)
        if ESPFonts.Loaded[wepFont] then
            SetPropertyIfChanged(espObj.WeaponText, "FontFace", ESPFonts.Loaded[wepFont])
        end
        ApplyTextOutline(espObj.WeaponText, GetCfg("Weapon.OutlineStyle") or textOutlineStyle, textOutlineColor)
    end

    local px, py = math.floor(position.X), math.floor(position.Y)
    local sx, sy = math.floor(size.X), math.floor(size.Y)
    local x, y = math.floor(px - sx / 2), math.floor(py - sy / 2)


    local health, maxHealth, healthPercent = 100, 100, 1
    if humanoid then
        health = humanoid.Health
        maxHealth = humanoid.MaxHealth
        healthPercent = math.clamp(health / maxHealth, 0, 1)
    end

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

    if GetCfg("DrawingMode") and DrawingAvailable then
        SetPropertyIfChanged(espObj.Container, "Visible", false)
        RenderDrawingESP(espObj, GetCfg, runtime, instance, name, distanceStuds, isCheap, noStatus,
            humanoid, x, y, sx, sy, px, py, textSize, textColor, boxColor,
            health, maxHealth, healthPercent,
            topOffset, bottomOffset, leftOffset, rightOffset)
        return
    end
    HideDrawings(espObj)

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


    espObj.Lines[1].Position = UDim2.new(0, x, 0, y)
    espObj.Lines[1].Size = UDim2.new(0, sx, 0, t)

    espObj.Lines[2].Position = UDim2.new(0, x, 0, y + sy)
    espObj.Lines[2].Size = UDim2.new(0, sx + t, 0, t)

    espObj.Lines[3].Position = UDim2.new(0, x, 0, y)
    espObj.Lines[3].Size = UDim2.new(0, t, 0, sy)

    espObj.Lines[4].Position = UDim2.new(0, x + sx, 0, y)
    espObj.Lines[4].Size = UDim2.new(0, t, 0, sy + t)

    local boxesEnabled = GetCfg("Boxes")
    local boxType = GetCfg("BoxType") or "Normal"
    local useCornerBoxes = boxType == "Corner"

    local outlineStyle = GetCfg("Outlines.Style")
    local outlineColor = GetCfg("Outlines.Color")
    local outlineThickness = GetCfg("Outlines.Thickness")

    if GetCfg("Outlines.Enabled") == false then outlineStyle = "None" end
    local outlineTransparency = 0
    local hasOutline = outlineStyle ~= "None"

    if useCornerBoxes then
        local cornerWidth = math.max(math.floor(sx * 0.25), t * 3)
        local cornerHeight = math.max(math.floor(sy * 0.25), t * 3)

        SetCornerGeometry(espObj.CornerLines[1], x, y, cornerWidth, t)
        SetCornerGeometry(espObj.CornerLines[2], x, y, t, cornerHeight)
        SetCornerGeometry(espObj.CornerLines[3], x + sx - cornerWidth + t, y, cornerWidth, t)
        SetCornerGeometry(espObj.CornerLines[4], x + sx, y, t, cornerHeight)
        SetCornerGeometry(espObj.CornerLines[5], x, y + sy, cornerWidth, t)
        SetCornerGeometry(espObj.CornerLines[6], x, y + sy - cornerHeight + t, t, cornerHeight)
        SetCornerGeometry(espObj.CornerLines[7], x + sx - cornerWidth + t, y + sy, cornerWidth, t)
        SetCornerGeometry(espObj.CornerLines[8], x + sx, y + sy - cornerHeight + t, t, cornerHeight)
    end

    for i = 1, 4 do
        SetPropertyIfChanged(espObj.Lines[i], "Visible", boxesEnabled and not useCornerBoxes)
        SetPropertyIfChanged(espObj.Outlines[i], "Visible", boxesEnabled and hasOutline and not useCornerBoxes)

        SetPropertyIfChanged(espObj.Outlines[i], "Position", UDim2.new(0, -outlineThickness, 0, -outlineThickness))
        SetPropertyIfChanged(espObj.Outlines[i], "Size", UDim2.new(1, outlineThickness * 2, 1, outlineThickness * 2))
        SetPropertyIfChanged(espObj.Outlines[i], "BackgroundTransparency", outlineTransparency)
        SetPropertyIfChanged(espObj.Lines[i], "BackgroundColor3", boxColor)
        SetPropertyIfChanged(espObj.Outlines[i], "BackgroundColor3", outlineColor)
    end

    for i = 1, 8 do
        SetPropertyIfChanged(espObj.CornerLines[i], "Visible", boxesEnabled and useCornerBoxes)
        SetPropertyIfChanged(espObj.CornerOutlines[i], "Visible", boxesEnabled and hasOutline and useCornerBoxes)

        SetPropertyIfChanged(espObj.CornerOutlines[i], "Position", UDim2.new(0, -outlineThickness, 0, -outlineThickness))
        SetPropertyIfChanged(espObj.CornerOutlines[i], "Size", UDim2.new(1, outlineThickness * 2, 1, outlineThickness * 2))
        SetPropertyIfChanged(espObj.CornerOutlines[i], "BackgroundTransparency", outlineTransparency)
        SetPropertyIfChanged(espObj.CornerLines[i], "BackgroundColor3", boxColor)
        SetPropertyIfChanged(espObj.CornerOutlines[i], "BackgroundColor3", outlineColor)
    end

    local fill = espObj.BoxFill
    local grad = espObj.BoxFillGradient
    if GetCfg("BoxFill.Enabled") and boxesEnabled then
        fill.Visible = true
        fill.Position = UDim2.new(0, x, 0, y)
        fill.Size = UDim2.new(0, sx, 0, sy)
        SetPropertyIfChanged(fill, "BackgroundTransparency", GetCfg("BoxFill.Transparency"))

        if GetCfg("BoxFill.Gradient.Enabled") then
            SetPropertyIfChanged(grad, "Enabled", true)
            local bgC1 = GetCfg("BoxFill.Gradient.Color1")
            local bgC2 = GetCfg("BoxFill.Gradient.Color2")
            local bgC3 = GetCfg("BoxFill.Gradient.Color3")
            SetThreeColorGradient(espObj, "BoxFillGradient", grad, bgC1, bgC2, bgC3)

            local rot = GetCfg("BoxFill.Gradient.Rotation")
            if GetCfg("BoxFill.Gradient.Animated") then
                local speed = GetCfg("BoxFill.Gradient.Speed")
                local dir = GetCfg("BoxFill.Gradient.Direction") == "Left" and -1 or 1
                rot = (rot + (_now * speed * dir)) % 360
            end
            grad.Rotation = rot
            SetPropertyIfChanged(fill, "BackgroundColor3", Color3.fromRGB(255, 255, 255))
        else
            SetPropertyIfChanged(grad, "Enabled", false)
            SetPropertyIfChanged(fill, "BackgroundColor3", GetCfg("BoxFill.Color"))
        end
    else
        fill.Visible = false
    end

    local nameY = y - textSize - (GetCfg("TextGap") or 0) - topOffset
    local leftTags = ""
    local rightTags = ""

    if GetCfg("TeamIndicator.Enabled") and teamOwner and teamOwner.Team then
        local teamColor = GetCfg("TeamIndicator.UseTeamColor") and teamOwner.TeamColor.Color or
        GetCfg("TeamIndicator.Color")
        local teamName = teamOwner.Team.Name
        local compactTeam = GetCfg("TeamIndicator.Compact") and CompactTeamName(teamName) or teamName
        local teamTag = string.format('<font color="%s">[%s]</font>', ColorToHex(teamColor), compactTeam)
        if GetCfg("TeamIndicator.Position") == "Left" then
            leftTags = teamTag
        else
            rightTags = teamTag
        end
    end

    local isFriendly = false
    if teamOwner and GetCfg("FriendlyIndicator.Enabled") then
        if GetCfg("FriendlyIndicator.CheckTeam") and LocalPlayer.Team ~= nil and teamOwner.Team == LocalPlayer.Team then
            isFriendly = true
        end
        if not isFriendly and GetCfg("FriendlyIndicator.CheckFriends") then
            isFriendly = IsCachedFriend(teamOwner)
        end
    end

    if isFriendly then
        local friendlyTag = string.format('<font color="%s">%s</font>', ColorToHex(GetCfg("FriendlyIndicator.Color")),
            tostring(GetCfg("FriendlyIndicator.Text") or "[F]"))
        if GetCfg("FriendlyIndicator.Position") == "Left" then
            leftTags = leftTags == "" and friendlyTag or (leftTags .. " " .. friendlyTag)
        else
            rightTags = rightTags == "" and friendlyTag or (rightTags .. " " .. friendlyTag)
        end
    end

    local finalNameText = name
    if leftTags ~= "" then
        finalNameText = leftTags .. " " .. finalNameText
    end
    if rightTags ~= "" then
        finalNameText = finalNameText .. " " .. rightTags
    end

    if GetCfg("Names") then
        espObj.Text.Text = finalNameText
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

    if GetCfg("Weapon.Enabled") then
        local weaponName = nil


        local holding = (runtime and runtime.Holding) or instance:FindFirstChild("Holding")
        if holding then
            if holding:IsA("ValueBase") then
                if holding.Value then
                    weaponName = tostring(holding.Value)
                end
            else
                weaponName = holding.Name
            end
        end


        if (not weaponName or weaponName == "" or weaponName == "nil") and GetCfg("Weapon.UseToolFallback") then
            local tool = (runtime and runtime.Tool) or instance:FindFirstChildWhichIsA("Tool")
            if tool then weaponName = tool.Name end
        end

        if (not weaponName or weaponName == "" or weaponName == "nil") and GetCfg("Weapon.UseRemoteFallback") then
            local entry = ReplicateWeaponNames[(runtime and runtime.Player) or instance]
            local maxAge = GetCfg("Weapon.RemoteMaxAge") or 120
            if type(entry) == "table" and (maxAge <= 0 or (entry.T and os.clock() - entry.T <= maxAge)) then
                weaponName = entry.Name
            end
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

    if GetCfg("HealthBar.Enabled") and instance:IsA("Model") and humanoid then

        local hpPos = GetCfg("HealthBar.Position")
        local isHorizontal = (hpPos == "Top" or hpPos == "Bottom")
        local hpWidth = GetCfg("HealthBar.Width")
        local hpSideGap = GetCfg("HealthBar.SideGap")
        local hpTextFollowBar = GetCfg("HealthBar.TextFollowBar")

        local hpOutlineStyle = GetCfg("HealthBar.Outline.Style")

        if GetCfg("HealthBar.Outline.Enabled") == false then hpOutlineStyle = "None" end
        espObj.HealthBarOutline.Visible = hpOutlineStyle ~= "None"
        SetPropertyIfChanged(espObj.HealthBarOutline, "BackgroundTransparency", 0)
        SetPropertyIfChanged(espObj.HealthBarOutline, "BackgroundColor3", GetCfg("HealthBar.Outline.Color"))
        local barWidth

        if isHorizontal then
            barWidth = math.floor((sx + 1) * healthPercent)
            espObj.HealthBarOutline.Size = UDim2.new(0, sx + 3, 0, hpWidth + 2)

            if hpPos == "Top" then
                espObj.HealthBarOutline.Position = UDim2.new(0, x - 1, 0,
                    y - o - hpSideGap - hpWidth - 1)
            else
                espObj.HealthBarOutline.Position = UDim2.new(0, x - 1, 0, y + sy + o + hpSideGap)
            end

            espObj.HealthBarContainer.Size = UDim2.new(0, barWidth, 0, hpWidth)
            espObj.HealthBarContainer.Position = UDim2.new(0, 1, 0, 1)

            espObj.HealthBar.Size = UDim2.new(0, sx + 1, 0, hpWidth)
            espObj.HealthBar.Position = UDim2.new(0, 0, 0, 0)
        else
            local barHeight = math.floor((sy + 1) * healthPercent)
            espObj.HealthBarOutline.Size = UDim2.new(0, hpWidth + 2, 0, sy + 3)

            if hpPos == "Left" then
                espObj.HealthBarOutline.Position = UDim2.new(0,
                    x - o - hpSideGap - hpWidth - 1, 0, y - 1)
            else
                espObj.HealthBarOutline.Position = UDim2.new(0, x + sx + o + hpSideGap, 0, y - 1)
            end

            espObj.HealthBarContainer.Size = UDim2.new(0, hpWidth, 0, barHeight)
            espObj.HealthBarContainer.Position = UDim2.new(0, 1, 0, (sy + 1) - barHeight + 1)

            espObj.HealthBar.Size = UDim2.new(0, hpWidth, 0, sy + 1)
            espObj.HealthBar.Position = UDim2.new(0, 0, 0, -(sy + 1 - barHeight))
        end


        local gradientEnabled = GetCfg("HealthBar.Gradient.Enabled")
        SetPropertyIfChanged(espObj.HealthGradient, "Enabled", gradientEnabled and not isHorizontal)
        SetThreeColorGradient(espObj, "HealthGradient", espObj.HealthGradient,
            GetCfg("HealthBar.Gradient.Color1"), GetCfg("HealthBar.Gradient.Color2"),
            GetCfg("HealthBar.Gradient.Color3"))
        local showText = GetCfg("HealthBar.ShowText")
        if GetCfg("HealthBar.HideWhenFullHP") and health >= maxHealth then
            showText = false
        end
        local followColorText = showText and GetCfg("HealthBar.FollowGradientColorText")
        local healthColor = Color3.fromHSV(healthPercent * 0.3, 1, 1)

        if gradientEnabled and not isHorizontal then
            SetPropertyIfChanged(espObj.HealthGradient, "Rotation", 90)
            SetPropertyIfChanged(espObj.HealthBar, "BackgroundColor3", Color3.fromRGB(255, 255, 255))

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
            SetPropertyIfChanged(espObj.HealthBar, "BackgroundColor3", healthColor)
        end

        if showText then
            espObj.HealthText.Visible = true
            espObj.HealthText.Text = math.floor(health)
            SetPropertyIfChanged(espObj.HealthText, "TextSize", GetCfg("HealthBar.TextSize"))
            local hpFont = GetCfg("HealthBar.Font")
            local hpFontObj = _fontMap[hpFont] or Enum.Font.Code
            SetPropertyIfChanged(espObj.HealthText, "Font", hpFontObj)
            if ESPFonts.Loaded[hpFont] then
                SetPropertyIfChanged(espObj.HealthText, "FontFace", ESPFonts.Loaded[hpFont])
            end
            SetPropertyIfChanged(espObj.HealthText, "TextColor3", followColorText and healthColor or GetCfg("TextColor"))
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
            local flagOptionsForceField = GetCfg("Flags.Options.ForceField")
            local flagOptionsExploiting = GetCfg("Flags.Options.Exploiting")
            local flagColorsMoving = GetCfg("Flags.Colors.Moving")
            local flagColorsJumping = GetCfg("Flags.Colors.Jumping")
            local flagColorsSwimming = GetCfg("Flags.Colors.Swimming")
            local flagColorsIdle = GetCfg("Flags.Colors.Idle")
            local flagColorsForceField = GetCfg("Flags.Colors.ForceField")
            local flagFont = GetCfg("Flags.Font")
            local flagTextSize = GetCfg("Flags.TextSize")
            local flagTextGap = GetCfg("Flags.TextGap")
            local flagGap = GetCfg("Flags.Gap") or 2
            local flagSideGap = GetCfg("Flags.SideGap")
            local flagPosition = GetCfg("Flags.Position")
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
            local flagIndex = 0
            local movementText
            local movementColor

            if isMoving and isJumping and flagOptionsMoving and flagOptionsJumping then
                movementText, movementColor = "Moving & Jumping", flagColorsMoving
            elseif isJumping and flagOptionsJumping then
                movementText, movementColor = "Jumping", flagColorsJumping
            elseif isMoving and flagOptionsMoving then
                movementText, movementColor = "Moving", flagColorsMoving
            elseif isSwimming and flagOptionsSwimming then
                movementText, movementColor = "Swimming", flagColorsSwimming
            elseif flagOptionsIdle then
                movementText, movementColor = "Idle", flagColorsIdle
            end

            if movementText then
                flagIndex = flagIndex + 1
                ShowESPFlag(espObj, flagIndex, movementText, movementColor, flagsFontObj, flagsFontLoaded,
                    flagTextSize, isRight, fx, fy, flagTextGap, flagOutlineStyle, textOutlineColor)
            end

            if flagOptionsForceField and instance:FindFirstChildOfClass("ForceField") then
                flagIndex = flagIndex + 1
                ShowESPFlag(espObj, flagIndex, "FF", flagColorsForceField, flagsFontObj, flagsFontLoaded,
                    flagTextSize, isRight, fx, fy, flagTextGap, flagOutlineStyle, textOutlineColor)
            end

            if flagOptionsExploiting and IsESPPlayerExploiting(teamOwner or (runtime and runtime.Player) or Players:GetPlayerFromCharacter(instance)) then
                flagIndex = flagIndex + 1
                ShowESPFlag(espObj, flagIndex, "exp", GetCfg("Flags.Colors.Exploiting"), flagsFontObj, flagsFontLoaded,
                    flagTextSize, isRight, fx, fy, flagTextGap, flagOutlineStyle, textOutlineColor)
            end
    end

end)
local BOX_CORNER_SIGNS = {
    Vector3.new(1, 1, 1),
    Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, 1),
    Vector3.new(-1, -1, 1),
    Vector3.new(1, 1, -1),
    Vector3.new(-1, 1, -1),
    Vector3.new(1, -1, -1),
    Vector3.new(-1, -1, -1),
}

local function ExpandFullProjectedBounds(cf, size, minX, minY, maxX, maxY)
    local halfX, halfY, halfZ = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
    for _, sign in ipairs(BOX_CORNER_SIGNS) do
        local screenPos = Camera:WorldToViewportPoint(cf * Vector3.new(
            halfX * sign.X,
            halfY * sign.Y,
            halfZ * sign.Z
        ))
        if screenPos.X < minX then minX = screenPos.X end
        if screenPos.X > maxX then maxX = screenPos.X end
        if screenPos.Y < minY then minY = screenPos.Y end
        if screenPos.Y > maxY then maxY = screenPos.Y end
    end
    return minX, minY, maxX, maxY
end

local function ExpandCheapProjectedBounds(part, minX, minY, maxX, maxY)
    local cf, halfSize = part.CFrame, part.Size * 0.5
    local s1 = Camera:WorldToViewportPoint(cf * Vector3.new(halfSize.X, halfSize.Y, halfSize.Z))
    local s2 = Camera:WorldToViewportPoint(cf * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z))
    if s1.X < minX then minX = s1.X end
    if s1.X > maxX then maxX = s1.X end
    if s1.Y < minY then minY = s1.Y end
    if s1.Y > maxY then maxY = s1.Y end
    if s2.X < minX then minX = s2.X end
    if s2.X > maxX then maxX = s2.X end
    if s2.Y < minY then minY = s2.Y end
    if s2.Y > maxY then maxY = s2.Y end
    return minX, minY, maxX, maxY
end

EnsureBoundingPartCache = function(espObj, instance)
    if espObj.BoundingSource ~= instance then
        if espObj.BoundingAddedConnection then espObj.BoundingAddedConnection:Disconnect() end
        if espObj.BoundingRemovedConnection then espObj.BoundingRemovedConnection:Disconnect() end
        espObj.BoundingAddedConnection = nil
        espObj.BoundingRemovedConnection = nil
        espObj.BoundingSource = instance
        espObj.BoundingPartsDirty = true

        if instance:IsA("Model") then
            espObj.BoundingAddedConnection = instance.ChildAdded:Connect(function()
                espObj.BoundingPartsDirty = true
            end)
            espObj.BoundingRemovedConnection = instance.ChildRemoved:Connect(function()
                espObj.BoundingPartsDirty = true
            end)
        end
    end

    if espObj.BoundingPartsDirty then
        table.clear(espObj.BoundingParts)
        if instance:IsA("Model") then
            for _, child in ipairs(instance:GetChildren()) do
                if child:IsA("BasePart") and not IsIgnoredColliderPart(child) then
                    espObj.BoundingParts[#espObj.BoundingParts + 1] = child
                end
            end
        elseif instance:IsA("BasePart") then
            espObj.BoundingParts[1] = instance
        end
        espObj.BoundingPartsDirty = false
    end
    return espObj.BoundingParts
end

local FAST_BOUND_CORNERS = {
    Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1), Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}

local function GetFastCombinedProjectedBounds(instance, espObj, rootPart)
    if not rootPart or not rootPart.Parent then return false, nil, nil end
    local rootCF = rootPart.CFrame
    local abs, min, max = math.abs, math.min, math.max
    local lowX, lowY, lowZ = math.huge, math.huge, math.huge
    local highX, highY, highZ = -math.huge, -math.huge, -math.huge
    local includeAll = ESPConfig.DynamicBoxesIncludeAll
    local count = 0

    for _, part in ipairs(EnsureBoundingPartCache(espObj, instance)) do
        if part.Parent and (includeAll or (part.Name ~= "HumanoidRootPart" and part.Transparency ~= 1)) then
            count += 1
            local relative = rootCF:ToObjectSpace(part.CFrame)
            local half = part.Size * 0.5
            local hx, hy, hz = half.X, half.Y, half.Z
            local right, up, look = relative.RightVector, relative.UpVector, relative.LookVector
            local ex = abs(right.X) * hx + abs(up.X) * hy + abs(look.X) * hz
            local ey = abs(right.Y) * hx + abs(up.Y) * hy + abs(look.Y) * hz
            local ez = abs(right.Z) * hx + abs(up.Z) * hy + abs(look.Z) * hz
            local position = relative.Position
            local px, py, pz = position.X, position.Y, position.Z

            lowX = min(lowX, px - ex); highX = max(highX, px + ex)
            lowY = min(lowY, py - ey); highY = max(highY, py + ey)
            lowZ = min(lowZ, pz - ez); highZ = max(highZ, pz + ez)
        end
    end

    if count == 0 then return false, nil, nil end

    local cx, cy, cz = (lowX + highX) * 0.5, (lowY + highY) * 0.5, (lowZ + highZ) * 0.5
    local hx, hy, hz = (highX - lowX) * 0.5, (highY - lowY) * 0.5, (highZ - lowZ) * 0.5
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local projected = 0

    for _, corner in ipairs(FAST_BOUND_CORNERS) do
        local world = rootCF:PointToWorldSpace(Vector3.new(cx + hx * corner.X, cy + hy * corner.Y, cz + hz * corner.Z))
        local point = Camera:WorldToViewportPoint(world)
        if point.Z > 0 then
            projected += 1
            local x, y = point.X, point.Y
            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end
    end

    if projected == 0 then return false, nil, nil end
    return true, Vector2.new((minX + maxX) * 0.5, (minY + maxY) * 0.5), Vector2.new(maxX - minX, maxY - minY)
end

local Get2DBoundingBox = (function(instance, espObj, runtime)
    local rootPart
    if instance:IsA("Model") then
        rootPart = (runtime and runtime.RootPart) or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChild("Torso") or
            instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
    elseif instance:IsA("BasePart") then
        rootPart = instance
    end

    if not rootPart or not Camera then return false, nil, nil end

    local rootPosition = rootPart.Position
    local position, onScreen = Camera:WorldToViewportPoint(rootPosition)
    if not onScreen then return false, nil, nil end

    if not ESPConfig.DynamicBoxes then
        local humanoid = instance:IsA("Model") and ((runtime and runtime.Humanoid) or instance:FindFirstChild("Humanoid"))
        if humanoid then
            local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
            local topOffset = isR6 and 2.8 or 3.0
            local bottomOffset = isR6 and 3.0 or 3.5
            local top2D = Camera:WorldToViewportPoint(rootPosition + Vector3.new(0, topOffset, 0))
            local bottom2D = Camera:WorldToViewportPoint(rootPosition - Vector3.new(0, bottomOffset, 0))
            local height = math.abs(top2D.Y - bottom2D.Y)
            return true, Vector2.new(position.X, (top2D.Y + bottom2D.Y) / 2), Vector2.new(height * 0.65, height)
        end

        local cf, size
        if instance:IsA("Model") then
            cf, size = instance:GetBoundingBox()
        else
            cf, size = instance.CFrame, instance.Size
        end

        local minX, minY, maxX, maxY = ExpandFullProjectedBounds(
            cf, size, math.huge, math.huge, -math.huge, -math.huge
        )
        return true, Vector2.new((minX + maxX) / 2, (minY + maxY) / 2), Vector2.new(maxX - minX, maxY - minY)
    end

    if ESPConfig.DynamicBoxesCheap and instance:IsA("Model") then
        return GetFastCombinedProjectedBounds(instance, espObj, rootPart)
    end

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local includeAll = ESPConfig.DynamicBoxesIncludeAll
    local partCount = 0

    if instance:IsA("BasePart") then
        partCount = 1
        if ESPConfig.DynamicBoxesCheap then
            minX, minY, maxX, maxY = ExpandCheapProjectedBounds(instance, minX, minY, maxX, maxY)
        else
            minX, minY, maxX, maxY = ExpandFullProjectedBounds(instance.CFrame, instance.Size, minX, minY, maxX, maxY)
        end
    else
        for _, part in ipairs(EnsureBoundingPartCache(espObj, instance)) do
            if part.Parent and (includeAll or (part.Name ~= "HumanoidRootPart" and part.Transparency ~= 1)) then
                partCount = partCount + 1
                if ESPConfig.DynamicBoxesCheap then
                    minX, minY, maxX, maxY = ExpandCheapProjectedBounds(part, minX, minY, maxX, maxY)
                else
                    minX, minY, maxX, maxY = ExpandFullProjectedBounds(part.CFrame, part.Size, minX, minY, maxX, maxY)
                end
            end
        end
    end

    if partCount == 0 then return false, nil, nil end
    return true, Vector2.new((minX + maxX) / 2, (minY + maxY) / 2), Vector2.new(maxX - minX, maxY - minY)
end)

local function DisableESPObj(espObj)
    if not espObj then return end

    SetPropertyIfChanged(espObj.Container, "Visible", false)
    SetPropertyIfChanged(espObj.ArrowInner, "Visible", false)
    SetPropertyIfChanged(espObj.ArrowOutline, "Visible", false)
    SetPropertyIfChanged(espObj.ArrowName, "Visible", false)
    SetPropertyIfChanged(espObj.ArrowDist, "Visible", false)
    HideDrawings(espObj)

    espObj.ActiveChamType = nil
    if espObj.Highlight then
        SetPropertyIfChanged(espObj.Highlight, "Enabled", false)
    end
    SetAdornmentRecordsVisible(espObj, false)
    DestroyAdornmentProxyLayers(espObj)
    DestroyCharacterClone(espObj)
    if espObj.MeshShell then
        espObj.MeshShell:Destroy()
        espObj.MeshShell = nil
        espObj.MeshHighlight = nil
    end
    Destroy3DSkeleton(espObj)
end

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

local ScanDirectories = (function()
    local newTracked = {}

    if ESPConfig.Players then
        for _, player in ipairs(Players:GetPlayers()) do
            if not ESPConfig.LocalPlayer and player == LocalPlayer then continue end
            if player.Character then
                newTracked[player.Character] = {
                    name = player.Name,
                    Cheap = false,
                    Player = player,
                }
            end
        end
    end

    for key, config in pairs(ESPConfig.Directories) do
        local displayName = nil
        if type(config) == "table" and config.DisplayName and config.DisplayName ~= "" then
            displayName = config.DisplayName
        elseif type(key) == "string" and type(config) ~= "table" then
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
            else
                if CheckNames(inst, config.Names) and CheckContains(inst, config.Contains) and not CheckBlockNames(inst, config.BlockNames) then
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

    for inst, data in pairs(newTracked) do
        if not TrackedInstances[inst] then
            TrackedInstances[inst] = {
                espObj = CreateESPObj(data.name),
                name = data.name,
                Cheap = data.Cheap,
                NonHuman = data.NonHuman,
                NoStatus = data.NoStatus,
                Config = data.Config,
                Player = data.Player,
            }
            TrackedInstances[inst].Runtime = NewTrackedRuntime(inst, TrackedInstances[inst])
            if not ESPConfig.Enabled then
                DisableESPObj(TrackedInstances[inst].espObj)
            end
        else
            TrackedInstances[inst].name = data.name
            TrackedInstances[inst].Cheap = data.Cheap
            TrackedInstances[inst].NonHuman = data.NonHuman
            TrackedInstances[inst].NoStatus = data.NoStatus
            TrackedInstances[inst].Config = data.Config
            TrackedInstances[inst].Player = data.Player
            if TrackedInstances[inst].Runtime then
                TrackedInstances[inst].Runtime.Player = data.Player or TrackedInstances[inst].Runtime.Player
            else
                TrackedInstances[inst].Runtime = NewTrackedRuntime(inst, TrackedInstances[inst])
            end
        end
    end

    for inst, data in pairs(TrackedInstances) do
        local waitingForRespawn = data.Player
            and ESPConfig.Players
            and (ESPConfig.LocalPlayer or data.Player ~= LocalPlayer)
            and data.Player.Parent
            and data.Player.Character == nil
            and inst.Parent

        if (not newTracked[inst] and not waitingForRespawn) or not inst.Parent then
            DestroyTrackedRuntime(data)
            data.espObj:Destroy()
            TrackedInstances[inst] = nil
        end
    end
end)

local function DisconnectCharacterConnections(player)
    local connections = CharacterConnections[player]
    if not connections then
        return
    end

    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    CharacterConnections[player] = nil
end

local ScheduleDirectoryScan

local function WatchPlayerCharacters(player)
    if CharacterConnections[player] then
        return
    end

    CharacterConnections[player] = {
        Added = player.CharacterAdded:Connect(function() ScheduleDirectoryScan() end),
        Removing = player.CharacterRemoving:Connect(function() ScheduleDirectoryScan() end),
    }
end

local lastScan = 0
local lastRender = 0
local pendingDirectoryScan = false

ScheduleDirectoryScan = function()
    pendingDirectoryScan = true
end

local function RuntimeStep()
    if not ESPActive then return end
    if not ESPConfig.Enabled then
        if ESPRenderEnabled then
            for _, data in pairs(TrackedInstances) do
                DisableESPObj(data.espObj)
            end
            ESPRenderEnabled = false
        end
        return
    end

    local now = tick()

    if not ESPRenderEnabled then
        ESPRenderEnabled = true
        lastRender = 0
        lastScan = 0
    end

    if not Camera then return end

    local limitFps = ESPConfig.LimitFPS
    if limitFps and limitFps > 0 then
        if now - lastRender < (1 / limitFps) then return end
        lastRender = now
    end

    if pendingDirectoryScan and now - lastScan > 0.25 then
        pendingDirectoryScan = false
        lastScan = now
        ScanDirectories()
    elseif next(ESPConfig.Directories) ~= nil and now - lastScan > 1 then
        lastScan = now
        ScanDirectories()
    end

    BumpConfigRevision()

    local cameraPosition = Camera.CFrame.Position
    local maxDistance = ESPConfig.MaxDistance or 0
    local cullSquared = maxDistance > 0 and maxDistance * maxDistance or 0
    local dead

    for inst, data in pairs(TrackedInstances) do
        if not inst or not inst.Parent then
            dead = dead or {}
            dead[#dead + 1] = inst
            continue
        end

        local runtime = data.Runtime
        if not runtime then
            runtime = NewTrackedRuntime(inst, data)
            data.Runtime = runtime
        end
        local rootPart = runtime.RootPart or (inst:IsA("BasePart") and inst)

        if rootPart then
            local offset = cameraPosition - rootPart.Position
            local distanceSquared = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

            if cullSquared > 0 and distanceSquared > cullSquared then
                DisableESPObj(data.espObj)
                continue
            end

            local onscreen, pos2d, size2d = false, nil, nil
            if Needs2DGeometry(data.Config, data.Cheap, inst, data.NoStatus, runtime) then
                onscreen, pos2d, size2d = Get2DBoundingBox(inst, data.espObj, runtime)
            elseif not data.Cheap and ResolveESPConfigValue(data.Config, "Skeleton.Enabled") then
                local _, rootOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
                onscreen = rootOnScreen
            end
            local distanceStuds = 0
            if NeedsDistanceValue(data.Config, data.Cheap) then
                distanceStuds = math.sqrt(distanceSquared)
            end
            UpdateESPObj(data.espObj, pos2d, size2d, data.name, distanceStuds, inst, data.Cheap, data.NonHuman,
                data.NoStatus, data.Config, onscreen, runtime)
        else
            UpdateESPObj(data.espObj, nil, nil, data.name, 0, inst, data.Cheap, data.NonHuman, data.NoStatus, data
                .Config, false, runtime)
        end
    end

    if dead then
        for _, inst in ipairs(dead) do
            local data = TrackedInstances[inst]
            if data then
                DestroyTrackedRuntime(data)
                data.espObj:Destroy()
                TrackedInstances[inst] = nil
            end
        end
    end
end

function ESP:Unload()
    ESPActive = false
    ESPRenderEnabled = false

    for inst, data in pairs(TrackedInstances) do
        DestroyTrackedRuntime(data)
        if data.espObj then
            data.espObj:Destroy()
        end
        TrackedInstances[inst] = nil
    end

    if PlayerRemovingConnection then
        PlayerRemovingConnection:Disconnect()
        PlayerRemovingConnection = nil
    end
    if PlayerAddedConnection then
        PlayerAddedConnection:Disconnect()
        PlayerAddedConnection = nil
    end
    local watchedPlayers = {}
    for player in pairs(CharacterConnections) do
        watchedPlayers[#watchedPlayers + 1] = player
    end
    for _, player in ipairs(watchedPlayers) do
        DisconnectCharacterConnections(player)
    end
    if InputBeganConnection then
        InputBeganConnection:Disconnect()
        InputBeganConnection = nil
    end
    if CameraConnection then
        CameraConnection:Disconnect()
        CameraConnection = nil
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
    ESPActive = true
    ESPRenderEnabled = false
    CurrentRunId = HttpService:GenerateGUID(false)
    lastScan = 0
    lastRender = 0
    Camera = Workspace.CurrentCamera
    table.clear(FriendStatusCache)

    CameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = Workspace.CurrentCamera
    end)

    PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        FriendStatusCache[player.UserId] = nil
        DisconnectCharacterConnections(player)
        for inst, data in pairs(TrackedInstances) do
            local runtimePlayer = data.Runtime and data.Runtime.Player or nil
            if data.Player == player or runtimePlayer == player or Players:GetPlayerFromCharacter(inst) == player then
                DestroyTrackedRuntime(data)
                data.espObj:Destroy()
                TrackedInstances[inst] = nil
            end
        end
    end)

    PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
        FriendStatusCache[player.UserId] = nil
        WatchPlayerCharacters(player)
        ScheduleDirectoryScan()
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        WatchPlayerCharacters(player)
    end

    InputBeganConnection = UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and ESPConfig.Keybind.Enabled and input.KeyCode == ESPConfig.Keybind.Key then
            ESPConfig.Enabled = not ESPConfig.Enabled
        end
    end)

    getgenv().SensoryESP_Loop = RunService.RenderStepped:Connect(RuntimeStep)
    ScanDirectories()
    return self
end

function ESP:Refresh()
    if ESPActive then
        ScanDirectories()
    end
end

function ESP:ClearSkeletons()
    for _, data in pairs(TrackedInstances) do
        if data and data.espObj then
            Destroy3DSkeleton(data.espObj)
        end
    end


    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Folder") and object.Name == "SensorySkeleton3D" then
            pcall(function()
                object:Destroy()
            end)
        elseif object:IsA("BasePart")
            and (object.Name == "SensorySkeletonAnchor"
                or object.Name == "SensorySkeletonSegment"
                or object.Name == "SensorySkeletonJoint") then
            pcall(function()
                object:Destroy()
            end)
        end
    end
end

function ESP:GetConfig()
    return ESPConfig
end


getgenv().SensoryESP_Unload = function()
    ESP:Unload()
end

return ESP

end)()
drain_boot_log("esp module built")
SensoryESP:Load()
drain_boot_log("esp loaded")
local SensoryESPConfig = SensoryESP:GetConfig()
Library.PlayerStatusColors = SensoryESPConfig.PlayerStatusColors

do
    local ok, err = pcall(function()
        local networking = RepSt:WaitForChild("Networking\013", 10)
        local remote = networking and (networking:FindFirstChild("RemoteEvent\013") or networking:GetChildren()[2])
        if not (remote and remote:IsA("RemoteEvent")) then return end
        remote.OnClientEvent:Connect(function(action, player, weaponName)
            if action == "Replicate Shot"
                and typeof(player) == "Instance" and player:IsA("Player")
                and type(weaponName) == "string" and weaponName ~= "" then
                ReplicateWeaponNames[player] = { Name = weaponName, T = os.clock() }
            end
        end)
    end)
    if not ok then
        drain_report_fail("weapon remote", err)
    end
end

do
    local ExploitDetect = { -- wrong game bro
        Flagged = {},
        Ids = {
            ["282574440"] = true,
            ["215384594"] = true,
        },
        Seen = setmetatable({}, { __mode = "k" }),
        Conns = setmetatable({}, { __mode = "k" }),
        NextPoll = 0,
    }

    Library.ExploitFlags = ExploitDetect.Flagged

    ExploitDetect.IsCheatId = function(id)
        if type(id) ~= "string" or id == "" then return false end
        local num = string.match(id, "(%d+)%s*$")
        return num ~= nil and ExploitDetect.Ids[num] == true
    end

    ExploitDetect.Unbind = function(player)
        local conn = ExploitDetect.Conns[player]
        if not conn then return end
        pcall(function() conn:Disconnect() end)
        ExploitDetect.Conns[player] = nil
    end

    ExploitDetect.Mark = function(player)
        if not player or player == LP then return end
        local userId = player.UserId
        if ExploitDetect.Flagged[userId] then return end
        ExploitDetect.Flagged[userId] = true

        ExploitDetect.Unbind(player)
        Library:Notify(player.Name .. " is exploiting", 5)
    end

    ExploitDetect.ScanTracks = function(animator, player)
        local ok, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
        if not ok or type(tracks) ~= "table" then return end
        for _, track in ipairs(tracks) do
            local anim = track.Animation
            if anim and ExploitDetect.IsCheatId(anim.AnimationId) then
                ExploitDetect.Mark(player)
                return
            end
        end
    end

    ExploitDetect.Bind = function(player, animator)
        ExploitDetect.Seen[animator] = true
        ExploitDetect.Unbind(player)

        ExploitDetect.Conns[player] = animator.AnimationPlayed:Connect(function(track)
            local anim = track and track.Animation
            if anim and ExploitDetect.IsCheatId(anim.AnimationId) then
                ExploitDetect.Mark(player)
            end
        end)

        ExploitDetect.ScanTracks(animator, player)
    end

    ExploitDetect.Poll = function()
        for _, player in ipairs(Plrs:GetPlayers()) do
            if player ~= LP and not ExploitDetect.Flagged[player.UserId] then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    if ExploitDetect.Seen[animator] then
                        ExploitDetect.ScanTracks(animator, player)
                    else
                        ExploitDetect.Bind(player, animator)
                    end
                end
            end
        end
    end

    Library:GiveSignal(RS.Heartbeat:Connect(function()
        local now = os.clock()
        if now < ExploitDetect.NextPoll then return end
        ExploitDetect.NextPoll = now + 0.4
        ExploitDetect.Poll()
    end))

    Library:GiveSignal(Plrs.PlayerRemoving:Connect(function(player)
        ExploitDetect.Unbind(player)
    end))

    Library:OnUnload(function()
        for player in pairs(ExploitDetect.Conns) do
            ExploitDetect.Unbind(player)
        end
        table.clear(ExploitDetect.Flagged)
        Library.ExploitFlags = nil
    end)
end
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
    Callback = function(value)
        SensoryESPConfig.Enabled = value

        if not value then
            SensoryESP:ClearSkeletons()
        end
    end,
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
    Callback = function(value) SensoryESPConfig.Players = value; SensoryESP:Refresh() end,
})

SensoryGeneral:AddToggle('SensoryZombiesESP', {
    Text = 'Zombies ESP',
    Default = true,
    Tooltip = 'workspace.Zombies children, one ESP per model.',
    Callback = function(value)
        if value then
            SensoryESPConfig.Directories.Zombies = { Path = 'workspace.Zombies', Multiple = true }
        else
            SensoryESPConfig.Directories.Zombies = nil
        end
        SensoryESP:Refresh()
    end,
})

SensoryGeneral:AddToggle('SensoryCorpsesESP', {
    Text = 'Corpses ESP',
    Default = true,
    Tooltip = 'workspace.Corpses children. Model names are uuids, so a fixed tag is used.',
    Callback = function(value)
        if value then
            SensoryESPConfig.Directories.Corpses = { Path = 'workspace.Corpses', Multiple = true, DisplayName = 'Corpse', NoStatus = true }
        else
            SensoryESPConfig.Directories.Corpses = nil
        end
        SensoryESP:Refresh()
    end,
})

SensoryGeneral:AddToggle('SensoryVehiclesESP', {
    Text = 'Vehicles ESP',
    Default = true,
    Tooltip = 'workspace.Vehicles children (Jeep etc.).',
    Callback = function(value)
        if value then
            SensoryESPConfig.Directories.Vehicles = { Path = 'workspace.Vehicles', Multiple = true, NoStatus = true }
        else
            SensoryESPConfig.Directories.Vehicles = nil
        end
        SensoryESP:Refresh()
    end,
})

SensoryGeneral:AddInput('SensoryCustomFolder', {
    Text = 'Custom folder path',
    Default = '',
    Finished = true,
    Placeholder = 'workspace.FolderName',
    Tooltip = 'Tracks every Model/Part inside that folder. Empty = off.',
    Callback = function(value)
        value = tostring(value or ''):match('^%s*(.-)%s*$') or ''
        if value == '' then
            SensoryESPConfig.Directories.CustomFolder = nil
        else
            SensoryESPConfig.Directories.CustomFolder = { Path = value, Multiple = true }
        end
        SensoryESP:Refresh()
    end,
})
SensoryGeneral:AddToggle('SensoryLocalPlayer', {
    Text = 'Include local player',
    Default = false,
    Callback = function(value) SensoryESPConfig.LocalPlayer = value; SensoryESP:Refresh() end,
})

SensoryGeneral:AddSlider('SensoryLimitFPS', {
    Text = 'ESP FPS limit',
    Default = 0,
    Min = 0,
    Max = 240,
    Rounding = 0,
    Suffix = ' FPS',
    Tooltip = '0 = every framзз зe. Set it below your actual frame rate or it does nothing.',
    Callback = function(value) SensoryESPConfig.LimitFPS = value end,
})

SensoryGeneral:AddSlider('SensoryMaxDistance', {
    Text = 'ESP max distance',
    Default = 0,
    Min = 0,
    Max = 5000,
    Rounding = 0,
    Suffix = ' st',
    Tooltip = 'Skips all drawing work for targets past this range. 0 = no limit.',
    Callback = function(value) SensoryESPConfig.MaxDistance = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicBoxes', {
    Text = 'Dynamic boxes',
    Default = true,
    Callback = function(value) SensoryESPConfig.DynamicBoxes = value end,
})

SensoryGeneral:AddToggle('SensoryDrawingMode', { --jerking my shit rn
    Text = 'Drawing mode',
    Default = false,
    Tooltip = 'Renders box, names, distance, weapon, bars and flags with Drawing instead of GUI frames. Gradients and team/friendly tags are dropped',
    Callback = function(value) SensoryESPConfig.DrawingMode = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicCheap', {
    Text = 'Cheap dynamic boxes',
    Default = true,
    Tooltip = 'Big FPS win. Turn off only if box edges look slightly loose',
    Callback = function(value) SensoryESPConfig.DynamicBoxesCheap = value end,
})

SensoryGeneral:AddToggle('SensoryDynamicAll', {
    Text = 'Include all body parts',
    Default = false,
    Callback = function(value) SensoryESPConfig.DynamicBoxesIncludeAll = value end,
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
    Values = {'Normal', 'Corner'},
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
    Text = 'ESP flags',
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
SensoryFlags:AddToggle('SensoryFlagForceField', {
    Text = 'ForceField flag',
    Default = false,
    Callback = function(value) SensoryESPConfig.Flags.Options.ForceField = value end,
}):AddColorPicker('SensoryFlagForceFieldColor', {
    Default = Color3.fromRGB(0, 140, 255),
    Title = 'ForceField flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.ForceField = color end,
})
SensoryFlags:AddToggle('SensoryFlagExploiting', {
    Text = 'Exploiting flag',
    Default = false,
    Tooltip = 'Flags players once a known exploit animation is seen. Stays for the session.',
    Callback = function(value) SensoryESPConfig.Flags.Options.Exploiting = value end,
}):AddColorPicker('SensoryFlagExploitingColor', {
    Default = Color3.fromRGB(255, 45, 45),
    Title = 'Exploiting flag',
    Callback = function(color) SensoryESPConfig.Flags.Colors.Exploiting = color end,
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
    Callback = function(value)
        SensoryESPConfig.Skeleton.Enabled = value

        if not value then
            SensoryESP:ClearSkeletons()
        end
    end,
})
SensorySkeletonToggle:AddColorPicker('SensorySkeletonColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Skeleton color',
    Callback = function(color) SensoryESPConfig.Skeleton.Color = color end,
})
SensoryFlags:AddSlider('SensorySkeletonThickness', {
    Text = 'Skeleton thickness',
    Default = 1.5,
    Min = 0.5,
    Max = 4,
    Rounding = 1,
    Suffix = 'px',
    Callback = function(value) SensoryESPConfig.Skeleton.Thickness = value end,
})
SensoryFlags:AddToggle('SensorySkeletonJoints', {
    Text = 'Skeleton joints',
    Default = true,
    Callback = function(value) SensoryESPConfig.Skeleton.Joints = value end,
})
SensoryFlags:AddSlider('SensorySkeletonJointScale', {
    Text = 'Skeleton joint size',
    Default = 1,
    Min = 0.5,
    Max = 2,
    Rounding = 1,
    Suffix = 'x',
    Callback = function(value) SensoryESPConfig.Skeleton.JointScale = value end,
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
    Values = Library.IsMobile
        and {'Highlight', 'BoxHandleAdornment'}
        or {'Highlight', 'BoxHandleAdornment', 'CharacterClone', 'MeshChams'},
    Default = 'Highlight',
    Tooltip = 'Highlight is the cheapest. MeshChams looks best but rebuilds shells on respawn',
    Callback = function(value) SensoryESPConfig.Chams.Type = value end,
})
SensoryChams:AddSlider('SensoryChamsRefreshRate', {
    Text = '3D chams refresh rate',
    Default = 0.1,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Suffix = 's',
    Callback = function(value) SensoryESPConfig.Chams.RefreshRate = value end,
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

SensoryChams:AddLabel('Invisible chams'):AddColorPicker('SensoryInvisibleChamColor', {
    Default = Color3.fromRGB(59, 144, 204),
    Transparency = 0.7,
    Title = 'Invisible chams',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.Adornment.Invisible.Color = color
        if alpha ~= nil then SensoryESPConfig.Chams.Adornment.Invisible.Transparency = alpha end
    end,
})
SensoryChams:AddToggle('SensoryVisibleChams', {
    Text = 'Visible chams',
    Default = true,
    Callback = function(value) SensoryESPConfig.Chams.Adornment.Visible.Enabled = value end,
}):AddColorPicker('SensoryVisibleChamColor', {
    Default = Color3.fromRGB(59, 204, 90),
    Transparency = 0.35,
    Title = 'Visible chams',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.Adornment.Visible.Color = color
        if alpha ~= nil then SensoryESPConfig.Chams.Adornment.Visible.Transparency = alpha end
    end,
})
SensoryChams:AddSlider('SensoryVisibleChamSize', {
    Text = 'Visible size increase',
    Default = 10,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = ' /100 st',
    Tooltip = 'How many studs / 100 the visible layer is larger than the invisible layer.',
    Callback = function(value) SensoryESPConfig.Chams.Adornment.VisibleSize = value / 100 end,
})
SensoryChams:AddToggle('SensoryRoundChamHead', {
    Text = 'Round head',
    Default = false,
    Tooltip = 'Uses a correctly oriented CylinderHandleAdornment for the head.',
    Callback = function(value) SensoryESPConfig.Chams.Adornment.RoundHead = value end,
})
SensoryChams:AddSlider('SensoryR6RoundChamHeadScale', {
    Text = 'R6 round head width',
    Default = 86,
    Min = 60,
    Max = 100,
    Rounding = 0,
    Suffix = '%',
    Tooltip = 'Width of the round R6 head relative to the original cylinder size.',
    Callback = function(value) SensoryESPConfig.Chams.Adornment.R6HeadScale = value / 100 end,
})

local SensoryAdornmentGlowToggle
SensoryAdornmentGlowToggle = SensoryChams:AddToggle('SensoryAdornmentXRayGlow', {
    Text = 'XRay adornment glow',
    Default = false,
    Tooltip = Library.IsMobile
        and 'Disabled on touch devices because this renderer can crash the Roblox client.'
        or 'Adds an HDR XRayShaded glow visible through walls; falls back to an AlwaysOnTop outer layer.',
    Callback = function(value)
        if Library.IsMobile and value then
            SensoryESPConfig.Chams.Adornment.Glow.Enabled = false
            task.defer(function()
                if SensoryAdornmentGlowToggle and SensoryAdornmentGlowToggle.Value then
                    SensoryAdornmentGlowToggle:SetValue(false)
                end
            end)
            Library:Notify('Adornment glow is disabled on mobile for stability.', 4)
            return
        end
        SensoryESPConfig.Chams.Adornment.Glow.Enabled = value
    end,
})
SensoryAdornmentGlowToggle:AddColorPicker('SensoryAdornmentXRayGlowColor', {
    Default = Color3.fromRGB(59, 144, 204),
    Title = 'XRay adornment glow',
    Callback = function(color) SensoryESPConfig.Chams.Adornment.Glow.Color = color end,
})
SensoryChams:AddSlider('SensoryAdornmentXRayGlowIntensity', {
    Text = 'Glow intensity',
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = 'x',
    Callback = function(value) SensoryESPConfig.Chams.Adornment.Glow.Intensity = value end,
})
SensoryChams:AddSlider('SensoryAdornmentXRayGlowSize', {
    Text = 'Glow size increase',
    Default = 3,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Suffix = ' /100 st',
    Callback = function(value) SensoryESPConfig.Chams.Adornment.Glow.Size = value / 100 end,
})

SensoryChams:AddToggle('SensoryInvisibleChamHighlight', {
    Text = 'Invisible highlight',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Adornment.Invisible.Highlight.Enabled = value end,
})
SensoryChams:AddLabel('Invisible highlight fill'):AddColorPicker('SensoryInvisibleHighlightFill', {
    Default = Color3.fromRGB(59, 144, 204),
    Transparency = 1,
    Title = 'Invisible highlight fill',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.Adornment.Invisible.Highlight
        highlight.FillColor = color
        highlight.FillTransparency = alpha
    end,
})
SensoryChams:AddLabel('Invisible highlight outline'):AddColorPicker('SensoryInvisibleHighlightOutline', {
    Default = Color3.fromRGB(59, 144, 204),
    Transparency = 0,
    Title = 'Invisible highlight outline',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.Adornment.Invisible.Highlight
        highlight.OutlineColor = color
        highlight.OutlineTransparency = alpha
    end,
})

SensoryChams:AddToggle('SensoryVisibleChamHighlight', {
    Text = 'Visible highlight',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.Adornment.Visible.Highlight.Enabled = value end,
})
SensoryChams:AddLabel('Visible highlight fill'):AddColorPicker('SensoryVisibleHighlightFill', {
    Default = Color3.fromRGB(59, 204, 90),
    Transparency = 1,
    Title = 'Visible highlight fill',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.Adornment.Visible.Highlight
        highlight.FillColor = color
        highlight.FillTransparency = alpha
    end,
})
SensoryChams:AddLabel('Visible highlight outline'):AddColorPicker('SensoryVisibleHighlightOutline', {
    Default = Color3.fromRGB(59, 204, 90),
    Transparency = 0,
    Title = 'Visible highlight outline',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.Adornment.Visible.Highlight
        highlight.OutlineColor = color
        highlight.OutlineTransparency = alpha
    end,
})

SensoryChams:AddLabel('Character clone'):AddColorPicker('SensoryCharacterCloneColor', {
    Default = Color3.fromRGB(190, 195, 205),
    Transparency = 0.55,
    Title = 'Character clone',
    Callback = function(color, alpha)
        SensoryESPConfig.Chams.CharacterClone.Color = color
        if alpha ~= nil then SensoryESPConfig.Chams.CharacterClone.Transparency = alpha end
    end,
})
SensoryChams:AddDropdown('SensoryCharacterCloneMaterial', {
    Text = 'Clone material',
    Values = {'SmoothPlastic', 'ForceField', 'Neon', 'Glass'},
    Default = 'SmoothPlastic',
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.Material = value end,
})
SensoryChams:AddSlider('SensoryCharacterCloneSize', {
    Text = 'Clone size',
    Default = 101.5,
    Min = 100,
    Max = 110,
    Rounding = 1,
    Suffix = '%',
    Tooltip = 'Slightly enlarges the copied geometry to prevent z-fighting.',
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.SizeScale = value / 100 end,
})
SensoryChams:AddToggle('SensoryCharacterCloneAccessories', {
    Text = 'Clone accessories',
    Default = true,
    Tooltip = 'Includes accessory Handles, MeshParts and SpecialMeshes.',
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.IncludeAccessories = value end,
})
SensoryChams:AddToggle('SensoryCharacterCloneTextures', {
    Text = 'Keep clone textures',
    Default = false,
    Tooltip = 'Keeps MeshPart, SpecialMesh, decal and SurfaceAppearance textures.',
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.KeepTextures = value end,
})
SensoryChams:AddToggle('SensoryCharacterCloneHighlight', {
    Text = 'Clone highlight',
    Default = true,
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.Highlight.Enabled = value end,
})
SensoryChams:AddLabel('Clone highlight fill'):AddColorPicker('SensoryCharacterCloneHighlightFill', {
    Default = Color3.fromRGB(190, 195, 205),
    Transparency = 0.75,
    Title = 'Clone highlight fill',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.CharacterClone.Highlight
        highlight.FillColor = color
        highlight.FillTransparency = alpha
    end,
})
SensoryChams:AddLabel('Clone highlight outline'):AddColorPicker('SensoryCharacterCloneHighlightOutline', {
    Default = Color3.fromRGB(255, 255, 255),
    Transparency = 0.25,
    Title = 'Clone highlight outline',
    Callback = function(color, alpha)
        local highlight = SensoryESPConfig.Chams.CharacterClone.Highlight
        highlight.OutlineColor = color
        highlight.OutlineTransparency = alpha
    end,
})
SensoryChams:AddToggle('SensoryCharacterCloneVisible', {
    Text = 'Clone highlight visible check',
    Default = false,
    Callback = function(value) SensoryESPConfig.Chams.CharacterClone.Highlight.VisibleCheck = value end,
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

drain_boot_log("all feature pages built")

local SettingsPage = Window:AddTab('Settings')
local MenuSection = SettingsPage:AddColumnGroupbox(3, 'Menu')
drain_boot_log("settings tab created")

do
    local CustomBackgroundSection = SettingsPage:AddLeftGroupbox('Custom Background')
    local CustomBackgroundState = {
        Enabled = false,
        Location = '',
        ImageTransparency = 0.35,
        PanelTransparency = 0.2,
        ScaleType = 'Crop',
    }
    local DetectedSourceLabel
    local ApplyGeneration = 0
    local CacheMetaPath = 'drain.solutions/custom_background_cache.txt'
    local AssetGetter = getcustomasset or getsynasset

    local function trim(value)
        return tostring(value or ''):match('^%s*(.-)%s*$') or ''
    end

    local function notifyBackground(message)
        Library:Notify('Custom Background: ' .. tostring(message), 6)
    end

    local function detectBackgroundSource(location)
        location = trim(location):lower()
        return location:match('^https?://') and 'Raw URL' or 'Workspace file'
    end

    local function refreshDetectedSource()
        local source = detectBackgroundSource(CustomBackgroundState.Location)
        if DetectedSourceLabel then
            DetectedSourceLabel:SetText('Detected source: ' .. source)
        end
        return source
    end

    local function assetFromFile(path)
        path = trim(path)
        if path == '' then
            return nil, 'enter a workspace file path'
        end
        if type(isfile) ~= 'function' or not isfile(path) then
            return nil, 'file was not found: ' .. path
        end
        if type(AssetGetter) ~= 'function' then
            return nil, 'Volt does not provide getcustomasset/getsynasset'
        end

        local success, asset = pcall(AssetGetter, path)
        if not success or type(asset) ~= 'string' or asset == '' then
            return nil, 'failed to load the workspace image'
        end
        return asset
    end

    local function detectImageExtension(data, url)
        if data:sub(1, 8) == '\137PNG\r\n\26\n' then
            return '.png'
        end
        if data:sub(1, 3) == '\255\216\255' then
            return '.jpg'
        end
        if data:sub(1, 4) == 'RIFF' and data:sub(9, 12) == 'WEBP' then
            return '.webp'
        end

        local cleanUrl = tostring(url):match('^[^%?]+') or ''
        local extension = cleanUrl:lower():match('(%.[%a%d]+)$')
        if extension == '.png' or extension == '.jpg' or extension == '.jpeg' or extension == '.webp' then
            return extension == '.jpeg' and '.jpg' or extension
        end
        return nil
    end

    local function ensureBackgroundFolder()
        if type(isfolder) == 'function' and type(makefolder) == 'function'
            and not isfolder('drain.solutions') then
            local success = pcall(makefolder, 'drain.solutions')
            if not success then
                return false
            end
        end
        return true
    end

    local function cachedRawAsset(url)
        if type(isfile) ~= 'function' or type(readfile) ~= 'function' or not isfile(CacheMetaPath) then
            return nil
        end

        local success, metadata = pcall(readfile, CacheMetaPath)
        if not success or type(metadata) ~= 'string' then
            return nil
        end

        local cachedUrl, cachedPath = metadata:match('^(.-)\n(.+)$')
        if trim(cachedUrl) ~= url or not cachedPath or not isfile(cachedPath) then
            return nil
        end

        return assetFromFile(cachedPath)
    end

    local function rawAsset(url, forceRefresh)
        url = trim(url)
        if not url:match('^https?://') then
            return nil, 'enter a direct http(s) raw image URL'
        end
        if type(game.HttpGet) ~= 'function' or type(writefile) ~= 'function' then
            return nil, 'Volt does not provide HttpGet/writefile'
        end

        if not forceRefresh then
            local cached = cachedRawAsset(url)
            if cached then
                return cached
            end
        end

        local downloadSuccess, data = pcall(function()
            return game:HttpGet(url)
        end)
        if not downloadSuccess or type(data) ~= 'string' or data == '' then
            return nil, 'the raw URL could not be downloaded'
        end
        if #data > 20 * 1024 * 1024 then
            return nil, 'image is larger than 20 MB'
        end

        local extension = detectImageExtension(data, url)
        if not extension then
            return nil, 'raw URL must return a PNG, JPG or WEBP image'
        end
        if not ensureBackgroundFolder() then
            return nil, 'failed to create the drain.solutions folder'
        end

        local cachePath = 'drain.solutions/custom_background_cache' .. extension
        local writeSuccess = pcall(writefile, cachePath, data)
        if not writeSuccess then
            return nil, 'failed to cache the downloaded image'
        end
        pcall(writefile, CacheMetaPath, url .. '\n' .. cachePath)

        return assetFromFile(cachePath)
    end

    local function resolveBackgroundAsset(forceRefresh)
        if detectBackgroundSource(CustomBackgroundState.Location) == 'Raw URL' then
            return rawAsset(CustomBackgroundState.Location, forceRefresh)
        end
        return assetFromFile(CustomBackgroundState.Location)
    end

    local function disableBackgroundToggle()
        local toggle = Toggles.Settings_CustomBackgroundEnabled
        if toggle and toggle.Value then
            toggle:SetValue(false)
        else
            CustomBackgroundState.Enabled = false
            Library:SetCustomBackgroundEnabled(false)
        end
    end

    local function applyCustomBackground(forceRefresh)
        ApplyGeneration += 1
        local generation = ApplyGeneration

        Library:SetCustomBackgroundTransparency(CustomBackgroundState.ImageTransparency)
        Library:SetCustomBackgroundPanelTransparency(CustomBackgroundState.PanelTransparency)
        Library:SetCustomBackgroundScaleType(CustomBackgroundState.ScaleType)

        if not CustomBackgroundState.Enabled then
            Library:SetCustomBackgroundEnabled(false)
            return
        end

        local asset, err = resolveBackgroundAsset(forceRefresh)
        if generation ~= ApplyGeneration or not CustomBackgroundState.Enabled then
            return
        end
        if not asset then
            Library:SetCustomBackgroundEnabled(false)
            notifyBackground(err or 'failed to load image')
            disableBackgroundToggle()
            return
        end

        Library:SetCustomBackgroundAsset(asset)
        Library:SetCustomBackgroundEnabled(true)
        notifyBackground(detectBackgroundSource(CustomBackgroundState.Location) == 'Raw URL'
            and 'raw image applied'
            or 'workspace image applied')
    end

    CustomBackgroundSection:AddToggle('Settings_CustomBackgroundEnabled', {
        Text = 'Enabled',
        Default = false,
        Callback = function(value)
            CustomBackgroundState.Enabled = value
            if not value then
                ApplyGeneration += 1
                Library:SetCustomBackgroundEnabled(false)
                return
            end
            task.spawn(function()
                applyCustomBackground(false)
            end)
        end,
    })

    CustomBackgroundSection:AddInput('Settings_CustomBackgroundLocation', {
        Text = 'Workspace path / raw URL (auto)',
        Default = '',
        Finished = false,
        Placeholder = 'drain.solutions/background.png',
        Tooltip = 'http(s) is detected as a raw URL. Every other value is treated as an executor workspace path.',
        Callback = function(value)
            CustomBackgroundState.Location = trim(value)
            refreshDetectedSource()
        end,
    })

    DetectedSourceLabel = CustomBackgroundSection:AddLabel('Detected source: Workspace file')

    CustomBackgroundSection:AddDropdown('Settings_CustomBackgroundScale', {
        Text = 'Image scaling',
        Values = { 'Crop', 'Fit', 'Stretch' },
        Default = 'Crop',
        Multi = false,
        Callback = function(value)
            CustomBackgroundState.ScaleType = value
            Library:SetCustomBackgroundScaleType(value)
        end,
    })

    CustomBackgroundSection:AddSlider('Settings_CustomBackgroundTransparency', {
        Text = 'Image transparency',
        Default = 35,
        Min = 0,
        Max = 95,
        Rounding = 0,
        Suffix = '%',
        Callback = function(value)
            CustomBackgroundState.ImageTransparency = value / 100
            Library:SetCustomBackgroundTransparency(CustomBackgroundState.ImageTransparency)
        end,
    })

    CustomBackgroundSection:AddSlider('Settings_CustomBackgroundPanelTransparency', {
        Text = 'Panel transparency',
        Default = 20,
        Min = 0,
        Max = 90,
        Rounding = 0,
        Suffix = '%',
        Callback = function(value)
            CustomBackgroundState.PanelTransparency = value / 100
            Library:SetCustomBackgroundPanelTransparency(CustomBackgroundState.PanelTransparency)
        end,
    })

    CustomBackgroundSection:AddButton({
        Text = 'Apply / reload',
        Func = function()
            local toggle = Toggles.Settings_CustomBackgroundEnabled
            if toggle and not toggle.Value then
                toggle:SetValue(true)
                return
            end
            task.spawn(function()
                applyCustomBackground(true)
            end)
        end,
    }):AddButton({
        Text = 'Disable',
        Func = disableBackgroundToggle,
    })
end
drain_boot_log("custom background section built")

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
        if type(getgenv().DrainLightingCleanup) == 'function' then
            pcall(getgenv().DrainLightingCleanup)
            getgenv().DrainLightingCleanup = nil
        end
        SensoryESP:Unload()
        Library:Unload()
    end,
})

drain_boot_log("menu section built")

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
drain_boot_log("managers bound")

ThemeManager:SetFolder('drain.solutions')
drain_boot_log("theme folder ready")

SaveManager:SetFolder('drain.solutions')
drain_boot_log("save folder ready")

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'PlayerList_Priority' })
drain_boot_log("save manager configured")

ThemeManager:ApplyToTab(SettingsPage)
drain_boot_log("theme tab applied")

SaveManager:BuildConfigSection(SettingsPage)
drain_boot_log("settings page built, applying autoload config")

SaveManager:LoadAutoloadConfig()
drain_boot_log("autoload config applied")

drain_boot_log("done")
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
    drain_report_fail("load after " .. tostring(DRAIN_LAST_STAGE), LoadError)
end

end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Ok, Err = pcall(RunDrain)

if not Ok then
    drain_report_fail('drain', Err)
end
