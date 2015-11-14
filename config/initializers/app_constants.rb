ERROR_CODES = {
	unknown: -1,
	success: 0,
	missing_parameters: 1,
	invalid_value: 2,
	item_not_found: 3,
	refresh_data: 4,
	user_is_inactive: 5
}

SUCCESS_CODES = {
	success: 0,
	refresh_data: 1,
	rejected: 2
}

PER_PAGE = 20

OBJECT_PER_PAGE = {
	user: 100,
	document: 100
}