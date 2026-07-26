extends Node

signal language_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES: Array[String] = ["zh", "en"]

const TEXTS: Dictionary = {
	"zh": {
		"main_title": "追求永生",
		"start_game": "开始游戏",
		"quick_start": "快速入门",
		"weapon_gallery": "武器画廊",
		"leaderboard": "轮回排行",
		"quit_game": "退出游戏",
		"language": "语言",
		"chinese": "中文",
		"english": "English",
		"paused": "游戏暂停",
		"resume": "继续游戏",
		"how_to_play": "玩法说明",
		"main_menu": "返回首页",
		"pause": "暂停",
		"back": "返回",
		"restart": "重新开始",
		"lifespan_depleted": "寿元耗尽",
		"ascension_complete": "飞升成功",
		"fatal_breakthrough": "元婴九层 · 突破陨落",
		"fatal_world_unstable": "此世界尚不稳定。你被懵懂的世界意志（天道）强行压制，请等下次轮回、天道完整之后，再来对抗天道。",
		"ordinary_run_ended": "本次轮回已经结束。",
		"run_summary": "本次游玩总结",
		"survival_duration": "抵抗天道时长",
		"weapon_levels": "武器等级",
		"total_damage_dealt": "造成总伤害",
		"enemies_defeated": "击杀敌人",
		"elite": "精英",
		"weapon_damage_ranking": "武器伤害排名",
		"local_survival_leaderboard": "本地排行榜 · 抵抗天道时长",
		"leaderboard_columns": "名次  ·  轮回  ·  生存时间  ·  总伤害  ·  输出最高武器",
		"cycle_number_format": "第%d次轮回",
		"damage_value_format": "总伤害 %d",
		"no_damage_recorded": "本轮未造成伤害",
		"no_local_records": "暂无本地记录",
		"realm_echo": "境界化身",
		"other_damage": "其他伤害",
		"heaven_suppressed": "天道镇压",
		"locked_by_realm": "境界锁定",
		"current": "当前",
		"new_weapon": "新武器",
		"empty": "空",
		"not_obtained": "尚未获得",
		"character_details": "角色详情",
		"release_tab_to_close": "松开 Tab 关闭",
		"complete_weapon_data": "完整武器数据（1–6 / Q 选择）",
		"danger_lifespan": "⚠  寿元危急  ⚠",
		"lifespan_format": "寿元  %.1fs / %.1fs",
		"lifespan_drain_format": "寿元消耗  -%.2f / 秒",
		"realm_format": "境界 %d",
		"realm_layer_format": "%s %d/%d层",
		"realm_stage_format": "%s境",
		"qi_format": "灵气  %d / %d",
		"technique_format": "功法  %s",
		"equipped_format": "当前装备  %s  · 伤害 %d",
		"realm_练气": "练气",
		"realm_筑基": "筑基",
		"realm_金丹": "金丹",
		"realm_元婴": "元婴",
		"gallery_hint": "选择武器查看真实基础属性与战斗特性",
		"weapon_stats": "基础属性",
		"damage": "伤害",
		"range": "范围",
		"interval": "攻击间隔",
		"seconds": "秒",
		"domain": "类型",
		"affinity": "修炼倾向",
		"melee": "近战",
		"ranged": "远程",
		"neutral": "无",
		"jing": "精",
		"qi": "气",
		"shen": "神",
		"weapon_trait": "战斗特性",
		"weapon_growth": "重复获得",
		"unknown": "未知",
		"invalid_weapon": "无效武器",
		"realm_default": "境界",
		"countdown_seconds": "%d秒",
		"elite_weapon": "武器精英",
		"elite_upgrade": "强化精英",
		"immobilized": "定",
		"critical_hit_format": "暴击！  -%d",
		"body_break": "破体！",
		"heavenly_strike_format": "天雷落点  %d / %d",
		"annihilation_warning": "元婴九层 · 天道绝杀",
		"annihilation_impact": "天罚命中 · 天道镇杀",
		"qi_pickup": "灵气",
		"weapon_channeling_format": "%s%s  %d\n同步 %.1f / %.1f秒",
		"weapon_choice_dimmed_format": "%s  %d\n另一项选择中",
		"weapon_choice_idle_format": "%s  %d\n停留1秒",
		"weapon_pickup_idle_format": "%s  %d\n圈内同步1秒",
		"fragment_channeling_format": "%s%s强化碎片\n引导 %.1f / %.1f秒",
		"fragment_choice_dimmed_format": "%s强化碎片\n另一项选择中",
		"fragment_choice_idle_format": "%s强化碎片\n停留1秒",
		"fragment_pickup_idle_format": "%s强化碎片\n靠近并持续停留",
		"upgrade_attack_speed": "攻速",
		"upgrade_damage": "伤害",
		"upgrade_mobility": "身法",
		"upgrade_range": "范围",
		"upgrade_speed_control": "加减速",
		"upgrade_attack_speed_glyph": "速",
		"upgrade_damage_glyph": "伤",
		"upgrade_mobility_glyph": "身",
		"upgrade_range_glyph": "域",
		"upgrade_speed_control_glyph": "控",
		"qi_glyph": "气",
		"player_stats_empty": "角色属性\n暂无战斗数据",
		"player_stats_title": "角色属性",
		"stats_base_format": "基础  %s · 全局伤害 +%.1f / +%s · %s伤害 %d",
		"realm_level_format": "境界 Lv.%d",
		"stats_overview_format": "总览  暴击 %s / %s · 攻速 %s",
		"stats_projectile_format": "投射  弹速 ×%.2f · 当前武器 ×%d · 范围 %s · 索敌 %s",
		"stats_fragments_format": "碎片  攻速 %d · 伤害 %d · 身法 %d · 范围 %d · 加减速 %d",
		"stats_movement_format": "移动  横向 %.0f · 纵向加速度 %.0f · 减速目标 %.0f",
		"fragments_unbound": "通用碎片：尚未绑定",
		"fragments_details_format": "通用碎片\n攻速 Lv.%d：每级 +%.0f%%\n伤害 Lv.%d：常规武器 +%d / 乾坤圈弹射 +1\n身法 Lv.%d：横移 +%.0f / 纵向加速度 +%.0f\n范围 Lv.%d：每级全武器 +%.0f%%\n加减速 Lv.%d：加速 +%.0f / 减速目标 -%.0f（最低 %.0f）",
		"level_up_format": "%s\n寿元 +%.0f",
		"ability_ground_training": "地上修行",
		"ability_roll_summary": "Space 翻滚无敌 · CD 0.8s",
		"flight_ascending": "上升",
		"flight_holding": "驭空滑行",
		"flight_descending": "下降",
		"flight_active_format": "驭空%s",
		"flight_prompt": "Space 跃起驭空",
		"flight_permanent": "御空飞行",
		"shield_active_summary": "灵气护盾已开启 [Space]",
		"shield_prompt": "Space 开启灵气护盾",
		"projection_active_summary": "灵体出窍 ×2伤害 / ×1.5承伤 / 灵盾开启 [Space]",
		"projection_prompt": "Space 灵体出窍",
		"ability_unknown": "尚未领悟",
		"ability_unlock_hint": "突破境界后解锁主动能力",
		"status_unavailable": "不可用",
		"status_ready": "可用",
		"ability_roll": "翻滚无敌",
		"ability_roll_description": "向前翻滚并短暂无视伤害",
		"status_rolling": "翻滚中",
		"cooldown_format": "冷却 %.1fs",
		"ability_flight": "跃起驭空",
		"ability_flight_description": "短暂升空，避开地面威胁",
		"status_ascending": "正在上升",
		"status_holding": "驭空滑行",
		"status_descending": "正在落地",
		"ability_qi_shield": "灵气护盾",
		"ability_qi_shield_description": "开启时消耗灵气抵挡伤害，灵气耗尽后伤害穿透",
		"status_shield_active": "护盾已开启 · 再按关闭",
		"status_shield_inactive": "默认关闭 · 可开启",
		"ability_spirit_projection": "灵体出窍",
		"ability_spirit_projection_description": "开启灵盾并造成 200% 伤害，同时承受 150% 伤害",
		"status_projection_active": "灵体已出窍 · 再按收回",
		"shield_off_projection": "◇ 灵气护盾关闭  ·  灵体出窍时自动开启",
		"shield_off_prompt": "◇ 灵气护盾关闭  ·  按 Space 开启",
		"qi_shield_capacity_format": "灵气  %d / %d  ·  灵盾 %.0f",
		"shield_status_format": "◉ 灵气护盾  %.0f 点  ·  1 灵气抵挡 %.1f 伤害",
		"shield_depleted": "◇ 灵气护盾耗尽  ·  收集灵气即可恢复",
		"shield_absorbed_format": "护盾吸收 %.0f  ·  消耗 %d 灵气  ·  剩余 %.0f",
		"shield_penetrated_format": "  ·  穿透 %.1f",
		"projection_entered": "灵体出窍\n伤害 ×2 · 承伤 ×1.5 · 灵盾开启",
		"projection_returned": "灵体归窍",
		"damage_upgrade_format": "伤害强化 %d级\n常规武器伤害 +%d · 乾坤圈弹射 +%d",
		"generic_upgrade_format": "%s强化 %d级\n全局生效",
		"tribulation_success": "渡劫成功\n寿元上限提升",
		"tribulation_warning": "准备渡劫\n进阶雷劫已来临",
		"route_main": "继续当前主路",
		"route_left": "左侧无尽岔路",
		"route_right": "右侧无尽岔路",
		"route_trial": "试炼地狱",
		"route_trial_description": "试炼地狱\n高压战斗区域",
		"route_selected_format": "已选择：%s",
		"route_entering_format": "进入：%s",
		"realm_progress_format": "%s · 第%d层",
		"shield_capacity_short_format": "灵盾 %.0f",
		"shield_empty_short": "灵盾耗尽",
		"shield_blocked_format": "抵挡 %.0f  ·  -%d 灵气",
		"lifespan_damage_format": "-%.1f 寿元",
		"equipment_locked_suffix": "  [当前境界不可用]",
		"equipment_entry_format": "%s%s ×%d  伤害 %d%s",
		"debug_waiting": "等待游戏状态",
		"debug_status_format": "%s · 灵气 %d/%d · 寿元 %.1f\n当前 %s ×%d · 伤害 %d\n碎片 %s",
		"debug_title": "运行中调试面板",
		"debug_palm_geometry": "显示大力掌精确范围",
		"debug_add_qi": "+一管灵气",
		"debug_add_level": "+小境界",
		"debug_lifespan_add": "寿元 +20",
		"debug_lifespan_remove": "寿元 -20",
		"debug_weapon_count": "武器数量",
		"debug_add_weapon": "+武器",
		"debug_remove_weapon": "-武器",
		"debug_damage_add": "当前伤害 +1",
		"debug_damage_remove": "当前伤害 -1",
		"debug_fragment_levels": "通用碎片等级",
		"debug_add_fragment": "+碎片",
		"debug_remove_fragment": "-碎片",
		"debug_base_stats": "玩家基础数值",
		"debug_forward_speed": "前进速度 ",
		"debug_lateral_speed": "横向速度 ",
		"debug_acceleration": "纵向加速度 ",
		"debug_apply_stats": "应用基础数值",
		"instructions_body": """[font_size=28][color=#a6ffdb][b]核心目标[/b][/color][/font_size]
你会自动向前飞行，寿元也会持续流逝。避开敌人、收集灵气并提升境界，在寿元耗尽前尽可能变强。

[font_size=28][color=#a6ffdb][b]基本操作[/b][/color][/font_size]
[b]A / D 或 ← / →[/b]：左右移动
[b]W / ↑[/b]：加速前进
[b]S / ↓[/b]：减速
[b]Space[/b]：使用当前境界能力
[b]按住 Tab[/b]：查看角色、碎片与武器详情
[b]1–6 / Q[/b]：选择装备
[b]Esc[/b]：暂停游戏

[font_size=28][color=#a6ffdb][b]战斗机制[/b][/color][/font_size]
• 武器会自动寻找敌人并攻击；取得武器后，用数字键切换当前装备。
• 敌人碰撞或攻击会直接扣除寿元。保持移动，别让敌群包围你。
• 击败金色精英可获得武器与强化碎片。
• 掉落物会随你移动；进入同步圈并停留至进度完成即可吸收，提前离开会重置进度。

[font_size=28][color=#a6ffdb][b]修炼与成长[/b][/color][/font_size]
• 收集灵气填满进度条可提升小境界，每次升级都会恢复部分寿元。
• 重复获得同种武器会强化其独特机制；详细效果可在“武器画廊”查看。
• 强化碎片会为武器提供额外的通用成长。

[font_size=28][color=#ffdf8f][b]突破与天劫[/b][/color][/font_size]
跨越大境界时会触发天劫。留意地面的预警区域并及时躲避；撑过全部雷击后，寿元上限会提高。

[font_size=28][color=#ff9e8f][b]道路选择[/b][/color][/font_size]
道路分岔会改变后续路线。“试炼地狱”中的敌人更强、更多、攻击更频繁。状态不好时，选择普通道路更稳妥。""",
		"weapon_great_strength_palm": "大力掌",
		"weapon_dao": "旋转刀",
		"weapon_flying_sword": "飞剑",
		"weapon_qiankun_ring": "乾坤圈",
		"weapon_golden_bell": "金钟罩",
		"weapon_thunder_hammer": "雷神之锤",
		"weapon_fantian_seal": "翻天印",
		"trait_great_strength_palm": "自动锁定最近敌人并连续出掌。境界越高，连击次数、击退和特殊效果越强。",
		"growth_great_strength_palm": "不依赖重复拾取；每个小境界都会提高伤害、范围和攻击速度。",
		"trait_dao": "刀刃持续环绕角色，对接触到的敌人造成稳定的近身范围伤害。",
		"growth_dao": "每次重复获得增加一圈旋转刀；达到范围成长上限后，额外等级改为提高伤害。",
		"trait_flying_sword": "高速直线飞行，拥有 3 点能量；每命中一个不同敌人消耗 1 点并继续穿透。",
		"growth_flying_sword": "每次重复获得会让一轮攻击顺序多发射一把飞剑。",
		"trait_qiankun_ring": "命中后会在敌人之间弹射，基础额外弹射 2 次，随后返回角色。",
		"growth_qiankun_ring": "每次重复获得会让一轮攻击多发射一个乾坤圈；伤害碎片改为增加弹射次数。",
		"trait_golden_bell": "在角色身边形成可恢复护罩。接触敌人时造成伤害并击退，外层护罩会优先消耗。",
		"growth_golden_bell": "每次重复获得增加一层护罩；被消耗的层会短暂闪烁后自动恢复。",
		"trait_thunder_hammer": "向目标发射缓慢移动的雷云，持续对范围内敌人造成多次伤害。",
		"growth_thunder_hammer": "每次重复获得会让一轮攻击多生成一片雷云；达到数量上限后提高伤害。",
		"trait_fantian_seal": "锁定目标后从高处砸落，对固定方形区域造成伤害、短暂定身并触发震屏。",
		"growth_fantian_seal": "每次重复获得增加一枚印，最多 10 枚；之后每级提高 10% 伤害。",
	},
	"en": {
		"main_title": "Chasing Eternity",
		"start_game": "Start Game",
		"quick_start": "Quick Start",
		"weapon_gallery": "Weapon Gallery",
		"leaderboard": "Cycle Leaderboard",
		"quit_game": "Quit Game",
		"language": "Language",
		"chinese": "中文",
		"english": "English",
		"paused": "Paused",
		"resume": "Resume",
		"how_to_play": "How to Play",
		"main_menu": "Main Menu",
		"pause": "Pause",
		"back": "Back",
		"restart": "Restart",
		"lifespan_depleted": "Lifespan Depleted",
		"ascension_complete": "Ascension Complete",
		"fatal_breakthrough": "Nascent Soul IX · Perished During Breakthrough",
		"fatal_world_unstable": "This world is still nascent. The unformed will of Heaven—the Heavenly Dao—has suppressed you by force. Return in the next cycle, when the Heavenly Dao is complete, and defy it once more.",
		"ordinary_run_ended": "This cycle has ended.",
		"run_summary": "Run Summary",
		"survival_duration": "Time Defying the Heavenly Dao",
		"weapon_levels": "Weapon Levels",
		"total_damage_dealt": "Total Damage",
		"enemies_defeated": "Enemies Defeated",
		"elite": "Elite",
		"weapon_damage_ranking": "Weapon Damage Ranking",
		"local_survival_leaderboard": "Local Leaderboard · Time Defying the Heavenly Dao",
		"leaderboard_columns": "Rank  ·  Cycle  ·  Survival  ·  Total Damage  ·  Top Weapon",
		"cycle_number_format": "Cycle %d",
		"damage_value_format": "Damage %d",
		"no_damage_recorded": "No damage dealt this run",
		"no_local_records": "No local records yet",
		"realm_echo": "Realm Echo",
		"other_damage": "Other Damage",
		"heaven_suppressed": "Suppressed by the Heavenly Dao",
		"locked_by_realm": "Realm Locked",
		"current": "Equipped",
		"new_weapon": "New",
		"empty": "Empty",
		"not_obtained": "Not Obtained",
		"character_details": "Character Details",
		"release_tab_to_close": "Release Tab to close",
		"complete_weapon_data": "Full Weapon Data (1–6 / Q to select)",
		"danger_lifespan": "⚠  LIFESPAN CRITICAL  ⚠",
		"lifespan_format": "Lifespan  %.1fs / %.1fs",
		"lifespan_drain_format": "Drain  -%.2f / sec",
		"realm_format": "Realm %d",
		"realm_layer_format": "%s · Layer %d/%d",
		"realm_stage_format": "%s Realm",
		"qi_format": "Spiritual Qi  %d / %d",
		"technique_format": "Cultivation Art  %s",
		"equipped_format": "Equipped  %s  · Damage %d",
		"realm_练气": "Qi Refining",
		"realm_筑基": "Foundation Establishment",
		"realm_金丹": "Golden Core",
		"realm_元婴": "Nascent Soul",
		"gallery_hint": "Select a weapon to view its real base stats and combat traits",
		"weapon_stats": "Base Stats",
		"damage": "Damage",
		"range": "Range",
		"interval": "Attack Interval",
		"seconds": "sec",
		"domain": "Type",
		"affinity": "Cultivation Affinity",
		"melee": "Melee",
		"ranged": "Ranged",
		"neutral": "None",
		"jing": "Essence",
		"qi": "Qi",
		"shen": "Spirit",
		"weapon_trait": "Combat Trait",
		"weapon_growth": "Duplicate Upgrade",
		"unknown": "Unknown",
		"invalid_weapon": "Invalid Weapon",
		"realm_default": "Realm",
		"countdown_seconds": "%ds",
		"elite_weapon": "Weapon Elite",
		"elite_upgrade": "Enhancement Elite",
		"immobilized": "ROOT",
		"critical_hit_format": "CRITICAL!  -%d",
		"body_break": "BODY BREAK!",
		"heavenly_strike_format": "Heavenly Strike  %d / %d",
		"annihilation_warning": "Nascent Soul IX · Heavenly Dao's Final Judgment",
		"annihilation_impact": "Heavenly Punishment · Annihilated by the Dao",
		"qi_pickup": "Spiritual Qi",
		"weapon_channeling_format": "%s%s  %d\nSynchronizing %.1f / %.1fs",
		"weapon_choice_dimmed_format": "%s  %d\nOther choice in progress",
		"weapon_choice_idle_format": "%s  %d\nRemain for 1 second",
		"weapon_pickup_idle_format": "%s  %d\nSynchronize inside for 1 second",
		"fragment_channeling_format": "%s%s Fragment\nChanneling %.1f / %.1fs",
		"fragment_choice_dimmed_format": "%s Fragment\nOther choice in progress",
		"fragment_choice_idle_format": "%s Fragment\nRemain for 1 second",
		"fragment_pickup_idle_format": "%s Fragment\nApproach and remain inside",
		"upgrade_attack_speed": "Attack Speed",
		"upgrade_damage": "Damage",
		"upgrade_mobility": "Mobility",
		"upgrade_range": "Area",
		"upgrade_speed_control": "Speed Control",
		"upgrade_attack_speed_glyph": "SPD",
		"upgrade_damage_glyph": "DMG",
		"upgrade_mobility_glyph": "MOV",
		"upgrade_range_glyph": "AOE",
		"upgrade_speed_control_glyph": "CTRL",
		"qi_glyph": "Qi",
		"player_stats_empty": "Character Stats\nNo combat data available",
		"player_stats_title": "Character Stats",
		"stats_base_format": "Core  %s · Global Damage +%.1f / +%s · %s Damage %d",
		"realm_level_format": "Realm Lv.%d",
		"stats_overview_format": "Overview  Crit %s / %s · Attack Speed %s",
		"stats_projectile_format": "Projectiles  Speed ×%.2f · Current Weapon ×%d · Area %s · Targeting %s",
		"stats_fragments_format": "Fragments  Attack Speed %d · Damage %d · Mobility %d · Area %d · Speed Control %d",
		"stats_movement_format": "Movement  Lateral %.0f · Forward Acceleration %.0f · Slow Target %.0f",
		"fragments_unbound": "Universal Fragments: No player bound",
		"fragments_details_format": "Universal Fragments\nAttack Speed Lv.%d: +%.0f%% per level\nDamage Lv.%d: Standard weapons +%d / Qiankun Ring +1 bounce\nMobility Lv.%d: Lateral Speed +%.0f / Forward Acceleration +%.0f\nArea Lv.%d: All weapons +%.0f%% per level\nSpeed Control Lv.%d: Boost +%.0f / Slow Target -%.0f (minimum %.0f)",
		"level_up_format": "%s\nLifespan +%.0f",
		"ability_ground_training": "Grounded Cultivation",
		"ability_roll_summary": "Space: Invincible Roll · CD 0.8s",
		"flight_ascending": "Ascending",
		"flight_holding": "Gliding",
		"flight_descending": "Descending",
		"flight_active_format": "Aerial Step: %s",
		"flight_prompt": "Space: Skyward Leap",
		"flight_permanent": "Skywalking",
		"shield_active_summary": "Spiritual Qi Shield active [Space]",
		"shield_prompt": "Space: Activate Spiritual Qi Shield",
		"projection_active_summary": "Spirit Projection · ×2 damage / ×1.5 damage taken / shield active [Space]",
		"projection_prompt": "Space: Spirit Projection",
		"ability_unknown": "Not Yet Comprehended",
		"ability_unlock_hint": "Break through to a higher realm to comprehend an active ability",
		"status_unavailable": "Unavailable",
		"status_ready": "Ready",
		"ability_roll": "Invincible Roll",
		"ability_roll_description": "Roll forward and briefly become immune to damage",
		"status_rolling": "Rolling",
		"cooldown_format": "Cooldown %.1fs",
		"ability_flight": "Skyward Leap",
		"ability_flight_description": "Rise briefly above the ground to evade terrestrial threats",
		"status_ascending": "Ascending",
		"status_holding": "Gliding",
		"status_descending": "Descending",
		"ability_qi_shield": "Spiritual Qi Shield",
		"ability_qi_shield_description": "Consume Spiritual Qi to absorb damage; attacks penetrate when Qi is depleted",
		"status_shield_active": "Shield active · Press again to dismiss",
		"status_shield_inactive": "Inactive · Ready to activate",
		"ability_spirit_projection": "Spirit Projection",
		"ability_spirit_projection_description": "Manifest your spirit for 200% damage while taking 150% damage",
		"status_projection_active": "Spirit projected · Press again to return",
		"shield_off_projection": "◇ Spiritual Qi Shield inactive · Activates with Spirit Projection",
		"shield_off_prompt": "◇ Spiritual Qi Shield inactive · Press Space to activate",
		"qi_shield_capacity_format": "Spiritual Qi  %d / %d  ·  Shield %.0f",
		"shield_status_format": "◉ Spiritual Qi Shield  %.0f capacity  ·  1 Qi absorbs %.1f damage",
		"shield_depleted": "◇ Spiritual Qi Shield depleted · Gather Qi to restore it",
		"shield_absorbed_format": "Shielded %.0f  ·  Spent %d Qi  ·  %.0f remaining",
		"shield_penetrated_format": "  ·  %.1f penetrated",
		"projection_entered": "Spirit Projection\nDamage ×2 · Damage Taken ×1.5 · Shield Active",
		"projection_returned": "Spirit Returned",
		"damage_upgrade_format": "Damage Enhancement Lv.%d\nStandard Weapons +%d Damage · Qiankun Ring +%d Bounces",
		"generic_upgrade_format": "%s Enhancement Lv.%d\nApplies Globally",
		"tribulation_success": "Tribulation Survived\nMaximum Lifespan Increased",
		"tribulation_warning": "Prepare for Tribulation\nA Realm-Advancement Lightning Tribulation Approaches",
		"route_main": "Continue on the Main Path",
		"route_left": "Endless Left Path",
		"route_right": "Endless Right Path",
		"route_trial": "Infernal Trial",
		"route_trial_description": "Infernal Trial\nHigh-Pressure Combat Zone",
		"route_selected_format": "Selected: %s",
		"route_entering_format": "Entering: %s",
		"realm_progress_format": "%s · Layer %d",
		"shield_capacity_short_format": "Shield %.0f",
		"shield_empty_short": "Shield Depleted",
		"shield_blocked_format": "Blocked %.0f  ·  -%d Qi",
		"lifespan_damage_format": "-%.1f Lifespan",
		"equipment_locked_suffix": "  [Locked in Current Realm]",
		"equipment_entry_format": "%s%s ×%d  Damage %d%s",
		"debug_waiting": "Waiting for game state",
		"debug_status_format": "%s · Spiritual Qi %d/%d · Lifespan %.1f\nCurrent %s ×%d · Damage %d\nFragments %s",
		"debug_title": "Runtime Debug Panel",
		"debug_palm_geometry": "Show Exact Mighty Palm Area",
		"debug_add_qi": "+1 Qi Bar",
		"debug_add_level": "+1 Minor Layer",
		"debug_lifespan_add": "Lifespan +20",
		"debug_lifespan_remove": "Lifespan -20",
		"debug_weapon_count": "Weapon Quantity",
		"debug_add_weapon": "+Weapon",
		"debug_remove_weapon": "-Weapon",
		"debug_damage_add": "Current Damage +1",
		"debug_damage_remove": "Current Damage -1",
		"debug_fragment_levels": "Universal Fragment Levels",
		"debug_add_fragment": "+Fragment",
		"debug_remove_fragment": "-Fragment",
		"debug_base_stats": "Player Base Stats",
		"debug_forward_speed": "Forward Speed ",
		"debug_lateral_speed": "Lateral Speed ",
		"debug_acceleration": "Forward Acceleration ",
		"debug_apply_stats": "Apply Base Stats",
		"instructions_body": """[font_size=28][color=#a6ffdb][b]Core Objective[/b][/color][/font_size]
You fly forward automatically while your lifespan steadily ticks down. Evade enemies, gather qi, and advance your cultivation before your lifespan runs out.

[font_size=28][color=#a6ffdb][b]Controls[/b][/color][/font_size]
[b]A / D or ← / →[/b]: Move left and right
[b]W / ↑[/b]: Accelerate
[b]S / ↓[/b]: Slow down
[b]Space[/b]: Use your current realm ability
[b]Hold Tab[/b]: View character, fragment, and weapon details
[b]1–6 / Q[/b]: Select equipment
[b]Esc[/b]: Pause the game

[font_size=28][color=#a6ffdb][b]Combat[/b][/color][/font_size]
• Weapons automatically seek and attack enemies. Use the number keys to switch equipment after collecting it.
• Enemy contact and attacks drain lifespan directly. Keep moving and avoid being surrounded.
• Defeat golden elite enemies to earn weapons and enhancement fragments.
• Drops travel with you. Stay inside a synchronization circle until it completes; leaving early resets its progress.

[font_size=28][color=#a6ffdb][b]Cultivation & Growth[/b][/color][/font_size]
• Fill the Spiritual Qi bar to advance one minor layer. Every advancement restores part of your lifespan.
• Duplicate weapons strengthen their unique mechanics. See the Weapon Gallery for exact effects.
• Upgrade fragments provide additional universal weapon growth.

[font_size=28][color=#ffdf8f][b]Breakthroughs & Tribulations[/b][/color][/font_size]
Breaking through into a major realm triggers a Heavenly Tribulation. Watch for marked danger zones and evade every strike; surviving raises your maximum lifespan.

[font_size=28][color=#ff9e8f][b]Choosing a Path[/b][/color][/font_size]
Road forks change the route ahead. The Infernal Trial contains stronger, denser enemies that attack more often. Remain on the ordinary path when your cultivation is struggling.""",
		"weapon_great_strength_palm": "Mighty Palm",
		"weapon_dao": "Orbiting Blades",
		"weapon_flying_sword": "Flying Sword",
		"weapon_qiankun_ring": "Qiankun Ring",
		"weapon_golden_bell": "Golden Bell Shield",
		"weapon_thunder_hammer": "Thunder God's Hammer",
		"weapon_fantian_seal": "Heaven-Overturning Seal",
		"trait_great_strength_palm": "Automatically targets the nearest enemy and delivers a rapid combo. Higher realms improve its hit count, knockback, and special effects.",
		"growth_great_strength_palm": "Does not require duplicate pickups. Every minor cultivation level improves its damage, range, and attack speed.",
		"trait_dao": "Blades continuously orbit the player, dealing reliable close-range area damage to enemies they touch.",
		"growth_dao": "Each duplicate adds another orbiting ring. Levels beyond the range-growth cap increase damage instead.",
		"trait_flying_sword": "A fast linear projectile with 3 energy. Hitting a new enemy consumes 1 energy and allows it to keep piercing.",
		"growth_flying_sword": "Each duplicate adds one more sequential sword to every attack volley.",
		"trait_qiankun_ring": "Bounces between enemies after impact, with 2 base bonus bounces, then returns to the player.",
		"growth_qiankun_ring": "Each duplicate adds another ring to the volley. Damage fragments grant extra bounces instead of damage.",
		"trait_golden_bell": "Forms renewable shields around the player. Contact damages and knocks enemies back; the outermost layer is consumed first.",
		"growth_golden_bell": "Each duplicate adds one shield layer. Spent layers briefly flicker, then regenerate automatically.",
		"trait_thunder_hammer": "Launches a slow-moving thundercloud that repeatedly damages enemies inside its area.",
		"growth_thunder_hammer": "Each duplicate adds another cloud to the volley. Levels beyond the cloud cap increase damage.",
		"trait_fantian_seal": "Locks onto a target and crashes down from above, damaging a fixed square area, briefly rooting survivors, and shaking the screen.",
		"growth_fantian_seal": "Each duplicate adds one seal, up to 10. Every level beyond that grants 10% more damage.",
	},
}

var current_locale: String = "zh"


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var saved_locale := str(
			settings.get_value("accessibility", "language", current_locale)
		)
		if saved_locale in SUPPORTED_LOCALES:
			current_locale = saved_locale
	TranslationServer.set_locale(current_locale)


func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES or locale == current_locale:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	var settings := ConfigFile.new()
	settings.set_value("accessibility", "language", current_locale)
	var error := settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save language preference: %s" % error_string(error))
	language_changed.emit(current_locale)


func text(key: String, fallback: String = "") -> String:
	var locale_table := TEXTS.get(current_locale, {}) as Dictionary
	return str(locale_table.get(key, fallback if not fallback.is_empty() else key))


func get_locale_index() -> int:
	return SUPPORTED_LOCALES.find(current_locale)


func get_weapon_name(weapon_id: StringName, fallback: String) -> String:
	if weapon_id == &"realm_echo":
		return text("realm_echo")
	if weapon_id == &"other":
		return text("other_damage")
	return text("weapon_%s" % String(weapon_id), fallback)


func get_realm_name(fallback: String) -> String:
	return text("realm_%s" % fallback, fallback)


func get_universal_upgrade_name(upgrade_type: int) -> String:
	match upgrade_type:
		UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED:
			return text("upgrade_attack_speed")
		UniversalUpgradeTypes.UpgradeType.DAMAGE:
			return text("upgrade_damage")
		UniversalUpgradeTypes.UpgradeType.MOVEMENT:
			return text("upgrade_mobility")
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE:
			return text("upgrade_range")
		UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL:
			return text("upgrade_speed_control")
	return text("unknown")


func get_universal_upgrade_glyph(upgrade_type: int) -> String:
	match upgrade_type:
		UniversalUpgradeTypes.UpgradeType.ATTACK_SPEED:
			return text("upgrade_attack_speed_glyph")
		UniversalUpgradeTypes.UpgradeType.DAMAGE:
			return text("upgrade_damage_glyph")
		UniversalUpgradeTypes.UpgradeType.MOVEMENT:
			return text("upgrade_mobility_glyph")
		UniversalUpgradeTypes.UpgradeType.DAMAGE_RANGE:
			return text("upgrade_range_glyph")
		UniversalUpgradeTypes.UpgradeType.SPEED_CONTROL:
			return text("upgrade_speed_control_glyph")
	return "?"


func get_route_name(route_name: String) -> String:
	match route_name:
		"继续当前主路":
			return text("route_main")
		"左侧无尽岔路":
			return text("route_left")
		"右侧无尽岔路":
			return text("route_right")
		"试炼地狱":
			return text("route_trial")
	return route_name


func format_realm_display(realm_name: String, layer: int) -> String:
	return text("realm_progress_format") % [
		get_realm_name(realm_name),
		maxi(layer, 1),
	]
