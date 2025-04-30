-- The addon namespace.
local addon, ns = ...

local shieldBarrierIcon = ns.ShieldBarrierIcon:new()
local shieldBlockIcon = ns.ShieldBlockIcon:new()
local manager = ns.Manager:new(shieldBarrierIcon, shieldBlockIcon);
local console = ns.Console:new(manager)

console:RegisterSlashCommands()
manager:RegisterHandlers()