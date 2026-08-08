# hive.luau

A [Luau](https://luau.org/) implementation of the C++ [`std::hive`](https://en.cppreference.com/w/cpp/container/hive) container — a bucket-based, stable-index storage structure for fast insertion, removal, and iteration.

## Why hive?

A hive stores elements in fixed-size blocks ("slots") and reuses freed slots via a free list. This gives you:

- **Stable indices** — an element's index never changes for as long as it lives, even as other elements are inserted or removed.
- **O(1) insert and remove** — no shifting of existing elements.
- **Free-slot reuse** — removed slots are recycled by later inserts instead of leaving permanent gaps.
- **Cheap iteration** — elements are walked block by block, skipping empty slots.

## Installation

This project has no external dependencies. Copy `src/init.luau` into your project (e.g. as a `Hive` module), or add this repository as a submodule/package source.

## Usage

```lua
local Hive = require("hive")

local hive = Hive.new()

local a = hive:insert("alpha")
local b = hive:insert("beta")
local c = hive:insert("gamma")

hive:index(a) --> "alpha"

hive:remove(b)

hive:size() --> 2

for index, value in hive:iter() do
    print(index, value)
end
```

## API

| Function | Description |
| --- | --- |
| `Hive.new<T>(): Hive<T>` | Creates a new, empty hive. |
| `hive:insert(value: T): number` | Inserts a value, returning its stable index. |
| `hive:index(idx: number): T?` | Looks up the value at an index, or `nil` if absent. |
| `hive:remove(idx: number)` | Removes the value at an index, freeing the slot for reuse. |
| `hive:iter(): () -> (number, T)` | Returns a stateful iterator over `(index, value)` pairs. |
| `hive:size(): number` | Returns the number of live elements. |

## How it works

Elements are stored in fixed-size blocks (`slot_size`, a power of two) so that a linear index can be split into a block index and a slot index using a bit shift and mask instead of division. New blocks are allocated on demand as the hive grows, and indices freed by `remove` are pushed onto a free list that `insert` drains first, in LIFO order, before appending to the end.
