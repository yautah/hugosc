#!/usr/bin/env ruby

require "optparse"
require "date"
require "yaml"

ROOT = File.expand_path("..", __dir__)
CARDS_PATH = File.join(ROOT, "data/clashroyale/cards.yaml")
EDITORIALS_DIR = File.join(ROOT, "data/clashroyale/card-editorials")
HISTORY_DIR = File.join(ROOT, "data/clashroyale/card-history-overrides")
VARIANT_MANIFEST_PATH = File.join(ROOT, "data/clashroyale/card-variant-manifest.yaml")
VARIANTS_DIR = File.join(ROOT, "data/clashroyale/card-variants")
CONTENT_DIR = File.join(ROOT, "content")
CARDS_CONTENT_DIR = File.join(CONTENT_DIR, "clashroyale", "cards")

options = { require_complete: false, format: "summary" }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby tools/audit-clash-card-workflow.rb [options]"
  parser.on("--require-complete", "存在未完成卡牌时返回失败") { options[:require_complete] = true }
  parser.on("--format FORMAT", %w[summary tsv], "输出 summary 或 tsv") { |value| options[:format] = value }
end.parse!

cards = YAML.load_file(CARDS_PATH).fetch("items")
editorials = Dir.glob(File.join(EDITORIALS_DIR, "*.yaml")).map { |path| File.basename(path, ".yaml") }
histories = Dir.glob(File.join(HISTORY_DIR, "*.yaml")).map { |path| File.basename(path, ".yaml") }
expected_variants = if File.file?(VARIANT_MANIFEST_PATH)
                      YAML.load_file(VARIANT_MANIFEST_PATH).fetch("items").group_by { |item| item.fetch("parent_key") }
                    else
                      {}
                    end
actual_variants = Dir.glob(File.join(VARIANTS_DIR, "*.yaml")).map { |path| File.basename(path, ".yaml") }

rows = cards.map do |card|
  key = card.fetch("key")
  route = File.join(CARDS_CONTENT_DIR, "#{key}.md")
  front_matter = if File.file?(route)
                   source = File.read(route)[/\A---\s*\n(.*?)\n---\s*\n?/m, 1]
                   source ? YAML.safe_load(source, permitted_classes: [Date, Time]) : {}
                 else
                   {}
                 end
  editorial = editorials.include?(key)
  history = histories.include?(key)
  route_reviewed = front_matter && front_matter["generated_card_data"] == false
  expected = Array(expected_variants[key]).map { |item| "#{key}-#{item.fetch('kind')}" }
  variants = expected.all? { |variant_key| actual_variants.include?(variant_key) }
  {
    "key" => key,
    "name" => card.fetch("name"),
    "editorial" => editorial,
    "history" => history,
    "route" => route_reviewed,
    "variants" => variants,
    "variant_count" => "#{expected.count { |variant_key| actual_variants.include?(variant_key) }}/#{expected.length}",
    "complete" => editorial && history && route_reviewed && variants
  }
end

if options[:format] == "tsv"
  puts %w[key name editorial history route variants variant_count complete].join("\t")
  rows.each do |row|
    puts [row["key"], row["name"], row["editorial"], row["history"], row["route"], row["variants"], row["variant_count"], row["complete"]].join("\t")
  end
else
  puts "卡牌工作流完成度"
  puts "- 卡牌总数：#{rows.length}"
  puts "- 中文编辑内容：#{rows.count { |row| row['editorial'] }}/#{rows.length}"
  puts "- 完整历史复核：#{rows.count { |row| row['history'] }}/#{rows.length}"
  puts "- 页面人工复核：#{rows.count { |row| row['route'] }}/#{rows.length}"
  puts "- 已上线形态齐全：#{rows.count { |row| row['variants'] }}/#{rows.length}"
  puts "- 全部完成：#{rows.count { |row| row['complete'] }}/#{rows.length}"
  missing = rows.reject { |row| row["complete"] }
  unless missing.empty?
    puts "\n未完成卡牌："
    missing.each do |row|
      needs = []
      needs << "编辑内容" unless row["editorial"]
      needs << "历史复核" unless row["history"]
      needs << "页面复核" unless row["route"]
      needs << "形态 #{row['variant_count']}" unless row["variants"]
      puts "- #{row['name']} (#{row['key']})：#{needs.join('、')}"
    end
  end
end

exit 1 if options[:require_complete] && rows.any? { |row| !row["complete"] }
