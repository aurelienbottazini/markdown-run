class LanguageResolver
  def initialize(aliases = {})
    @aliases = aliases
  end

  def resolve_language(lang)
    @aliases[lang] || lang
  end

  def update_aliases(new_aliases)
    @aliases.merge!(new_aliases)
  end

  def get_aliases
    @aliases.dup
  end
end