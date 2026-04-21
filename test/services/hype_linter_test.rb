require "test_helper"

class HypeLinterTest < ActiveSupport::TestCase
  test "flags configured hype terms and urgency patterns" do
    text = "REVOLUTIONIZE your workflow!! Act now for a seamless next-gen launch."

    flags = HypeLinter.flags_for_text(text)

    assert_includes flags, "revolutionize"
    assert_includes flags, "multiple_exclamation_marks"
    assert_includes flags, "exaggerated_urgency"
    assert_includes flags, "seamless"
    assert_includes flags, "next_gen"
    assert_includes flags, "all_caps_word_runs"
  end

  test "returns unique flags in rule order" do
    flags = HypeLinter.flags_for_text("game changer game-changer")

    assert_equal [ "game_changer" ], flags
  end
end
