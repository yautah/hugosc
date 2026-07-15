#!/usr/bin/env ruby

require "date"
require "json"
require "open-uri"
require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
API_URL = "https://clashroyale.fandom.com/api.php"
MANIFEST_PATH = File.join(ROOT, "data/clashroyale/card-source-manifest.yaml")
OUTPUT_PATH = File.join(ROOT, "data/clashroyale/card-variant-manifest.yaml")
USER_AGENT = "SCBase/1.0 (card variant discovery)"

options = { write: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby tools/discover-clash-card-variants.rb [options]"
  parser.on("--write", "更新卡牌形态来源清单") { options[:write] = true }
end.parse!

cards = YAML.load_file(MANIFEST_PATH).fetch("items")
candidates = cards.flat_map do |card|
  [
    { "parent_key" => card.fetch("key"), "kind" => "evolution", "title" => "#{card.fetch('fandom_page')}/Evolution" },
    { "parent_key" => card.fetch("key"), "kind" => "hero", "title" => "#{card.fetch('fandom_page')}/Hero" }
  ]
end

pages_by_title = {}
candidates.each_slice(50) do |slice|
  query = {
    "action" => "query",
    "titles" => slice.map { |candidate| candidate.fetch("title") }.join("|"),
    "prop" => "info|revisions",
    "rvprop" => "ids|timestamp",
    "format" => "json",
    "formatversion" => "2"
  }
  url = "#{API_URL}?#{URI.encode_www_form(query)}"
  response = JSON.parse(URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 30).read)
  response.fetch("query").fetch("pages").each { |page| pages_by_title[page.fetch("title")] = page }
end

items = candidates.map do |candidate|
  page = pages_by_title[candidate.fetch("title")]
  next unless page && !page.key?("missing") && !page.key?("redirect")

  revision = page.dig("revisions", 0) || {}
  {
    "parent_key" => candidate.fetch("parent_key"),
    "kind" => candidate.fetch("kind"),
    "fandom_page" => candidate.fetch("title"),
    "source_url" => "https://clashroyale.fandom.com/wiki/#{URI.encode_www_form_component(candidate.fetch('title')).gsub('+', '_').gsub('%2F', '/')}",
    "source_revision" => revision["revid"],
    "source_modified_at" => revision["timestamp"]
  }
end.compact

output = {
  "meta" => {
    "source" => API_URL,
    "retrieved_at" => Date.today.iso8601,
    "count" => items.length
  },
  "items" => items
}

if options[:write]
  File.write(OUTPUT_PATH, YAML.dump(output, line_width: -1))
  puts "已更新 #{OUTPUT_PATH}"
end

counts = items.group_by { |item| item.fetch("kind") }.transform_values(&:length)
puts "发现 #{items.length} 个已上线形态：觉醒 #{counts.fetch('evolution', 0)}，精英 #{counts.fetch('hero', 0)}。"
