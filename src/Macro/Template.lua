-- Macro/Template.lua
--
-- The macro body template: plain macro text with `$Token.Property$` placeholders. Pure logic
-- with no game API use, so it is fully unit tested.
--
-- Rules:
--   * `$Target.Name$` style tokens are replaced by their registered resolver's value.
--   * Token names are case-sensitive.
--   * `$$` is a literal `$`.
--   * Anything token-shaped that isn't registered (`$Target.Nmae$`) stays exactly as typed and
--     is reported as unknown, so the Options page can warn about it.
--   * Any other `$` is literal.

---@type string, GirthBindNamespace
local _, ns = ...
local L = ns.L

---@class GirthBindTemplate
local Template = {}
ns.Template = Template

Template.DEFAULT_BODY = "/targetexact $Target.Name$\n/cleartarget [dead]\n/tm 8"
Template.IDLE_BODY = "/stopmacro"

---@class GirthBindTemplateContext
---@field target GirthBindBound?

---@class GirthBindTokenSpec
---@field key string "Namespace.Property"
---@field description string Shown in the Options token list
---@field sample string Used for the preview when nothing is bound
---@field resolve fun(context: GirthBindTemplateContext): string?

---@type table<string, GirthBindTokenSpec>
local tokens = {}
---@type string[]
local tokenOrder = {}

local TOKEN_SHAPE = "^%$([%w_%.]+)%$"
local VALID_KEY = "^[%a_][%w_]*%.[%a_][%w_]*$"

--- Adds a token. Keys must look like `Namespace.Property`.
---@param key string
---@param spec { description: string, sample: string, resolve: fun(context: GirthBindTemplateContext): string? }
function Template.RegisterToken(key, spec)
    assert(type(key) == "string" and key:match(VALID_KEY), "token key must look like Namespace.Property")
    assert(type(spec) == "table" and type(spec.resolve) == "function", "token spec needs a resolve function")
    if not tokens[key] then
        tokenOrder[#tokenOrder + 1] = key
    end
    tokens[key] = {
        key = key,
        description = spec.description or "",
        sample = spec.sample or "",
        resolve = spec.resolve,
    }
end

--- Registered tokens in registration order.
---@return GirthBindTokenSpec[]
function Template.GetTokens()
    local list = {}
    for index, key in ipairs(tokenOrder) do
        list[index] = tokens[key]
    end
    return list
end

---@param key string
---@return boolean
function Template.IsToken(key)
    return tokens[key] ~= nil
end

---@class GirthBindTemplatePart
---@field kind "text"|"token"|"unknown"
---@field value string Literal text, the token key, or the unknown token as typed

--- Splits a template into literal text, known tokens and unknown tokens.
---@param text string
---@return GirthBindTemplatePart[]
function Template.Parse(text)
    local parts = {}
    local buffer = {}
    local function flush()
        if #buffer > 0 then
            parts[#parts + 1] = { kind = "text", value = table.concat(buffer) }
            buffer = {}
        end
    end

    local position, length = 1, #text
    while position <= length do
        local dollar = text:find("$", position, true)
        if not dollar then
            buffer[#buffer + 1] = text:sub(position)
            break
        end
        buffer[#buffer + 1] = text:sub(position, dollar - 1)

        if text:sub(dollar + 1, dollar + 1) == "$" then
            buffer[#buffer + 1] = "$"
            position = dollar + 2
        else
            local key = text:match(TOKEN_SHAPE, dollar)
            if key then
                flush()
                local raw = "$" .. key .. "$"
                parts[#parts + 1] = tokens[key] and { kind = "token", value = key } or { kind = "unknown", value = raw }
                position = dollar + #raw
            else
                buffer[#buffer + 1] = "$"
                position = dollar + 1
            end
        end
    end
    flush()
    return parts
end

--- Unknown tokens in the template, each listed once, in order of appearance.
---@param text string
---@return string[]
function Template.FindUnknown(text)
    local unknown, seen = {}, {}
    for _, part in ipairs(Template.Parse(text)) do
        if part.kind == "unknown" and not seen[part.value] then
            seen[part.value] = true
            unknown[#unknown + 1] = part.value
        end
    end
    return unknown
end

--- Expands the template. Known tokens with no value expand to "".
---@param text string
---@param context GirthBindTemplateContext?
---@param useSamples boolean? Expand each token to its sample value instead (Options preview)
---@return string body
---@return string[] unknown Unknown tokens, left in the body as typed
function Template.Render(text, context, useSamples)
    local out, unknown, seen = {}, {}, {}
    for _, part in ipairs(Template.Parse(text)) do
        if part.kind == "text" then
            out[#out + 1] = part.value
        elseif part.kind == "token" then
            local spec = tokens[part.value]
            local value
            if useSamples then
                value = spec.sample
            else
                value = spec.resolve(context or {})
            end
            out[#out + 1] = value ~= nil and tostring(value) or ""
        else
            out[#out + 1] = part.value
            if not seen[part.value] then
                seen[part.value] = true
                unknown[#unknown + 1] = part.value
            end
        end
    end
    return table.concat(out), unknown
end

--- The context every token resolves against.
---@param bound GirthBindBound?
---@return GirthBindTemplateContext
function Template.BuildContext(bound)
    return { target = bound }
end

--------------------------------------------------------------------------------------------
-- Built-in tokens
--------------------------------------------------------------------------------------------

Template.RegisterToken("Target.Name", {
    description = L["TOKEN_TARGET_NAME"],
    sample = L["TOKEN_TARGET_NAME_SAMPLE"],
    resolve = function(context)
        return context.target and context.target.name
    end,
})
