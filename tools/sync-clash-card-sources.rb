#!/usr/bin/env ruby

require "cgi"
require "date"
require "json"
require "nokogiri"
require "open-uri"
require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
API_URL = "https://clashroyale.fandom.com/api.php"
CARD_DATA_URL = "https://royaleapi.github.io/cr-api-data/json/cards_i18n.json"
USER_AGENT = "SCBase/1.0 (card encyclopedia source sync)"

NAME_OVERRIDES = {
  "berserker" => ["狂战士", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/2月-活动-挑战-2"],
  "goblin-demolisher" => ["哥布林爆破手", "https://supercell.com/en/games/clashroyale/zh-hans/blog/news/哥布林女皇征程更新"],
  "suspicious-bush" => ["可疑草丛", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/哥布林女皇征程调整"],
  "rune-giant" => ["符文巨人", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/2月-活动-挑战-2"],
  "spirit-empress" => ["精灵女王", "https://supercell.com/en/games/clashroyale/zh-hans/blog/news/全新-主题季-女王-的-新衣"],
  "goblin-machine" => ["哥布林机甲", "https://supercell.com/en/games/clashroyale/zh-hans/blog/news/哥布林女皇征程更新"],
  "ronin" => ["浪人", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/全新-主题季-荣耀-与-离乡"],
  "boss-bandit" => ["刺客头领", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/4月-更新"],
  "goblinstein" => ["科学怪哥布林", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/十月更新"],
  "little-prince" => ["小王子", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/11月13日更新"],
  "vines" => ["藤蔓法术", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/三月-平衡性-调整"],
  "goblin-curse" => ["哥布林魔咒", "https://supercell.com/en/games/clashroyale/zh-hans/blog/news/哥布林女皇征程更新"],
  "void" => ["虚空法术", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/十月更新"],
  "tower-princess" => ["皇家塔公主", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/12月13日游戏更新"],
  "cannoneer" => ["炮兵", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/维护调整详情"],
  "dagger-duchess" => ["飞刀女爵", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/4月活动和挑战"],
  "royal-chef" => ["皇家大厨", "https://supercell.com/en/games/clashroyale/zh-hans/blog/release-notes/游戏更新-全新皇家塔部队皇家大厨"]
}.freeze

TYPE_KEYS = {
  "Troops" => "troop",
  "Spells" => "spell",
  "Buildings" => "building",
  "Tower Troops" => "tower_troop"
}.freeze

RARITY_KEYS = {
  "Common" => "common",
  "Rare" => "rare",
  "Epic" => "epic",
  "Legendary" => "legendary",
  "Champion" => "champion"
}.freeze

def fetch_parse(page, props)
  query = {
    "action" => "parse",
    "page" => page,
    "prop" => props.join("|"),
    "format" => "json",
    "formatversion" => "2"
  }
  url = "#{API_URL}?#{URI.encode_www_form(query)}"
  payload = URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 30).read
  parsed = JSON.parse(payload)
  raise "Fandom 页面读取失败：#{page}" if parsed["error"] || !parsed["parse"]

  parsed.fetch("parse")
end

def fetch_json(url)
  JSON.parse(URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 30).read)
end

def fetch_wikitext_batch(titles)
  results = {}

  titles.each_slice(50) do |slice|
    query = {
      "action" => "query",
      "titles" => slice.join("|"),
      "redirects" => "1",
      "prop" => "revisions",
      "rvprop" => "content",
      "rvslots" => "main",
      "format" => "json",
      "formatversion" => "2"
    }
    url = "#{API_URL}?#{URI.encode_www_form(query)}"
    payload = URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 30).read
    response = JSON.parse(payload).fetch("query")
    aliases = {}
    Array(response["normalized"]).each { |entry| aliases[entry["from"]] = entry["to"] }
    Array(response["redirects"]).each { |entry| aliases[entry["from"]] = entry["to"] }

    pages = response.fetch("pages").to_h do |page|
      content = page.dig("revisions", 0, "slots", "main", "content")
      [page.fetch("title"), content]
    end

    slice.each do |title|
      resolved = title
      resolved = aliases[resolved] while aliases[resolved] && aliases[resolved] != resolved
      results[title] = pages[resolved]
    end
  end

  results
end

def card_key(name)
  name.downcase
      .gsub("&", " and ")
      .delete(".")
      .gsub(/[^a-z0-9]+/, "-")
      .gsub(/\A-+|-+\z/, "")
end

def parse_catalog(wikitext)
  type = nil
  rarity = nil
  cards = []

  wikitext.each_line do |line|
    if (heading = line.match(/^==([^=]+)==\s*$/))
      type = TYPE_KEYS[heading[1].strip]
      rarity = nil
      next
    end

    if (heading = line.match(/^===([^=<]+)(?:<.*)?===\s*$/))
      rarity = RARITY_KEYS[heading[1].strip]
      next
    end

    match = line.match(/\{\{CardOverview\|Card\s*=\s*([^|}\n]+)/i)
    next unless match

    name = match[1].strip
    raise "无法判断 #{name} 的类型或稀有度" unless type && rarity

    cards << {
      "key" => card_key(name),
      "fandom_page" => name,
      "type" => type,
      "rarity" => rarity,
      "source_url" => "https://clashroyale.fandom.com/wiki/#{CGI.escape(name.tr(' ', '_')).gsub('+', '_')}"
    }
  end

  duplicates = cards.group_by { |card| card["key"] }.select { |_key, rows| rows.length > 1 }
  raise "规范化 key 冲突：#{duplicates.keys.join(', ')}" unless duplicates.empty?

  cards
end

def clean_text(node)
  node.text.gsub(/\s+/, " ").strip
end

def parse_table(doc, selector)
  table = doc.at_css(selector)
  return nil unless table

  rows = table.css("tr")
  raw_headers = rows.first&.css("th")&.map { |cell| clean_text(cell) } || []
  counts = Hash.new(0)
  headers = raw_headers.map do |header|
    counts[header] += 1
    counts[header] > 1 ? "#{header}__#{counts[header]}" : header
  end
  values = rows.drop(1).map do |row|
    cells = row.css("th, td").map { |cell| clean_text(cell) }
    next if cells.empty?

    headers.zip(cells).to_h
  end.compact

  { "headers" => headers, "rows" => values }
end

def parse_infobox(wikitext)
  raw = wikitext[/\{\{Card Infobox\|(.*?)\}\}/m, 1]
  return {} unless raw

  raw.split("|").map do |part|
    key, value = part.split("=", 2)
    next unless value

    [key.strip, value.strip]
  end.compact.to_h
end

def parse_chinese_name(wikitext)
  template = wikitext[/\{\{Other languages\s*\|(.*?)\}\}/m, 1]
  if template
    fields = template.split("|").map do |part|
      key, value = part.split("=", 2)
      next unless value

      [key.strip, value.strip]
    end.compact.to_h
    return fields["cn"] || fields["cnt"] if fields["cn"] || fields["cnt"]
  end

  wikitext[/^\[\[zh:([^\]]+)\]\]\s*$/i, 1]
end

def release_date_from_history(wikitext)
  history = parse_history(wikitext).map { |entry| entry["raw"] }.join(" ")
  match = history.match(/(?:added to the game|generally released).*?on\s+(\d{1,2}\/\d{1,2}\/\d{4})/i)
  match && match[1]
end

def enrich_catalog(cards)
  pages = fetch_wikitext_batch(cards.map { |card| card["fandom_page"] })
  official_cards = fetch_json(CARD_DATA_URL).to_h { |card| [card["key"], card] }

  cards.each do |card|
    wikitext = pages[card["fandom_page"]]
    next unless wikitext

    infobox = parse_infobox(wikitext)
    card["name_zh"] = parse_chinese_name(wikitext)
    card["cost"] = infobox["Cost"]
    card["arena"] = infobox["Arena"]
    card["release_date"] = infobox["ReleaseDate"] || release_date_from_history(wikitext)

    official = official_cards[card["key"]]
    if official
      card["official_id"] = official["id"]
      card["name_zh"] ||= official.dig("_lang", "name", "cn")
      card["official_description_zh"] = official.dig("_lang", "description", "cn")
      card["cost"] ||= official["elixir"]
      card["arena"] ||= official["arena"]
    end

    override = NAME_OVERRIDES[card["key"]]
    next unless override

    card["name_zh"] = override[0]
    card["name_source"] = override[1]
  end
end

def parse_history(wikitext)
  section = wikitext[/^==\s*History\s*==\s*(.*?)(?=^==[^=])/m, 1]
  return [] unless section

  section.lines.map do |line|
    text = line.strip
    next unless text.start_with?("*")

    {
      "raw" => text.sub(/^\*+\s*/, ""),
      "balance_types" => text.scan(/\{\{Balance\|([^}]+)\}\}/i).flatten.map(&:downcase).uniq
    }
  end.compact
end

def inspect_card(page)
  parsed = fetch_parse(page, %w[text wikitext])
  wikitext = parsed.fetch("wikitext")
  doc = Nokogiri::HTML.fragment(parsed.fetch("text"))

  {
    "page" => parsed.fetch("title"),
    "key" => card_key(parsed.fetch("title")),
    "name_zh" => parse_chinese_name(wikitext),
    "infobox" => parse_infobox(wikitext),
    "attributes" => parse_table(doc, "#unit-attributes-table"),
    "level_stats" => parse_table(doc, "#unit-statistics-table"),
    "history" => parse_history(wikitext)
  }
end

def parse_card_source(page)
  parsed = fetch_parse(page, %w[text wikitext])
  wikitext = parsed.fetch("wikitext")
  doc = Nokogiri::HTML.fragment(parsed.fetch("text"))
  image = doc.at_css(".portable-infobox .pi-image-thumbnail") || doc.at_css(".pi-image-thumbnail")
  attribute_groups = doc.css('table[id^="unit-attributes-table"]').map do |table|
    heading = table.previous_element
    heading = heading.previous_element while heading && heading.name != "h3"
    name = heading ? clean_text(heading).sub(/\s+Attributes\z/i, "") : parsed.fetch("title")
    parsed_table = parse_table(Nokogiri::HTML.fragment(table.to_html), "table")
    { "name" => name, "table_id" => table["id"], "table" => parsed_table }
  end

  {
    "page" => parsed.fetch("title"),
    "infobox" => parse_infobox(wikitext),
    "attributes" => attribute_groups.first && attribute_groups.first["table"],
    "attribute_groups" => attribute_groups,
    "level_stats" => parse_table(doc, "#unit-statistics-table"),
    "history" => parse_history(wikitext),
    "image_url" => image && (image["data-src"] || image["src"])
  }
end

def fetch_card_sources(cards, workers: 8)
  queue = Queue.new
  cards.each { |card| queue << card }
  results = {}
  errors = []
  lock = Mutex.new

  threads = Array.new(workers) do
    Thread.new do
      loop do
        card = queue.pop(true)
        source = nil
        3.times do |attempt|
          begin
            source = parse_card_source(card.fetch("fandom_page"))
            break
          rescue StandardError => error
            raise error if attempt == 2
            sleep(attempt + 1)
          end
        end
        lock.synchronize { results[card.fetch("key")] = source }
      rescue ThreadError
        break
      rescue StandardError => error
        lock.synchronize { errors << "#{card['fandom_page']}: #{error.message}" }
      end
    end
  end
  threads.each(&:join)
  raise "卡牌详情读取失败：\n#{errors.join("\n")}" unless errors.empty?

  results
end

def print_field_audit(cards, sources)
  attribute_headers = cards.flat_map do |card|
    sources.dig(card["key"], "attributes", "headers") || []
  end.uniq.sort
  stat_headers = cards.flat_map do |card|
    sources.dig(card["key"], "level_stats", "headers") || []
  end.uniq.sort

  puts "战斗参数字段（#{attribute_headers.length}）："
  puts attribute_headers
  puts "\n等级属性字段（#{stat_headers.length}）："
  puts stat_headers
end

if $PROGRAM_NAME == __FILE__
  options = { write_manifest: false, inspect: nil, audit_fields: false }
  OptionParser.new do |parser|
    parser.banner = "Usage: ruby tools/sync-clash-card-sources.rb [options]"
    parser.on("--write-manifest", "更新 Fandom 卡牌来源清单") { options[:write_manifest] = true }
    parser.on("--inspect PAGE", "解析并打印一张卡牌的源数据") { |page| options[:inspect] = page }
    parser.on("--audit-fields", "审计全部卡牌详情表字段") { options[:audit_fields] = true }
  end.parse!

  if options[:inspect]
    puts YAML.dump(inspect_card(options[:inspect]))
    exit 0
  end

  catalog_page = fetch_parse("Card Overviews", ["wikitext"])
  cards = parse_catalog(catalog_page.fetch("wikitext"))
  counts = cards.group_by { |card| card["type"] }.transform_values(&:length)

  puts "发现 #{cards.length} 张卡牌：#{counts.map { |type, count| "#{type}=#{count}" }.join(', ')}"

  if options[:audit_fields]
    sources = fetch_card_sources(cards)
    print_field_audit(cards, sources)
  end

  if options[:write_manifest]
    enrich_catalog(cards)
    output = {
      "meta" => {
        "source" => "https://clashroyale.fandom.com/wiki/Card_Overviews",
        "retrieved_at" => Time.now.strftime("%Y-%m-%d"),
        "count" => cards.length
      },
      "items" => cards
    }
    path = File.join(ROOT, "data/clashroyale/card-source-manifest.yaml")
    File.write(path, YAML.dump(output, line_width: -1))
    puts "已更新 #{path}"
  end
end
