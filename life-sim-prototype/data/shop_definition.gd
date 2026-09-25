class_name ShopDefinition
extends Resource
## One shop: what it sells, what it charges, when it is open, and who works there.
##
## A shop does NOT own a price list. Prices live in one place (Economy), and a shop applies its own markup to them,
## so the same jacket costs a little more at the boutique than at the general store without anyone maintaining two
## numbers that can drift apart.

@export var id: String = ""
@export var display_name: String = ""
## The WorldState location this shop's register stands at.
@export var location_id: String = ""
## Which job id staffs it (see WorldState.jobs); an unstaffed shop is shut.
@export var job_id: String = ""
## Kinds of thing it stocks. "garment", "prop", "equipment", "food", "board_part".
@export var stock_kinds: Array[String] = []
## Explicit item ids, when the shop sells a hand-picked set rather than a whole category.
@export var stock_ids: Array[String] = []
## Everything here costs this much more (or less) than the base price. 1.0 is the book price.
@export var markup: float = 1.0
## What it pays for something sold back, as a share of the price it would charge.
@export var buyback: float = 0.4
@export var open_hour: int = 9
@export var close_hour: int = 18
@export var open_weekends: bool = true

func is_open_at(hour: int, weekend: bool) -> bool:
	if weekend and not open_weekends:
		return false
	return hour >= open_hour and hour < close_hour

func sells(item_id: String, kind: String) -> bool:
	if item_id in stock_ids:
		return true
	return stock_kinds.has(kind) and stock_ids.is_empty()

## The shelf price of something whose book price is `base`.
func price_for(base: int) -> int:
	return int(round(float(base) * markup))

func sell_back_for(base: int) -> int:
	return int(round(float(base) * markup * buyback))
