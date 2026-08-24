# frozen_string_literal: true

module ::Pangram
  class TextCleaner
    def self.clean(
      raw_text,
      ignore_quotes: SiteSetting.pangram_ignore_quotes,
      ignore_code_blocks: SiteSetting.pangram_ignore_code_blocks
    )
      return "" if raw_text.blank?

      text = raw_text.dup

      if ignore_quotes
        text = strip_quotes(text)
      end

      if ignore_code_blocks
        text = strip_code_blocks(text)
      end

      text.strip
    end

    def self.word_count(raw_text, **opts)
      cleaned = clean(raw_text, **opts)
      cleaned.scan(/\S+/).size
    end

    def self.strip_quotes(text)
      result = text.dup
      # Recursively remove BBCode [quote] blocks (handles nested quotes)
      loop do
        prev = result.dup
        result.gsub!(/\[quote\b[^\]]*\].*?\[\/quote\]/mi, "")
        break if result == prev
      end
      # Strip Markdown blockquotes (> ...) line by line
      result = result.lines.reject { |line| line.strip.start_with?(">") }.join
      result
    end

    def self.strip_code_blocks(text)
      result = text.dup
      # Fenced markdown code blocks ``` ... ```
      result.gsub!(/```[\s\S]*?```/m, "")
      # HTML <pre> and <code> blocks
      result.gsub!(/<pre\b[^>]*>[\s\S]*?<\/pre>/mi, "")
      result.gsub!(/<code\b[^>]*>[\s\S]*?<\/code>/mi, "")
      # Inline code `...`
      result.gsub!(/`[^`\n]+`/, "")
      result
    end
  end
end
