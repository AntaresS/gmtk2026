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
		"quick_start_kicker": "行动简报",
		"weapon_gallery_kicker": "兵装资料库",
		"leaderboard_kicker": "轮回档案",
		"quick_start_hint": "掌握移动、战斗与修炼循环，做好对抗天道的准备。",
		"quick_objective_title": "核心目标",
		"quick_objective_body": "角色会自动向前飞行，寿元也会持续流失。\n躲避敌人、收集灵气，并在寿元归零前提升境界。",
		"quick_controls_title": "移动与操作",
		"quick_controls_body": "[color=#a5b4fc][b]A / D · ← / →[/b][/color]  横向移动\n[color=#a5b4fc][b]W / S · ↑ / ↓[/b][/color]  加速或减速\n[color=#a5b4fc][b]Space[/b][/color]  境界能力\n[color=#a5b4fc][b]Tab[/b][/color]  战斗详情\n[color=#a5b4fc][b]1–6 / Q[/b][/color]  切换装备",
		"quick_combat_title": "战斗与战利品",
		"quick_combat_body": "武器会自动索敌攻击。保持移动，避免被敌人包围。\n击败金色精英可获得武器与强化碎片；留在同步区域内即可吸收掉落。",
		"quick_growth_title": "境界升级",
		"quick_growth_body": "收集灵气填满进度条即可提升一层，所需灵气会逐层增加。每次升级恢复 [color=#86d7c4][b]10 秒寿元[/b][/color]，寿元上限 [color=#86d7c4][b]+2 秒[/b][/color]。\n每个境界共 9 层。练气、筑基、金丹九层后再次填满灵气会引发天劫；躲过全部雷击即可进入下一境界，寿元上限再 [color=#86d7c4][b]+60 秒[/b][/color]。",
		"quick_tribulation_title": "境界独有能力",
		"quick_tribulation_body": "[color=#a5b4fc][b]练气[/b][/color]  Space 翻滚 0.6 秒，期间无敌；冷却 0.8 秒。\n[color=#a5b4fc][b]筑基[/b][/color]  Space 跃起驭空，升空时可避开地面威胁。\n[color=#a5b4fc][b]金丹[/b][/color]  永久飞行；Space 开关灵气护盾，1 灵气抵挡 1 寿元伤害。\n[color=#a5b4fc][b]元婴[/b][/color]  Space 灵体出窍并自动开盾；造成 200% 伤害，承受 150% 伤害。",
		"quick_routes_title": "路线选择",
		"quick_routes_body": "岔路会改变后续路线。试炼地狱拥有更密集、更强的敌人；状态不佳时应选择普通路线。",
		"gallery_archive_label": "战斗资料库",
		"leaderboard_hint": "本地保存的最佳轮回记录，按生存时间排序。",
		"leaderboard_record_count": "%d 条轮回记录",
		"leaderboard_rank": "排名",
		"leaderboard_cycle": "轮回",
		"leaderboard_survival": "生存时间",
		"leaderboard_damage": "总伤害",
		"leaderboard_top_weapon": "最高输出兵装",
		"settings": "设置",
		"audio_settings_hint": "分别调整音乐与游戏音效。",
		"background_music": "背景音乐",
		"sound_effects": "游戏音效",
		"mute": "静音",
		"muted": "已静音",
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
		"death_epitaph": "寿尽于 %s，止步于 %s",
		"fatal_death_epitaph": "寿元 %s，境至 %s，终陨于雷劫",
		"epitaph_realm_format": "%s%d层",
		"skip_run_reveal": "点击跳过",
		"run_summary": "本次游玩总结",
		"result_duration": "生存时间",
		"result_damage": "总伤害",
		"result_enemies": "击败敌人",
		"result_loadout": "最终武器等级",
		"result_damage_breakdown": "武器输出",
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
		"detail_shortcut_hint": "按住 Tab 查看具体信息",
		"detail_current_damage": "当前伤害",
		"detail_movement_speed": "移动速度",
		"detail_attack_range": "攻击范围",
		"detail_upgrade_levels": "强化等级",
		"start_survival_prompt": "快跑，挺住攻击活下去！",
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
		"gallery_hint": "选择武器、境界能力或能力碎片，查看完整战斗数据与成长效果。",
		"realm_skills_gallery_label": "境界能力",
		"realm_unique_skill": "独有能力",
		"realm_skill_mechanics": "使用方式与效果",
		"realm_breakthrough_stage": "境界突破",
		"realm_stage_qi_refining": "初始境界 · 总等级 1–9",
		"realm_stage_foundation": "第一次突破 · 总等级 10–18",
		"realm_stage_golden_core": "第二次突破 · 总等级 19–27",
		"realm_stage_nascent_soul": "第三次突破 · 总等级 28–36",
		"realm_skill_mechanics_qi_refining": "按 Space 向前翻滚 0.6 秒；期间免疫伤害且武器暂停攻击。翻滚结束后需等待 0.8 秒才能再次使用。",
		"realm_skill_mechanics_foundation": "按 Space 完成一次升空、滑行与落地循环；升空期间可避开地面威胁。落地后可立即再次使用。",
		"realm_skill_mechanics_golden_core": "按 Space 开启或关闭。开启后受到伤害会先消耗灵气：1 点灵气抵挡 1 点寿元伤害；灵气不足时剩余伤害穿透。默认关闭，无冷却。",
		"realm_skill_mechanics_nascent_soul": "按 Space 开启或收回灵体。开启时自动开启灵气护盾，造成 200% 伤害，但承受 150% 伤害；灵气耗尽后伤害穿透。",
		"realm_breakthrough_qi_refining": "初始境界。角色在地面修行，并从第一层开始掌握翻滚无敌。",
		"realm_breakthrough_foundation": "渡过练气九层后的第一次天劫进入。突破时会自动跃起，此后可主动驭空；练气敌人无法再伤害你。",
		"realm_breakthrough_golden_core": "渡过筑基九层后的第二次天劫进入。临时驭空升级为永久飞行，并解锁灵气护盾；练气和筑基敌人无法再伤害你。",
		"realm_breakthrough_nascent_soul": "渡过金丹九层后的第三次天劫进入。保留永久飞行与护盾，并以灵体出窍取代独立护盾切换；低于元婴的敌人无法伤害你。元婴九层后的突破为致命天劫。",
		"fragment_gallery_label": "能力碎片",
		"fragment_meta": "本轮全局能力强化",
		"fragment_effect_profile": "能力效果",
		"fragment_acquisition": "获取方式",
		"fragment_acquisition_body": "击败强化精英后会出现两枚能力碎片供你选择。进入其中一枚的同步区域并持续停留即可吸收；效果可在本次轮回中叠加。",
		"fragment_effect_attack_speed": "缩短所有武器的攻击间隔，让自动攻击循环更快。",
		"fragment_effect_damage": "为常规武器增加固定伤害；乾坤圈则改为增加一次额外弹射。",
		"fragment_effect_mobility": "提高横向移动速度与纵向加速度，让走位和变速更加灵活。",
		"fragment_effect_range": "按比例扩大所有适用武器的攻击范围与伤害区域。",
		"fragment_effect_speed_control": "提高加速状态的目标速度，并降低减速状态的目标速度，使节奏控制更强。",
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
		"instructions_body": """[font_size=14][color=#5f8798]01  //  核心循环[/color][/font_size]
[font_size=27][color=#7edce3][b]核心目标[/b][/color][/font_size]
你会自动向前飞行，寿元也会持续流逝。避开敌人、收集灵气并提升境界，在寿元耗尽前尽可能变强。

[font_size=14][color=#5f8798]02  //  输入配置[/color][/font_size]
[font_size=27][color=#7edce3][b]基本操作[/b][/color][/font_size]
[color=#f0d68e][b]A / D 或 ← / →[/b][/color]    左右移动
[color=#f0d68e][b]W / ↑[/b][/color]    加速前进
[color=#f0d68e][b]S / ↓[/b][/color]    减速
[color=#f0d68e][b]Space[/b][/color]    使用当前境界能力
[color=#f0d68e][b]按住 Tab[/b][/color]    查看核心战斗数据与碎片等级
[color=#f0d68e][b]1–6 / Q[/b][/color]    选择装备
[color=#f0d68e][b]Esc[/b][/color]    暂停游戏

[font_size=14][color=#5f8798]03  //  交战协议[/color][/font_size]
[font_size=27][color=#7edce3][b]战斗机制[/b][/color][/font_size]
• 武器会自动寻找敌人并攻击；取得武器后，用数字键切换当前装备。
• 敌人碰撞或攻击会直接扣除寿元。保持移动，别让敌群包围你。
• 击败金色精英可获得武器与强化碎片。
• 掉落物会随你移动；进入同步圈并停留至进度完成即可吸收，提前离开会重置进度。

[font_size=14][color=#5f8798]04  //  成长系统[/color][/font_size]
[font_size=27][color=#7edce3][b]修炼与成长[/b][/color][/font_size]
• 收集灵气填满进度条可提升小境界，每次升级都会恢复部分寿元。
• 重复获得同种武器会强化其独特机制；详细效果可在“武器画廊”查看。
• 强化碎片会为武器提供额外的通用成长。

[font_size=14][color=#8f805b]05  //  高风险事件[/color][/font_size]
[font_size=27][color=#f0d68e][b]突破与天劫[/b][/color][/font_size]
跨越大境界时会触发天劫。留意地面的预警区域并及时躲避；撑过全部雷击后，寿元上限会提高。

[font_size=14][color=#9b665f]06  //  路线决策[/color][/font_size]
[font_size=27][color=#e99c8d][b]道路选择[/b][/color][/font_size]
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
		"quick_start_kicker": "FIELD BRIEFING",
		"weapon_gallery_kicker": "ARSENAL DATABASE",
		"leaderboard_kicker": "CYCLE ARCHIVE",
		"quick_start_hint": "Master movement, combat, and cultivation before defying the Heavenly Dao.",
		"quick_objective_title": "Core Objective",
		"quick_objective_body": "You fly forward automatically while your lifespan steadily drains.\nEvade enemies, gather Spiritual Qi, and cultivate before time runs out.",
		"quick_controls_title": "Movement & Input",
		"quick_controls_body": "[color=#a5b4fc][b]A / D · ← / →[/b][/color]  Move sideways\n[color=#a5b4fc][b]W / S · ↑ / ↓[/b][/color]  Accelerate or slow down\n[color=#a5b4fc][b]Space[/b][/color]  Realm ability\n[color=#a5b4fc][b]Tab[/b][/color]  Combat details\n[color=#a5b4fc][b]1–6 / Q[/b][/color]  Switch equipment",
		"quick_combat_title": "Combat & Drops",
		"quick_combat_body": "Weapons seek targets automatically. Keep moving and avoid being surrounded.\nDefeat golden elites for weapons and fragments; remain inside a sync zone to absorb a drop.",
		"quick_growth_title": "Realm Advancement",
		"quick_growth_body": "Fill the Spiritual Qi bar to gain one layer; each new layer costs more Qi. Every upgrade restores [color=#86d7c4][b]10s lifespan[/b][/color] and raises its cap by [color=#86d7c4][b]2s[/b][/color].\nEach realm has 9 layers. Filling the bar after Qi Refining IX, Foundation IX, or Golden Core IX starts a tribulation. Evade every strike to enter the next realm and gain another [color=#86d7c4][b]60s[/b][/color] of maximum lifespan.",
		"quick_tribulation_title": "Unique Realm Abilities",
		"quick_tribulation_body": "[color=#a5b4fc][b]Qi Refining[/b][/color]  Space: roll for 0.6s with invulnerability; 0.8s cooldown.\n[color=#a5b4fc][b]Foundation[/b][/color]  Space: leap and glide above ground threats.\n[color=#a5b4fc][b]Golden Core[/b][/color]  Permanent flight; Space toggles a shield where 1 Qi blocks 1 lifespan damage.\n[color=#a5b4fc][b]Nascent Soul[/b][/color]  Space projects your spirit and enables the shield; deal 200% and take 150% damage.",
		"quick_routes_title": "Route Choice",
		"quick_routes_body": "Road forks change the route ahead. Infernal Trials contain denser, stronger enemies; take a normal path when resources are low.",
		"gallery_archive_label": "COMBAT CATALOG",
		"leaderboard_hint": "Your best runs saved locally, ranked by survival time.",
		"leaderboard_record_count": "%d CYCLE RECORDS",
		"leaderboard_rank": "RANK",
		"leaderboard_cycle": "CYCLE",
		"leaderboard_survival": "SURVIVAL",
		"leaderboard_damage": "TOTAL DAMAGE",
		"leaderboard_top_weapon": "TOP ARMAMENT",
		"settings": "Settings",
		"audio_settings_hint": "Tune music and gameplay sound independently.",
		"background_music": "Background Music",
		"sound_effects": "Sound Effects",
		"mute": "Mute",
		"muted": "Muted",
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
		"death_epitaph": "Lifespan %s · Reached %s",
		"fatal_death_epitaph": "Lifespan %s · Reached %s · Felled by tribulation",
		"epitaph_realm_format": "%s Layer %d",
		"skip_run_reveal": "Click to skip",
		"run_summary": "Run Summary",
		"result_duration": "Survival",
		"result_damage": "Total Damage",
		"result_enemies": "Enemies Defeated",
		"result_loadout": "Final Loadout",
		"result_damage_breakdown": "Damage by Weapon",
		"survival_duration": "Time Spent Defying the Heavenly Dao",
		"weapon_levels": "Weapon Levels",
		"total_damage_dealt": "Total Damage",
		"enemies_defeated": "Enemies Defeated",
		"elite": "Elite",
		"weapon_damage_ranking": "Weapon Damage Ranking",
		"local_survival_leaderboard": "Local Leaderboard · Survival Time",
		"leaderboard_columns": "Rank  ·  Cycle  ·  Survival  ·  Total Damage  ·  Top Weapon",
		"cycle_number_format": "Cycle %d",
		"damage_value_format": "Total Damage %d",
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
		"detail_shortcut_hint": "Hold Tab to view details",
		"detail_current_damage": "Current Damage",
		"detail_movement_speed": "Movement Speed",
		"detail_attack_range": "Attack Range",
		"detail_upgrade_levels": "Upgrade Levels",
		"start_survival_prompt": "Run! Endure the onslaught and stay alive!",
		"complete_weapon_data": "Full Weapon Data (1–6 / Q to select)",
		"danger_lifespan": "⚠  LIFESPAN CRITICAL  ⚠",
		"lifespan_format": "Lifespan  %.1fs / %.1fs",
		"lifespan_drain_format": "Drain  -%.2f / sec",
		"realm_format": "Realm %d",
		"realm_layer_format": "%s · Layer %d/%d",
		"realm_stage_format": "%s",
		"qi_format": "Spiritual Qi  %d / %d",
		"technique_format": "Cultivation Art  %s",
		"equipped_format": "Equipped  %s  · Damage %d",
		"realm_练气": "Qi Refining",
		"realm_筑基": "Foundation Establishment",
		"realm_金丹": "Golden Core",
		"realm_元婴": "Nascent Soul",
		"gallery_hint": "Select a weapon, realm skill, or upgrade fragment to inspect its full combat profile.",
		"realm_skills_gallery_label": "Realm Skills",
		"realm_unique_skill": "Unique Skill",
		"realm_skill_mechanics": "How It Works",
		"realm_breakthrough_stage": "Breakthrough Stage",
		"realm_stage_qi_refining": "Starting Realm · Overall Levels 1–9",
		"realm_stage_foundation": "First Breakthrough · Overall Levels 10–18",
		"realm_stage_golden_core": "Second Breakthrough · Overall Levels 19–27",
		"realm_stage_nascent_soul": "Third Breakthrough · Overall Levels 28–36",
		"realm_skill_mechanics_qi_refining": "Press Space to roll forward for 0.6 seconds. You are immune to damage and your weapons pause during the roll. Afterward, wait 0.8 seconds before rolling again.",
		"realm_skill_mechanics_foundation": "Press Space to rise, glide, and descend in one cycle. While airborne, you can evade ground threats. The skill is ready again as soon as you land.",
		"realm_skill_mechanics_golden_core": "Press Space to toggle the shield. While active, incoming damage spends 1 Spiritual Qi to absorb 1 lifespan damage; any damage beyond your remaining Qi penetrates. The shield starts off and has no cooldown.",
		"realm_skill_mechanics_nascent_soul": "Press Space to project or recall your spirit. Projection automatically activates the Qi shield, doubles outgoing damage, and increases damage taken to 150%; damage penetrates when Qi is depleted.",
		"realm_breakthrough_qi_refining": "Your starting realm. You cultivate on the ground and know Invincible Roll from the first layer.",
		"realm_breakthrough_foundation": "Enter by surviving the first tribulation after Qi Refining IX. You leap automatically on breakthrough and can then use temporary flight; Qi Refining enemies can no longer harm you.",
		"realm_breakthrough_golden_core": "Enter by surviving the second tribulation after Foundation IX. Temporary flight becomes permanent and Spiritual Qi Shield unlocks; Qi Refining and Foundation enemies can no longer harm you.",
		"realm_breakthrough_nascent_soul": "Enter by surviving the third tribulation after Golden Core IX. Permanent flight and the shield remain, while Spirit Projection replaces independent shield toggling; lower-realm enemies cannot harm you. The breakthrough after Nascent Soul IX is fatal.",
		"fragment_gallery_label": "Upgrade Fragments",
		"fragment_meta": "Run-Wide Weapon Upgrade",
		"fragment_effect_profile": "Effect Profile",
		"fragment_acquisition": "Acquisition",
		"fragment_acquisition_body": "Defeat a Fragment Elite to choose between two Upgrade Fragments. Stay inside one synchronization field to absorb it; all effects stack for the current run.",
		"fragment_effect_attack_speed": "Shortens every weapon's attack interval, accelerating all automatic attack cycles.",
		"fragment_effect_damage": "Adds flat damage to standard weapons. Qiankun Ring gains one additional bounce instead.",
		"fragment_effect_mobility": "Raises lateral movement speed and forward acceleration for more responsive positioning.",
		"fragment_effect_range": "Expands the attack range and damage area of every compatible weapon.",
		"fragment_effect_speed_control": "Increases your top speed while accelerating and lowers your speed while braking, giving you finer control over your pace.",
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
		"weapon_growth": "Duplicate Bonus",
		"unknown": "Unknown",
		"invalid_weapon": "Invalid Weapon",
		"realm_default": "Realm",
		"countdown_seconds": "%ds",
		"elite_weapon": "Weapon Elite",
		"elite_upgrade": "Fragment Elite",
		"immobilized": "ROOT",
		"critical_hit_format": "CRITICAL!  -%d",
		"body_break": "EXECUTED!",
		"heavenly_strike_format": "Heavenly Strike  %d / %d",
		"annihilation_warning": "Nascent Soul IX · Heavenly Dao's Final Judgment",
		"annihilation_impact": "Heavenly Punishment · Annihilated by the Heavenly Dao",
		"qi_pickup": "Spiritual Qi",
		"weapon_channeling_format": "%s%s  %d\nSynchronizing %.1f / %.1fs",
		"weapon_choice_dimmed_format": "%s  %d\nOther choice in progress",
		"weapon_choice_idle_format": "%s  %d\nStay here for 1 second",
		"weapon_pickup_idle_format": "%s  %d\nStay inside the circle for 1 second",
		"fragment_channeling_format": "%s%s Fragment\nChanneling %.1f / %.1fs",
		"fragment_choice_dimmed_format": "%s Fragment\nOther choice in progress",
		"fragment_choice_idle_format": "%s Fragment\nStay here for 1 second",
		"fragment_pickup_idle_format": "%s Fragment\nEnter the circle and stay inside",
		"upgrade_attack_speed": "Attack Speed",
		"upgrade_damage": "Damage",
		"upgrade_mobility": "Mobility",
		"upgrade_range": "Range",
		"upgrade_speed_control": "Speed Control",
		"upgrade_attack_speed_glyph": "SPD",
		"upgrade_damage_glyph": "DMG",
		"upgrade_mobility_glyph": "MOV",
		"upgrade_range_glyph": "AOE",
		"upgrade_speed_control_glyph": "CTRL",
		"qi_glyph": "Qi",
		"player_stats_empty": "Character Stats\nNo combat data available",
		"player_stats_title": "Character Stats",
		"stats_base_format": "Base  %s · Global Damage +%.1f flat / %s · %s Damage %d",
		"realm_level_format": "Realm Lv.%d",
		"stats_overview_format": "Overview  Crit Chance %s · Crit Damage %s · Attack Speed %s",
		"stats_projectile_format": "Attacks  Projectile Speed ×%.2f · Copies per Attack %d · Area Bonus %s · Targeting Range %s",
		"stats_fragments_format": "Fragments  Attack Speed %d · Damage %d · Mobility %d · Range %d · Speed Control %d",
		"stats_movement_format": "Movement  Lateral Speed %.0f · Forward Acceleration %.0f · Braking Speed %.0f",
		"fragments_unbound": "Upgrade Fragments: No character data available",
		"fragments_details_format": "Upgrade Fragments\nAttack Speed Lv.%d: +%.0f%% per level\nDamage Lv.%d: Standard weapons +%d / Qiankun Ring +1 bounce\nMobility Lv.%d: Lateral Speed +%.0f / Forward Acceleration +%.0f\nRange Lv.%d: All weapons +%.0f%% per level\nSpeed Control Lv.%d: Top Speed +%.0f / Braking Speed -%.0f (minimum %.0f)",
		"level_up_format": "%s\nLifespan +%.0f",
		"ability_ground_training": "Grounded Cultivation",
		"ability_roll_summary": "Space: Invincible Roll · CD 0.8s",
		"flight_ascending": "Ascending",
		"flight_holding": "Gliding",
		"flight_descending": "Descending",
		"flight_active_format": "Skyward Leap: %s",
		"flight_prompt": "Space: Skyward Leap",
		"flight_permanent": "Permanent Flight",
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
		"ability_flight_description": "Rise briefly above the ground to evade ground hazards",
		"status_ascending": "Ascending",
		"status_holding": "Gliding",
		"status_descending": "Descending",
		"ability_qi_shield": "Spiritual Qi Shield",
		"ability_qi_shield_description": "Consume Spiritual Qi to absorb damage; attacks penetrate when Qi is depleted",
		"status_shield_active": "Shield active · Press again to deactivate",
		"status_shield_inactive": "Inactive · Ready to activate",
		"ability_spirit_projection": "Spirit Projection",
		"ability_spirit_projection_description": "Activate your shield and project your spirit, dealing 200% damage while taking 150% damage",
		"status_projection_active": "Spirit Projection active · Press again to return",
		"shield_off_projection": "◇ Spiritual Qi Shield inactive · Activates with Spirit Projection",
		"shield_off_prompt": "◇ Spiritual Qi Shield inactive · Press Space to activate",
		"qi_shield_capacity_format": "Spiritual Qi  %d / %d  ·  Shield %.0f",
		"shield_status_format": "◉ Spiritual Qi Shield  %.0f capacity  ·  1 Qi absorbs %.1f damage",
		"shield_depleted": "◇ Spiritual Qi Shield depleted · Gather Qi to restore it",
		"shield_absorbed_format": "Absorbed %.0f damage  ·  Spent %d Qi  ·  %.0f shield remaining",
		"shield_penetrated_format": "  ·  %.1f damage bypassed the shield",
		"projection_entered": "Spirit Projection\nDamage ×2 · Damage Taken ×1.5 · Shield Active",
		"projection_returned": "Spirit Returned",
		"damage_upgrade_format": "Damage Upgrade Lv.%d\nStandard Weapons +%d Damage · Qiankun Ring: Bounces +%d",
		"generic_upgrade_format": "%s Upgrade Lv.%d\nApplies Globally",
		"tribulation_success": "Tribulation Survived\nMaximum Lifespan Increased",
		"tribulation_warning": "Prepare for Tribulation\nA Lightning Tribulation Approaches",
		"route_main": "Continue on the Main Path",
		"route_left": "Endless Left Path",
		"route_right": "Endless Right Path",
		"route_trial": "Infernal Trial",
		"route_trial_description": "Infernal Trial\nHigh-Intensity Combat Zone",
		"route_selected_format": "Selected: %s",
		"route_entering_format": "Entering: %s",
		"realm_progress_format": "%s · Layer %d",
		"shield_capacity_short_format": "Shield %.0f",
		"shield_empty_short": "Shield Depleted",
		"shield_blocked_format": "Blocked %.0f  ·  -%d Qi",
		"lifespan_damage_format": "-%.1f Lifespan",
		"equipment_locked_suffix": "  [Unavailable in This Realm]",
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
		"debug_fragment_levels": "Upgrade Fragment Levels",
		"debug_add_fragment": "+Fragment",
		"debug_remove_fragment": "-Fragment",
		"debug_base_stats": "Player Base Stats",
		"debug_forward_speed": "Forward Speed ",
		"debug_lateral_speed": "Lateral Speed ",
		"debug_acceleration": "Forward Acceleration ",
		"debug_apply_stats": "Apply Base Stats",
		"instructions_body": """[font_size=14][color=#5f8798]01  //  CORE LOOP[/color][/font_size]
[font_size=27][color=#7edce3][b]CORE OBJECTIVE[/b][/color][/font_size]
You fly forward automatically while your lifespan steadily ticks down. Evade enemies, gather Spiritual Qi, and advance your cultivation before your lifespan runs out.

[font_size=14][color=#5f8798]02  //  INPUT MAP[/color][/font_size]
[font_size=27][color=#7edce3][b]CONTROLS[/b][/color][/font_size]
[color=#f0d68e][b]A / D or ← / →[/b][/color]    Move left and right
[color=#f0d68e][b]W / ↑[/b][/color]    Accelerate
[color=#f0d68e][b]S / ↓[/b][/color]    Slow down
[color=#f0d68e][b]Space[/b][/color]    Use your current realm ability
[color=#f0d68e][b]Hold Tab[/b][/color]    View core combat stats and fragment levels
[color=#f0d68e][b]1–6 / Q[/b][/color]    Select equipment
[color=#f0d68e][b]Esc[/b][/color]    Pause the game

[font_size=14][color=#5f8798]03  //  ENGAGEMENT PROTOCOL[/color][/font_size]
[font_size=27][color=#7edce3][b]COMBAT[/b][/color][/font_size]
• Weapons automatically seek and attack enemies. After collecting weapons, use the number keys to switch between them.
• Enemy contact and attacks drain lifespan directly. Keep moving and avoid being surrounded.
• Defeat golden elite enemies to earn weapons and upgrade fragments.
• Drops travel with you. Stay inside a synchronization circle until the meter fills; leaving early resets its progress.

[font_size=14][color=#5f8798]04  //  PROGRESSION SYSTEM[/color][/font_size]
[font_size=27][color=#7edce3][b]CULTIVATION & GROWTH[/b][/color][/font_size]
• Fill the Spiritual Qi bar to advance one minor layer. Every advancement restores part of your lifespan.
• Duplicate weapons strengthen their unique mechanics. See the Weapon Gallery for exact effects.
• Upgrade fragments grant bonuses that apply to every weapon.

[font_size=14][color=#8f805b]05  //  HIGH-RISK EVENT[/color][/font_size]
[font_size=27][color=#f0d68e][b]BREAKTHROUGHS & TRIBULATIONS[/b][/color][/font_size]
Breaking through to a new major realm triggers a Heavenly Tribulation. Watch for marked danger zones and evade every strike; surviving raises your maximum lifespan.

[font_size=14][color=#9b665f]06  //  ROUTE DECISION[/color][/font_size]
[font_size=27][color=#e99c8d][b]CHOOSING A PATH[/b][/color][/font_size]
Road forks change the route ahead. The Infernal Trial contains stronger, more numerous enemies that attack more often. Choose an ordinary path if you are struggling.""",
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
		"trait_qiankun_ring": "Bounces between enemies after impact, making 2 additional bounces by default before returning to the player.",
		"growth_qiankun_ring": "Each duplicate adds another ring to the volley. Damage fragments grant extra bounces instead of damage.",
		"trait_golden_bell": "Forms renewable shield layers around the player. Contact with the shield damages and knocks enemies back; the outermost layer is consumed first.",
		"growth_golden_bell": "Each duplicate adds one shield layer. Spent layers briefly flicker, then regenerate automatically.",
		"trait_thunder_hammer": "Launches a slow-moving thundercloud that repeatedly damages enemies inside its area.",
		"growth_thunder_hammer": "Each duplicate adds another cloud to the volley. Levels beyond the cloud cap increase damage.",
		"trait_fantian_seal": "Locks onto a target and crashes down from above, damaging a fixed square area, briefly rooting survivors, and shaking the screen.",
		"growth_fantian_seal": "Each duplicate adds one seal, up to 10. Every level beyond that grants 10% more damage.",
	},
}

var current_locale: String = "en"


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
