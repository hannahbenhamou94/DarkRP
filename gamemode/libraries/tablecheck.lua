--[[
tablecheck

WIP

Author: FPtje Falco

Purpose:
Allow validating tables by creating schemas of tables. Inspired by Joi (https://github.com/hapijs/joi)

Requires fn library (https://github.com/FPtje/GModFunctional),

Example:
```lua
local schema = tc.assertTable{
    name   = tc.assert(isstring, "The name must be a string!"),
    id     = tc.assert(isnumber, "The id must be a number!"),
    gender = tc.assert(tc.oneOf{"male", "female", "carp"}, "Gender missing or not recognised!", {"Perhaps you are a carp?"}),
}

local correct, err, hints = schema({name = "Dick", id = 3, gender = "carp"})
print(correct) -- true


local correct, err, hints = schema({name = "Dick", id = 3, gender = "crap"})
print(correct) -- false
print(err) -- Gender missing or not recognised!
PrintTable(hints) -- {"Perhaps you are a carp?"}
```

For further examples, including nesting and combining of schemas, please see the `unitTests` function for now.
--]]

module("tc", package.seeall)

-- Helpers for quick access to metatables
angle                  = FindMetaTable("Angle")
convar                 = FindMetaTable("ConVar")
effectdata             = FindMetaTable("CEffectData")
entity                 = FindMetaTable("Entity")
file                   = FindMetaTable("File")
imaterial              = FindMetaTable("IMaterial")
irestore               = FindMetaTable("IRestore")
isave                  = FindMetaTable("ISave")
itexture               = FindMetaTable("ITexture")
lualocomotion          = FindMetaTable("CLuaLocomotion")
movedata               = FindMetaTable("CMoveData")
navarea                = FindMetaTable("CNavArea")
navladder              = FindMetaTable("CNavLadder")
nextbot                = FindMetaTable("NextBot")
npc                    = FindMetaTable("NPC")
pathfollower           = FindMetaTable("PathFollower")
physobj                = FindMetaTable("PhysObj")
player                 = FindMetaTable("Player")
recipientfilter        = FindMetaTable("CRecipientFilter")
soundpatch             = FindMetaTable("CSoundPatch")
takedamageinfo         = FindMetaTable("CTakeDamageInfo")
usercmd                = FindMetaTable("CUserCmd")
vector                 = FindMetaTable("Vector")
vehicle                = FindMetaTable("Vehicle")
vmatrix                = FindMetaTable("VMatrix")
weapon                 = FindMetaTable("Weapon")

-- Returns whether a value is nil
isnil = fn.Curry(fn.Eq, 2)(nil)

-- Optional value, when filled in it must meet the conditions
optional = function(...) return fn.FOr{isnil, ...} end

-- A table of which each element must meet condition f
-- i.e. "this must be a table of xxx"
-- example: tc.tableOf(isnumber) demands that the table contains only numbers
tableOf = function(f) return function(tbl)
    if not istable(tbl) then return false end
    for k,v in pairs(tbl) do if not f(v) then return false end end
    return true
end end

-- Checks whether a value is amongst a given set of values
-- exapmle: tc.oneOf{"jobs", "entities", "shipments", "weapons", "vehicles", "ammo"}
oneOf = function(f) return fp{table.HasValue, f} end

-- A table that is nonempty, also useful for wrapping around tableOf
-- example: nonempty(tableOf(isnumber))
-- example: nonempty() -- just checks that the table is non-empty
nonempty = function(f) return function(tbl) return istable(tbl) and #tbl > 0 and (not f or f(tbl)) end end



-- Assert function, asserts a property and returns the error if false.
-- Allows f to override err and hints by simply returning them
assert = function(f, err, hints) return function(...)
    local res = {f(...)}
    table.insert(res, err)
    table.insert(res, hints)

    return unpack(res)
end end

--[[ Validates a table against a schema
Capable of nesting
--]]
function assertTable(schema)
    return function(tbl)
        if not istable(tbl) then
            return false, "Not a table!"
        end

        for k, v in pairs(schema or {}) do
            local correct, err, hints = tbl[v] ~= nil
            if isfunction(v) then correct, err, hints = v(tbl[k], tbl) end

            err = err or string.format("Element '%s' is corrupt!", k)

            if not correct then return correct, err, hints end
        end

        return true
    end
end

-- Test cases. Also serve as nice examples
function unitTests()
    local id = 0

    -- unit test helper functions
    local function checkCorrect(correct, err, hints)
        id = id + 1

        if correct ~= true then
            print(id, "Incorrect value that should be correct!", correct, err, hints)
            if hints then PrintTable(hints) end
            return
        end

        print(id, "Correct")
    end

    local function checkIncorrect(correct, err, hints)
        id = id + 1

        if correct then
            print(id, "Correct value that should be incorrect!", correct, err, hints)
            if hints then PrintTable(hints) end
            return
        end

        print(id, "Correct")
    end

    --[[
    Simple value schema. Checks whether the input is a number.
    ]]
    local simpleSchema = tc.assert(isnumber, "Must be a number!")

    -- This is how a schema is to be used. Just call it with the value you want to check.
    -- In further unit tests, the schema function is immediately called inside the checkCorrect/checIncorrect call for brevity
    local correct, err, hints = simpleSchema(3)

    checkCorrect(correct, err, hints)


    --[[
    Simple table schema
    ]]
    local simpleTableSchema = tc.assertTable{
        name        = tc.assert(isstring, "The name must be a string!"),
        id          = tc.assert(isnumber, "The id must be a number!"),
        gender      = tc.assert(tc.oneOf{"male", "female", "carp"}, "Gender missing or not recognised!", {"Perhaps you are a carp?"}),
        nilthing    = tc.assert(isnil, "nilthing must be nil"),
        nonempty    = tc.assert(nonempty(tableOf(isnumber)), "nonempty not table of numbers"),
        optnum      = tc.assert(optional(isnumber), "optnum given, but not a number"),
        strnum      = tc.assert(fn.FOr{isstring, isnumber}, "strnum must either be a string or a number"),
    }

    checkCorrect(simpleTableSchema({name = "Dick", id = 3, gender = "carp", nonempty = {1,2,3}, strnum = "str"}))

    -- Counterexamples, should throw errors
    local badTables = {
        {},
        {name = 1, id = 3, gender = "carp", nonempty = {1,2,3}, strnum = "str"},
        {name = "Dick", id = "3", gender = "carp", nonempty = {1,2,3}, strnum = "str"},
        {name = "Dick", id = 3, gender = "other", nonempty = {1,2,3}, strnum = "str"},
        {name = "Dick", id = 3, gender = "carp", nonempty = {}, strnum = "str"},
        {name = "Dick", id = 3, gender = "carp", nonempty = {1,2,3}, strnum = {}},
        {name = "Dick", id = 3, gender = "carp", nonempty = {1,2,3}, strnum = "str", optnum = "nope"},
    }

    for _, tbl in pairs(badTables) do
        checkIncorrect(simpleTableSchema(tbl))
    end

    --[[
    Table Schema with no explicit keys
    ]]
    local nokeysSchema = tc.assertTable{
        tc.assert(isstring, "The first value must be a string."),
        tc.assert(isnumber, "The second value must be a number!"),
    }
    checkCorrect(nokeysSchema({"string", 3}))

    --[[
    Nested table schema
    ]]
    local nestedSchema = tc.assertTable{
        nested = tc.assertTable{
            val = tc.assert(isnumber, "'val' must be a number!")
        }
    }

    checkCorrect(nestedSchema({nested = {val = 3}}))
    checkIncorrect(nestedSchema({}))

    --[[
    Combining schemas using the fn library
    ]]
    local andSchema = fn.FAnd{
        tc.assertTable{
            num = tc.assert(isnumber, "num is not a number")
        },
        tc.assertTable{
            str = tc.assert(isstring, "str is not a string")
        }
    }

    checkCorrect(andSchema({num = 1, str = "string!"}))
    checkIncorrect(andSchema({num = 1}))
    checkIncorrect(andSchema({str = "string!"}))

    local orSchema = fn.FOr{
        tc.assertTable{
            num = tc.assert(isnumber, "num is not a number")
        },
        tc.assertTable{
            str = tc.assert(isstring, "str is not a string")
        }
    }
    checkCorrect(orSchema({num = 1}))
    checkCorrect(orSchema({str = "string!"}))

    print("finished")
end
