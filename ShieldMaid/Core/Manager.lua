-- The addon namespace.
local addon, ns = ...

-- Define the manager class and put it in the addon namespace.
local Manager = {}
local ManagerMetatable = { __index = Manager }
ns.Manager = Manager

-- Constructor.
function Manager:new(shieldBarrierIcon, shieldBlockIcon)
	local self = {}
	setmetatable(self, ManagerMetatable)
	
	-- Initialize variables.
	self.Initialized = false
	self.Active = false
	self.PlayerName = UnitName("player") 
	self.CurrentRage = 0
	self.TotalBlocked = 0
	self.ShieldBlockActive = false
	self.BlockedAmounts = ns.LinkedList:new()
	self.ElapsedTime = 0.0
	self.ShieldBarrierIcon = shieldBarrierIcon
	self.ShieldBlockIcon = shieldBlockIcon	
	
	-- Main frame (pun intended) for listening.
	self.Main =  CreateFrame("Frame", nil, UIParent)
	
	-- Event handler stuff. handlers are not fired when the addon is inactive, 
	-- listeners are. This is just my personal terminology.
	self.Handlers = {}
	self.Listeners = {}
	
	function self.Handlers.COMBAT_LOG_EVENT_UNFILTERED(sender, ...)
		local eventType = select(2, ...)
		local target = select(9, ...)
		local spellId = select(12, ...)
		if (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE") and target == self.PlayerName and self.ShieldBlockActive then  
			local blocked = select(16, ...) 
			if blocked and blocked > 0 then -- blocked can be -1 and nil
				self.TotalBlocked = self.TotalBlocked + blocked
			end
		end 
		if eventType == "SPELL_AURA_APPLIED" and spellId == self.ShieldBlockIcon.SpellId and target == self.PlayerName then
			self.ShieldBlockActive = true
			self.TotalBlocked = 0;
		end 
		if eventType == "SPELL_AURA_REMOVED" and spellId == self.ShieldBlockIcon.SpellId and target == self.PlayerName then
			self.ShieldBlockActive = false
		end 
		if (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE") and target == self.PlayerName then
			local damage = select(eventType == "SWING_DAMAGE" and 12 or 15, ...) or 0
			local school = select(14, ...)
			local blocked = select(16, ...) or 0
			local absorbed = select(17, ...) or 0
			if bit.band(school, 1) ~= 0 then -- 00000001 is the bit mask for physical.
				self.BlockedAmounts:Add(damage + blocked + absorbed)
			end
		end
		if (eventType == "SWING_MISSED" or eventType == "SPELL_MISSED") and target == self.PlayerName then
			local missType = select(eventType == "SWING_MISSED" and 12 or 15, ...)
			local school = select(eventType == "SWING_MISSED" and 13 or 14, ...) or 1
			local absorbed = select(eventType == "SWING_MISSED" and 14 or 17, ...) or 0
			if missType == "ABSORB" and bit.band(school, 1) ~= 0 then -- 00000001 is the bit mask for physical. 
				self.BlockedAmounts:Add(absorbed)
			end
		end
	end

	function self.Handlers.UNIT_POWER(sender, ...)
		local unitId = select(1, ...)
		if unitId == "player" then
			self.CurrentRage = UnitPower("player", SPELL_POWER_RAGE)
		end
	end

	function self.Handlers.PLAYER_REGEN_ENABLED(sender, ...)
		if ShieldMaidConfig.hiddenOutOfCombat then
			self.ShieldBarrierIcon:Hide()
			self.ShieldBlockIcon:Hide()
		end
	end

	function self.Handlers.PLAYER_REGEN_DISABLED(sender, ...)
		if ShieldMaidConfig.hiddenOutOfCombat then
			self.ShieldBarrierIcon:Show()
			self.ShieldBlockIcon:Show()
		end
	end

	function self.Listeners.PLAYER_SPECIALIZATION_CHANGED(sender, ...)
		self:Load()
	end

	function self.Listeners.ADDON_LOADED(sender, ...)
		local name = select(1, ...)
		if name == addon then
			self:LoadDefaultConfig()
		end
	end
	
	function self.Listeners.PLAYER_LOGIN(...)
		self:Load()
	end
	
	-- Handler that makes sure the Tick function is called every ns.Config.updateInterval seconds.
	function self.OnUpdateHandler(sender, seconds)
		self.ElapsedTime = self.ElapsedTime + seconds
		while self.Active and self.ElapsedTime > ns.Config.updateInterval do
			self:Tick()
			self.ElapsedTime = self.ElapsedTime - ns.Config.updateInterval
		end
	end

	-- OnEvent handler that delegates to the correct handler. If inactive, we only handle ACTIVE_TALENT_GROUP_CHANGED.
	function self.OnEventHandler(sender, event, ...)
		if self.Active and self.Handlers[event] then
			self.Handlers[event](sender, ...)
		end
		if self.Listeners[event] then
			self.Listeners[event](sender, ...)
		end
	end
	
	return self
end

-- Calculates the estimated absorb value.
function Manager:CalculateEstimatedAbsorb(rage)
	local baseAttackPower, positiveBuff, negativeBuff = UnitAttackPower("player")
	local attackPower = baseAttackPower + positiveBuff + negativeBuff
	local _, strength = UnitStat("player", 1)
	local _, stamina = UnitStat("player", 3)
	local rageMultiplier = max(20, min(60, rage)) / 60.0
	return max(1.8 * (attackPower - 2 * strength), stamina * 2.5) * rageMultiplier
end	

-- Calculates the estimated block based on entries from the past 6 seconds in the linked list.
-- At the same time, entries more than 6 seconds old are removed.
function Manager:CalculateEstimatedBlock()
	local sum = self.BlockedAmounts:Sum(6)
	local mastery, _ = GetMasteryEffect()
	local criticalBlockChance = mastery / 100
	local criticalBlock = sum * criticalBlockChance * 0.6
	local normalBlock = sum * (1 - criticalBlockChance) * 0.3
	return criticalBlock + normalBlock
end

-- Updates the glow depending on which ability has the highest predicted mitigation value.
function Manager:UpdateGlow(estimatedBlock)
	local shieldBarrier = UnitBuff("player", self.ShieldBarrierIcon.SpellName)
	local shieldBlock = UnitBuff("player", self.ShieldBlockIcon.SpellName)
	if shieldBarrier or shieldBlock or self.CurrentRage < 20 then
		self.ShieldBarrierIcon:HideGlow()
		self.ShieldBlockIcon:HideGlow()
	else   
		if self:CalculateEstimatedAbsorb(60) >= estimatedBlock then   
			if self.CurrentRage >= 20 then
				self.ShieldBarrierIcon:ShowGlow()
				self.ShieldBlockIcon:HideGlow()
			end
		else
			if self.CurrentRage >= 60 then
				self.ShieldBarrierIcon:HideGlow()
				self.ShieldBlockIcon:ShowGlow()
			end
		end
	end
end

-- Tick function, called in updateInterval intervals.
function Manager:Tick()
	local estimatedAbsorb = self:CalculateEstimatedAbsorb(self.CurrentRage)
	local estimatedBlock = self:CalculateEstimatedBlock()
	self:UpdateGlow(estimatedBlock)
	self.ShieldBarrierIcon:Update(self.CurrentRage, estimatedAbsorb)
	self.ShieldBlockIcon:Update(self.CurrentRage, self.TotalBlocked, estimatedBlock)
end

-- Enables/disables the addon depending on class and spec. 
function Manager:Load()
	local _, class = UnitClassBase("player")
	local spec = GetSpecialization()
	if class == "WARRIOR" and spec == 3 then
		self.Active = true
			
		self.ShieldBarrierIcon:Reload()
		self.ShieldBlockIcon:Reload()
			
		-- In case we reload or change spec in the middle of combat, we check for it here.
		if UnitAffectingCombat("player") or not ShieldMaidConfig.hiddenOutOfCombat then
			self.ShieldBarrierIcon:Show()
			self.ShieldBlockIcon:Show()
		else
			self.ShieldBarrierIcon:Hide()
			self.ShieldBlockIcon:Hide()
		end
		
		self:Tick()
		
	else
		self.Active = false
		self.ShieldBarrierIcon:Hide()
		self.ShieldBlockIcon:Hide()
		
	end
end

-- Registers update and event handlers.
function Manager:RegisterHandlers()
	for k, v in pairs(self.Handlers) do
		self.Main:RegisterEvent(k);
	end
	
	for k, v in pairs(self.Listeners) do
		self.Main:RegisterEvent(k);
	end

	self.Main:SetScript("OnUpdate", self.OnUpdateHandler)
	self.Main:SetScript("OnEvent", self.OnEventHandler)
end

-- Set the default configuration if no previous configuration has been saved.
function Manager:LoadDefaultConfig()
	if not ShieldMaidConfig then
		ShieldMaidConfig = {}
	end

	for k, v in pairs(ns.Config.Default) do
		if ShieldMaidConfig[k] == nil then
			ShieldMaidConfig[k] = v
		end
	end
end

-- Set the default configuration if no previous configuration has been saved.
function Manager:Reset()
	ShieldMaidConfig = {}
	for k, v in pairs(ns.Config.Default) do
		ShieldMaidConfig[k] = v
	end
	
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Locks the icons.
function Manager:Lock()
	self.ShieldBarrierIcon:Lock()
	self.ShieldBlockIcon:Lock()
end

-- Unlocks the icons for dragging.
function Manager:Unlock()
	self.ShieldBarrierIcon:Unlock()
	self.ShieldBlockIcon:Unlock()
end

-- Sets the icon sizes.
function Manager:SetSize(size)
	ShieldMaidConfig.size = size
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets the icon scale.
function Manager:SetScale(scale)
	ShieldMaidConfig.scale = scale
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets the icon margin.
function Manager:SetMargin(margin)
	ShieldMaidConfig.margin = margin
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets a value indicating whether to hide the icons when out of combat.
function Manager:SetHiddenOutOfCombat(value)
	ShieldMaidConfig.hiddenOutOfCombat = value
	if UnitAffectingCombat("player") or not ShieldMaidConfig.hiddenOutOfCombat then
		self.ShieldBarrierIcon:Show()
		self.ShieldBlockIcon:Show()
	else
		self.ShieldBarrierIcon:Hide()
		self.ShieldBlockIcon:Hide()
	end
end

-- Sets a value indicating whether to show the icon frames.
function Manager:SetShowFrames(value)
	ShieldMaidConfig.showFrames = value
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets a value indicating whether to show the glow.
function Manager:SetShowGlow(value)
	ShieldMaidConfig.showGlow = value
	if not value then
		self.ShieldBarrierIcon:HideGlow()
		self.ShieldBlockIcon:HideGlow()
	end
end

-- Sets a value indicating whether to show the cooldown "clock" on icons.
function Manager:SetShowCooldown(value)
	ShieldMaidConfig.showCooldown = value
end