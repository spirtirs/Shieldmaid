-- The addon namespace.
local addon, ns = ...

-- Define the icon class and put it in the addon namespace.
local Icon = {}
local IconMetatable = { __index = Icon }
ns.Icon = Icon

-- Constructor.
function Icon:new()
	local self = {} 
	setmetatable(self, IconMetatable)
		
	local cfg = ns.Config
	
	-- The icon frame.
	self.Icon = CreateFrame("Frame", nil, UIParent) 
    self.Icon:SetFrameStrata(cfg.strata)
	self.Icon:SetFrameLevel(1)
    self.Icon:SetAlpha(cfg.inactiveAlpha)

	-- The background (frame).
	self.Background = self.Icon:CreateTexture(nil, "BACKGROUND")
	self.Background:SetTexture(cfg.backgroundColor[1], cfg.backgroundColor[2], cfg.backgroundColor[3], cfg.backgroundAlpha)
	
	-- The ability texture.
	self.Texture = self.Icon:CreateTexture(nil, "BACKGROUND")
    self.Texture:SetAllPoints(self.Icon)
    self.Texture:SetVertexColor(cfg.unavailableTint[1], cfg.unavailableTint[2], cfg.unavailableTint[3])
	
	-- The cooldown "clock".
	self.Cooldown = CreateFrame("Cooldown", nil, self.Icon, "CooldownFrameTemplate")
	self.Cooldown:SetAllPoints()
	
	-- The glow.
	self.Glow = CreateFrame("Frame", nil, UIParent, "ActionBarButtonSpellActivationAlert")
	self.Glow:SetFrameStrata(cfg.strata)
	self.Glow:SetFrameLevel(2)
	self.Glow.spark:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
    self.Glow.innerGlow:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
    self.Glow.innerGlowOver:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
    self.Glow.outerGlow:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
    self.Glow.outerGlowOver:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
    self.Glow.ants:SetVertexColor(cfg.glowColor[1], cfg.glowColor[2], cfg.glowColor[3])
	
	-- A frame for the text to overlay it properly.
	local textFrame = CreateFrame("Frame", nil, self.Icon)
	textFrame:SetAllPoints()
	
	-- The duration text.
	self.DurationText = textFrame:CreateFontString(nil, "OVERLAY")
    self.DurationText:SetJustifyH(cfg.durationTextJustifyH)
    self.DurationText:SetPoint(cfg.durationTextAnchor, cfg.durationTextX, cfg.durationTextY)
    self.DurationText:SetFont(cfg.font, cfg.durationTextSize, cfg.fontOutline)	
    self.DurationText:SetTextColor(cfg.durationTextColor[1], cfg.durationTextColor[2], cfg.durationTextColor[3], 1)
    self.DurationText:SetText("")
	
	-- The information text.
	self.InfoText = textFrame:CreateFontString(nil, "OVERLAY")
    self.InfoText:SetJustifyH(cfg.infoTextJustifyH)
    self.InfoText:SetPoint(cfg.infoTextAnchor, cfg.infoTextX, cfg.infoTextY)
    self.InfoText:SetFont(cfg.font, cfg.infoTextSize, cfg.fontOutline)	
    self.InfoText:SetTextColor(cfg.infoTextColorInactive[1], cfg.infoTextColorInactive[2], cfg.infoTextColorInactive[3], 1)
    self.InfoText:SetText("") 
	
	-- Dragging.
	self.Icon:RegisterForDrag("LeftButton")
	self.Icon:SetScript("OnDragStart", self.Icon.StartMoving)
	
	return self
end

-- Initializes the icon with values from the saved variables config.
function Icon:ReloadBase()
	-- Size, strata and alpha.
    self.Icon:SetWidth(ShieldMaidConfig.size)
    self.Icon:SetHeight(ShieldMaidConfig.size)
    self.Icon:SetScale(ShieldMaidConfig.scale)
	
	-- The background (frame).
	self.Background:SetWidth(ShieldMaidConfig.size + 2 * ShieldMaidConfig.margin)
    self.Background:SetHeight(ShieldMaidConfig.size + 2 * ShieldMaidConfig.margin)
    self.Background:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", -ShieldMaidConfig.margin, ShieldMaidConfig.margin)
	self.Background:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT", ShieldMaidConfig.margin, -ShieldMaidConfig.margin)
	
	-- The ability texture.
    if ShieldMaidConfig.showFrames then
        self.Texture:SetTexCoord(0, 1, 0, 1)
	else
		self.Texture:SetTexCoord(0.1, 0.8, 0.1, 0.8)
    end  
	
	-- The glow.
    self.Glow:SetWidth(ShieldMaidConfig.size * 1.7)
    self.Glow:SetHeight(ShieldMaidConfig.size * 1.7)
    self.Glow:SetScale(ShieldMaidConfig.scale)
	self.Glow:SetPoint("CENTER", self.Icon, -1, -1);
    self.Glow.animIn:Play()
	
	-- Dragging
	self.Icon:EnableMouse(false)
	self.Icon:SetMovable(false)
end

-- Number format function.
function Icon:FormatNumber(number)
	if not ns.Config.truncatedNumbers then
		number = floor(number)
		local left, middle, right = string.match(number,"^([^%d]*%d)(%d*)(.-)$")
		return left..(middle:reverse():gsub("(%d%d%d)","%1,"):reverse())..right
	elseif number > 1E10 then
		return floor(number / 1E9).."b"
	elseif number > 1E9 then
		return (floor((number / 1E9) * 10) / 10).."b"
	elseif number > 1E7 then
		return floor(number / 1E6).."m"
	elseif number > 1E6 then
		return (floor((number / 1E6) * 10) / 10).."m"
	elseif number > 1E4 then
		return floor(number / 1E3).."k"
	elseif number > 1E3 then
		return (floor((number / 1E3) * 10) / 10).."k"
	else
		return floor(number)
	end
end

-- Rounds numbers to the nearest integer.
function Icon:RoundNumber(number)
	return math.floor(number + 0.5)
end

-- Updates icon tint.
function Icon:UpdateTint(currentRage, requiredRage)
	if currentRage < requiredRage then
		self.Texture:SetVertexColor(ns.Config.unavailableTint[1], ns.Config.unavailableTint[2], ns.Config.unavailableTint[3])
	else
		self.Texture:SetVertexColor(1, 1, 1)  
	end
end

-- Updates the cooldown "clock"
function Icon:UpdateCooldown()
	if ShieldMaidConfig.showCooldown and self.SpellName then
		local start, duration, enabled, charges, maxCharges = GetSpellCooldown(self.SpellName)
		if start and duration then
			if charges and maxCharges then
				self.Cooldown:SetCooldown(start, duration, charges, maxCharges)
			else
				self.Cooldown:SetCooldown(start, duration)
			end
		end
	end
end

-- Shows the icon.
function Icon:Show()
	self.Icon:Show()
end

-- Hides the icon.
function Icon:Hide()
	self.Icon:Hide()
	self:HideGlow()
end

-- Shows the icon glow.
function Icon:ShowGlow()
	if ShieldMaidConfig.showGlow then
		self.Glow:Show()
	end
end

-- Hides the icon glow.
function Icon:HideGlow()
	self.Glow:Hide()
end

-- Locks the icon.
function Icon:Lock()
	self.Icon:SetMovable(false)
	self.Icon:EnableMouse(false)
end

-- Unlocks the icon for dragging.
function Icon:Unlock()
	self.Icon:SetMovable(true)
	self.Icon:EnableMouse(true)
end