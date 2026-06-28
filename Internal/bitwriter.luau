------------------------
----- [ Services ] -----

-----------------------
----- [ Modules ] -----
local t = require("../Dependencies/t")
local Log = require("../Helpers/Log")

------------------------
----- [ Varibles ] -----
local tU8 = t.every(t.integer, t.numberMin(0), t.numberMax(255))
local tU16 = t.every(t.integer, t.numberMin(0), t.numberMax(65535))
local tU32 = t.every(t.integer, t.numberMin(0), t.numberMax(4294967295))
local tI8 = t.every(t.integer, t.numberMin(-128), t.numberMax(127))
local tI16 = t.every(t.integer, t.numberMin(-32768), t.numberMax(32767))
local tI32 = t.every(t.integer, t.numberMin(-2147483648), t.numberMax(2147483647))
local tF32 = t.number
local tF64 = t.number

----------------------
----- [ Tables ] -----
local Bit = {}

Bit.__index = Bit
---------------------
----- [ Types ] -----
export type methods = typeof(Bit)
export type BitObject = MemoryStack & typeof(Bit)
export type MemoryStack = {
	_buf: buffer, -- > the raw buffer that contains your memory stack
	_mem: number, -- mem -> Memory
	_cursor: number?, -- > decides the location of your content being compressed is allocated
}

------------------------
----- [ Functions ] ----
--[[
    @Function: Bit.CreateStack(Storage: number)
     Creates a self object that acts as your memory stack for your buffer
    
    @Options (Arguments): 
      Storage: number expected
    
      return BitObject
]]
--
function Bit.CreateStack(Storage: number): BitObject
	--- Verifying & Type checking
	assert(t.integer(Storage))

	--- Varibles
	local self = setmetatable({}, Bit)

	-- Setting the memory stack information
	self._buf = buffer.create(Storage)
	self._mem = Storage
	self._cursor = 0

	return self :: BitObject
end

--[[
    @Function: Bit:_expand(space_needed: number)
     expands your buffer / memory's size in the scenario the thing we're compressing was under estimated
    
    @Options (arguments):
      space_needed: number expected

    return nothing
]]
--
function Bit:_expand(space_needed: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:_expand(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(t.integer(space_needed))

	--- Varibles
	local SpaceNeeded: number = self._cursor + space_needed
	local Size = self._mem
	local new_stack

	-- Checking if the space we need is less than or equal to the current size we have
	if SpaceNeeded <= Size then
		return
	end

	--- Creating space within the stack
	while Size < SpaceNeeded do
		Size *= 2
	end

	--- Now that we've updated our size reference to how much we need
	-- mabye with some space left over, we now need to make a new buffer and copy
	-- all the existing information on the buffer and set the size of the new buffer to the reference we have set
	new_stack = buffer.create(Size)

	-- Copying information from the pre-existing buffer
	buffer.copy(new_stack, 0, self._buf, 0, self._mem)

	--- Updating self varibles
	self._buf = new_stack
	self._mem = Size
end

--[[
    @Function: Bit:WriteU8(value: number) -> U8 == Usigned 8 Bit Integer
     writes a 8 bit integer (only accepting 0 -> 255)
     
    @Options (Arguments):
        value: number expected
]]
--
function Bit:WriteU8(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteU8(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tU8(value))

	--- Expanding our memory
	self:_expand(1) -- Attempting to expand our storage by 1 byte

	--- Attempting to write to the buffer
	buffer.writeu8(self._buf, self._cursor, value)

	--- Updating our cursor
	self._cursor += 1
end

--[[
   @Function: Bit:WriteU16(value: number) -> U16 == Usigned 16 Bit Integer
     writes a 16 bit integer (only accepting 0 -> 65,535)
     
    @Options (Arguments):
        value: number expected
]]
--
function Bit:WriteU16(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteU16(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tU16(value))

	--- Expanding our memory
	self:_expand(2) -- Attempting to expand our storage by 2 bytes

	--- Attempting to write to the buffer
	buffer.writeu16(self._buf, self._cursor, value)

	--- Updating cursor
	self._cursor += 2
end

function Bit:WriteU32(value)
	---  Verifying & type Checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteU32(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tU32(value))

	--- Expanding our memory
	self:_expand(4) -- Attempting to expand our storage by 4 bytes

	--- Attempting to write to the buffer
	buffer.writeu32(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 4
end

--[[
    @Function: Bit:WriteI8(value)
     writes a signed integer with the range limited between -128 | 127

    @Options (arguments):
        Value: number

]]
--
function Bit:WriteI8(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:I8(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tI8(value))

	--- Expanding our memory
	self:_expand(1) -- Attempting to expand our storage by 4 bytes

	--- Attempting to write to the buffer
	buffer.writei8(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 1
end

--[[
    @Function: Bit:WriteI16(value)
     writes a signed integer with the range limited between -32,768 | 32,767

    @Options (arguments):
        Value: number

]]
--
function Bit:WriteI16(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteI16(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tI16(value))

	--- Expanding our memory
	self:_expand(2) -- Attempting to expand our storage by 2 bytes

	--- Attempting to write to the buffer
	buffer.writei16(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 2
end

--[[
    @Function: Bit:WriteI32(value)
     writes a signed integer with the range limited between -2,147,483,648 | 2,147,483,647

    @Options (arguments):
        Value: number

]]
--
function Bit:WriteI32(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteI32(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tI32(value))

	--- Expanding our memory
	self:_expand(4) -- Attempting to expand our storage by 4 bytes

	--- Attempting to write to the buffer
	buffer.writei32(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 4
end

--[[
    @Function: Bit:WriteF32(value)
        Writes a 32-bit float to the buffer 

    @Options (arguments):
        Value: number

]]
--
function Bit:WriteF32(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteF32(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tF32(value))

	--- Expanding our memory
	self:_expand(4) -- Attempting to expand our storage by 4 bytes

	--- Attempting to write to the buffer
	buffer.writef32(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 4
end

--[[
    @Function: Bit:WriteF64(value) 
        Writes a 64-bit float to the buffer 

    @Options (arguments):
        Value: number

]]
--
function Bit:WriteF64(value: number)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteF64(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(tF64(value))

	--- Expanding our memory
	self:_expand(8) -- Attempting to expand our storage by 4 bytes

	--- Attempting to write to the buffer
	buffer.writef64(self._buf, self._cursor, value)

	-- Updating cursor
	self._cursor += 8
end

--[[
    @Function: Bit:WriteString(value)
        writes a string into a buffer
    
    @Options (arguments):
        value: string
]]
--
function Bit:WriteString(value: string)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteString(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	assert(t.string(value))

	--- Varibles
	local Length = #value

	--- we'll attempt to expand the buffer by the length of the string
	self:_expand(4 + Length)

	--- writting the length of the string to the buffer
	self:WriteU32(Length)

	-- writting the raw string to the buffer
	buffer.writestring(self._buf, self._cursor, value)

	self._cursor += Length
end

--[[
    @Function: Bit:WriteBoolean(value)
        writes a boolean into a buffer by considering false as 0 and true as 1
         etheir of these numbers will be written into the buffer sense you cannot write a raw boolean
          into a buffer directly

    @Options (arguments):
        Value: Boolean

]]
--
function Bit:WriteBoolean(value: boolean)
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:WriteBoolean(), not with a BitObject, Please call it like YOUR_BITOBJECT:_expand(value)"
		)
		return
	end

	assert(t.boolean(value))

	-- Calling our WriteU8 function sense we're writing a POSITIVE number
	-- if it was negative we would call WriteI8
	self:WriteU8(value and 1 or 0)
end

--[[
    @Function: Bit:ReadU8
        Reads a unsigned 8-bit integer (1 byte) from the buffer
        at the current cursor position then advances the cursor by 1.

    @Returns:
        number 
]]
--
function Bit:ReadU8()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadU8(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readu8(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 1

	return res
end

--[[
    @Function: Bit:ReadU16
        Reads a unsigned 16-bit integer (2 bytes) from the buffer
        at the current cursor position then advances the cursor by 2.

    @Returns:
        number
]]
--
function Bit:ReadU16()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadU16(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readu16(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 2

	return res
end

--[[
    @Function: Bit:ReadU32
        Reads a unsigned 32-bit integer (4 byte) from the buffer
        at the current cursor position then advances the cursor by 4.

    @Returns:
        number 
]]
--
function Bit:ReadU32()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadU32(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readu32(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 4

	return res
end

--[[
    @Function: Bit:ReadU8
        Reads a signed 8-bit integer (1 byte) from the buffer
        at the current cursor position then advances the cursor by 1.

    @Returns:
        number 
]]
--
function Bit:ReadI8()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadI8(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readi8(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 1

	return res
end

--[[
    @Function: Bit:ReadI16
        Reads a signed 16-bit integer (2 byte) from the buffer
        at the current cursor position then advances the cursor by 2.

    @Returns:
        number
]]
function Bit:ReadI16()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadI16(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readi16(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 2

	return res
end

--[[
    @Function: Bit:ReadI32
        Reads a signed 32-bit integer (4 byte) from the buffer
        at the current cursor position then advances the cursor by 4.

    @Returns:
        number
]]
--
function Bit:ReadI32()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadI32(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readi32(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 4

	return res
end

--[[
    @Function: Bit:ReadF32
         Reads a 32-bit floating point number (4 bytes) from the buffer
        at the current cursor position then advances the cursor by 4.

    @Returns:
        number -- A whole number between 0 and 255
]]
--
function Bit:ReadF32()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadF32(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readf32(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 4

	return res
end

--[[
    @Function: Bit:ReadF32
         Reads a 64-bit floating point number (8 bytes) from the buffer
        at the current cursor position then advances the cursor by 8.

    @Returns:
        number -- A whole number between 0 and 255
]]
--
function Bit:ReadF64()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadF64(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local res = buffer.readf64(self._buf, self._cursor)

	-- updating the cursor's position
	self._cursor += 8

	return res
end

--[[
    @Function: Bit:ReadString
        reads the given compressed string stored in a buffer    

    @Returns:
        string (the original string)
]]
--
function Bit:ReadString()
	--- Verifying & type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:ReadString(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	--- Varibles
	local length = self:ReadU32()
	local res = buffer.readstring(self._buf, self._cursor, length)

	-- updating the cursor's position
	self._cursor += length

	return res
end

--[[
    @Function: Bit:SetCursorAt(n)
        set's the position of your cursor at position equal to n.
        The cursor is the object that references where to read the next set of bits at

    @Options (arguments):
     n: number
]]
--
function Bit:SetCursorAt(n: number)
	--- verifiying and type checking
	if getmetatable(self) ~= Bit then
		Log(
			"Warn",
			"attempted to call self:SetCursorAt(), not with a BitObject, Please call it like YOUR_BITOBJECT:WriteString(value)"
		)
		return
	end

	assert(t.integer(n))
	assert(n >= 0, "Cursor position cannot go below 0")

	--- setting cursor at the given point
	self._cursor = n
end

return Bit :: methods
