extends RefCounted
class_name RewardItem

## Represents a reward item (XP, badge, currency, etc.)
## Usage: RewardItem.new("xp", 50, "Experience Points")

var type: String  # "xp", "badge", "currency", "item"
var amount: int
var name: String
var icon: Texture2D
var description: String

func _init(p_type: String, p_amount: int, p_name: String, p_icon: Texture2D = null, p_desc: String = ""):
	type = p_type
	amount = p_amount
	name = p_name
	icon = p_icon
	description = p_desc