# hive.luau

A [Luau](https://luau.org/) implementation of the C++ [`std::hive`](https://en.cppreference.com/w/cpp/container/hive) container — a bucket-based, stable-index storage structure for fast insertion, removal, and iteration.

## Why hive?

A hive stores elements in fixed-size blocks ("slots") and reuses freed slots via a free list. This gives you:

- **Stable indices** — an element's index never changes for as long as it lives, even as other elements are inserted or removed.
- **O(1) insert and remove** — no shifting of existing elements.
- **Free-slot reuse** — removed slots are recycled by later inserts instead of leaving permanent gaps.
- **Cheap iteration** — elements are walked block by block, skipping empty slots.

> [!NOTE]
> `hive` is not a general performance optimization over a plain Luau table. A plain table is a native VM structure, while `hive` is a Luau-level wrapper around one, so it loses on raw ops/s for plain insert, index, remove, and iterate — see [Benchmark](#benchmark). The one case it wins is free-slot reuse: a plain table has no free list, so code that keeps appending past removed keys pays repeated array-part reallocation, while `hive` just reuses the freed slot. Reach for `hive` when that reuse pattern matters, not for speed in general.

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

## Benchmark

```sh
luau bench/init.luau
```

Times `insert`, `index`, `iter`, and `remove` (including free-slot reuse) over a configurable number of elements, alongside the same operations on a plain table for comparison. On this machine (N = 10000000), plain tables outperform `hive` on plain insert/index/iter/remove, from ~6.5x (remove) to ~19x (iterate). The one exception is free-slot reuse: `hive` reusing a freed slot beats a plain table appending past a removed key by ~4.2x, since the table pays for array-part reallocation that `hive`'s free list avoids — see the note in [Why hive?](#why-hive).

## How it works

Elements are stored in fixed-size blocks (`slot_size`, a power of two) so that a linear index can be split into a block index and a slot index using a bit shift and mask instead of division. New blocks are allocated on demand as the hive grows, and indices freed by `remove` are pushed onto a free list that `insert` drains first, in LIFO order, before appending to the end.
