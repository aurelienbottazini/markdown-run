This is an example markdown file

The following psql code block should be executed
And the result should be shown in a following codeblock

```ruby
p "foo"
```

```ruby RESULT
p "foo"
# >> "foo"
```

```bash
date
```

```RESULT
Sun May 18 15:05:35 CEST 2025
```

```zsh
date
```

```RESULT
Sun May 18 15:05:13 CEST 2025
```

```js
1 + 2;
console.log(3);
```

```RESULT
3
```

```psql
\d
```

```RESULT
public|ar_internal_metadata|table|aurelienbottazini
public|schema_migrations|table|aurelienbottazini
```

```sqlite3
.stats
```

```RESULT
Memory Used:                         147824 (max 147888) bytes
Number of Outstanding Allocations:   169 (max 170)
Number of Pcache Overflow Bytes:     4608 (max 4608) bytes
Largest Allocation:                  122400 bytes
Largest Pcache Allocation:           4104 bytes
Lookaside Slots Used:                34 (max 34)
Successful lookaside attempts:       34
Lookaside failures due to size:      0
Lookaside failures due to OOM:       0
Pager Heap Usage:                    5632 bytes
Page cache hits:                     0
Page cache misses:                   0
Page cache writes:                   0
Page cache spills:                   0
Schema Heap Usage:                   0 bytes
Statement Heap/Lookaside Usage:      0 bytes
```
