#!/usr/bin/env ruby
# Read-only checks for this repository's article and image conventions.
require "date"
require "json"
require "optparse"
require "pathname"
require "time"
require "yaml"

options = { stage: "draft" }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby check-article.rb [--stage draft|ready] ARTICLE"
  opts.on("--stage STAGE", %w[draft ready]) { |value| options[:stage] = value }
  opts.on("--root PATH", "Repository root (defaults to the skill's repository)") { |value| options[:root] = value }
end
begin
  parser.parse!
  raise ArgumentError, "Provide exactly one article path" unless ARGV.length == 1
rescue OptionParser::ParseError, ArgumentError => e
  warn e.message
  exit 2
end

root = Pathname.new(options[:root] || File.expand_path("../../..", __dir__)).expand_path
article = Pathname.new(ARGV.first).expand_path
errors = []
warnings = []
images = []
remote = ->(src) { src.match?(%r{\A(?:https?:)?//}i) }
issue = ->(message) { (options[:stage] == "ready" ? errors : warnings) << message }

begin
  source = article.read(encoding: "UTF-8")
  match = source.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
  raise ArgumentError, "Missing YAML Front Matter" unless match
  fm = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: false)
  raise ArgumentError, "Front Matter must be a mapping" unless fm.is_a?(Hash)
  body = match[2]
  %w[title slug].each { |key| errors << "Missing #{key}" if fm[key].to_s.strip.empty? }
  %w[description game date updated].each { |key| issue.call("Missing #{key}") if fm[key].to_s.strip.empty? }
  issue.call("Missing or non-boolean draft") unless [true, false].include?(fm["draft"])
  dates = {}
  %w[date updated].each do |key|
    next if fm[key].to_s.empty?
    begin
      value = fm[key].is_a?(Time) ? fm[key].iso8601 : fm[key].to_s
      raise ArgumentError unless value.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)
      dates[key] = DateTime.iso8601(value)
    rescue ArgumentError
      errors << "#{key} must be an ISO timestamp with timezone"
    end
  end
  errors << "updated precedes date" if dates.size == 2 && dates["updated"] < dates["date"]
  issue.call("Empty article body") if body.strip.empty?
  issue.call("Missing categories") unless fm["categories"].is_a?(Array) && !fm["categories"].empty?
  if fm["wechat"] && !fm["wechat"].is_a?(Hash)
    errors << "wechat must be a mapping"
  end

  image = fm["image"].to_s.strip
  if image.empty? || image.end_with?("/")
    issue.call("Missing website image or directory placeholder")
  elsif remote.call(image)
    warnings << "Remote website cover requires separate availability verification"
  else
    website_cover = root.join("assets", image.sub(%r{\A/+}, ""))
    issue.call("Website cover not found under assets: #{image}") unless website_cover.file?
    warnings << "Website cover path is not a site /images/ URL; verify schema and rendered URL" unless image.start_with?("/images/")
  end

  # Check common Markdown and Obsidian local image references.
  body.scan(/!\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/) { |m| images << m[0] }
  body.scan(/!\[\[([^\]]+)\]\]/) { |m| images << m[0].split("|", 2).first.strip }
  images.uniq.each do |src|
    if remote.call(src)
      warnings << "Remote body image requires separate availability verification: #{src}"
      next
    end
    if src.start_with?("data:", "#")
      warnings << "Special image reference requires render review"
      next
    end
    errors << "Body image missing: #{src}" unless article.dirname.join(src).file?
    warnings << "Absolute body image is not portable: #{src}" if Pathname.new(src).absolute?
  end
  recognized_count = body.scan(/!\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/).size + body.scan(/!\[\[[^\]]+\]\]/).size
  if body.scan(/!\[/).size > recognized_count || body.match?(/<img\b/i) || body.match?(/!\[[^\]]*\]\[/)
    warnings << "Some image syntax is outside this checker's subset; inspect manually"
  end
  warnings << "Markdown table found; check mobile width" if body.match?(/^\s*\|.*\|\s*$/)
  warnings << "Hugo draft is false; verify website release intent" if fm["draft"] == false
rescue Errno::ENOENT, Psych::Exception, ArgumentError => e
  errors << e.message
end

puts JSON.pretty_generate({ article: article.to_s, stage: options[:stage], ok: errors.empty?, errors: errors, warnings: warnings.uniq, body_images: images.uniq.size })
exit(errors.empty? ? 0 : 1)
