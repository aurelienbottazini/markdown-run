---
markdown-run:
  defaults:
    rerun: false
  ruby:
    rerun: true
---

```ruby
puts "Override test: #{Time.now.to_i}"
```

```ruby RESULT
Override test: 22222222
```
