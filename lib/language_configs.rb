LANGUAGE_REGEX_PART = MarkdownRunConfig::SUPPORTED_LANGUAGES.keys.map { |lang| Regexp.escape(lang) }.join("|").freeze
CODE_BLOCK_START_REGEX = /^```(#{LANGUAGE_REGEX_PART})$/i # rubocop:disable Style/MutableConstant
