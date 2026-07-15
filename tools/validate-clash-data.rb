#!/usr/bin/env ruby

require "yaml"

ROOT = File.expand_path("..", __dir__)
CARDS_CONTENT_DIR = File.join(ROOT, "content", "clashroyale", "cards")
require_editorials = ARGV.delete("--require-editorials")
cards_data = YAML.load_file(File.join(ROOT, "data/clashroyale/cards.yaml"))
decks_data = YAML.load_file(File.join(ROOT, "data/clashroyale/decks.yaml"))
details_dir = File.join(ROOT, "data/clashroyale/card-details")
card_details = Dir.glob(File.join(details_dir, "*.yaml")).to_h do |path|
  [File.basename(path, ".yaml"), YAML.load_file(path)]
end
editorials_dir = File.join(ROOT, "data/clashroyale/card-editorials")
card_editorials = Dir.glob(File.join(editorials_dir, "*.yaml")).to_h do |path|
  [File.basename(path, ".yaml"), YAML.load_file(path)]
end
history_overrides_dir = File.join(ROOT, "data/clashroyale/card-history-overrides")
history_overrides = Dir.glob(File.join(history_overrides_dir, "*.yaml")).to_h do |path|
  [File.basename(path, ".yaml"), YAML.load_file(path)]
end
variants_dir = File.join(ROOT, "data/clashroyale/card-variants")
card_variants = Dir.glob(File.join(variants_dir, "*.yaml")).map { |path| YAML.load_file(path) }
cards = cards_data.fetch("items")
decks = decks_data.fetch("items")
errors = []

def card_content_path(key)
  File.join(CARDS_CONTENT_DIR, "#{key}.md")
end

def variant_content_path(key)
  File.join(CARDS_CONTENT_DIR, "#{key}.md")
end

def duplicates(values)
  counts = values.each_with_object(Hash.new(0)) { |value, result| result[value] += 1 }
  counts.select { |_value, count| count > 1 }.keys
end

duplicates(cards.map { |card| card.fetch("key") }).each do |key|
  errors << "重复的卡牌 key: #{key}"
end

duplicates(decks.map { |deck| deck.fetch("id") }).each do |id|
  errors << "重复的卡组 id: #{id}"
end

duplicates(decks.map { |deck| deck.fetch("slug") }).each do |slug|
  errors << "重复的卡组 slug: #{slug}"
end

cards_by_key = cards.to_h { |card| [card.fetch("key"), card] }

cards.each do |card|
  key = card.fetch("key")
  elixir = card["elixir"]
  if card.fetch("type") == "tower_troop" || %w[mirror spirit-empress].include?(key)
    errors << "#{key}: 不应配置固定圣水" unless elixir.nil?
  else
    errors << "#{key}: 圣水必须在 1-10 之间" unless elixir && (1..10).cover?(elixir)
  end

  image = File.join(ROOT, "assets", card.fetch("image"))
  errors << "#{key}: 图片不存在 #{card.fetch('image')}" unless File.file?(image)

  errors << "#{key}: 缺少详情页地址" if card["detail_url"].to_s.empty?
  route = card_content_path(key)
  errors << "#{key}: 缺少详情页内容路由" unless File.file?(route)

  detail = card_details[key]
  unless detail
    errors << "#{key}: 缺少独立详情数据文件"
    next
  end

  %w[release_date units balance_history source_retrieved_at].each do |field|
    errors << "#{key}: 详情数据缺少 #{field}" unless detail.key?(field)
  end

  units = detail["units"] || []
  errors << "#{key}: 单位数据必须是非空列表" unless units.is_a?(Array) && !units.empty?
  errors << "#{key}: 第一个单位必须是主单位" unless units.first&.fetch("kind", nil) == "main"
  errors << "#{key}: 只能配置一个主单位" unless units.count { |unit| unit["kind"] == "main" } == 1
  errors << "#{key}: 单位名称重复" unless units.map { |unit| unit["name"] }.uniq.length == units.length

  units.each do |unit|
    unit_name = unit["name"].to_s
    errors << "#{key}: 单位缺少中文名称" if unit_name.empty? || unit_name.match?(/[A-Za-z]/)
    errors << "#{key}: 未知单位类型 #{unit['kind']}" unless %w[main child].include?(unit["kind"])

    mechanics = unit["mechanics"] || []
    errors << "#{key}/#{unit_name}: 战斗参数必须是列表" unless mechanics.is_a?(Array)
    Array(mechanics).each do |field|
      errors << "#{key}/#{unit_name}: 战斗参数缺少标签或值" if field["label"].to_s.empty? || field["value"].to_s.empty?
      errors << "#{key}/#{unit_name}: 战斗参数存在英文标签 #{field['label']}" if field["label"].to_s.match?(/[A-Za-z]/)
      errors << "#{key}/#{unit_name}: 战斗参数存在英文值 #{field['value']}" if field["value"].to_s.match?(/[A-Za-z]/)
    end

    level_stats = unit["level_stats"]
    errors << "#{key}/#{unit_name}: 战斗参数和等级属性不能同时为空" if mechanics.empty? && level_stats.nil?
    next if level_stats.nil?

    columns = level_stats["columns"] || []
    rows = level_stats["rows"] || []
    errors << "#{key}/#{unit_name}: 等级属性缺少列定义" if columns.empty?
    errors << "#{key}/#{unit_name}: 等级属性缺少数据行" if rows.empty?
    columns.each do |column|
      errors << "#{key}/#{unit_name}: 等级属性存在英文标签 #{column['label']}" if column["label"].to_s.match?(/[A-Za-z]/)
    end
    levels = rows.map { |row| row["level"].to_i }
    errors << "#{key}/#{unit_name}: 等级属性存在重复等级" unless levels.uniq.length == levels.length
    errors << "#{key}/#{unit_name}: 等级属性必须按等级升序排列" unless levels == levels.sort
    rows.each do |row|
      columns.each do |column|
        field = column.fetch("key")
        errors << "#{key}/#{unit_name}: 等级属性缺少 #{field}" unless row.key?(field)
      end
    end
  end

  history = detail["balance_history"] || []
  dates = history.map { |entry| entry["date"] }
  errors << "#{key}: 平衡记录必须按日期倒序排列" unless dates == dates.sort.reverse
  history.each do |entry|
    errors << "#{key}: 未知平衡调整类型 #{entry['type']}" unless %w[buff nerf adjustment release visual evolution hero].include?(entry["type"])
    errors << "#{key}: 平衡记录缺少说明" if entry["summary"].to_s.empty?
    errors << "#{key}: 平衡记录存在英文说明 #{entry['summary']}" if entry["summary"].to_s.match?(/[A-Za-z]/)
  end
end

unknown_details = card_details.keys.reject { |key| cards_by_key.key?(key) }
errors << "存在没有卡牌主数据的详情文件: #{unknown_details.join(', ')}" unless unknown_details.empty?

unknown_editorials = card_editorials.keys.reject { |key| cards_by_key.key?(key) }
errors << "存在没有卡牌主数据的编辑内容: #{unknown_editorials.join(', ')}" unless unknown_editorials.empty?
if require_editorials
  missing_editorials = cards_by_key.keys.sort.reject { |key| card_editorials.key?(key) }
  errors << "以下卡牌缺少固定编辑模块: #{missing_editorials.join(', ')}" unless missing_editorials.empty?
end
card_editorials.each do |key, editorial|
  overview = editorial["overview"] || []
  usage_tips = editorial["usage_tips"] || []
  matchups = editorial["matchups"] || []
  errors << "#{key}: 卡牌特点至少需要一个自然段" unless overview.is_a?(Array) && !overview.empty?
  errors << "#{key}: 使用要点至少需要三条" unless usage_tips.is_a?(Array) && usage_tips.length >= 3
  errors << "#{key}: 对局信息必须包含适合应对、需要提防和搭配思路" unless matchups.is_a?(Array) && matchups.length == 3
  Array(overview).each { |paragraph| errors << "#{key}: 卡牌特点存在空段落" if paragraph.to_s.strip.empty? }
  Array(usage_tips).each { |tip| errors << "#{key}: 使用要点存在空内容" if tip.to_s.strip.empty? }
  Array(matchups).each do |matchup|
    errors << "#{key}: 对局信息缺少标题或正文" if matchup["title"].to_s.strip.empty? || matchup["text"].to_s.strip.empty?
  end
end

unknown_history_overrides = history_overrides.keys.reject { |key| cards_by_key.key?(key) }
errors << "存在没有卡牌主数据的平衡记录覆盖文件: #{unknown_history_overrides.join(', ')}" unless unknown_history_overrides.empty?
history_overrides.each do |key, override|
  errors << "#{key}: 平衡记录覆盖文件缺少来源地址" if override["source_url"].to_s.empty?
  history = override["items"] || []
  errors << "#{key}: 平衡记录覆盖内容不能为空" unless history.is_a?(Array) && !history.empty?
  dates = history.map { |entry| entry["date"] }
  errors << "#{key}: 平衡记录覆盖内容必须按日期倒序排列" unless dates == dates.sort.reverse
  history.each do |entry|
    errors << "#{key}: 平衡记录覆盖内容存在未知类型 #{entry['type']}" unless %w[buff nerf adjustment release visual evolution hero].include?(entry["type"])
    errors << "#{key}: 平衡记录覆盖内容缺少说明" if entry["summary"].to_s.empty?
    errors << "#{key}: 平衡记录覆盖内容存在英文说明 #{entry['summary']}" if entry["summary"].to_s.match?(/[A-Za-z]/)
  end
end

duplicates(card_variants.map { |variant| variant.fetch("key") }).each do |key|
  errors << "重复的卡牌形态 key: #{key}"
end

duplicates(card_variants.map { |variant| variant.fetch("url") }).each do |url|
  errors << "重复的卡牌形态地址: #{url}"
end

card_variants.each do |variant|
  key = variant.fetch("key")
  parent_key = variant.fetch("parent_key")
  kind = variant.fetch("kind")
  errors << "#{key}: 父卡牌不存在 #{parent_key}" unless cards_by_key.key?(parent_key)
  errors << "#{key}: 未知形态类型 #{kind}" unless %w[evolution hero].include?(kind)
  errors << "#{key}: 形态名称或标签不能为空" if variant["name"].to_s.empty? || variant["label"].to_s.empty?
  errors << "#{key}: 形态名称存在英文" if variant["name"].to_s.match?(/[A-Za-z]/)
  errors << "#{key}: 缺少来源地址" if variant["source_url"].to_s.empty?
  errors << "#{key}: 缺少抓取日期" if variant["source_retrieved_at"].to_s.empty?

  image = File.join(ROOT, "assets", variant.fetch("image"))
  errors << "#{key}: 图片不存在 #{variant.fetch('image')}" unless File.file?(image)
  route = variant_content_path(key)
  errors << "#{key}: 缺少详情页内容路由" unless File.file?(route)

  facts = variant["facts"] || []
  errors << "#{key}: 顶部信息必须包含四项" unless facts.is_a?(Array) && facts.length == 4
  Array(facts).each do |fact|
    errors << "#{key}: 顶部信息缺少标签或值" if fact["label"].to_s.empty? || fact["value"].to_s.empty?
  end

  overview = variant["overview"] || []
  errors << "#{key}: 形态特点至少需要两个自然段" unless overview.is_a?(Array) && overview.length >= 2
  usage_tips = variant["usage_tips"] || []
  errors << "#{key}: 使用要点至少需要三条" unless usage_tips.is_a?(Array) && usage_tips.length >= 3
  matchups = variant["matchups"] || []
  errors << "#{key}: 对局信息必须包含三项" unless matchups.is_a?(Array) && matchups.length == 3

  units = variant["units"] || []
  errors << "#{key}: 单位数据必须是非空列表" unless units.is_a?(Array) && !units.empty?
  units.each do |unit|
    errors << "#{key}: 单位名称必须使用中文" if unit["name"].to_s.empty? || unit["name"].to_s.match?(/[A-Za-z]/)
    mechanics = unit["mechanics"] || []
    errors << "#{key}: 战斗参数不能为空" unless mechanics.is_a?(Array) && !mechanics.empty?
    Array(mechanics).each do |field|
      errors << "#{key}: 战斗参数缺少标签或值" if field["label"].to_s.empty? || field["value"].to_s.empty?
      errors << "#{key}: 战斗参数存在英文标签" if field["label"].to_s.match?(/[A-Za-z]/)
    end
    stats = unit["level_stats"] || {}
    columns = stats["columns"] || []
    rows = stats["rows"] || []
    errors << "#{key}: 等级属性缺少列定义或数据" if columns.empty? || rows.empty?
    levels = rows.map { |row| row["level"].to_i }
    errors << "#{key}: 等级属性必须按等级升序排列" unless levels == levels.sort
    rows.each do |row|
      columns.each do |column|
        errors << "#{key}: 等级属性缺少 #{column['key']}" unless row.key?(column.fetch("key"))
      end
    end
  end

  history = variant["balance_history"] || []
  dates = history.map { |entry| entry["date"] }
  errors << "#{key}: 版本记录不能为空" if history.empty?
  errors << "#{key}: 版本记录必须按日期倒序排列" unless dates == dates.sort.reverse
  history.each do |entry|
    errors << "#{key}: 版本记录存在未知类型 #{entry['type']}" unless %w[buff nerf adjustment release visual evolution hero].include?(entry["type"])
    errors << "#{key}: 版本记录缺少说明" if entry["summary"].to_s.empty?
    errors << "#{key}: 版本记录存在英文说明 #{entry['summary']}" if entry["summary"].to_s.match?(/[A-Za-z]/)
  end
end

decks.each do |deck|
  id = deck.fetch("id")
  card_keys = deck.fetch("cards")
  errors << "#{id}: 卡组必须恰好包含 8 张卡" unless card_keys.length == 8
  errors << "#{id}: 卡组中存在重复卡牌" unless card_keys.uniq.length == card_keys.length

  unknown = card_keys.reject { |key| cards_by_key.key?(key) }
  errors << "#{id}: 引用了不存在的卡牌 #{unknown.join(', ')}" unless unknown.empty?
  next unless unknown.empty? && card_keys.length == 8

  costs = card_keys.map { |key| cards_by_key.fetch(key).fetch("elixir") }
  average = (costs.sum.fdiv(8)).round(1)
  cycle = costs.sort.first(4).sum
  errors << "#{id}: 平均圣水应为 #{average}，当前为 #{deck.fetch('average_elixir')}" unless deck.fetch("average_elixir").to_f == average
  errors << "#{id}: 四卡循环应为 #{cycle}，当前为 #{deck.fetch('cycle_elixir')}" unless deck.fetch("cycle_elixir") == cycle
end

if errors.empty?
  puts "卡牌与卡组数据校验通过：#{cards.length} 张卡牌，#{card_variants.length} 个卡牌形态，#{decks.length} 套卡组。"
  exit 0
end

warn errors.map { |error| "- #{error}" }.join("\n")
exit 1
