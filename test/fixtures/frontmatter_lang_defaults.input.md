---
markdown-run:
  ruby:
    rerun: true
  psql:
    explain: true
---

```ruby
puts "Language-specific ruby test: #{Time.now.to_i}"
```

```ruby RESULT
Language-specific ruby test: 87654321
```
