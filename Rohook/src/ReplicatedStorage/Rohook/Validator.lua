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
    Validator - Advanced Validation Utility
]]--


local Validator = {}
Validator.__index = Validator

-- Type Definitions
export type EmbedData = {
	title: string?, description: string?, url: string?, timestamp: string?, color: number?,
	footer: {text: string, icon_url: string?}?, image: {url: string}?, thumbnail: {url: string}?,
	author: {name: string, url: string?, icon_url: string?}?, fields: {{name: string, value: string, inline: boolean?}}?
}

export type WebhookData = {
	content: string?, username: string?, avatar_url: string?, tts: boolean?, embeds: {EmbedData}?,
	thread_name: string?, thread_id: string?, flags: number?
}

function Validator.new(): Validator
	return setmetatable({}, Validator)
end

function Validator:Embed(embed: EmbedData): (boolean, string?)
	if typeof(embed) ~= "table" then
		return false, "Embed must be a table, got: " .. typeof(embed)
	end

	local totalLength = 0
	if embed.title then
		if #embed.title > 256 then return false, "Title exceeds 256 characters" end
		totalLength += #embed.title
	end
	if embed.description then
		if #embed.description > 4096 then return false, "Description exceeds 4096 characters" end
		totalLength += #embed.description
	end
	if embed.url and not string.match(embed.url, "^https?://") then
		return false, "Invalid URL format: " .. embed.url
	end
	if embed.timestamp and not string.match(embed.timestamp, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then
		return false, "Invalid ISO timestamp: " .. embed.timestamp
	end
	if embed.color and (embed.color < 0 or embed.color > 0xFFFFFF) then
		return false, "Color must be between 0 and 16777215 (0xFFFFFF)"
	end
	if embed.footer then
		if #embed.footer.text > 2048 then return false, "Footer text exceeds 2048 characters" end
		totalLength += #embed.footer.text
	end
	if embed.fields then
		if #embed.fields > 25 then return false, "Too many fields (max 25)" end
		for i, field in ipairs(embed.fields) do
			if #field.name > 256 then return false, "Field " .. i .. " name exceeds 256 characters" end
			if #field.value > 1024 then return false, "Field " .. i .. " value exceeds 1024 characters" end
			totalLength += #field.name + #field.value
		end
	end
	if totalLength > 6000 then return false, "Total embed length exceeds 6000 characters" end
	return true, nil
end

function Validator:WebhookData(data: WebhookData): (boolean, string?)
	if typeof(data) ~= "table" then
		return false, "Webhook data must be a table, got: " .. typeof(data)
	end
	if data.content and #data.content > 2000 then
		return false, "Content exceeds 2000 characters"
	end
	if data.username and #data.username > 80 then
		return false, "Username exceeds 80 characters"
	end
	if data.avatar_url and not string.match(data.avatar_url, "^https?://") then
		return false, "Invalid avatar URL: " .. data.avatar_url
	end
	if data.embeds then
		if #data.embeds > 10 then return false, "Too many embeds (max 10)" end
		for i, embed in ipairs(data.embeds) do
			local isValid, errorMsg = self:Embed(embed)
			if not isValid then return false, "Embed " .. i .. ": " .. errorMsg end
		end
	end
	return true, nil
end

local instance = Validator.new()
return setmetatable({}, {
	__index = function(_, key) return instance[key] end,
	__newindex = function(_, key, value) instance[key] = value end,
	__call = function(_, ...) return instance.new(...) end
})