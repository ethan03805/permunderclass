require "test_helper"

class StylesheetContractTest < ActiveSupport::TestCase
  test "application stylesheet defines core tokens and underlined links" do
    stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_includes stylesheet, ":root"
    assert_includes stylesheet, "--font-sans"
    assert_includes stylesheet, "--color-background: #f6f2e8"
    assert_includes stylesheet, "--color-text: #171614"
    assert_match(/a\s*\{[^}]*text-decoration:\s*underline/m, stylesheet)
  end

  test "application stylesheet avoids forbidden visual effects" do
    stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read

    refute_match(/shadow/i, stylesheet)
    refute_match(/gradient/i, stylesheet)
  end

  test "application stylesheet includes a mobile-first responsive breakpoint" do
    stylesheet = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_match(/@media\s*\(min-width:\s*48rem\)/, stylesheet)
    assert_match(/\.site-header__inner\s*\{[^}]*flex-direction:\s*column/m, stylesheet)
    assert_match(/@media\s*\(min-width:\s*48rem\)\s*\{[\s\S]*\.site-header__inner\s*\{[^}]*flex-direction:\s*row/m, stylesheet)
  end
end
