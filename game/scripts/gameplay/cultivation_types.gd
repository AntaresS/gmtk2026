class_name CultivationTypes
extends RefCounted

enum CultivationType {
	JING,
	QI,
	SHEN,
}

const NEUTRAL: int = -1
const ORDER: Array[CultivationType] = [
	CultivationType.JING,
	CultivationType.QI,
	CultivationType.SHEN,
]


static func is_valid_type(value: int) -> bool:
	return value >= CultivationType.JING and value <= CultivationType.SHEN


static func get_next_type(value: int) -> CultivationType:
	if not is_valid_type(value):
		return CultivationType.JING
	return ORDER[(ORDER.find(value) + 1) % ORDER.size()]


static func get_name_zh(value: int) -> String:
	match value:
		CultivationType.JING:
			return "精"
		CultivationType.QI:
			return "气"
		CultivationType.SHEN:
			return "神"
		_:
			return "无"
