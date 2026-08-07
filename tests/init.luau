local Hive = require("./src")

local hive = Hive.new()

local a = hive:insert("alpha")
local b = hive:insert("beta")
local c = hive:insert("gamma")

hive:index(a) --> "alpha"

hive:remove(b)

hive:size() --> 2
hive:is_empty() --> false

for index, value in hive:iter() do
    print(index, value)
end
