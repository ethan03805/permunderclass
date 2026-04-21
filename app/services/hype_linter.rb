class HypeLinter
  RULES = {
    repeated_emoji_sequences: /(?:\p{Extended_Pictographic}\s*){2,}/u,
    revolutionize: /\brevolutionize(?:d|s|ing)?\b/i,
    game_changer: /\bgame[\s-]changer\b/i,
    disrupt: /\bdisrupt(?:s|ed|ing)?\b/i,
    ten_x: /\b10x\b/i,
    unicorn: /\bunicorn\b/i,
    world_class: /\bworld-class\b/i,
    best_in_class: /\bbest-in-class\b/i,
    groundbreaking: /\bgroundbreaking\b/i,
    next_gen: /\bnext-gen\b/i,
    seamless: /\bseamless\b/i,
    all_caps_word_runs: /\b[A-Z]{4,}\b/,
    multiple_exclamation_marks: /!!+/,
    exaggerated_urgency: /\b(?:act now|limited time|don't miss|last chance|available now|launching now|sign up today)\b/i
  }.freeze

  def self.flags_for_text(text)
    content = text.to_s

    RULES.each_with_object([]) do |(flag, pattern), flags|
      flags << flag.to_s if content.match?(pattern)
    end
  end

  def self.flags_for_post(post)
    flags_for_text([ post.title, post.body ].compact.join("\n"))
  end
end
