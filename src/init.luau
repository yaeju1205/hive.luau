--- hive.luau (fixed)
--- implement like data structure C++ std::hive
local hive = {}

--- Hive structure properties
--- give a user configuration
export type HiveProps<T> = {
    --- slot size in element block
    --- element blocks
    --- [
    ---   [ slot, slot, slot, slot ]
    ---   [ slot, slot, slot, slot ]
    --- ]
    ---
    --- slot size is power of two integer
    --- default: 16
    slot_size: number,
}

--- Hive element block
--- [ slot, slot, slot, slot ]
type HiveElementBlock<T> = { [number]: T }

--- Hive inner properties
--- not user configuration
type HiveInner<T> = {
    --- Element blocks
    --- main container
    blocks: { [number]: HiveElementBlock<T> },

    --- blocks count
    --- indexing faster
    block_count: number,

    --- used to clac slot index
    --- value is log2(slot_size)
    ---
    --- slot size is 2^k
    --- slot shift is k
    ---
    --- slot size   (binary) | 1000
    --- slot shift  (digit)  | 4
    ---
    --- if index is 12 and slot size is 4 then
    --- index           | 1100  (12)
    --- fit index       | 1011  (11) (sub : 1)
    --- slot shift      | 2
    --- shifted index   | 0010  (2)  (shift : 1)
    --- block index     | 0011  (3)  (add : 1)
    ---                              total cost : 3
    --- get a block index
    slot_shift: number,

    --- used to clac slot index
    --- value is slot_size - 1
    ---
    --- slot size | 1000
    --- slot mask | 0111
    ---
    --- if index is 12 and slot size is 4 then
    --- index       | 1100 (12)
    --- fit index   | 1011 (11) (sub : 1)
    --- slot mask   | 0011 (3)
    --- bit anded   | 0011 (3)  (and : 1)
    --- slot index  | 0100 (4)  (add : 1)
    ---                         total cost : 3
    --- get a slot index
    slot_mask: number,

    --- slot index
    --- store next index
    slot_index: number,

    --- free slots
    --- trigger hive.remove
    free_slots: { [number]: number },

    --- free slots count
    --- indexing faster for LIFO(Stack)
    free_count: number,

    --- live slots count
    --- getting faster for hive.size
    live_count: number,
}

export type Hive<T> = typeof(setmetatable(
    {} :: {
        props: HiveProps<T>,
        inner: HiveInner<T>,
    },
    {} :: {
        __index: typeof(hive),
    }
))

--- Create new hive metatable
function hive.new<T>(): Hive<T>
    local props: HiveProps<T> = {
        slot_size = 16, -- 2^k   slot size
    }

    local inner: HiveInner<T> = {
        blocks = table.create(128),
        block_count = 1,

        slot_shift = math.log(props.slot_size, 2),
        slot_mask = props.slot_size - 1,
        slot_index = 0,

        free_slots = {},
        free_count = 0,
        live_count = 0,
    }

    inner.blocks[1] = table.create(props.slot_size)

    return setmetatable({
        props = props,
        inner = inner,
    }, {
        __index = hive,
    })
end

--- Index a hive slot
--- over range then, return nil
---
--- for example
--- ```luau
--- local a_index = hive::insert("apple")
--- local a = hive::index(a_index)
--- ```
---
--- @param idx slot index
--- @return slot value
function hive.index<T>(self: Hive<T>, idx: number): T?
    local inner = self.inner

    -- over range
    if idx < 1 then
        return nil
    end

    local block_index = bit32.rshift(idx - 1, inner.slot_shift) + 1

    -- over range
    if inner.blocks[block_index] == nil then
        return nil
    end

    local slot_index = bit32.band(idx - 1, inner.slot_mask) + 1

    return inner.blocks[block_index][slot_index]
end

--- Remove a value
--- return inserted value index
---
--- for example
--- ```luau
--- local a_index = hive::insert("apple")
--- local a = hive::index(a_index)
--- ```
---
--- @param value slot value
--- @return slot index
function hive.insert<T>(self: Hive<T>, value: T): number
    local props = self.props
    local inner = self.inner

    local free_count = inner.free_count
    local free_slots = inner.free_slots

    if free_count > 0 then
        local free_index = free_slots[free_count]
        inner.free_count = free_count - 1
        free_slots[free_count] = nil

        local block_index = bit32.rshift(free_index - 1, inner.slot_shift) + 1
        local slot_index  = bit32.band(free_index - 1, inner.slot_mask) + 1

        inner.blocks[block_index][slot_index] = value
        inner.live_count = inner.live_count + 1

        return free_index
    end

    local block_index = inner.block_count
    local slot_index = bit32.band(inner.slot_index, inner.slot_mask) + 1

    inner.blocks[block_index][slot_index] = value
    inner.live_count = inner.live_count + 1
    inner.slot_index = slot_index

    if slot_index == props.slot_size then
        inner.block_count = block_index + 1
        inner.blocks[block_index + 1] = table.create(props.slot_size)
    end

    return (block_index - 1) * props.slot_size + slot_index
end

--- Remove a value
---
--- for example
--- ```luau
--- local a_index = hive::insert("apple")
--- local a = hive::remove(a_index)
--- ```
---
--- @param idx slot index
function hive.remove<T>(self: Hive<T>, idx: number)
    local inner = self.inner

    if idx < 1 then
        return
    end

    local shift = inner.slot_shift
    local mask  = inner.slot_mask

    local block_index = bit32.rshift(idx - 1, shift) + 1
    local slot_index  = bit32.band(idx - 1, mask) + 1

    local block = inner.blocks[block_index]
    if block == nil or block[slot_index] == nil then
        return
    end

    block[slot_index] = nil

    inner.live_count = inner.live_count - 1

    local free_count = inner.free_count + 1
    inner.free_count = free_count
    inner.free_slots[free_count] = idx
end

--- Get a hive iterator
---
--- for example
--- ```luau
--- hive::insert("apple")
---
--- for index, fruit in hive:iter() do
---   print(index, fruit)
--- end
--- ```
---
--- @return hive iterator
function hive.iter<T>(self: Hive<T>): () -> (number, T)
    local props = self.props
    local inner = self.inner

    local size = props.slot_size
    local block_index = 1
    local slot_index = 0

    return function(): (number, T)
        while true do
            local block = inner.blocks[block_index]
            if block == nil then
                return nil :: any, nil :: any
            end

            slot_index += 1
            while slot_index <= size do
                local v = block[slot_index]
                if v ~= nil then
                    return (block_index - 1) * size + slot_index, v
                end
                slot_index += 1
            end

            slot_index = 0
            block_index += 1
        end
    end
end

--- Get a hive size
---
--- for example
--- ```luau
--- hive::insert("apple")
---
--- print(hive:size()) -- 1
--- ```
---
--- @return hive size
function hive.size<T>(self: Hive<T>): number
    return self.inner.live_count
end

return hive
