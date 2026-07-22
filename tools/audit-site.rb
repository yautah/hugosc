#!/usr/bin/env ruby

require "cgi"
require "json"
require "pathname"
require "uri"

ROOT = Pathname.new(File.expand_path("..", __dir__))
PUBLIC_DIR = ROOT.join("public")
SITE_HOST = "scbase.cn"
CANONICAL_EXEMPT = [
  %r{\Abaidu_verify_codeva-[^/]+\.html\z},
  %r{\Akl/index\.html\z},
  %r{\Asb-chests/index\.html\z}
].freeze

abort "public/ 不存在，请先运行 hugo 构建。" unless PUBLIC_DIR.directory?

html_files = Dir[PUBLIC_DIR.join("**/*.html").to_s].sort
errors = []
warnings = []
internal_links = 0
json_ld_blocks = 0
canonical_pages = 0
noindex_pages = []

def output_file_for(path)
  clean_path = path.sub(%r{\A/+}, "")
  return PUBLIC_DIR.join("index.html") if clean_path.empty?

  direct = PUBLIC_DIR.join(clean_path)
  return direct if direct.file?

  PUBLIC_DIR.join(clean_path, "index.html")
end

def internal_path(raw_url, base_dir = "/")
  value = CGI.unescapeHTML(raw_url.to_s.strip)
  return nil if value.empty? || value.start_with?("#", "mailto:", "tel:", "javascript:", "data:", "//")

  uri = URI.parse(value)
  return nil if uri.host && uri.host != SITE_HOST && uri.host != "localhost" && uri.host != "127.0.0.1"

  path = uri.path.to_s
  path = "." if path.empty?
  path = File.expand_path(path, base_dir) unless path.start_with?("/")
  URI::DEFAULT_PARSER.unescape(path)
rescue URI::InvalidURIError, ArgumentError
  nil
end

def attribute_value(tag, name)
  match = tag.match(/\b#{Regexp.escape(name)}\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i)
  match && (match[1] || match[2] || match[3])
end

html_files.each do |file|
  html = File.read(file, encoding: "UTF-8")
  relative = Pathname.new(file).relative_path_from(PUBLIC_DIR).to_s
  page_dir = File.dirname("/#{relative}")

  canonical_tag = html.scan(/<link\b[^>]*>/i).find do |tag|
    attribute_value(tag, "rel").to_s.split.include?("canonical")
  end
  canonical = attribute_value(canonical_tag, "href") if canonical_tag
  if canonical
    canonical_pages += 1
    if (path = internal_path(canonical)) && !output_file_for(path).file?
      errors << "canonical 目标不存在: #{relative} -> #{path}"
    end
  elsif !CANONICAL_EXEMPT.any? { |pattern| relative.match?(pattern) }
    errors << "缺少 canonical: #{relative}"
  end

  noindex = html.scan(/<meta\b[^>]*>/i).any? do |tag|
    attribute_value(tag, "name") == "robots" && attribute_value(tag, "content").to_s.include?("noindex")
  end
  noindex_pages << relative if noindex

  html.scan(/<script\b([^>]*)>(.*?)<\/script>/im).each do |attributes, body|
    next unless attribute_value(attributes, "type") == "application/ld+json"

    json_ld_blocks += 1
    JSON.parse(body)
  rescue JSON::ParserError => e
    errors << "JSON-LD 无法解析: #{relative} (#{e.message})"
  end

  html.scan(/\b(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i).each do |values|
    url = values.compact.first
    path = internal_path(url, page_dir)
    next unless path
    next if path.start_with?("/__")

    internal_links += 1
    target = output_file_for(path)
    errors << "内部链接目标不存在: #{relative} -> #{path}" unless target.file?
  end
end

sitemap_file = PUBLIC_DIR.join("sitemap.xml")
if sitemap_file.file?
  sitemap = File.read(sitemap_file, encoding: "UTF-8")
  sitemap_paths = sitemap.scan(/<loc>(.*?)<\/loc>/).flatten.map { |url| internal_path(url) }.compact
  sitemap_paths.each do |path|
    target = output_file_for(path)
    unless target.file?
      errors << "Sitemap 目标不存在: #{path}"
      next
    end

    html = File.read(target, encoding: "UTF-8")
    if html.match?(/<meta\s+[^>]*name=["']robots["'][^>]*content=["'][^"']*noindex/i)
      errors << "Sitemap 包含 noindex 页面: #{path}"
    end
  end
else
  errors << "缺少 sitemap.xml"
  sitemap_paths = []
end

ad_pages = html_files.select do |file|
  File.read(file, encoding: "UTF-8").include?("pagead2.googlesyndication.com")
end
warnings << "当前仍有 #{ad_pages.length} 个页面加载 AdSense" unless ad_pages.empty?

errors.uniq!
warnings.uniq!

puts "站点技术审计"
puts "- HTML 页面: #{html_files.length}"
puts "- canonical 页面: #{canonical_pages}"
puts "- 内部链接引用: #{internal_links}"
puts "- JSON-LD 数据块: #{json_ld_blocks}"
puts "- noindex 页面: #{noindex_pages.length}"
puts "- Sitemap URL: #{sitemap_paths.length}"
puts "- AdSense 页面: #{ad_pages.length}"

unless warnings.empty?
  puts "\n提醒："
  warnings.each { |warning| puts "- #{warning}" }
end

unless errors.empty?
  puts "\n错误："
  errors.first(100).each { |error| puts "- #{error}" }
  puts "- 其余 #{errors.length - 100} 项未显示" if errors.length > 100
  exit 1
end

puts "\n审计通过。"
