--[[
    THIS SCRIPT MADE BY ^
    
             _                              _ 
     /\     | |                            | |
    /  \    | |__    _ __ ___     ___    __| |
   / /\ \   | '_ \  | '_ ` _ \   / _ \  / _` |
  / ____ \  | | | | | | | | | | |  __/ | (_| |
 /_/    \_\ |_| |_| |_| |_| |_|  \___|  \__,_|
                                              
    Back-end Engineer & Game Dev on Roblox!
    
    Portfolio: https://ahmedsayed.vercel.app
    Discord Username: ahmedsayed0
]]--

-- Types for autocomplete
export type RGB = {R: number, G: number, B: number}
export type Vector2 = {X: number, Y: number}

export type EmbedFooter = {
	text: string,
	icon_url: string?
}

export type EmbedImage = {
	url: string,
	proxy_url: string?,
	height: number?,
	width: number?
}

export type EmbedThumbnail = {
	url: string,
	proxy_url: string?,
	height: number?,
	width: number?
}

export type EmbedAuthor = {
	name: string,
	url: string?,
	icon_url: string?,
	proxy_icon_url: string?
}

export type EmbedField = {
	name: string,
	value: string,
	inline: boolean?
}

export type EmbedData = {
	title: string?,
	description: string?,
	url: string?,
	timestamp: string?,
	color: number?,
	footer: EmbedFooter?,
	image: EmbedImage?,
	thumbnail: EmbedThumbnail?,
	author: EmbedAuthor?,
	fields: {EmbedField}?
}

export type AllowedMentions = {
	parse: {"roles" | "users" | "everyone"}?,
	roles: {string}?,
	users: {string}?,
	replied_user: boolean?
}

export type WebhookData = {
	content: string?,
	username: string?,
	avatar_url: string?,
	tts: boolean?,
	embeds: {EmbedData}?,
	allowed_mentions: AllowedMentions?,
	thread_name: string?
}

export type WebhookResponse = {
	Success: boolean,
	Code: number,
	Message: string,
	RetryAfter: number?,
	Timestamp: number
}

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

-- Service
local WebhookService = {}
WebhookService.__index = WebhookService

-- Constants
local CONSTANTS = {
	MAX_RETRIES = 3,
	MAX_CONTENT_LENGTH = 2000,
	MAX_EMBED_LENGTH = 6000,
	MAX_FIELD_LENGTH = 1024,
	MAX_EMBEDS = 10,
	RATE_LIMIT_DELAY = 1,
	DEFAULT_TIMEOUT = 10,
	MAX_BATCH_SIZE = 10
}

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Internal Types
type QueueItem = {
	url: string,
	data: WebhookData,
	retryCount: number,
	callback: ((response: WebhookResponse) -> ())?
}

-- Queue system
local MessageQueue: {QueueItem} = {}
local IsProcessingQueue = false
local LastRequestTime = 0

-- Advanced Logger
local Logger = {
	Level = {
		DEBUG = 1,
		INFO = 2,
		WARN = 3,
		ERROR = 4
	},
	CurrentLevel = 2,
	Callbacks = {} :: {(level: LogLevel, message: string, ...any) -> ()}
}

function Logger:AddCallback(callback: (level: LogLevel, message: string, ...any) -> ())
	table.insert(self.Callbacks, callback)
end

function Logger:Log(level: LogLevel, message: string, ...: any)
	local levelNum = self.Level[level]
	if levelNum >= self.CurrentLevel then
		local formattedMessage = string.format("[WebhookService][%s][%s] %s",
			os.date("%Y-%m-%d %H:%M:%S"),
			level,
			string.format(message, ...))

		print(formattedMessage)

		for _, callback in self.Callbacks do
			task.spawn(callback, level, formattedMessage)
		end
	end
end

-- Validation Module
local Validator = {}

function Validator.Url(url: string): boolean
	return typeof(url) == "string" 
		and string.match(url, "^https://discord.com/api/webhooks/") ~= nil
end

function Validator.Embed(embed: EmbedData): (boolean, string?)
	local totalLength = 0

	if embed.title then
		if #embed.title > 256 then
			return false, "Title exceeds 256 characters"
		end
		totalLength += #embed.title
	end

	if embed.description then
		if #embed.description > 4096 then
			return false, "Description exceeds 4096 characters"
		end
		totalLength += #embed.description
	end

	if embed.fields then
		if #embed.fields > 25 then
			return false, "Too many fields (max 25)"
		end

		for _, field in embed.fields do
			if #field.name > 256 then
				return false, "Field name exceeds 256 characters"
			end
			if #field.value > CONSTANTS.MAX_FIELD_LENGTH then
				return false, "Field value exceeds 1024 characters"
			end
			totalLength += #field.name + #field.value
		end
	end

	if totalLength > CONSTANTS.MAX_EMBED_LENGTH then
		return false, "Total embed length exceeds 6000 characters"
	end

	return true, nil
end

-- Rich Embed Builder with Autocomplete
local EmbedBuilder = {}
EmbedBuilder.__index = EmbedBuilder

export type EmbedBuilder = typeof(setmetatable({} :: {
	embed: EmbedData,
	Build: (self: EmbedBuilder) -> EmbedData,
	SetTitle: (self: EmbedBuilder, title: string) -> EmbedBuilder,
	SetDescription: (self: EmbedBuilder, description: string) -> EmbedBuilder,
	SetColor: (self: EmbedBuilder, color: Color3 | RGB | number) -> EmbedBuilder,
	SetTimestamp: (self: EmbedBuilder, timestamp: DateTime?) -> EmbedBuilder,
	SetFooter: (self: EmbedBuilder, text: string, iconUrl: string?) -> EmbedBuilder,
	SetImage: (self: EmbedBuilder, url: string, size: Vector2?) -> EmbedBuilder,
	SetThumbnail: (self: EmbedBuilder, url: string, size: Vector2?) -> EmbedBuilder,
	SetAuthor: (self: EmbedBuilder, name: string, url: string?, iconUrl: string?) -> EmbedBuilder,
	AddField: (self: EmbedBuilder, name: string, value: string, inline: boolean?) -> EmbedBuilder,
}, EmbedBuilder))

function WebhookService.CreateEmbedBuilder(): EmbedBuilder
	local self = setmetatable({}, EmbedBuilder)
	self.embed = {}
	return self
end

-- Rich Embed Builder Method Implementations
function EmbedBuilder:Build(): EmbedData
	return self.embed
end

function EmbedBuilder:SetTitle(title: string): EmbedBuilder
	assert(type(title) == "string", "Title must be a string")
	assert(#title <= 256, "Title must not exceed 256 characters")
	self.embed.title = title
	return self
end

function EmbedBuilder:SetDescription(description: string): EmbedBuilder
	assert(type(description) == "string", "Description must be a string")
	assert(#description <= 4096, "Description must not exceed 4096 characters")
	self.embed.description = description
	return self
end

function EmbedBuilder:SetColor(color: Color3 | RGB | number): EmbedBuilder
	if typeof(color) == "Color3" then
		self.embed.color = (color.R * 255) * 65536 + (color.G * 255) * 256 + (color.B * 255)
	elseif type(color) == "table" and color.R and color.G and color.B then
		self.embed.color = color.R * 65536 + color.G * 256 + color.B
	elseif type(color) == "number" then
		self.embed.color = color
	else
		error("Invalid color format")
	end
	return self
end

function EmbedBuilder:SetTimestamp(timestamp: DateTime?): EmbedBuilder
	if timestamp then
		self.embed.timestamp = timestamp:ToIsoDate()
	else
		self.embed.timestamp = DateTime.now():ToIsoDate()
	end
	return self
end

function EmbedBuilder:SetFooter(text: string, iconUrl: string?): EmbedBuilder
	assert(type(text) == "string", "Footer text must be a string")
	assert(#text <= 2048, "Footer text must not exceed 2048 characters")
	self.embed.footer = {
		text = text,
		icon_url = iconUrl
	}
	return self
end

function EmbedBuilder:SetImage(url: string, size: Vector2?): EmbedBuilder
	assert(type(url) == "string", "Image URL must be a string")
	local imageData: EmbedImage = {
		url = url
	}
	if size then
		imageData.height = size.Y
		imageData.width = size.X
	end
	self.embed.image = imageData
	return self
end

function EmbedBuilder:SetThumbnail(url: string, size: Vector2?): EmbedBuilder
	assert(type(url) == "string", "Thumbnail URL must be a string")
	local thumbnailData: EmbedThumbnail = {
		url = url
	}
	if size then
		thumbnailData.height = size.Y
		thumbnailData.width = size.X
	end
	self.embed.thumbnail = thumbnailData
	return self
end

function EmbedBuilder:SetAuthor(name: string, url: string?, iconUrl: string?): EmbedBuilder
	assert(type(name) == "string", "Author name must be a string")
	assert(#name <= 256, "Author name must not exceed 256 characters")
	self.embed.author = {
		name = name,
		url = url,
		icon_url = iconUrl
	}
	return self
end

function EmbedBuilder:AddField(name: string, value: string, inline: boolean?): EmbedBuilder
	assert(type(name) == "string", "Field name must be a string")
	assert(type(value) == "string", "Field value must be a string")
	assert(#name <= 256, "Field name must not exceed 256 characters")
	assert(#value <= 1024, "Field value must not exceed 1024 characters")

	if not self.embed.fields then
		self.embed.fields = {}
	end
	assert(#self.embed.fields < 25, "Cannot add more than 25 fields")

	table.insert(self.embed.fields, {
		name = name,
		value = value,
		inline = inline or false
	})
	return self
end

-- Enhanced Queue Processor with Advanced Error Handling
local function ProcessQueue()
	if IsProcessingQueue then return end
	IsProcessingQueue = true

	while #MessageQueue > 0 do
		local currentTime = os.time()
		local timeSinceLastRequest = currentTime - LastRequestTime

		if timeSinceLastRequest < CONSTANTS.RATE_LIMIT_DELAY then
			task.wait(CONSTANTS.RATE_LIMIT_DELAY - timeSinceLastRequest)
		end

		local nextMessage = table.remove(MessageQueue, 1)
		local success, response = pcall(function()
			return HttpService:RequestAsync({
				Url = nextMessage.url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = HttpService:JSONEncode(nextMessage.data)
			})
		end)

		LastRequestTime = os.time()

		local result: WebhookResponse = {
			Success = false,
			Code = 0,
			Message = "",
			Timestamp = os.time()
		}

		if not success then
			Logger:Log("ERROR", "Request failed: %s", response)
			result.Message = tostring(response)

			if nextMessage.retryCount < CONSTANTS.MAX_RETRIES then
				nextMessage.retryCount += 1
				table.insert(MessageQueue, nextMessage)
				Logger:Log("WARN", "Retrying request (Attempt %d/%d)", 
					nextMessage.retryCount, CONSTANTS.MAX_RETRIES)
			end
		else
			result.Code = response.StatusCode

			if response.StatusCode == 429 then
				local retryAfter = tonumber(response.Headers["retry-after"] or 
					CONSTANTS.RATE_LIMIT_DELAY)
				result.RetryAfter = retryAfter

				Logger:Log("WARN", "Rate limited. Waiting %d seconds", retryAfter)
				task.wait(retryAfter)

				table.insert(MessageQueue, nextMessage)
			elseif response.StatusCode >= 200 and response.StatusCode < 300 then
				result.Success = true
				result.Message = "Success"
			else
				result.Message = string.format("HTTP %d: %s", 
					response.StatusCode, response.Body)
			end
		end

		if nextMessage.callback then
			task.spawn(nextMessage.callback, result)
		end
	end

	IsProcessingQueue = false
end

-- Enhanced WebhookService Methods
function WebhookService:SendMessage(url: string, content: string | WebhookData, 
	callback: ((response: WebhookResponse) -> ())?)

	assert(Validator.Url(url), "Invalid webhook URL")

	local data = if type(content) == "string" 
		then { content = content } 
		else content

	if type(content) == "string" and #content > CONSTANTS.MAX_CONTENT_LENGTH then
		local chunks = {}
		for i = 1, #content, CONSTANTS.MAX_CONTENT_LENGTH do
			table.insert(chunks, content:sub(i, i + CONSTANTS.MAX_CONTENT_LENGTH - 1))
		end

		for i, chunk in chunks do
			table.insert(MessageQueue, {
				url = url,
				data = { content = chunk },
				retryCount = 0,
				callback = if i == #chunks then callback else nil
			})
		end
	else
		table.insert(MessageQueue, {
			url = url,
			data = data,
			retryCount = 0,
			callback = callback
		})
	end

	task.spawn(ProcessQueue)
end

function WebhookService:BatchSend(url: string, messages: {string | WebhookData}, 
	callback: ((responses: {WebhookResponse}) -> ())?)

	local responses = {}
	local remaining = #messages

	local function handleResponse(index: number, response: WebhookResponse)
		responses[index] = response
		remaining -= 1

		if remaining == 0 and callback then
			callback(responses)
		end
	end

	for i, message in messages do
		self:SendMessage(url, message, function(response)
			handleResponse(i, response)
		end)
	end
end

-- Configuration
function WebhookService:SetLogLevel(level: LogLevel)
	Logger.CurrentLevel = Logger.Level[level]
end

function WebhookService:OnLog(callback: (level: LogLevel, message: string) -> ())
	Logger:AddCallback(callback)
end

-- Initialize the service
local function Init()
	Logger:Log("INFO", "Made by @ahmedsayed0, Porfolio: https://ahmedsayedv2.vercel.app/")
	Logger:Log("INFO", "WebhookService initialized")
end

-- Run initialization
Init()

return WebhookService
