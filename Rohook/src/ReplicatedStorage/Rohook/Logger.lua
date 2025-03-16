--[[
	░█████╗░██╗░░██╗███╗░░░███╗███████╗██████╗░
	██╔══██╗██║░░██║████╗░████║██╔════╝██╔══██╗
	███████║███████║██╔████╔██║█████╗░░██║░░██║
	██╔══██║██╔══██║██║╚██╔╝██║██╔══╝░░██║░░██║
	██║░░██║██║░░██║██║░╚═╝░██║███████╗██████╔╝
	╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░░░░╚═╝╚══════╝╚═════╝░

    Rohook - Version 2 of Webhook library.
    Original by Ahmed Sayed (Discord: ahmedsayed0 / Roblox: ModyNegm00)
    Portfolio: https://ahmedsayedv2.vercel.app
    
    Overview:
    Logger - Advanced Logging Utility
]]--

local Utils = require(script.Parent.Utils)
local Logger = {}
Logger.__index = Logger

-- Type Definitions
export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR" | "FATAL"
export type LogCategory = "SYSTEM" | "NETWORK" | "WEBHOOK" | "VALIDATION" | "CUSTOM"
export type LogEntry = {
	timestamp: string,
	level: LogLevel,
	category: LogCategory?,
	message: string,
	args: {any}?
}
export type LoggerConfig = {
	level: LogLevel?,
	timestampFormat: string?,
	useCategories: boolean?,
	persistLogs: boolean?
}

function Logger.new(config: LoggerConfig?): Logger
	local self = setmetatable({}, Logger)
	self.Level = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4, FATAL = 5}
	self.Config = {
		level = config and config.level or "INFO",
		timestampFormat = config and config.timestampFormat or "%Y-%m-%d %H:%M:%S",
		useCategories = config and config.useCategories or false,
		persistLogs = config and config.persistLogs or false
	}
	self.CurrentLevel = self.Level[self.Config.level]
	self.Callbacks = {} :: {(entry: LogEntry) -> ()}
	self.LogHistory = {} :: {LogEntry}
	return self
end

function Logger:AddCallback(callback: (entry: LogEntry) -> ()): () -> ()
	table.insert(self.Callbacks, callback)
	local index = #self.Callbacks
	return function()
		table.remove(self.Callbacks, index)
	end
end

function Logger:Log(level: LogLevel, message: string, category: LogCategory?, ...: any)
	local levelNum = self.Level[level] or self.Level.INFO
	if levelNum < self.CurrentLevel then return end

	local timestamp = os.date(self.Config.timestampFormat) or os.date("%Y-%m-%d %H:%M:%S")
	local cat = self.Config.useCategories and (category or "CUSTOM") or nil
	local args = {...}
	local entry: LogEntry = {
		timestamp = timestamp,
		level = level,
		category = cat,
		message = message,
		args = args
	}

	local formattedMessage
	if #args > 0 then
		local success, result = pcall(function()
			return string.format(message, unpack(args))
		end)
		if not success then
			formattedMessage = message .. " [Format Error: " .. tostring(result) .. "]"
		else
			formattedMessage = result
		end
	else
		formattedMessage = message
	end

	local baseFormatted
	if cat then
		baseFormatted = string.format("[%s][%s][%s] %s", 
			timestamp or "UNKNOWN_TIME", 
			level or "UNKNOWN_LEVEL", 
			cat or "UNKNOWN_CAT", 
			formattedMessage)
	else
		baseFormatted = string.format("[%s][%s] %s", 
			timestamp or "UNKNOWN_TIME", 
			level or "UNKNOWN_LEVEL", 
			formattedMessage)
	end

	local coloredOutput
	if level == "DEBUG" then
		coloredOutput = "[BLUE] " .. baseFormatted
		print(coloredOutput)
	elseif level == "INFO" then
		coloredOutput = "[WHITE] " .. baseFormatted
		print(coloredOutput)
	elseif level == "WARN" then
		coloredOutput = "[YELLOW] " .. baseFormatted
		warn(coloredOutput)
	elseif level == "ERROR" then
		coloredOutput = "[RED] " .. baseFormatted
		print(coloredOutput)
	elseif level == "FATAL" then
		coloredOutput = "[RED] " .. baseFormatted
		print(coloredOutput)
	end

	if self.Config.persistLogs then
		table.insert(self.LogHistory, entry)
	end
	for _, cb in ipairs(self.Callbacks) do
		task.spawn(cb, entry)
	end
end

function Logger:SetLevel(level: LogLevel)
	self.CurrentLevel = self.Level[level] or self.Level.INFO
	self.Config.level = level
end

function Logger:GetHistory(): {LogEntry}
	return Utils.deepCopy(self.LogHistory)
end

function Logger:ClearHistory()
	self.LogHistory = {}
end

-- Convenience methods
function Logger:Debug(message: string, category: LogCategory?, ...: any)
	self:Log("DEBUG", message, category, ...)
end

function Logger:Info(message: string, category: LogCategory?, ...: any)
	self:Log("INFO", message, category, ...)
end

function Logger:Warn(message: string, category: LogCategory?, ...: any)
	self:Log("WARN", message, category, ...)
end

function Logger:Error(message: string, category: LogCategory?, ...: any)
	self:Log("ERROR", message, category, ...)
end

function Logger:Fatal(message: string, category: LogCategory?, ...: any)
	self:Log("FATAL", message, category, ...)
end

-- Singleton instance
local instance = Logger.new()
return setmetatable({}, {
	__index = function(_, key) return instance[key] end,
	__newindex = function(_, key, value) instance[key] = value end,
	__call = function(_, ...) return instance.new(...) end
})