-- The addon namespace.
local addon, ns = ...

-- Define the shield barrier icon class and put it in the addon namespace.
local ShieldBarrierIcon = {}
local ShieldBarrierIconMetatable = { __index = ShieldBarrierIcon }
ns.ShieldBarrierIcon = ShieldBarrierIcon

-- Inherit methods from the Icon class.
setmetatable(ShieldBarrierIcon, { __index = ns.Icon })

-- Constructor.
function ShieldBarrierIcon:new()
	local self = ns.Icon:new()	
	setmetatable(self, ShieldBarrierIconMetatable)
	
	-- Set the Shield Barrier texture and the spell name.
	local spellId = 112048
	local spellName, _, texture = GetSpellInfo(spellId)
    self.Texture:SetTexture(texture)
	self.SpellName = spellName
	self.SpellId = spellId
	
	-- Shield Barrier bar.
	self.Bar = self.Icon:CreateTexture(nil, "ARTWORK")
	self.Bar:SetTexture(ns.Config.barColor[1], ns.Config.barColor[2], ns.Config.barColor[3], ns.Config.barAlpha)
	self.Bar:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT")
	self.Bar:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT")
	self.Bar.Max = 0

	-- Dragging.
	self.Icon:SetScript("OnDragStop", self.OnDragStopHandler)
	
	return self
end

-- Handler that stops dragging and saves the position to the saved variables.
-- Note that self is the icon frame and not the icon class.
function ShieldBarrierIcon:OnDragStopHandler()
	self:StopMovingOrSizing()
	ShieldMaidConfig.shieldBarrierAnchor, _, _, ShieldMaidConfig.shieldBarrierX, ShieldMaidConfig.shieldBarrierY = self:GetPoint(1)
end

-- (Re)loads the icon with values from the saved variables config.
function ShieldBarrierIcon:Reload()
	self:ReloadBase()
	
	-- Set the position.
	self.Icon:SetPoint(ShieldMaidConfig.shieldBarrierAnchor, ShieldMaidConfig.shieldBarrierX, ShieldMaidConfig.shieldBarrierY)
end

-- Utility function for setting the height if the Shield Barrier Bar.
function ShieldBarrierIcon:UpdateBar(absorb)
	if absorb > 0 then
		if self.Bar.Max < absorb then
			self.Bar.Max = absorb
		end
		self.Bar:Show()
		self.Bar:SetHeight(ShieldMaidConfig.size * (absorb / self.Bar.Max))        
	else
		self.Bar.Max = 0
		self.Bar:Hide()
	end
end

-- Updates the icon.
function ShieldBarrierIcon:Update(currentRage, estimatedAbsorb)
	local name, _, _, _, _, _, expires, _, _, _, _, _, _, _, absorb = UnitBuff("player", self.SpellName)
	if name then
		self:UpdateTint(currentRage, 0)
		self:UpdateBar(absorb)
		self.InfoText:SetTextColor(ns.Config.infoTextColorActive[1], ns.Config.infoTextColorActive[2], ns.Config.infoTextColorActive[3], 1)
		local systemTime = GetTime()
		self.InfoText:SetText(self:FormatNumber(absorb))        
		self.DurationText:SetText(self:RoundNumber(expires - systemTime))
		self.Icon:SetAlpha(ns.Config.activeAlpha)
	else
		self.Icon:SetAlpha(ns.Config.inactiveAlpha)
		self:UpdateTint(currentRage, 20)
		self:UpdateBar(0)
		self.InfoText:SetTextColor(ns.Config.infoTextColorInactive[1], ns.Config.infoTextColorInactive[2], ns.Config.infoTextColorInactive[3], 1)
		self.InfoText:SetText(self:FormatNumber(estimatedAbsorb)) 
		self.DurationText:SetText("")        
	end
	
	self:UpdateCooldown()
end