---@meta _
-- LuaLS declarations for the parts of QuestieDB's public API (contract 4) GirthBind reads.
-- Written from QuestieDB's documented API; see QuestieDB's own Types/ for the full surface.
-- Not loaded by the game.

---@class GirthBindQuestieQuestReads
---@field name fun(id: integer): string?
---@field questLevel fun(id: integer): integer?
---@field requiredLevel fun(id: integer): integer?
---@field zoneOrSort fun(id: integer): integer? Positive AreaID or negative quest-sort ID
---@field objectives fun(id: integer): table? {[1]=creatures, [2]=objects, [3]=items, [4]=reputation, [5]=killCredit, [6]=spells}
---@field extraObjectives fun(id: integer): table[]?
---@field GetAllIds fun(): integer[]

---@class GirthBindQuestieNpcReads
---@field name fun(id: integer): string?
---@field minLevel fun(id: integer): integer?
---@field maxLevel fun(id: integer): integer?
---@field rank fun(id: integer): integer?
---@field zoneID fun(id: integer): integer?

---@class GirthBindQuestieItemReads
---@field name fun(id: integer): string?
---@field npcDrops fun(id: integer): integer[]?

---@class GirthBindLibQuestieDB
---@field Quest GirthBindQuestieQuestReads
---@field Npc GirthBindQuestieNpcReads
---@field Item GirthBindQuestieItemReads
---@field RequireContract fun(required: integer): boolean, string?

---@type GirthBindLibQuestieDB?
LibQuestieDB = nil
