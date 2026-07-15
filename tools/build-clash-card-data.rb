#!/usr/bin/env ruby

require "date"
require "fileutils"
require "open3"
require "optparse"
require "tempfile"
require "yaml"

require_relative "sync-clash-card-sources"

MANIFEST_PATH = File.join(ROOT, "data/clashroyale/card-source-manifest.yaml")
CARDS_PATH = File.join(ROOT, "data/clashroyale/cards.yaml")
DETAILS_DIR = File.join(ROOT, "data/clashroyale/card-details")
HISTORY_OVERRIDES_DIR = File.join(ROOT, "data/clashroyale/card-history-overrides")
IMAGES_DIR = File.join(ROOT, "assets/images/clashroyale/cards")
CONTENT_DIR = File.join(ROOT, "content")
CARDS_CONTENT_DIR = File.join(CONTENT_DIR, "clashroyale", "cards")

TYPE_LABELS = {
  "troop" => "部队", "spell" => "法术", "building" => "建筑", "tower_troop" => "皇家塔部队"
}.freeze

ARENA_LABELS = {
  "Training Camp" => "训练营", "Goblin Stadium" => "哥布林竞技场", "Bone Pit" => "骷髅墓园",
  "Barbarian Bowl" => "野蛮人擂台", "P.E.K.K.A's Playhouse" => "皮卡超人乐园", "Spell Valley" => "法术幽谷",
  "Builder's Workshop" => "建筑工人工坊", "Royal Arena" => "皇家竞技场", "Frozen Peak" => "冰封之巅",
  "Jungle Arena" => "丛林竞技场", "Hog Mountain" => "野猪山脉", "Electro Valley" => "电磁峡谷",
  "Spooky Town" => "惊魂小镇", "Rascal's Hideout" => "淘气岭", "Serenity Peak" => "宁静圣殿",
  "Miner's Mine" => "矿工矿井", "Executioner's Kitchen" => "行刑者厨房", "Royal Crypt" => "皇家墓穴",
  "Silent Sanctuary" => "寂静圣殿", "Dragon Spa" => "龙温泉"
}.freeze

ATTRIBUTE_LABELS = {
  "Ability Cooldown" => "技能冷却", "Ability Count" => "技能次数", "Activation" => "激活时间",
  "Buff Threshold" => "增益触发阈值", "Cast Time" => "施法时间", "Charge Range" => "冲锋距离",
  "Cooking Speed" => "烹饪间隔", "Dagger Charge Time" => "飞刀恢复时间", "Dagger Count" => "飞刀数量",
  "Damage Reduced" => "伤害减免", "Dash Range" => "突袭距离", "Dash Speed" => "突袭速度",
  "Dash Time" => "突袭时间", "Enchant Limit" => "附魔上限", "Enchant Range" => "附魔范围",
  "Enchant Shot" => "附魔攻击", "Enchant duration after she dies" => "死亡后附魔持续时间",
  "Heal Speed" => "治疗间隔", "Hook Projectile Speed" => "鱼钩速度", "Hook Range" => "鱼钩距离",
  "Hook Time" => "鱼钩时间", "Invulnerability Duration" => "无敌持续时间", "Jump Range" => "跃击距离",
  "Jump Speed" => "跃击速度", "Jump Time" => "跃击时间", "Level Increase" => "提升等级",
  "Maximum Dash Distance" => "最大突袭距离", "Maximum Dashes" => "最大突袭次数",
  "Parry Cooldown" => "格挡冷却", "Parry Damage" => "反击伤害", "Skeleton Count" => "骷髅兵数量",
  "Skeleton Hitpoints" => "骷髅兵生命值", "Slowdown Duration" => "减速持续时间",
  "Snare Duration" => "束缚持续时间", "Spawn Slow Duration" => "登场减速持续时间",
  "Time Before Cooking" => "首次烹饪时间", "Time Between Pulses" => "治疗脉冲间隔",
  "Time Between pulses" => "治疗脉冲间隔",
  "Attack Period" => "攻击间隔", "Axe Time" => "斧头准备时间", "Boost" => "强化效果",
  "Clone Hitpoints" => "克隆单位生命值", "Clone Shield Hitpoints" => "克隆单位护盾生命值",
  "Count" => "单位数量", "Curse Duration" => "诅咒持续时间", "Death Damage Splash Radius" => "死亡伤害范围",
  "Deploy Time" => "部署时间", "Duration" => "持续时间", "First Attack Period" => "首次攻击间隔",
  "First Hit Speed" => "首次攻击间隔", "Freeze Duration" => "冰冻持续时间", "Hit Speed" => "攻击间隔",
  "Hit Speed (Stage 1)" => "第一阶段攻击间隔", "Hit Speed (Stage 2)" => "第二阶段攻击间隔",
  "Hit Speed (Stage 3)" => "第三阶段攻击间隔", "Invisibility Time" => "隐身持续时间",
  "Lifetime" => "持续时间", "Production Speed" => "生产间隔", "Projectile Radius" => "投射物半径",
  "Projectile Range" => "投射距离", "Projectile Speed" => "投射物速度", "Projectile Width" => "投射物宽度",
  "Radius" => "作用半径", "Range" => "攻击距离", "Slow Duration" => "减速持续时间",
  "Slowdown" => "减速幅度", "Spawn Delay" => "生成延迟", "Spawn Range" => "生成范围",
  "Spawn Speed" => "生成间隔", "Speed" => "移动速度", "Splash Radius" => "溅射半径",
  "Stun Duration" => "眩晕持续时间", "Target" => "攻击目标", "Transport" => "移动方式", "Width" => "宽度"
}.freeze

SUBUNIT_LABELS = {
  "Kamikaze Goblin Demolisher" => "自爆哥布林爆破手", "Broken Cannon Cart" => "损坏后的加农炮战车",
  "Bush Goblin" => "草丛哥布林", "Bush" => "可疑草丛", "Cursed Hog" => "被诅咒的皇家野猪",
  "Doctor" => "博士", "Monster" => "怪物", "Elixir Blob" => "圣水泡泡", "Elixir Golemite" => "小圣水戈仑",
  "Golemite" => "小戈仑石人", "Goblin Brawler" => "哥布林硬汉", "Guardienne" => "专属护卫",
  "Lava Pup" => "熔岩幼犬", "Phoenix Egg" => "凤凰蛋", "Rascal Boy" => "绿林小哥",
  "Rascal Girl" => "绿林小妹", "Rocket Launcher" => "火箭发射器", "Spear Goblin" => "哥布林投矛手",
  "Skeleton" => "骷髅兵", "Goblin" => "哥布林", "Bat" => "蝙蝠", "Barbarian" => "野蛮人",
  "Archer" => "弓箭手", "Minion" => "亡灵", "Royal Hog" => "皇家野猪", "Wall Breaker" => "攻城炸弹人",
  "Lightning Link" => "闪电连接", "Royal Rescue" => "皇室救援", "Explosive Escape" => "爆炸逃生",
  "Cloned" => "克隆后的", "Mirrored" => "镜像后的", "Skeleton Container" => "骷髅气球外壳",
  "Backpack Spear Goblin" => "背包哥布林投矛手", "Royal Recruit" => "皇家卫兵"
}.freeze

NON_UNIT_GROUPS = %w[
  Charge Ranged\ Attack Melee\ Attack Active\ Healing Spawn\ Healing Death\ Nova Healing Bomb Enchant
  Zap\ Pack Jump Zap Spawn\ Damage Dash Rage Air\ Form Ground\ Form Rocket\ Launcher Hook Dashing\ Dash
  Soul\ Summoning Getaway\ Grenade Cloaking\ Cape Explosive\ Escape Royal\ Rescue Pensive\ Protection Dagger Cooking
].freeze

GROUP_LABELS = {
  "Charge" => "冲锋", "Ranged Attack" => "远程攻击", "Melee Attack" => "近战攻击",
  "Active Healing" => "持续治疗", "Spawn Healing" => "登场治疗", "Death Nova" => "死亡冰爆",
  "Healing" => "治疗效果", "Bomb" => "炸弹", "Enchant" => "符文强化", "Zap Pack" => "电击背包",
  "Jump" => "跃击", "Zap" => "登场电击", "Spawn Damage" => "登场伤害", "Dash" => "突袭",
  "Rage" => "狂暴效果", "Air Form" => "空中形态", "Ground Form" => "地面形态",
  "Rocket Launcher" => "火箭发射器", "Hook" => "鱼钩", "Dashing Dash" => "连续突袭",
  "Soul Summoning" => "灵魂召唤", "Getaway Grenade" => "逃生手榴弹", "Cloaking Cape" => "隐身斗篷",
  "Explosive Escape" => "爆炸逃生", "Royal Rescue" => "皇室救援", "Pensive Protection" => "超然物外",
  "Dagger" => "飞刀", "Cooking" => "烹饪", "Lightning Link" => "闪电连接"
}.freeze

SUMMARY_OVERRIDES = {
  "berserker" => "两费近战部队，生命值扎实且攻击速度很快，适合补充防守与反击输出。",
  "goblin-demolisher" => "远程投掷炸药的哥布林部队，生命值降低后会冲向目标并引爆。",
  "suspicious-bush" => "不会被皇家塔锁定的移动草丛，抵达目标或被摧毁后会放出哥布林。",
  "rune-giant" => "可为身旁友军附加符文效果的支援型巨人，适合围绕推进部队组织进攻。",
  "spirit-empress" => "可按不同圣水费用部署为地面或空中形态的传奇部队。",
  "goblin-machine" => "兼具近战承伤与远程火箭支援能力的哥布林机甲。",
  "ronin" => "能够周期性反弹近战攻击的传奇剑客，擅长正面对抗近战部队。",
  "boss-bandit" => "拥有主动位移技能的英雄部队，可重新拉开距离并再次发动突袭。",
  "goblinstein" => "由博士与怪物共同作战的英雄卡牌，技能可激活两者之间的闪电连接。",
  "little-prince" => "攻击速度会逐步提升的远程英雄，技能可召唤专属护卫加入战斗。",
  "vines" => "短暂束缚多个高生命值目标并造成伤害的控制法术。",
  "goblin-curse" => "使范围内敌军承受额外伤害，并将被击倒单位转化为哥布林的法术。",
  "void" => "根据作用范围内目标数量改变伤害的法术，目标越集中单体伤害越高。",
  "tower-princess" => "基础皇家塔部队，能够稳定攻击空中与地面目标。",
  "cannoneer" => "攻击速度较慢但单次伤害较高的皇家塔部队，擅长处理高生命值目标。",
  "dagger-duchess" => "储存飞刀后可快速连续攻击的皇家塔部队，爆发后需要时间恢复。",
  "royal-chef" => "能够周期性提升友方部队等级的皇家塔部队。"
}.freeze

VALUE_REPLACEMENTS = {
  "Friendly Troops & Buildings" => "友方部队和建筑", "Friendly Troops" => "友方部队",
  "4 pulses every 1 second" => "4 次脉冲，每次间隔 1 秒", "4 pulses every 1 sec" => "4 次脉冲，每次间隔 1 秒",
  "Every 3rd Attack" => "每第 3 次攻击",
  "Troops only" => "仅部队", "Troops" => "部队",
  "Air & Ground" => "空中和地面", "Ground" => "地面", "Air" => "空中", "Buildings" => "建筑",
  "Very Fast" => "极快", "Fast" => "快", "Medium" => "中等", "Slow" => "慢", "Very Slow" => "极慢",
  "Melee: Short" => "近战：短", "Melee: Medium" => "近战：中", "Melee: Long" => "近战：长",
  "Troop" => "部队", "Spell" => "法术", "Building" => "建筑", "Tower Troop" => "皇家塔部队",
  "Common" => "普通", "Rare" => "稀有", "Epic" => "史诗", "Legendary" => "传奇", "Champion" => "英雄"
}.freeze

def normalize_date(value)
  return nil if value.to_s.empty?

  text = value.to_s.strip
  date = if text.match?(/\A\d{1,2}\/\d{1,2}\/\d{4}\z/)
           Date.strptime(text, "%d/%m/%Y")
         else
           Date.parse(text)
         end
  date.iso8601
rescue Date::Error
  text
end

def translate_arena(value)
  return "待核验" if value.nil?
  return "#{value} 阶竞技场" if value.is_a?(Integer)

  ARENA_LABELS.fetch(value.to_s, value.to_s.gsub("Arena", "竞技场"))
end

def translate_value(value)
  text = value.to_s.strip
  VALUE_REPLACEMENTS.sort_by { |source, _target| -source.length }.each { |source, target| text = text.gsub(source, target) }
  text = text.gsub(/(\d+(?:\.\d+)?)\s*sec(?:onds?)?/i, '\\1 秒')
             .gsub(/(\d+(?:\.\d+)?)\s*min(?:utes?)?/i, '\\1 分')
             .gsub(/(\d+(?:\.\d+)?)\s*tiles?/i, '\\1 格')
             .gsub(/\Ax(\d+)\z/i, '\\1')
             .gsub(/\A(\d+)x\z/i, '\\1')
  text
end


def label_replacements(cards)
  card_names = cards.map { |card| [card.fetch("fandom_page"), card.fetch("name_zh")] }
  (card_names + SUBUNIT_LABELS.to_a).sort_by { |source, _target| -source.length }
end

def translate_stat_label(label, replacements)
  text = label.to_s
  replacements.each { |source, target| text = text.gsub(source, target) }
  substitutions = {
    "Crown Tower Damage per second" => "皇家塔每秒伤害",
    "Damage per Second" => "每秒伤害", "Damage Per Second" => "每秒伤害", "Damage per second" => "每秒伤害",
    "Hitpoints lost per second" => "每秒损失生命值", "Healing Per Second" => "每秒治疗量",
    "Healing Per Pulse" => "每次治疗量", "healing per second" => "每秒治疗量", "healing per pulse" => "每次治疗量",
    "Crown Tower Damage" => "皇家塔伤害", "Tower Damage" => "皇家塔伤害", "Shield Hitpoints" => "护盾生命值", "Hitpoints" => "生命值",
    "Area Damage" => "范围伤害", "Death Damage" => "死亡伤害", "Spawn Damage" => "登场伤害",
    "Charge Damage" => "冲锋伤害", "Dash Damage" => "突袭伤害", "Reflected Tower Damage" => "反弹皇家塔伤害",
    "Reflected Damage" => "反弹伤害", "Bonus Damage" => "额外伤害", "Building Damage" => "建筑伤害",
    "Damage" => "伤害", "Level" => "等级", "Active" => "持续效果", "Spawn" => "登场效果",
    "Cloned" => "克隆后的", "Mirrored" => "镜像后的", "Common" => "普通", "Rare" => "稀有",
    "Epic" => "史诗", "Legendary" => "传奇", "Champion" => "英雄", "Air Form" => "空中形态",
    "Ground Form" => "地面形态", "Melee" => "近战", "Ranged" => "远程", "Single Target" => "单个目标",
    "2-4 Targets" => "2 至 4 个目标", "5 Or More Targets" => "5 个及以上目标", "both Forms" => "两种形态",
    "with Cloaking Cape" => "隐身斗篷生效时", "Stage 1" => "第一阶段", "Stage 2" => "第二阶段",
    "Stage 3" => "第三阶段", "1 stage" => "第一阶段", "2 stage" => "第二阶段", "3 stage" => "第三阶段",
    "Empty Dagger" => "飞刀耗尽时", "Explosive Escape" => "爆炸逃生", "Lightning Link" => "闪电连接",
    "Royal Rescue" => "皇室救援", "Rage" => "狂暴效果", "Zap" => "电击", "Jump" => "跳跃",
    "Combo" => "连击", "Dashing" => "突袭时", "Rider" => "骑手", "Ram" => "攻城槌"
  }
  substitutions.sort_by { |source, _target| -source.length }.each do |source, target|
    text = text.gsub(/#{Regexp.escape(source)}/i, target)
  end
  text.gsub(/\s+/, "").strip
end

def field_key(header)
  card_key(header).tr("-", "_")
end

def build_table(table, replacements)
  return nil unless table && table["rows"] && !table["rows"].empty?

  key_counts = Hash.new(0)
  columns = table.fetch("headers").map do |header|
    display_header = header.sub(/__\d+\z/, "")
    base_key = field_key(display_header)
    key_counts[base_key] += 1
    duplicate = key_counts[base_key] > 1
    {
      "key" => duplicate ? "#{base_key}_#{key_counts[base_key]}" : base_key,
      "label" => "#{duplicate ? '生成单位' : ''}#{translate_stat_label(display_header, replacements)}",
      "_source" => header
    }
  end
  english_labels = columns.select { |column| column["label"].match?(/[A-Za-z]/) }
  raise "存在未翻译字段：#{english_labels.map { |column| column['label'] }.join(', ')}" unless english_labels.empty?

  rows = table.fetch("rows").map do |row|
    columns.zip(table.fetch("headers")).to_h do |column, header|
      [column.fetch("key"), row[header].to_s.delete(",")]
    end
  end
  { "columns" => columns, "rows" => rows }
end

def build_mechanics(table)
  return [] unless table && table.dig("rows", 0)

  ignored = %w[Cost Type Rarity]
  table.fetch("headers").reject { |header| ignored.include?(header) }.map do |header|
    label = ATTRIBUTE_LABELS[header]
    raise "战斗参数字段未翻译：#{header}" unless label

    { "key" => field_key(header), "label" => label, "value" => translate_value(table.dig("rows", 0, header)) }
  end
end

def translate_group_name(name, card, replacements)
  return card.fetch("name_zh") if name == card.fetch("fandom_page")
  return GROUP_LABELS[name] if GROUP_LABELS[name]

  translated = translate_stat_label(name, replacements)
  raise "单位名称未翻译：#{name}" if translated.match?(/[A-Za-z]/)
  translated
end

def build_units(source, card, replacements)
  raw_groups = source["attribute_groups"] || []
  raw_groups = [{ "name" => card.fetch("fandom_page"), "table" => source["attributes"] }] if raw_groups.empty?

  physical_groups = []
  merged_groups = []
  seen_names = {}
  raw_groups.each do |group|
    name = group.fetch("name")
    if NON_UNIT_GROUPS.include?(name) || seen_names[name]
      merged_groups << group
    else
      physical_groups << group
      seen_names[name] = true
    end
  end
  physical_groups = [raw_groups.first] if physical_groups.empty?

  units = physical_groups.map.with_index do |group, index|
    {
      "source_name" => group.fetch("name"),
      "name" => translate_group_name(group.fetch("name"), card, replacements),
      "kind" => index.zero? ? "main" : "child",
      "mechanics" => build_mechanics(group["table"])
    }
  end

  merged_groups.each do |group|
    prefix = translate_group_name(group.fetch("name"), card, replacements)
    build_mechanics(group["table"]).each do |field|
      field = field.dup
      field["label"] = "#{prefix}·#{field.fetch('label')}"
      units.first.fetch("mechanics") << field
    end
  end

  full_table = build_table(source["level_stats"], replacements)
  return units unless full_table

  columns_by_unit = Array.new(units.length) { [] }
  level_column = full_table.fetch("columns").find { |column| column["key"] == "level" }
  columns_by_unit.each { |columns| columns << level_column } if level_column
  current_unit = 0

  full_table.fetch("columns").each do |column|
    next if column["key"] == "level"

    source_header = column.fetch("_source")
    display_header = source_header.sub(/__\d+\z/, "")
    matched_index = physical_groups.each_index.select do |index|
      name = physical_groups[index].fetch("name")
      display_header == name || display_header.start_with?("#{name} ")
    end.max_by { |index| physical_groups[index].fetch("name").length }

    effect_names = (merged_groups.map { |group| group.fetch("name") } + GROUP_LABELS.keys).uniq
    effect_match = effect_names.any? do |name|
      display_header == name || display_header.start_with?("#{name} ")
    end
    matched_index = 0 if effect_match

    if matched_index
      current_unit = matched_index
    elsif (duplicate = source_header[/__(\d+)\z/, 1]) && units.length > 1
      current_unit = [duplicate.to_i - 1, units.length - 1].min
    end
    columns_by_unit[current_unit] << column
  end

  units.each_with_index do |unit, index|
    columns = columns_by_unit[index].compact
    next if columns.length <= 1

    clean_columns = columns.map do |column|
      result = column.reject { |key, _value| key == "_source" }
      result["label"] = result.fetch("label").sub(/\A#{Regexp.escape(unit.fetch('name'))}/, "")
      result["label"] = result.fetch("label").sub(/\A生成单位/, "") if unit.fetch("kind") == "child"
      result
    end
    keys = clean_columns.map { |column| column.fetch("key") }
    rows = full_table.fetch("rows").map { |row| row.select { |key, _value| keys.include?(key) } }
    unit["level_stats"] = { "columns" => clean_columns, "rows" => rows }
  end

  units.each { |unit| unit.delete("source_name") }
  units
end

def clean_history_text(raw)
  raw.to_s.gsub(/\[\[[^\]|]+\|([^\]]+)\]\]/, '\\1')
     .gsub(/\[\[([^\]]+)\]\]/, '\\1')
     .gsub(/\{\{[^}]+\}\}/, "")
     .gsub(/'''?/, "")
     .gsub(/\s+/, " ")
     .strip
     .sub(/\A[\u2018\u2019'\"]+/, "")
end

def translate_history_entry(entry, card, replacements)
  text = clean_history_text(entry.fetch("raw"))
  date_match = text.match(/(?:On|on)\s+(\d{1,2}\/\d{1,2}\/\d{4})/)
  return nil unless date_match

  card_names = [card.fetch("fandom_page"), "the #{card.fetch('fandom_page')}"]
  body = text.sub(/.*?\b(?:increased|decreased|reduced)\b/i) { |prefix| prefix[/\b(?:increased|decreased|reduced)\b/i] }
  verb = body[/\A(increased|decreased|reduced)\b/i, 1]&.downcase
  return nil unless verb

  statement = body.sub(/\A(?:increased|decreased|reduced)\s+/i, "")
  card_names.each { |name| statement = statement.gsub(/(?:the\s+)?#{Regexp.escape(name)}(?:'s|’s)?\s*/i, "") }
  statement = statement.sub(/\.$/, "")

  summary = nil
  if (match = statement.match(/\A(.+?)\s+by\s+([\d.]+%)/i))
    label = translate_stat_label(match[1], replacements)
    summary = "#{label}#{verb == 'increased' ? '提高' : '降低'} #{match[2]}。" unless label.match?(/[A-Za-z]/)
  elsif (match = statement.match(/\A(.+?)\s+to\s+(.+?)\s+\(from\s+(.+?)\)/i))
    label = translate_stat_label(match[1], replacements)
    before = translate_value(match[3])
    after = translate_value(match[2])
    summary = "#{label}由 #{before} 调整为 #{after}。" unless [label, before, after].any? { |value| value.match?(/[A-Za-z]/) }
  end
  return nil unless summary

  type = verb == "increased" ? "buff" : "nerf"
  { "date" => normalize_date(date_match[1]), "type" => type, "summary" => summary }
end

def download_image(url, destination)
  return if File.file?(destination)
  raise "卡牌图片地址缺失：#{destination}" if url.to_s.empty?

  FileUtils.mkdir_p(File.dirname(destination))
  Tempfile.create(["clash-card", ".png"]) do |source|
    source.binmode
    source.write(URI.open(url, "User-Agent" => USER_AGENT, read_timeout: 30).read)
    source.flush
    _output, error, status = Open3.capture3(
      "magick", source.path, "-resize", "150x180>", "-background", "none", "-gravity", "center",
      "-extent", "150x180", "-quality", "84", destination
    )
    raise "图片转换失败：#{error}" unless status.success?
  end
end

def existing_details
  Dir.glob(File.join(DETAILS_DIR, "*.yaml")).to_h do |path|
    [File.basename(path, ".yaml"), YAML.load_file(path)]
  end
end

def history_overrides
  Dir.glob(File.join(HISTORY_OVERRIDES_DIR, "*.yaml")).to_h do |path|
    [File.basename(path, ".yaml"), YAML.load_file(path).fetch("items")]
  end
end

def write_content_page(card)
  path = File.join(CARDS_CONTENT_DIR, "#{card.fetch('key')}.md")
  return if File.file?(path) && card.fetch("key") == "mini-pekka"

  if File.file?(path)
    source = File.read(path)
    front_matter_source = source[/\A---\s*\n(.*?)\n---\s*\n?/m, 1]
    existing = front_matter_source && YAML.safe_load(front_matter_source)
    return if existing && existing["generated_card_data"] == false
  end

  front_matter = {
    "title" => "#{card.fetch('name')}：卡牌数据、等级属性与平衡调整",
    "description" => "查询皇室战争#{card.fetch('name')}的圣水、解锁位置、战斗参数、等级属性与历次平衡性调整。",
    "date" => "2026-07-15T03:00:00+08:00",
    "updated" => "2026-07-15T03:00:00+08:00",
    "url" => card.fetch("detail_url"),
    "layout" => "clashroyale-card",
    "card_key" => card.fetch("key"),
    "noindex" => true,
    "generated_card_data" => true,
    "draft" => false
  }
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{YAML.dump(front_matter)}---\n")
end

options = { write: false, images: false }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby tools/build-clash-card-data.rb [options]"
  parser.on("--write", "生成全部卡牌主数据和详情数据") { options[:write] = true }
  parser.on("--images", "下载缺失卡牌图片并转换为 WebP") { options[:images] = true }
end.parse!

abort "请先运行 sync-clash-card-sources.rb --write-manifest" unless File.file?(MANIFEST_PATH)
manifest = YAML.load_file(MANIFEST_PATH)
cards = manifest.fetch("items")
sources = fetch_card_sources(cards)
replacements = label_replacements(cards)
old_cards = File.file?(CARDS_PATH) ? YAML.load_file(CARDS_PATH).fetch("items").to_h { |card| [card["key"], card] } : {}
old_details = existing_details
manual_history = history_overrides
generated_cards = []
skipped_history = 0

cards.each_with_index do |card, index|
  key = card.fetch("key")
  source = sources.fetch(key)
  previous = old_cards[key] || {}
  elixir = card["cost"].to_s.match?(/\A\d+\z/) ? card["cost"].to_i : nil
  elixir_label = case card["cost"].to_s
                 when "3/6" then "3 或 6"
                 when "?" then "随上一张卡变化"
                 end
  summary = previous["summary"] || card["official_description_zh"] || SUMMARY_OVERRIDES[key] || "#{card.fetch('name_zh')}是皇室战争中的#{TYPE_LABELS.fetch(card.fetch('type'))}卡牌。"
  generated_cards << {
    "key" => key,
    "name" => card.fetch("name_zh"),
    "name_en" => card.fetch("fandom_page"),
    "type" => card.fetch("type"),
    "rarity" => card.fetch("rarity"),
    "elixir" => elixir,
    "elixir_label" => elixir_label,
    "arena" => translate_arena(card["arena"]),
    "image" => "images/clashroyale/cards/#{key}.webp",
    "summary" => summary,
    "roles" => previous["roles"] || [],
    "detail_url" => "/clashroyale/cards/#{key}/",
    "source_url" => card.fetch("source_url")
  }

  generated_history = source.fetch("history").map { |entry| translate_history_entry(entry, card, replacements) }.compact
  skipped_history += source.fetch("history").length - generated_history.length
  previous_detail = old_details[key] || {}
  units = build_units(source, card, replacements)
  previous_units = Array(previous_detail["units"]).to_h { |unit| [unit["name"], unit] }
  units.each do |unit|
    previous_unit = previous_units[unit["name"]]
    next unless previous_unit

    %w[section_label summary].each do |field|
      unit[field] = previous_unit[field] if previous_unit.key?(field)
    end
    previous_levels = previous_unit["level_stats"]
    if unit["level_stats"] && previous_levels&.key?("derived_levels")
      unit["level_stats"]["derived_levels"] = previous_levels["derived_levels"]
    end
  end

  detail = {
    "release_date" => normalize_date(card.fetch("release_date")),
    "source_retrieved_at" => manifest.dig("meta", "retrieved_at"),
    "units" => units,
    "balance_history" => manual_history[key] || (key == "mini-pekka" && previous_detail["balance_history"] ? previous_detail["balance_history"] : generated_history.sort_by { |entry| entry.fetch("date") }.reverse)
  }
  detail["strategy"] = previous_detail["strategy"] if previous_detail["strategy"]

  if options[:write]
    FileUtils.mkdir_p(DETAILS_DIR)
    File.write(File.join(DETAILS_DIR, "#{key}.yaml"), YAML.dump(detail, line_width: -1))
  end
  download_image(source["image_url"], File.join(IMAGES_DIR, "#{key}.webp")) if options[:images]
  puts "[#{index + 1}/#{cards.length}] #{card.fetch('name_zh')}"
end

if options[:write]
  output = {
    "meta" => {
      "updated_at" => Date.today.iso8601,
      "status" => "active",
      "facts_source" => manifest.dig("meta", "source"),
      "retrieved_at" => manifest.dig("meta", "retrieved_at"),
      "image_source" => "Fandom card infobox",
      "image_policy" => "Supercell Fan Content Policy"
    },
    "items" => generated_cards
  }
  File.write(CARDS_PATH, YAML.dump(output, line_width: -1))
  generated_cards.each { |card| write_content_page(card) }
end

puts "完成：#{generated_cards.length} 张卡牌，未自动收录的历史记录 #{skipped_history} 条。"
