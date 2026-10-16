#!/usr/bin/env ruby
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

class ArticleCheckTest < Minitest::Test
  CHECKER = File.expand_path("check-article.rb", __dir__)

  def setup
    @root = Dir.mktmpdir("scbase-editor-test-")
    @dir = File.join(@root, "content/posts/clashroyale/2026-10-15/test")
    FileUtils.mkdir_p(@dir)
    FileUtils.mkdir_p(File.join(@root, "assets/images/2026"))
    File.binwrite(File.join(@root, "assets/images/2026/cover.webp"), "fixture")
    File.binwrite(File.join(@dir, "body.webp"), "fixture")
    @fm = {
      "title" => "Fixture", "slug" => "test", "description" => "Summary",
      "image" => "/images/2026/cover.webp", "game" => "clashroyale",
      "date" => "2026-10-15T10:00:00+08:00", "updated" => "2026-10-15T11:00:00+08:00",
      "categories" => ["皇室战争"], "draft" => true
    }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def run_check(stage: "ready", body: "![Fixture](body.webp)\n", raw: nil)
    path = File.join(@dir, "index.md")
    File.write(path, raw || "#{YAML.dump(@fm)}---\n#{body}")
    stdout, stderr, status = Open3.capture3("ruby", CHECKER, "--root", @root, "--stage", stage, path)
    assert_equal "", stderr
    [JSON.parse(stdout), status.exitstatus]
  end

  def test_complete_ready_article_and_obsidian_image
    result, code = run_check(body: "![[body.webp|Fixture]]\n")
    assert_equal 0, code
    assert result["ok"]
    assert_equal 1, result["body_images"]
    assert_empty result["warnings"]
  end

  def test_missing_cover_is_draft_warning_but_ready_error
    @fm.delete("image")
    result, code = run_check(stage: "draft")
    assert_equal 0, code
    assert result["warnings"].any? { |x| x.include?("website image") }
    result, code = run_check
    assert_equal 1, code
    refute result["ok"]
  end

  def test_bundle_cover_is_not_a_hugo_asset
    @fm["image"] = "body.webp"
    result, code = run_check
    assert_equal 1, code
    assert result["errors"].any? { |x| x.include?("Website cover") }
  end

  def test_wechat_metadata_does_not_trigger_publishing_checks
    @fm["wechat"] = { "cover" => "user-will-edit-later.webp", "template" => "redream-obsidian-blue" }
    result, code = run_check
    assert_equal 0, code
    assert result["ok"]
  end

  def test_missing_body_image_even_in_draft
    result, code = run_check(stage: "draft", body: "![Lost](lost.webp)\n")
    assert_equal 1, code
    assert result["errors"].any? { |x| x.include?("Body image missing") }
  end

  def test_real_yaml_date_and_update_order
    raw = "#{YAML.dump(@fm)}---\nBody\n".gsub("'2026-10-15T10:00:00+08:00'", "2026-10-15T10:00:00+08:00")
    result, code = run_check(raw: raw)
    assert_equal 0, code
    assert result["ok"]
    @fm["updated"] = "2026-10-14T11:00:00+08:00"
    result, code = run_check
    assert_equal 1, code
    assert_includes result["errors"], "updated precedes date"
  end

  def test_invalid_yaml_and_missing_timezone
    result, code = run_check(raw: "---\ntitle: [broken\n---\nBody\n")
    assert_equal 1, code
    refute result["ok"]
    @fm["date"] = "2026-10-15"
    result, code = run_check
    assert_equal 1, code
    assert result["errors"].any? { |x| x.include?("ISO timestamp") }
  end

  def test_unsupported_image_syntax_warns_instead_of_silent_pass
    result, code = run_check(body: "![Fixture](<image with spaces.webp>)\n")
    assert_equal 0, code
    assert result["warnings"].any? { |x| x.include?("outside this checker's subset") }
  end

  def test_remote_website_cover_requires_manual_review
    @fm["image"] = "https://example.com/cover.webp"
    result, code = run_check
    assert_equal 0, code
    assert result["warnings"].any? { |x| x.include?("availability verification") }
  end
end
