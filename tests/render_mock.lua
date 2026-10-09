-- Geometry-aware frames for tests/render.py. Loaded after the API globals of smoke.lua; replaces
-- CreateFrame and UIParent so every frame, texture and font string remembers what it would show
-- and where. `RenderDump(root)` lays the tree out like the client and returns a flat draw list.

local registry = {}
local rects = {}
local serial = 0
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local NUMERIC = { GetLeft = 0, GetTop = 0, GetStringHeight = 12, GetNumPoints = 1 }

local M = {}

local function New(kind, parent, extra)
    serial = serial + 1
    local o = { _kind = kind, _parent = parent, _points = {}, _shown = true, _scripts = {}, _hooks = {},
        _scale = 1, _alpha = 1, _serial = serial, _children = {}, _regions = {} }
    for k, v in pairs(extra or {}) do o[k] = v end
    registry[#registry + 1] = o
    return setmetatable(o, { __index = function(_, k)
        if M[k] then return M[k] end
        if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
        if NUMERIC[k] then return function() return NUMERIC[k] end end
        if type(k) == "string" and k:match("^Create") then
            return function(self) return New("other", self) end
        end
        return function() end
    end })
end

local function NewFrame(kind, parent)
    local f = New(kind, parent)
    f._level = parent and (rawget(parent, "_level") or 0) + 1 or 0
    if parent and type(rawget(parent, "_children")) == "table" then table.insert(parent._children, f) end
    return f
end

-- Points and size ---------------------------------------------------------------------------------

function M:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then
        rel, relPoint, x, y = nil, point, rel, relPoint
    elseif type(relPoint) == "number" then
        relPoint, x, y = point, relPoint, x
    end
    if type(rel) == "string" then rel = _G[rel] end
    if type(rel) ~= "table" then rel = rawget(self, "_parent") end
    self._points[point] = { rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
function M:ClearAllPoints() self._points = {} end
function M:SetAllPoints(rel)
    if type(rel) ~= "table" then rel = self._parent end
    self._points = {}
    self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end
function M:SetSize(w, h) self._w, self._h = w, h end
function M:SetWidth(w) self._w = w end
function M:SetHeight(h) self._h = h end
function M:GetWidth() rects = {}; local r = RenderRect(self); return r and (r.r - r.l) / RenderScale(self) or (self._w or 0) end
function M:GetHeight() rects = {}; local r = RenderRect(self); return r and (r.b - r.t) / RenderScale(self) or (self._h or 0) end
function M:GetSize() return self:GetWidth(), self:GetHeight() end
function M:SetScale(s) self._scale = s end
function M:GetScale() return self._scale end
function M:GetEffectiveScale() return RenderScale(self) end
function M:GetCenter() rects = {}; local r = RenderRect(self); if r then return (r.l + r.r) / 2, 10000 - (r.t + r.b) / 2 end return 0, 0 end
function M:GetParent() return self._parent end
function M:SetParent(p)
    self._parent = p
    if self._kind ~= "texture" and self._kind ~= "font" and p then table.insert(p._children, self) end
end
function M:GetPoint() return "CENTER", self._parent, "CENTER", 0, 0 end
function M:SetFrameLevel(l) self._level = l end
function M:GetFrameLevel() return self._level or 0 end
function M:SetClipsChildren(c) self._clip = c end

-- Visibility -----------------------------------------------------------------------------------

function M:IsShown() return self._shown end
function M:IsVisible()
    local f = self
    while f do
        if not rawget(f, "_shown") then return false end
        f = rawget(f, "_parent")
    end
    return true
end
function M:Show()
    if not self._shown then
        self._shown = true
        if self:IsVisible() then M._Fire(self, "OnShow") end
    end
end
function M:Hide()
    if self._shown then
        self._shown = false
        M._Fire(self, "OnHide")
    end
end
function M:SetShown(s) if s then self:Show() else self:Hide() end end
function M:SetAlpha(a) self._alpha = a end
function M:GetAlpha() return self._alpha end

-- Scripts ----------------------------------------------------------------------------------------

function M._Fire(self, name, ...)
    local fn = self._scripts[name]
    if fn then fn(self, ...) end
    for _, h in ipairs(self._hooks[name] or {}) do h(self, ...) end
end
function M:SetScript(name, fn) self._scripts[name] = fn end
function M:GetScript(name) return self._scripts[name] end
function M:HookScript(name, fn)
    self._hooks[name] = self._hooks[name] or {}
    table.insert(self._hooks[name], fn)
end
function M:IsMouseOver() return self._mouseOver or false end
function M:IsEnabled() return self._enabled ~= false end
function M:SetEnabled(e)
    local was = self._enabled ~= false
    self._enabled = e and true or false
    if was ~= self._enabled then M._Fire(self, e and "OnEnable" or "OnDisable") end
end
function M:Enable() self:SetEnabled(true) end
function M:Disable() self:SetEnabled(false) end
function M:EnableMouse(e) self._mouse = e end
function M:IsMouseEnabled() return self._mouse end

-- Regions -----------------------------------------------------------------------------------------

local function NewRegion(kind, parent, layer, sub)
    local r = New(kind, parent)
    r._layer, r._sub = LAYERS[layer or "ARTWORK"] or 3, sub or 0
    r._color, r._coord = { 1, 1, 1, 1 }, { 0, 1, 0, 1 }
    table.insert(parent._regions, r)
    return r
end

function M:CreateTexture(_, layer, _, sub) return NewRegion("texture", self, layer, sub) end
function M:CreateMaskTexture() local m = NewRegion("mask", self, "ARTWORK"); m._isMask = true; return m end
function M:CreateFontString(_, layer)
    local fs = NewRegion("font", self, layer)
    fs._size, fs._flags, fs._justifyH, fs._justifyV, fs._wrap = 12, "", "CENTER", "MIDDLE", true
    fs._shadow = true
    return fs
end
function M:SetDrawLayer(layer, sub) self._layer, self._sub = LAYERS[layer] or 3, sub or 0 end

function M:SetTexture(file)
    self._file, self._atlas, self._solid = file, nil, nil
end
function M:SetAtlas(name, useSize) self._atlas, self._file, self._solid = name, nil, nil end
function M:GetAtlas() return self._atlas end
function M:SetColorTexture(r, g, b, a) self._solid = { r, g, b, a or 1 }; self._file, self._atlas = nil, nil end
function M:SetTexCoord(a, b, c, d, e, f, g, h)
    if e then self._coord = { a, g, b, h } else self._coord = { a, b, c, d } end
end
function M:SetVertexColor(r, g, b, a) self._color = { r, g, b, a or 1 } end
function M:SetDesaturated(d) self._desat = d and true or false end
function M:SetBlendMode(mode) self._blend = mode end
function M:SetRotation(rad) self._rot = rad end
function M:AddMaskTexture(mask) self._mask = mask end
function M:GetTexture() return self._file end

function M:SetFont(file, size, flags) self._size, self._flags = size or self._size, flags or "" end
function M:SetFontObject(font)
    if font and font._fsize then
        self._size, self._flags = font._fsize, font._fflags or ""
        if font._fcolor then self._textColor = font._fcolor end
    end
end
function M:GetFont() return "font", self._size, self._flags end
function M:SetText(t) self._text = t ~= nil and tostring(t) or nil end
function M:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function M:GetText() return self._text end
function M:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a or 1 } end
function M:SetJustifyH(j) self._justifyH = j end
function M:SetJustifyV(j) self._justifyV = j end
function M:SetWordWrap(w) self._wrap = w end
function M:SetShadowOffset(x, y) self._shadow = (x ~= 0 or y ~= 0) end
function M:SetSpacing(s) self._spacing = s end
function M:GetStringWidth() return #(self._text or "") * self._size * 0.52 end
function M:GetStringHeight() return self._size end
function M:SetMaxLines(n) self._maxLines = n end

-- Status bars and models -------------------------------------------------------------------------

function M:SetStatusBarTexture(file)
    if not self._bar then self._bar = NewRegion("texture", self, "ARTWORK") end
    self._bar._file = file
end
function M:SetStatusBarColor(r, g, b, a)
    if not self._bar then self:SetStatusBarTexture(nil) end
    self._bar._color = { r, g, b, a or 1 }
end
function M:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
function M:SetValue(v) self._value = v end
function M:GetValue() return self._value or 0 end
function M:SetDisplayInfo(id) self._display = id end
function M:ClearModel() self._display = nil end
function M:SetCreature(id) self._display = "c" .. id end

-- Creating frames ----------------------------------------------------------------------------------

local createdFrames = {}
RenderFrames = createdFrames
function CreateFrame(kind, name, parent)
    local f = NewFrame(kind == "PlayerModel" and "model" or "frame", parent)
    f._type = kind
    createdFrames[#createdFrames + 1] = f
    if name then _G[name] = f end
    return f
end
function CreateFont(name)
    local f = New("fontobject")
    f.SetFont = function(self, _, size, flags) self._fsize, self._fflags = size, flags end
    f.SetTextColor = function(self, r, g, b) self._fcolor = { r, g, b, 1 } end
    return f
end
UIParent = NewFrame("frame", nil)
UIParent._w, UIParent._h = 1920, 1080
Minimap = CreateFrame("Frame", nil, UIParent)
GameTooltip = CreateFrame("Frame", nil, UIParent)
function SetPortraitTextureFromCreatureDisplayID(tex, display) tex._portrait = display; tex._file = nil; tex._atlas = nil end
C_Texture = { GetAtlasInfo = function(name) return RENDER_ATLASES and RENDER_ATLASES[name:lower()] and { width = 1, height = 1 } or nil end }

-- Layout ---------------------------------------------------------------------------------------------

local H_PART = { TOPLEFT = "l", LEFT = "l", BOTTOMLEFT = "l", TOP = "c", CENTER = "c", BOTTOM = "c", TOPRIGHT = "r", RIGHT = "r", BOTTOMRIGHT = "r" }
local V_PART = { TOPLEFT = "t", TOP = "t", TOPRIGHT = "t", LEFT = "m", CENTER = "m", RIGHT = "m", BOTTOMLEFT = "b", BOTTOM = "b", BOTTOMRIGHT = "b" }

function RenderScale(o)
    if o._kind == "texture" or o._kind == "font" or o._kind == "mask" then return RenderScale(rawget(o, "_parent")) end
    local s = 1
    local f = o
    while type(f) == "table" do
        s = s * (rawget(f, "_scale") or 1)
        f = rawget(f, "_parent")
    end
    return s
end

local function PointOf(rect, part)
    local h, v = H_PART[part], V_PART[part]
    local x = h == "l" and rect.l or (h == "r" and rect.r or (rect.l + rect.r) / 2)
    local y = v == "t" and rect.t or (v == "b" and rect.b or (rect.t + rect.b) / 2)
    return x, y
end

local function TextWidth(o)
    local text = (o._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW")
    local widest = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do widest = math.max(widest, #line) end
    return widest * o._size * 0.5
end

local resolving = {}
function RenderRect(o)
    if rects[o] ~= nil then return rects[o] or nil end
    if o == UIParent then
        rects[o] = { l = 0, t = 0, r = 1920, b = 1080 }
        return rects[o]
    end
    if resolving[o] then return nil end
    resolving[o] = true
    local s = RenderScale(o)
    local xs, ys = {}, {}
    for point, p in pairs(o._points) do
        local rel = type(p.rel) == "table" and rawget(p.rel, "_points") and RenderRect(p.rel)
        if rel then
            local rx, ry = PointOf(rel, p.relPoint)
            xs[H_PART[point]] = rx + p.x * s
            ys[V_PART[point]] = ry - p.y * s
        end
    end
    local w = o._w and o._w * s
    local h = o._h and o._h * s
    if o._kind == "font" then
        local natural = TextWidth(o) * s
        if not w and not (xs.l and xs.r) then w = natural end
        if not h and not (ys.t and ys.b) then
            local lines = 1
            local avail = w or (xs.l and xs.r and xs.r - xs.l)
            if avail and avail > 0 and o._wrap ~= false then lines = math.max(1, math.ceil(natural / avail)) end
            local _, breaks = (o._text or ""):gsub("\n", "")
            lines = math.max(lines, breaks + 1)
            h = lines * (o._size + 2) * s
        end
    end
    local l, r, t, b
    if xs.l and xs.r then l, r = xs.l, xs.r
    elseif w and xs.l then l, r = xs.l, xs.l + w
    elseif w and xs.r then l, r = xs.r - w, xs.r
    elseif w and xs.c then l, r = xs.c - w / 2, xs.c + w / 2 end
    if ys.t and ys.b then t, b = ys.t, ys.b
    elseif h and ys.t then t, b = ys.t, ys.t + h
    elseif h and ys.b then t, b = ys.b - h, ys.b
    elseif h and ys.m then t, b = ys.m - h / 2, ys.m + h / 2 end
    resolving[o] = nil
    if l and t then
        rects[o] = { l = l, r = r, t = t, b = b }
    else
        rects[o] = false
    end
    return rects[o] or nil
end

-- Collects everything visible below `root`, in draw order, in root coordinates.
function RenderDump(root)
    rects = {}
    local origin = RenderRect(root)
    local frames = {}
    local function Walk(f, clip)
        if not f._shown then return end
        local rect = RenderRect(f)
        local myClip = clip
        if f._clip and rect then
            myClip = { l = math.max(rect.l, clip and clip.l or -1e9), t = math.max(rect.t, clip and clip.t or -1e9),
                r = math.min(rect.r, clip and clip.r or 1e9), b = math.min(rect.b, clip and clip.b or 1e9) }
        end
        frames[#frames + 1] = { f = f, clip = clip, alpha = f._alpha }
        for _, c in ipairs(f._children) do
            if c._parent == f then Walk(c, myClip) end
        end
    end
    Walk(root, nil)
    -- Effective alpha multiplies down the tree.
    local function Alpha(f)
        local a = 1
        while f do a = a * (f._alpha or 1); f = f._parent end
        return a
    end
    table.sort(frames, function(a, b)
        local la, lb = a.f._level or 0, b.f._level or 0
        if la ~= lb then return la < lb end
        return a.f._serial < b.f._serial
    end)
    local out = {}
    local function Rel(r)
        return { r.l - origin.l, r.t - origin.t, r.r - origin.l, r.b - origin.t }
    end
    for _, entry in ipairs(frames) do
        local f = entry.f
        local alpha = Alpha(f)
        local regions = {}
        for _, r in ipairs(f._regions) do
            if r._shown and not r._isMask and r._layer ~= 5 then regions[#regions + 1] = r end
        end
        table.sort(regions, function(a, b)
            if a._layer ~= b._layer then return a._layer < b._layer end
            if a._sub ~= b._sub then return a._sub < b._sub end
            return a._serial < b._serial
        end)
        if f._kind == "model" and f._display then
            local r = RenderRect(f)
            if r then out[#out + 1] = { kind = "model", rect = Rel(r), alpha = alpha, clip = entry.clip and Rel(entry.clip), display = tostring(f._display) } end
        end
        if f._bar then
            local r = RenderRect(f)
            if r and f._max and f._max > f._min then
                local share = math.max(0, math.min(1, ((f._value or 0) - f._min) / (f._max - f._min)))
                out[#out + 1] = { kind = "texture", rect = Rel({ l = r.l, t = r.t, r = r.l + (r.r - r.l) * share, b = r.b }),
                    alpha = alpha, solid = f._bar._color }
            end
        end
        for _, reg in ipairs(regions) do
            local r = RenderRect(reg)
            if r and r.r > r.l and r.b > r.t then
                local item = { rect = Rel(r), alpha = alpha * (reg._alpha or 1), clip = entry.clip and Rel(entry.clip), layer = reg._layer }
                if reg._kind == "font" then
                    if reg._text and reg._text ~= "" then
                        item.kind = "text"
                        item.text, item.size, item.flags = reg._text, reg._size * RenderScale(reg), reg._flags or ""
                        item.color = reg._textColor or { 1, 0.82, 0, 1 }
                        item.justifyH, item.justifyV, item.wrap, item.shadow = reg._justifyH, reg._justifyV, reg._wrap, reg._shadow
                        out[#out + 1] = item
                    end
                elseif reg._file or reg._atlas or reg._solid or reg._portrait then
                    item.kind = "texture"
                    item.file = reg._file and tostring(reg._file)
                    item.atlas, item.solid, item.portrait = reg._atlas, reg._solid, reg._portrait
                    item.coord, item.color, item.desat, item.blend, item.rot = reg._coord, reg._color, reg._desat, reg._blend, reg._rot
                    if reg._mask then
                        local mr = RenderRect(reg._mask)
                        if mr then item.mask = { file = tostring(reg._mask._file), rect = Rel(mr) } end
                    end
                    out[#out + 1] = item
                end
            end
        end
    end
    return out, origin.r - origin.l, origin.b - origin.t
end

-- Lists clickable frames under a point (root coordinates): what a click there would hit.
function RenderHits(root, x, y)
    local origin = RenderRect(root)
    local hits = {}
    for _, f in ipairs(createdFrames) do
        if f:IsVisible() and (f._mouse or f._type == "Button" or f._scripts.OnClick or f._scripts.OnEnter) then
            local r = RenderRect(f)
            if r and x >= r.l - origin.l and x <= r.r - origin.l and y >= r.t - origin.t and y <= r.b - origin.t then
                hits[#hits + 1] = f
            end
        end
    end
    table.sort(hits, function(a, b) return (a._level or 0) > (b._level or 0) end)
    return hits
end
