---
markdown-run:
  defaults:
    rerun: true
  ruby:
    rerun: false
---

```ruby rerun=true
puts "Priority test: #{Time.now.to_i}"
```

```ruby RESULT
Priority test: 11111111
```
