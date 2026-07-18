#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "rexml/document"
require "set"
require "uri"

DEFAULT_SITE = "https://scbase.cn"
DEFAULT_SITEMAP = "#{DEFAULT_SITE}/sitemap.xml"
DEFAULT_ENDPOINT = "http://data.zz.baidu.com/urls"

def request(uri, request = Net::HTTP::Get.new(uri), redirects = 5)
  raise "重定向次数过多：#{uri}" if redirects.negative?

  response = Net::HTTP.start(
    uri.hostname,
    uri.port,
    use_ssl: uri.scheme == "https",
    open_timeout: 15,
    read_timeout: 30
  ) { |http| http.request(request) }

  if response.is_a?(Net::HTTPRedirection)
    target = URI.join(uri, response.fetch("location"))
    return request(target, Net::HTTP::Get.new(target), redirects - 1)
  end

  response
end

def read_url(url)
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req["User-Agent"] = "SCBase-BaiduSubmit/1.0"
  response = request(uri, req)
  raise "读取 #{url} 失败：HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def sitemap_urls(sitemap_url, seen = Set.new)
  return [] if seen.include?(sitemap_url)

  seen << sitemap_url
  document = REXML::Document.new(read_url(sitemap_url))
  root = document.root
  raise "Sitemap 没有根节点：#{sitemap_url}" unless root

  locations = []
  REXML::XPath.each(root, ".//*[local-name()='loc']") do |element|
    locations << element.text.to_s.strip unless element.text.to_s.strip.empty?
  end

  case root.name
  when "sitemapindex"
    locations.flat_map { |child| sitemap_urls(child, seen) }
  when "urlset"
    locations
  else
    raise "不支持的 Sitemap 根节点：#{root.name}"
  end
end

def validate_urls(urls, site)
  site_uri = URI(site)
  seen = Set.new

  urls.each_with_object([]) do |raw_url, accepted|
    value = raw_url.strip
    next if value.empty? || seen.include?(value)

    uri = URI(value)
    unless uri.scheme == site_uri.scheme && uri.host == site_uri.host && uri.port == site_uri.port
      warn "跳过非本站 URL：#{value}"
      next
    end

    seen << value
    accepted << value
  rescue URI::InvalidURIError
    warn "跳过无效 URL：#{value}"
  end
end

def submit(urls, site, token, batch_size)
  endpoint = URI(DEFAULT_ENDPOINT)
  site_uri = URI(site)
  site_parameter = site_uri.host || site
  endpoint.query = URI.encode_www_form(site: site_parameter, token: token)
  submitted = 0

  urls.each_slice(batch_size).with_index(1) do |batch, index|
    req = Net::HTTP::Post.new(endpoint)
    req["Content-Type"] = "text/plain"
    req.body = "#{batch.join("\n")}\n"
    response = request(endpoint, req)
    raise "百度接口返回 HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body)
    success = result.fetch("success", 0).to_i
    submitted += success
    puts "批次 #{index}：提交 #{batch.length} 条，成功 #{success} 条，今日剩余 #{result.fetch("remain", "未知")} 条。"
    warn "非本站 URL：#{result["not_same_site"]}" if result["not_same_site"]&.any?
    warn "无效 URL：#{result["not_valid"]}" if result["not_valid"]&.any?
  end

  submitted
end


begin
options = {
  site: DEFAULT_SITE,
  sitemap: DEFAULT_SITEMAP,
  batch_size: 2000,
  dry_run: false
}

OptionParser.new do |parser|
  parser.banner = "用法：ruby tools/submit-baidu-urls.rb [选项]"
  parser.on("--site URL", "百度资源平台中的站点地址") { |value| options[:site] = value }
  parser.on("--sitemap URL", "用于读取 URL 的 Sitemap") { |value| options[:sitemap] = value }
  parser.on("--file PATH", "改为读取每行一个 URL 的文本文件") { |value| options[:file] = value }
  parser.on("--limit N", Integer, "只取前 N 条 URL") { |value| options[:limit] = value }
  parser.on("--batch-size N", Integer, "每批提交数量") { |value| options[:batch_size] = value }
  parser.on("--dry-run", "仅输出待提交 URL，不请求百度") { options[:dry_run] = true }
end.parse!

raise "--limit 必须大于 0" if options[:limit] && options[:limit] < 1
raise "--batch-size 必须大于 0" if options[:batch_size] < 1

token = ENV["BAIDU_PUSH_TOKEN"]
abort "缺少环境变量 BAIDU_PUSH_TOKEN。" if !options[:dry_run] && (token.nil? || token.empty?)

urls = if options[:file]
         File.readlines(options[:file], chomp: true)
       else
         sitemap_urls(options[:sitemap])
       end
urls = validate_urls(urls, options[:site])
urls = urls.first(options[:limit]) if options[:limit]

if urls.empty?
  puts "没有可提交的 URL。"
  exit 0
end

puts "发现 #{urls.length} 条本站 URL。"
if options[:dry_run]
  puts urls
  exit 0
end

submitted = submit(urls, options[:site], token, options[:batch_size])
puts "提交完成，百度接受 #{submitted} 条 URL。"
rescue JSON::ParserError, OptionParser::ParseError, REXML::ParseException, StandardError => e
  warn "提交失败：#{e.message}"
  exit 1
end
