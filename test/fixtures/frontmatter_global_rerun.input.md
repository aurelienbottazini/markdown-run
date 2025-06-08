---
markdown-run:
  defaults:
    rerun: true
---

```ruby
puts "Global rerun test: #{Time.now.to_i}"
```

```ruby RESULT
Global rerun test: 12345678
```
