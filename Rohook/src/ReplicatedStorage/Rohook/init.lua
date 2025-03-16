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
    A robust library for interacting with Discord webhooks from Roblox. Supports sending messages, editing, deleting, scheduling, and managing templates with priority queuing, rate limiting, and an EmbedBuilder for rich embeds.

    Dependencies:
    - Logger: For logging events (Credits: Ahmed).
    - Validator: For validating URLs and embeds (Credits: Ahmed).
    - Utils: For deep copying and placeholder replacement (Credits: Ahmed).

    Send your first webhook message:
    local Rohook = require(path.to.Rohook)
    local webhook = Rohook.new(
    	"https://discord.com/api/webhooks/123/token", 
    	{rateLimitWarning = true, batchProcessing = true}
    )
    webhook:SendMessage("Hello, Roblox!")
]]

-- **Dependencies**
local Logger = require(script.Logger)
local Validator = require(script.Validator)
local Utils = require(script.Utils)
local HttpService = game:GetService("HttpService")

local log = Logger.new()
local validator = Validator.new()

-- **Type Definitions**

-- Basic utility types
export type RGB = {R: number, G: number, B: number}
export type Vector2 = {X: number, Y: number} -- 2D vector for image/thumbnail sizes.
export type ISODateString = string -- ISO 8601 date string (e.g., "2025-03-12T14:30:00Z").

-- Embed-related types (aligned with Validator's EmbedData)
export type EmbedFooter = {text: string, icon_url: string?} -- Footer for an embed.
export type EmbedImage = {url: string, proxy_url: string?, height: number?, width: number?} -- Image in an embed.
export type EmbedThumbnail = {url: string, proxy_url: string?, height: number?, width: number?} -- Thumbnail in an embed.
export type EmbedAuthor = {name: string, url: string?, icon_url: string?} -- Author of an embed.
export type EmbedField = {name: string, value: string, inline: boolean?} -- Field in an embed.

--[[
    EmbedData: Structure for a Discord embed (matches Validator's definition).
    - title: Optional title (max 256 chars).
    - description: Optional description (max 4096 chars).
    - url: Optional title hyperlink.
    - timestamp: Optional ISO timestamp.
    - color: Optional color as a hex number.
    - footer: Optional footer.
    - image: Optional main image.
    - thumbnail: Optional thumbnail.
    - author: Optional author info.
    - fields: Optional array of fields (max 25, each name ≤ 256 chars, value ≤ 1024 chars).
]]
export type EmbedData = {
	title: string?, description: string?, url: string?, timestamp: ISODateString?, color: number?,
	footer: EmbedFooter?, image: EmbedImage?, thumbnail: EmbedThumbnail?, author: EmbedAuthor?,
	fields: {EmbedField}?
}

--[[
    WebhookData: Payload for a Discord webhook.
    - content: Optional message text (max 2000 chars).
    - username: Optional override for webhook username.
    - avatar_url: Optional override for webhook avatar.
    - tts: Optional text-to-speech flag.
    - embeds: Optional array of embeds (max 10).
    - thread_name: Optional name for a new thread.
    - thread_id: Optional ID of target thread.
    - flags: Optional message flags.
]]
export type WebhookData = {
	content: string?, username: string?, avatar_url: string?, tts: boolean?, embeds: {EmbedData}?,
	thread_name: string?, thread_id: string?, flags: number?
}

--[[
    WebhookResponse: Response from a webhook request.
    - Success: Whether the request succeeded.
    - Code: HTTP status code.
    - Message: Response or error message.
    - MessageId: ID of the sent message (if applicable).
    - RetryAfter: Seconds to wait if rate limited.
    - Timestamp: Time of response.
    - RateLimitRemaining: Remaining requests before rate limit.
]]
export type WebhookResponse = {
	Success: boolean, Code: number, Message: string, MessageId: string?, RetryAfter: number?,
	Timestamp: number, RateLimitRemaining: number?
}

-- Configuration and options
export type WebhookOptions = {rateLimitWarning: boolean?, batchProcessing: boolean?} -- Webhook setup options.

-- Predefined colors for embeds
export type ColorName = "Red" | "Green" | "Blue" | "Yellow" | "Purple" | "Orange" | "Cyan" | "Magenta" | "White" | "Black" | "Gray"
export type Colors = {[ColorName]: number} -- Maps color names to hex values.

--[[
    TimeBasedOptions: Options for scheduling a message.
    - data: Message data to send.
    - delaySeconds: Delay in seconds before sending.
    - scheduleTime: ISO timestamp for sending.
    - repeatInterval: Interval in seconds for repeating.
    - callback: Optional callback on send.
]]
export type TimeBasedOptions = {
	data: WebhookData, delaySeconds: number?, scheduleTime: ISODateString?, repeatInterval: number?,
	callback: ((response: WebhookResponse) -> ())?
}

--[[
    EditTimeBasedOptions: Options for scheduling a message edit.
    - messageId: ID of the message to edit.
    - data: New message data.
    - delaySeconds: Delay in seconds before editing.
    - scheduleTime: ISO timestamp for editing.
    - callback: Optional callback on edit.
]]
export type EditTimeBasedOptions = {
	messageId: string, data: WebhookData, delaySeconds: number?, scheduleTime: ISODateString?,
	callback: ((response: WebhookResponse) -> ())?
}

export type TemplateVariables = {[string]: string} -- Key-value pairs for template substitution (e.g., {["username"] = "Roblox"}).

-- **Constants**
local CONSTANTS = {
	MAX_CONTENT = 2000, -- Max characters for content
	MAX_EMBEDS = 10,    -- Max embeds per message
	MAX_CACHE = 100,    -- Max cached messages
	RETRY_DELAY = 1,    -- Base delay for retries (seconds)
	MAX_RETRIES = 5,    -- Max retry attempts
	RATE_LIMIT_THRESHOLD = 5, -- Warn when remaining requests ≤ this
	BATCH_SIZE = 50,    -- Max items per batch
	DEFAULT_PRIORITY = 1 -- Default queue priority
}

-- **Webhook Object Definitions**
local Rohook = {} :: WebhookServiceType
local Webhook = {} :: WebhookType
Webhook.__index = Webhook
Rohook.__index = Rohook

--[[
    WebhookServiceType: Main service interface.
    - new: Creates a new webhook instance.
    - CreateEmbedBuilder: Creates an embed builder.
    - Colors: Predefined color codes.
]]
type WebhookServiceType = {
	new: (url: string, options: WebhookOptions?) -> WebhookType,
	CreateEmbedBuilder: () -> EmbedBuilderType,
	Colors: Colors
}

--[[
    WebhookType: Instance of a webhook with methods.
]]
type WebhookType = {
	url: string, queue: {QueueItem}, priorityQueue: {QueueItem}, isProcessing: boolean,
	templates: {[string]: WebhookData}, messageCache: {{id: string, data: WebhookData}},
	rateLimitWarning: boolean, batchProcessing: boolean, scheduledTasks: {[string]: boolean},
	stats: {sent: number, failed: number, rateLimited: number}, rateLimitInfo: {remaining: number?, reset: number?},
	SendMessage: (self: WebhookType, content: string | WebhookData, callback: ((WebhookResponse) -> ())?, priority: number?) -> (),
	sendImportantMessage: (self: WebhookType, data: WebhookData, callback: ((WebhookResponse) -> ())?) -> (),
	sendTimeBasedMessage: (self: WebhookType, options: TimeBasedOptions) -> string,
	editTimeBasedMessage: (self: WebhookType, options: EditTimeBasedOptions) -> string,
	cancelScheduledTask: (self: WebhookType, taskId: string) -> boolean,
	bulkSend: (self: WebhookType, messages: {WebhookData}, callback: (({WebhookResponse}) -> ())?) -> (),
	sendWithRetry: (self: WebhookType, data: WebhookData, maxRetries: number?, callback: ((WebhookResponse) -> ())?) -> (),
	send: (self: WebhookType, data: WebhookData, callback: ((WebhookResponse) -> ())?, priority: number?) -> (),
	editMessage: (self: WebhookType, messageId: string, data: WebhookData, callback: ((WebhookResponse) -> ())?) -> (),
	deleteMessage: (self: WebhookType, messageId: string, callback: ((WebhookResponse) -> ())?) -> (),
	saveTemplate: (self: WebhookType, name: string, data: WebhookData) -> (),
	useTemplate: (self: WebhookType, name: string, variables: TemplateVariables?, callback: ((WebhookResponse) -> ())?) -> (),
	getStats: (self: WebhookType) -> {sent: number, failed: number, rateLimited: number},
	checkRateLimit: (self: WebhookType) -> {remaining: number?, reset: number?},
	checkWebhookHealth: (self: WebhookType, callback: ((boolean, string) -> ())?) -> ()
}

type QueueItem = {
	type: "send" | "edit" | "delete", url: string?, data: WebhookData?, messageId: string?,
	retryCount: number, callback: ((WebhookResponse) -> ())?, priority: number
}

-- **EmbedBuilder Definition**
local EmbedBuilder = {} :: EmbedBuilderType
EmbedBuilder.__index = EmbedBuilder

--[[
    EmbedBuilderType: Interface for building embeds with chaining.
]]
type EmbedBuilderType = {
	embed: EmbedData,
	Build: (self: EmbedBuilderType) -> EmbedData,
	SetTitle: (self: EmbedBuilderType, title: string) -> EmbedBuilderType,
	SetDescription: (self: EmbedBuilderType, desc: string) -> EmbedBuilderType,
	SetColor: (self: EmbedBuilderType, color: Color3 | RGB | number) -> EmbedBuilderType,
	SetTimestamp: (self: EmbedBuilderType) -> EmbedBuilderType,
	SetFooter: (self: EmbedBuilderType, text: string, iconUrl: string?) -> EmbedBuilderType,
	SetImage: (self: EmbedBuilderType, url: string, size: Vector2?) -> EmbedBuilderType,
	SetThumbnail: (self: EmbedBuilderType, url: string, size: Vector2?) -> EmbedBuilderType,
	SetAuthor: (self: EmbedBuilderType, name: string, url: string?, iconUrl: string?) -> EmbedBuilderType,
	AddField: (self: EmbedBuilderType, name: string, value: string, inline: boolean?) -> EmbedBuilderType
}

-- **Main Methods**

--[[
    Creates a new Webhook instance.
    @param url Discord webhook URL (e.g., "https://discord.com/api/webhooks/123/token").
    @param options Optional settings (rateLimitWarning, batchProcessing).
    @return Webhook instance.
    @example local webhook = Rohook.new("https://discord.com/api/webhooks/123/token", {rateLimitWarning = true, batchProcessing = true})
]]
function Rohook.new(url: string, options: WebhookOptions?): WebhookType
	local isValid, errorMsg = validator:Url(url)
	assert(isValid, errorMsg or "Invalid webhook URL")
	local self = setmetatable({
		url = url, queue = {}, priorityQueue = {}, isProcessing = false, templates = {},
		messageCache = {}, rateLimitWarning = options and options.rateLimitWarning or false,
		batchProcessing = options and options.batchProcessing or false, scheduledTasks = {},
		stats = {sent = 0, failed = 0, rateLimited = 0}, rateLimitInfo = {remaining = nil, reset = nil}
	}, Webhook) :: WebhookType
	self:checkWebhookHealth(function(isHealthy, message)
		if not isHealthy then log:Warn("Webhook health check failed: %s", "WEBHOOK", message or "Unknown error") end
	end)
	log:Info("Rohook initialized for URL: %s", "SYSTEM", tostring(url))
	return self
end

--[[
    Creates a new EmbedBuilder instance.
    @return EmbedBuilder instance.
    @example local builder = Rohook.CreateEmbedBuilder()
]]
function Rohook.CreateEmbedBuilder(): EmbedBuilderType
	return setmetatable({embed = {}}, EmbedBuilder) :: EmbedBuilderType
end

--[[
    Predefined color codes for embeds.
    @example local red = Rohook.Colors.Red
]]
Rohook.Colors = {
	Red = 0xFF0000, Green = 0x00FF00, Blue = 0x0000FF, Yellow = 0xFFFF00, Purple = 0x800080,
	Orange = 0xFFA500, Cyan = 0x00FFFF, Magenta = 0xFF00FF, White = 0xFFFFFF, Black = 0x000000, Gray = 0x808080
} :: Colors

-- **Core Queue Processor**
local function processQueue(self: WebhookType)
	if self.isProcessing then return end
	self.isProcessing = true
	task.spawn(function()
		while #self.priorityQueue > 0 or #self.queue > 0 do
			local queueToProcess = #self.priorityQueue > 0 and self.priorityQueue or self.queue
			table.sort(queueToProcess, function(a, b) return a.priority > b.priority end)
			local items: {QueueItem} = {}
			for i = 1, math.min(self.batchProcessing and CONSTANTS.BATCH_SIZE or 1, #queueToProcess) do
				if #queueToProcess > 0 then table.insert(items, table.remove(queueToProcess, 1) :: QueueItem) end
			end

			for _, item in ipairs(items) do
				local url = item.url or self.url
				if item.type == "send" then
					url = url .. (string.find(url, "?") and "&" or "?") .. "wait=true"
					if item.data and item.data.thread_id then url = url .. "&thread_id=" .. item.data.thread_id end
				elseif item.type == "edit" or item.type == "delete" then
					url = url .. "/messages/" .. item.messageId
				end
				local method = item.type == "delete" and "DELETE" or (item.type == "edit" and "PATCH" or "POST")
				local cleanedData = item.data and Utils.deepCopy(item.data) :: WebhookData?
				log:Debug("Sending payload: %s to %s", "NETWORK", HttpService:JSONEncode(cleanedData or {}), url)

				local success, response = pcall(function()
					return HttpService:RequestAsync({
						Url = url, Method = method, Headers = {["Content-Type"] = "application/json"},
						Body = item.type ~= "delete" and HttpService:JSONEncode(cleanedData) or nil
					})
				end)
				local result: WebhookResponse = {
					Success = false, Code = 0, Message = "", MessageId = nil, RetryAfter = nil,
					Timestamp = os.time(), RateLimitRemaining = nil
				}
				if success then
					self.stats.sent += 1
					result.Code = response.StatusCode
					result.RateLimitRemaining = tonumber(response.Headers["x-ratelimit-remaining"])
					self.rateLimitInfo.remaining = result.RateLimitRemaining
					self.rateLimitInfo.reset = tonumber(response.Headers["x-ratelimit-reset"])
					if response.StatusCode >= 200 and response.StatusCode < 300 then
						result.Success = true
						result.Message = "Success"
						if item.type == "send" and response.Body and response.Body ~= "" then
							local decodeSuccess, body = pcall(HttpService.JSONDecode, HttpService, response.Body)
							if decodeSuccess then
								result.MessageId = body.id
								table.insert(self.messageCache, 1, {id = result.MessageId :: string, data = item.data :: WebhookData})
								if #self.messageCache > CONSTANTS.MAX_CACHE then table.remove(self.messageCache) end
							end
						end
					elseif response.StatusCode == 429 then
						self.stats.rateLimited += 1
						result.RetryAfter = tonumber(response.Headers["retry-after"] or CONSTANTS.RETRY_DELAY)
						result.Message = "Rate limited, retrying after " .. result.RetryAfter .. "s"
						task.wait(result.RetryAfter)
						table.insert(queueToProcess, 1, item)
					else
						self.stats.failed += 1
						result.Message = "HTTP " .. response.StatusCode .. ": " .. (response.Body or "Unknown error")
					end
					if self.rateLimitWarning and result.RateLimitRemaining and result.RateLimitRemaining <= CONSTANTS.RATE_LIMIT_THRESHOLD then
						log:Warn("Rate limit nearing: %d requests remaining", "NETWORK", result.RateLimitRemaining)
					end
				else
					self.stats.failed += 1
					result.Message = "Request failed: " .. tostring(response)
					log:Error("Request failed: %s", "NETWORK", tostring(response))
					if item.retryCount < CONSTANTS.MAX_RETRIES then
						item.retryCount += 1
						task.wait(2 ^ item.retryCount * CONSTANTS.RETRY_DELAY)
						table.insert(queueToProcess, 1, item)
					end
				end
				if item.callback then task.spawn(item.callback, result) end
			end
			task.wait(0.1)
		end
		self.isProcessing = false
	end)
end

-- **Webhook Instance Methods**

--[[
    Sends a message to the webhook.
    @param content String for simple text or WebhookData for complex payloads.
    @param callback Optional function to handle response.
    @param priority Optional priority level (default 1).
    @example webhook:SendMessage("Hello!", function(resp) log:Info(resp.Success) end)
]]
function Webhook:SendMessage(content: string | WebhookData, callback: ((WebhookResponse) -> ())?, priority: number?)
	local data: WebhookData = type(content) == "string" and {content = content} or content :: WebhookData
	if data.content and #data.content > CONSTANTS.MAX_CONTENT then
		for i = 1, #data.content, CONSTANTS.MAX_CONTENT do
			local chunk = data.content:sub(i, i + CONSTANTS.MAX_CONTENT - 1)
			self:SendMessage({content = chunk}, i == math.ceil(#data.content / CONSTANTS.MAX_CONTENT) and callback or nil, priority)
		end
		return
	end
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	table.insert(self.queue, {type = "send", url = self.url, data = data, retryCount = 0, callback = callback, priority = priority or CONSTANTS.DEFAULT_PRIORITY} :: QueueItem)
	processQueue(self)
end

--[[
    Sends a high-priority message.
    @param data Message data.
    @param callback Optional response handler.
    @example webhook:sendImportantMessage({content = "Urgent!"}, function(resp) log:Info(resp.Success) end)
]]
function Webhook:sendImportantMessage(data: WebhookData, callback: ((WebhookResponse) -> ())?)
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	table.insert(self.priorityQueue, {type = "send", url = self.url, data = data, retryCount = 0, callback = callback, priority = 10} :: QueueItem)
	processQueue(self)
end

--[[
    Schedules a message to send later.
    @param options Scheduling options.
    @return Task ID for cancellation.
    @example local id = webhook:sendTimeBasedMessage({data = {content = "Later"}, delaySeconds = 60})
]]
function Webhook:sendTimeBasedMessage(options: TimeBasedOptions): string
	local taskId = HttpService:GenerateGUID(false)
	local data = Utils.deepCopy(options.data) :: WebhookData
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return taskId end
		end
	end
	self.scheduledTasks[taskId] = true
	task.spawn(function()
		if options.scheduleTime then
			local timeParts = {options.scheduleTime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")}
			local scheduledTime = os.time({year = timeParts[1], month = timeParts[2], day = timeParts[3], hour = timeParts[4], min = timeParts[5], sec = timeParts[6]})
			task.wait(math.max(0, scheduledTime - os.time()))
		elseif options.delaySeconds then
			task.wait(options.delaySeconds)
		end
		if self.scheduledTasks[taskId] then
			self:send(data, options.callback)
			if options.repeatInterval then
				while self.scheduledTasks[taskId] do
					task.wait(options.repeatInterval)
					if self.scheduledTasks[taskId] then self:send(data, options.callback) end
				end
			else
				self.scheduledTasks[taskId] = nil
			end
		end
	end)
	return taskId
end

--[[
    Schedules an edit to an existing message.
    @param options Edit scheduling options.
    @return Task ID for cancellation.
    @example local id = webhook:editTimeBasedMessage({messageId = "123", data = {content = "Edited"}, delaySeconds = 30})
]]
function Webhook:editTimeBasedMessage(options: EditTimeBasedOptions): string
	local taskId = HttpService:GenerateGUID(false)
	local data = Utils.deepCopy(options.data) :: WebhookData
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return taskId end
		end
	end
	self.scheduledTasks[taskId] = true
	task.spawn(function()
		if options.scheduleTime then
			local timeParts = {options.scheduleTime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")}
			local scheduledTime = os.time({year = timeParts[1], month = timeParts[2], day = timeParts[3], hour = timeParts[4], min = timeParts[5], sec = timeParts[6]})
			task.wait(math.max(0, scheduledTime - os.time()))
		elseif options.delaySeconds then
			task.wait(options.delaySeconds)
		end
		if self.scheduledTasks[taskId] then
			self:editMessage(options.messageId, data, options.callback)
			self.scheduledTasks[taskId] = nil
		end
	end)
	return taskId
end

--[[
    Cancels a scheduled task.
    @param taskId ID of the task to cancel.
    @return True if cancelled, false if not found.
    @example local cancelled = webhook:cancelScheduledTask("task-id")
]]
function Webhook:cancelScheduledTask(taskId: string): boolean
	if self.scheduledTasks[taskId] then
		self.scheduledTasks[taskId] = nil
		log:Info("Cancelled task: %s", "WEBHOOK", taskId)
		return true
	end
	return false
end

--[[
    Sends multiple messages in bulk.
    @param messages Array of message data.
    @param callback Optional handler for responses.
    @example webhook:bulkSend({{content = "Msg1"}, {content = "Msg2"}}, function(responses) log:Info(#responses) end)
]]
function Webhook:bulkSend(messages: {WebhookData}, callback: (({WebhookResponse}) -> ())?)
	local responses = {}
	for i, data in ipairs(messages) do
		if data.embeds then
			for _, embed in ipairs(data.embeds) do
				local isValid, errorMsg = validator:Embed(embed)
				if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return end
			end
		end
		self:SendMessage(data, function(resp)
			responses[i] = resp
			if #responses == #messages and callback then callback(responses) end
		end)
	end
end

--[[
    Sends a message with automatic retries on failure.
    @param data Message data.
    @param maxRetries Optional max retry attempts (default 5).
    @param callback Optional response handler.
    @example webhook:sendWithRetry({content = "Retry me"}, 3, function(resp) log:Info(resp.Success) end)
]]
function Webhook:sendWithRetry(data: WebhookData, maxRetries: number?, callback: ((WebhookResponse) -> ())?)
	local retries = 0
	local max = maxRetries or CONSTANTS.MAX_RETRIES
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	local function attempt()
		self:SendMessage(data, function(resp)
			if not resp.Success and retries < max and resp.Code == 429 then
				retries += 1
				task.wait(resp.RetryAfter or CONSTANTS.RETRY_DELAY)
				attempt()
			elseif callback then
				callback(resp)
			end
		end)
	end
	attempt()
end

--[[
    Alias for SendMessage.
    @param data Message data.
    @param callback Optional response handler.
    @param priority Optional priority level.
    @example webhook:send({content = "Alias"})
]]
function Webhook:send(data: WebhookData, callback: ((WebhookResponse) -> ())?, priority: number?)
	self:SendMessage(data, callback, priority)
end

--[[
    Edits a previously sent message.
    @param messageId ID of the message to edit.
    @param data New message data.
    @param callback Optional response handler.
    @example webhook:editMessage("123", {content = "Edited"}, function(resp) log:Info(resp.Success) end)
]]
function Webhook:editMessage(messageId: string, data: WebhookData, callback: ((WebhookResponse) -> ())?)
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	table.insert(self.queue, {type = "edit", messageId = messageId, data = data, retryCount = 0, callback = callback, priority = CONSTANTS.DEFAULT_PRIORITY} :: QueueItem)
	processQueue(self)
end

--[[
    Deletes a previously sent message.
    @param messageId ID of the message to delete.
    @param callback Optional response handler.
    @example webhook:deleteMessage("123", function(resp) log:Info(resp.Success) end)
]]
function Webhook:deleteMessage(messageId: string, callback: ((WebhookResponse) -> ())?)
	table.insert(self.queue, {type = "delete", messageId = messageId, retryCount = 0, callback = callback, priority = CONSTANTS.DEFAULT_PRIORITY} :: QueueItem)
	processQueue(self)
end

--[[
    Saves a message template for reuse.
    @param name Template name.
    @param data Template data with placeholders (e.g., "{username}").
    @example webhook:saveTemplate("greet", {content = "Hello, {username}!", embeds = {{title = "Welcome {username}"}}})
]]
function Webhook:saveTemplate(name: string, data: WebhookData)
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed in template: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	self.templates[name] = Utils.deepCopy(data)
	log:Info("Saved template: %s", "WEBHOOK", name)
end

--[[
    Sends a message using a saved template with variable substitution.
    @param name Template name.
    @param variables Optional variables to substitute (e.g., {["username"] = "Roblox"}).
    @param callback Optional response handler.
    @example webhook:useTemplate("greet", {["username"] = "Roblox"}, function(resp) log:Info(resp.Success) end)
]]
function Webhook:useTemplate(name: string, variables: TemplateVariables?, callback: ((WebhookResponse) -> ())?)
	if not self.templates[name] then
		log:Error("Template not found: %s", "WEBHOOK", name)
		return
	end
	local data = Utils.deepCopy(self.templates[name]) :: WebhookData
	if variables then
		data = Utils.replacePlaceholders(data, variables) :: WebhookData
	end
	if data.embeds then
		for _, embed in ipairs(data.embeds) do
			local isValid, errorMsg = validator:Embed(embed)
			if not isValid then log:Error("Invalid embed after substitution: %s", "WEBHOOK", errorMsg or "Unknown error") return end
		end
	end
	self:SendMessage(data, callback)
end

--[[
    Gets statistics on sent messages.
    @return Stats including sent, failed, and rate-limited counts.
    @example local stats = webhook:getStats()
]]
function Webhook:getStats(): {sent: number, failed: number, rateLimited: number}
	return Utils.deepCopy(self.stats)
end

--[[
    Checks current rate limit status.
    @return Rate limit info (remaining requests, reset time).
    @example local limits = webhook:checkRateLimit()
]]
function Webhook:checkRateLimit(): {remaining: number?, reset: number?}
	return Utils.deepCopy(self.rateLimitInfo)
end

--[[
    Checks the health of the webhook.
    @param callback Optional handler with health status and message.
    @example webhook:checkWebhookHealth(function(healthy, msg) log:Info(tostring(healthy) .. ": " .. msg) end)
]]
function Webhook:checkWebhookHealth(callback: ((boolean, string) -> ())?)
	local success, response = pcall(function()
		return HttpService:RequestAsync({Url = self.url, Method = "GET"})
	end)
	if success and response.StatusCode == 200 then
		if callback then callback(true, "Webhook is healthy") end
	else
		if callback then callback(false, success and response.StatusMessage or tostring(response)) end
	end
end

-- **EmbedBuilder Methods**

--[[
    Finalizes and returns the embed data.
    @return Constructed embed data.
    @example local embed = builder:Build()
]]
function EmbedBuilder:Build(): EmbedData
	local embed = Utils.deepCopy(self.embed)
	local isValid, errorMsg = validator:Embed(embed)
	if not isValid then log:Error("Invalid embed: %s", "VALIDATION", errorMsg or "Unknown error") return {} :: EmbedData end
	return embed
end

--[[
    Sets the embed title.
    @param title Title text (max 256 chars).
    @return Self for method chaining.
    @example builder:SetTitle("Announcement")
]]
function EmbedBuilder:SetTitle(title: string): EmbedBuilderType
	self.embed.title = title
	return self
end

--[[
    Sets the embed description.
    @param desc Description text (max 4096 chars).
    @return Self for method chaining.
    @example builder:SetDescription("Details here")
]]
function EmbedBuilder:SetDescription(desc: string): EmbedBuilderType
	self.embed.description = desc
	return self
end

--[[
    Sets the embed color.
    @param color Color3, RGB table, or hex number.
    @return Self for method chaining.
    @example builder:SetColor(Rohook.Colors.Blue)
]]
function EmbedBuilder:SetColor(color: Color3 | RGB | number): EmbedBuilderType
	if typeof(color) == "Color3" then
		self.embed.color = math.floor(color.R * 255) * 65536 + math.floor(color.G * 255) * 256 + math.floor(color.B * 255)
	elseif type(color) == "table" then
		self.embed.color = math.floor(color.R) * 65536 + math.floor(color.G) * 256 + math.floor(color.B)
	else
		self.embed.color = color
	end
	return self
end

--[[
    Sets the embed timestamp to the current time.
    @return Self for method chaining.
    @example builder:SetTimestamp()
]]
function EmbedBuilder:SetTimestamp(): EmbedBuilderType
	self.embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
	return self
end

--[[
    Sets the embed footer.
    @param text Footer text.
    @param iconUrl Optional icon URL.
    @return Self for method chaining.
    @example builder:SetFooter("Powered by Roblox", "https://example.com/icon.png")
]]
function EmbedBuilder:SetFooter(text: string, iconUrl: string?): EmbedBuilderType
	self.embed.footer = {text = text, icon_url = iconUrl}
	return self
end

--[[
    Sets the embed image.
    @param url Image URL.
    @param size Optional Vector2 for dimensions.
    @return Self for method chaining.
    @example builder:SetImage("https://example.com/image.png")
]]
function EmbedBuilder:SetImage(url: string, size: Vector2?): EmbedBuilderType
	self.embed.image = {url = url, height = size and size.Y, width = size and size.X}
	return self
end

--[[
    Sets the embed thumbnail.
    @param url Thumbnail URL.
    @param size Optional Vector2 for dimensions.
    @return Self for method chaining.
    @example builder:SetThumbnail("https://example.com/thumb.png")
]]
function EmbedBuilder:SetThumbnail(url: string, size: Vector2?): EmbedBuilderType
	self.embed.thumbnail = {url = url, height = size and size.Y, width = size and size.X}
	return self
end

--[[
    Sets the embed author.
    @param name Author name.
    @param url Optional author URL.
    @param iconUrl Optional icon URL.
    @return Self for method chaining.
    @example builder:SetAuthor("Roblox", nil, "https://example.com/icon.png")
]]
function EmbedBuilder:SetAuthor(name: string, url: string?, iconUrl: string?): EmbedBuilderType
	self.embed.author = {name = name, url = url, icon_url = iconUrl}
	return self
end

--[[
    Adds a field to the embed.
    @param name Field name (max 256 chars).
    @param value Field value (max 1024 chars).
    @param inline Optional inline display flag.
    @return Self for method chaining.
    @example builder:AddField("Info", "Value", true)
]]
function EmbedBuilder:AddField(name: string, value: string, inline: boolean?): EmbedBuilderType
	self.embed.fields = self.embed.fields or {}
	table.insert(self.embed.fields, {name = name, value = value, inline = inline})
	return self
end

log:Info("Rohook v2 initialized", "SYSTEM")
return Rohook