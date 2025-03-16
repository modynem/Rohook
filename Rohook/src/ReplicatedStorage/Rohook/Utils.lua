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
    Utils - Advanced Utility Functions
]]--

local Utils = {}

-- Type Definitions
export type TemplateVariables = {[string]: string | number | boolean}
export type DeepCopyable = {any} | string | number | boolean

-- Replaces placeholders in a template (e.g., "{key}" with value from replacements)
function Utils.replacePlaceholders(template: any, replacements: TemplateVariables): any
	local function replace(value: any): any
		if type(value) == "string" then
			return value:gsub("{(%w+)}", function(key)
				local replacement = replacements[key]
				return replacement ~= nil and tostring(replacement) or "{" .. key .. "}"
			end)
		elseif type(value) == "table" then
			local new = {}
			for k, v in pairs(value) do
				new[k] = replace(v)
			end
			return new
		end
		return value
	end
	return replace(template)
end

-- Creates a deep copy of a table or value
function Utils.deepCopy(tbl: DeepCopyable): DeepCopyable
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = Utils.deepCopy(v)
	end
	return copy
end

-- Merges two tables, with tbl2 overriding tbl1 where keys conflict
function Utils.mergeTables(tbl1: {any}, tbl2: {any}): {any}
	local result = Utils.deepCopy(tbl1)
	for k, v in pairs(tbl2) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = Utils.mergeTables(result[k], v)
		else
			result[k] = Utils.deepCopy(v)
		end
	end
	return result
end

-- Trims whitespace from a string
function Utils.trim(str: string): string
	return str:match("^%s*(.-)%s*$") or str
end

-- Checks if a table is empty
function Utils.isEmpty(tbl: {any}): boolean
	return next(tbl) == nil
end

return Utils