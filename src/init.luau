--- hive.luau (fixed)
--- implement like data structure C++ std::hive
local hive = {}

--- Hive structure properties
--- give a user configuration
export type HiveProps<T> = {
    --- slot size in element block
    --- element blocks
    --- [
    ---     [ slot, slot, slot, slot ]
    ---     [ slot, slot, slot, slot ]
    --- ]
    slot_size: number,

    --- used to clac slot index
    --- value is log2(slot_size)
    slot_shift: number,
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
    { __index = hive }
))

function hive.new<T>(): Hive<T>
    local props: HiveProps<T> = {
        slot_size = 4,     -- 2^k   slot size
        slot_shift = 2,    -- k     (log2(slot_Size))
    }

    local inner: HiveInner<T> = {
        blocks = table.create(8),
        block_count = 1,

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
        __index = hive
    })
end

function hive.index<T>(self: Hive<T>, idx: number): T?
    local props = self.props
    local inner = self.inner

    if idx < 1 then
        return nil
    end

    local fit_idx = idx - 1

    -- index for 4 - 1
    -- 0b0011
    -- shift right 2
    -- 0b0000
    -- degit to 0
    local block_index = bit32.rshift(fit_idx, props.slot_shift) + 1

    if inner.blocks[block_index] == nil then
        return nil
    end

    -- slot size - 1 to binary
    -- 0b0011
    local mask = props.slot_size - 1

    -- index for 8
    --   0b0111 | index - 1
    -- & 0b0011 | mask
    --   0b0011
    -- to digit 3
    -- final index is 4
    local slot_index = bit32.band(fit_idx, mask) + 1

    return inner.blocks[block_index][slot_index]
end

function hive.insert<T>(self: Hive<T>, value: T): number
    local props = self.props
    local inner = self.inner

    local free_count = inner.free_count
    local free_slots = inner.free_slots

    local mask = props.slot_size - 1

    if free_count > 0 then
        local free_index = free_slots[free_count]
        inner.free_count = free_count - 1
        free_slots[free_count] = nil

        local block_index = bit32.rshift(free_index - 1, props.slot_shift) + 1
        local slot_index  = bit32.band(free_index - 1, mask) + 1

        inner.blocks[block_index][slot_index] = value
        inner.live_count = inner.live_count + 1

        return free_index
    end

    local block_index = inner.block_count
    local slot_index = bit32.band(inner.slot_index, mask) + 1

    inner.blocks[block_index][slot_index] = value
    inner.live_count = inner.live_count + 1
    inner.slot_index = slot_index

    if slot_index == props.slot_size then
        inner.block_count = block_index + 1
        inner.blocks[block_index + 1] = table.create(props.slot_size)
    end

    return (block_index - 1) * props.slot_size + slot_index
end

function hive.remove<T>(self: Hive<T>, idx: number)
    local props = self.props
    local inner = self.inner

    if idx < 1 then
        return
    end

    local shift = props.slot_shift
    local mask  = props.slot_size - 1

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

function hive.size<T>(self: Hive<T>): number
    return self.inner.live_count
end

function hive.is_empty<T>(self: Hive<T>): boolean
    return self.inner.live_count == 0
end

return hive
