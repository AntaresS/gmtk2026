class_name UniversalUpgradeTypes
extends RefCounted

enum UpgradeType {
	ATTACK_SPEED,
	DAMAGE,
	MOVEMENT,
	DAMAGE_RANGE,
	SPEED_CONTROL,
}

const COUNT: int = 5


static func get_display_name(upgrade_type: int) -> String:
	match upgrade_type:
		UpgradeType.ATTACK_SPEED:
			return "攻速"
		UpgradeType.DAMAGE:
			return "伤害"
		UpgradeType.MOVEMENT:
			return "身法"
		UpgradeType.DAMAGE_RANGE:
			return "范围"
		UpgradeType.SPEED_CONTROL:
			return "加减速"
		_:
			return "未知"


static func get_color(upgrade_type: int) -> Color:
	match upgrade_type:
		UpgradeType.ATTACK_SPEED:
			return Color("55d8ff")
		UpgradeType.DAMAGE:
			return Color("ff713d")
		UpgradeType.MOVEMENT:
			return Color("62f29a")
		UpgradeType.DAMAGE_RANGE:
			return Color("c985ff")
		UpgradeType.SPEED_CONTROL:
			return Color("ffe15d")
		_:
			return Color.WHITE
