--- hive.luau benchmark
--- run with: luau bench/init.luau
local Hive = require("./src")

--- 100000, 10000000
local N = 10000000

--- Time fn and print its throughput
--- @param name benchmark label
--- @param fn benchmark body
local function bench(name: string, fn: () -> ())
    local start = os.clock()
    fn()
    local elapsed = os.clock() - start
    print(string.format("%-32s %8.4fs  (%.0f ops/s)", name, elapsed, N / elapsed))
end

print(string.format("hive.luau benchmark (N = %d)", N))
print(string.rep("-", 56))

-- hive --

local hive = Hive.new()
local indices = table.create(N) :: { number }

bench("hive insert", function()
    for i = 1, N do
        indices[i] = hive:insert(i)
    end
end)

bench("hive index (lookup)", function()
    for i = 1, N do
        hive:index(indices[i])
    end
end)

bench("hive iter", function()
    for _, _ in hive:iter() do
    end
end)

bench("hive remove (every other)", function()
    for i = 1, N, 2 do
        hive:remove(indices[i])
    end
end)

bench("hive insert (into freed slots)", function()
    for i = 1, N // 2 do
        hive:insert(i)
    end
end)

bench("hive remove (rest)", function()
    for i = 2, N, 2 do
        hive:remove(indices[i])
    end
end)

print(string.rep("-", 56))
print("hive final size:", hive:size())
print(string.rep("-", 56))

-- plain table --
-- table has no free list, so a slot freed by removal can only
-- be reused by keeping track of it yourself; here we just keep
-- appending past N, which is what most code actually does

local t = table.create(N)
local t_live = 0
local t_next = N

bench("table insert", function()
    for i = 1, N do
        t[i] = i
        t_live += 1
    end
end)

bench("table index (lookup)", function()
    for i = 1, N do
        local _ = t[i]
    end
end)

bench("table iter", function()
    for _, _ in t do
    end
end)

bench("table remove (every other)", function()
    for i = 1, N, 2 do
        t[i] = nil
        t_live -= 1
    end
end)

bench("table insert (append, no reuse)", function()
    for i = 1, N // 2 do
        t_next += 1
        t[t_next] = i
        t_live += 1
    end
end)

bench("table remove (rest)", function()
    for i = 2, N, 2 do
        t[i] = nil
        t_live -= 1
    end
end)

print(string.rep("-", 56))
print("table final size:", t_live)
print(string.format("table final key range: 1..%d  (%d permanent holes)", t_next, t_next - t_live))
