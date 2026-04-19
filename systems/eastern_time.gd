extends RefCounted
class_name EasternTime

const TIMEZONE_NAME := "America/New_York"
const STANDARD_OFFSET_SECONDS := -5 * 3600
const DAYLIGHT_OFFSET_SECONDS := -4 * 3600
const DAILY_RESET_HOUR := 8
const DAILY_RESET_MINUTE := 0

static func get_current_business_day_key() -> String:
	return get_business_day_key_for_unix(Time.get_unix_time_from_system())

static func get_business_day_key_for_unix(unix_time: int) -> String:
	var local := get_local_datetime_for_unix(unix_time)
	var target_unix := unix_time
	if int(local.get("hour", 0)) < DAILY_RESET_HOUR or (
		int(local.get("hour", 0)) == DAILY_RESET_HOUR and int(local.get("minute", 0)) < DAILY_RESET_MINUTE
	):
		target_unix -= 86400
	return format_date_dict(get_local_datetime_for_unix(target_unix))

static func get_time_until_next_reset_text() -> String:
	var current_unix := int(Time.get_unix_time_from_system())
	var local := get_local_datetime_for_unix(current_unix)
	var target_year := int(local.get("year", 1970))
	var target_month := int(local.get("month", 1))
	var target_day := int(local.get("day", 1))
	if int(local.get("hour", 0)) > DAILY_RESET_HOUR or (
		int(local.get("hour", 0)) == DAILY_RESET_HOUR and int(local.get("minute", 0)) >= DAILY_RESET_MINUTE
	):
		var tomorrow := get_local_datetime_for_unix(current_unix + 86400)
		target_year = int(tomorrow.get("year", target_year))
		target_month = int(tomorrow.get("month", target_month))
		target_day = int(tomorrow.get("day", target_day))
	var target_unix := get_utc_unix_for_local_datetime(
		target_year,
		target_month,
		target_day,
		DAILY_RESET_HOUR,
		DAILY_RESET_MINUTE,
		0
	)
	var remaining_seconds := maxi(target_unix - current_unix, 0)
	var hours := int(remaining_seconds / 3600)
	var minutes := int((remaining_seconds % 3600) / 60)
	return "%02dh %02dm until new missions" % [hours, minutes]

static func get_reset_label() -> String:
	return "Resets daily at 8:00 AM ET"

static func get_local_datetime_for_unix(unix_time: int) -> Dictionary:
	var offset := DAYLIGHT_OFFSET_SECONDS if is_daylight_savings_for_utc(unix_time) else STANDARD_OFFSET_SECONDS
	var adjusted_unix := unix_time + offset
	var local := Time.get_datetime_dict_from_unix_time(adjusted_unix)
	local["utc_offset_seconds"] = offset
	local["timezone"] = TIMEZONE_NAME
	return local

static func is_daylight_savings_for_utc(unix_time: int) -> bool:
	var utc := Time.get_datetime_dict_from_unix_time(unix_time)
	var year := int(utc.get("year", 1970))
	var dst_start_day := nth_weekday_of_month(year, 3, 0, 2)
	var dst_end_day := nth_weekday_of_month(year, 11, 0, 1)
	var dst_start_utc := int(Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT07:00:00Z" % [year, 3, dst_start_day]))
	var dst_end_utc := int(Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT06:00:00Z" % [year, 11, dst_end_day]))
	return unix_time >= dst_start_utc and unix_time < dst_end_utc

static func is_daylight_savings_for_local_date(year: int, month: int, day: int, hour: int = 12) -> bool:
	if month < 3 or month > 11:
		return false
	if month > 3 and month < 11:
		return true
	if month == 3:
		var start_day := nth_weekday_of_month(year, 3, 0, 2)
		return day > start_day or (day == start_day and hour >= 2)
	var end_day := nth_weekday_of_month(year, 11, 0, 1)
	return day < end_day or (day == end_day and hour < 2)

static func get_utc_unix_for_local_datetime(year: int, month: int, day: int, hour: int, minute: int, second: int) -> int:
	var offset := DAYLIGHT_OFFSET_SECONDS if is_daylight_savings_for_local_date(year, month, day, hour) else STANDARD_OFFSET_SECONDS
	var local_iso := "%04d-%02d-%02dT%02d:%02d:%02dZ" % [year, month, day, hour, minute, second]
	return int(Time.get_unix_time_from_datetime_string(local_iso)) - offset

static func nth_weekday_of_month(year: int, month: int, weekday: int, ordinal: int) -> int:
	var first_day_unix := int(Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00Z" % [year, month]))
	var first_day_dict := Time.get_datetime_dict_from_unix_time(first_day_unix)
	var first_weekday := int(first_day_dict.get("weekday", 0))
	var day := 1 + posmod(weekday - first_weekday, 7)
	day += (ordinal - 1) * 7
	return day

static func format_date_dict(date_dict: Dictionary) -> String:
	return "%04d-%02d-%02d" % [
		int(date_dict.get("year", 1970)),
		int(date_dict.get("month", 1)),
		int(date_dict.get("day", 1)),
	]
