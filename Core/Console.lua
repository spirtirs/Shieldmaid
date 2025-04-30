-- The addon namespace.
local addon, ns = ...

-- Define the console class and put it in the addon namespace.
local Console = {}
local ConsoleMetatable = { __index = Console }
ns.Console = Console

-- Constructor.
function Console:new(manager)
	local self = {}
	setmetatable(self, ConsoleMetatable)
	
	self.Manager = manager
	
	-- Slash command handler
	function self.SlashCommandHandler(msg, editbox)
		local command, rest = msg:match("^(%S*)%s*(.-)$");
		if command == "" or command == "help" then
			Console.Write("Usage: /shieldmaid <command> or /sm <command>")
			Console.Write("Commands:")
			Console.Write("help")
			Console.Write("reset")
			Console.Write("lock")
			Console.Write("unlock")
			Console.Write("size <pixels>")
			Console.Write("scale <number>")
			Console.Write("margin <pixels>")
			Console.Write("hiddenOutOfCombat true/false")
			Console.Write("showFrames true/false")
			Console.Write("showGlow true/false")
			Console.Write("showCooldown true/false")
		elseif command == "reset" then
			self.Manager:Reset()	
			Console.Write("Configuration reset")
		elseif command == "lock" then
			self.Manager:Lock()
			Console.Write("Frames locked")
		elseif command == "unlock" then
			self.Manager:Unlock()
			Console.Write("Frames unlocked")
		elseif command == "size" then
			local size = tonumber(rest)
			if size then
				self.Manager:SetSize(size)
				Console.Write("Size set to "..size)
			else
				Console.Write("Unable to parse size: "..rest)
			end
		elseif command == "scale" then
			local scale = tonumber(rest)
			if scale then
				self.Manager:SetScale(scale)
				Console.Write("Scale set to "..scale)
			else
				Console.Write("Unable to parse scale: "..rest)
			end
		elseif command == "margin" then
			local margin = tonumber(rest)
			if margin then
				self.Manager:SetMargin(margin)
				Console.Write("Margin set to "..margin)
			else
				Console.Write("Unable to parse margin: "..rest)
			end
		elseif command == "hiddenOutOfCombat" then
			if rest == "true" then
				self.Manager:SetHiddenOutOfCombat(true)
				Console.Write("Icons will be hidden out of combat.")
			elseif rest == "false" then
				self.Manager:SetHiddenOutOfCombat(false)
				Console.Write("Icons will be visible out of combat.")
			else
				Console.Write("Unable to parse boolean value: "..rest)
			end
		elseif command == "showFrames" then
			if rest == "true" then
				self.Manager:SetShowFrames(true)
				Console.Write("Frames will be visible.")
			elseif rest == "false" then
				self.Manager:SetShowFrames(false)
				Console.Write("Frames will be hidden.")
			else
				Console.Write("Unable to parse boolean value: "..rest)
			end
		elseif command == "showGlow" then
			if rest == "true" then
				self.Manager:SetShowGlow(true)
				Console.Write("Glow will be visible.")
			elseif rest == "false" then
				self.Manager:SetShowGlow(false)
				Console.Write("Glow will be hidden.")
			else
				Console.Write("Unable to parse boolean value: "..rest)
			end
		elseif command == "showCooldown" then
			if rest == "true" then
				self.Manager:SetShowCooldown(true)
				Console.Write("The cooldown 'clock' will be visible.")
			elseif rest == "false" then
				self.Manager:SetShowCooldown(false)
				Console.Write("The cooldown 'clock' will be hidden.")
			else
				Console.Write("Unable to parse boolean value: "..rest)
			end
		else
			Console.Write("Unknown command: "..command)
		end
	end
	
	return self
end

-- Utility function for writing to the chat window.
function Console.Write(text)
	print("|c00C79C6EShield Maid:|r "..text)
end

-- Register slash command handler.
function Console:RegisterSlashCommands()
	SLASH_SHIELDMAID1, SLASH_SHIELDMAID2 = "/shieldmaid", "/sm"
	SlashCmdList["SHIELDMAID"] = self.SlashCommandHandler
end


