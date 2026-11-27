extends RefCounted
## Examples refer to existing original assets. No invented animations.
static func for_clip(clip: String) -> Dictionary:
	var c := clip.get_file().to_lower()
	if c.begins_with("pistol_"):
		return {"label": "Pistola", "item": "survival_pack/Pistol_1", "slot": 0}
	if c.begins_with("sword_"):
		return {"label": "Espada", "item": "medieval_weapons_pack/Sword", "slot": 0}
	if c.begins_with("bow_"):
		return {"label": "Arco", "item": "medieval_weapons_pack/Bow_Wooden", "slot": 1}
	if c.begins_with("shield_"):
		return {"label": "Escudo", "item": "medieval_weapons_pack/Shield_Round", "slot": 1}
	if c.begins_with("treechopping"):
		return {"label": "Machado e árvore", "item": "medieval_weapons_pack/Axe", "slot": 0, "context": "nature_pack/CommonTree_1", "z": -0.85}
	if c.begins_with("drink") or c.begins_with("consume"):
		return {"label": "Beber poção", "item": "rpg_items_pack/Potion1_Filled", "slot": 0}
	if c.begins_with("chest_open"):
		return {"label": "Abrir baú", "context": "rpg_items_pack/Chest_Closed", "z": -0.65}
	if c.begins_with("sitting_"):
		return {"label": "Sentar em cadeira", "context": "house_interior_pack/Chair_1", "z": 0.2}
	if c.begins_with("push"):
		return {"label": "Empurrar caixote", "context": "medieval_village_pack/Crate", "z": -0.7}
	if c.begins_with("climbup") or c.begins_with("safetyvault") or c.begins_with("climbledge"):
		return {"label": "Transpor caixote", "context": "medieval_village_pack/Crate", "z": -0.7, "height": 2.0 if c.contains("2m") else 1.0}
	if c.begins_with("mining"):
		return {"label": "Mineração — picareta ausente", "context": "rpg_items_pack/Mineral", "z": -0.8, "missing": "Picareta"}
	return {}

static func find_item(items: Array, key: String) -> int:
	if key.is_empty():
		return -1
	for i in range(items.size()):
		if str(items[i]["pack"]) + "/" + str(items[i]["name"]) == key:
			return i
	return -1
