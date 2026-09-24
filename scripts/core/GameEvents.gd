extends Node
## باس رویدادهای بازی (Autoload) — ارتباط شِل بین سامانه‌ها بدون وابستگی مستقیم.
## در گام‌های بعدی (واحدها، دشمنان، اقتصاد، UI) همه از این مسیر خبر می‌دهند.

## پرچم/گروهی انتخاب شد (نخ اصلی، از ورودی کاربر)
signal squad_selected(squad: Node)

## هدف ناوبری تغییر کرد (world_pos روی صفحه‌ی XZ)
signal goal_changed(world_pos: Vector2)

## هدف ناوبری «یک دسته» تغییر کرد (گام ۵ — میدان جریان چندکاناله per-squad)
signal squad_goal_changed(squad_id: int, world_pos: Vector2)

## دشمنی شروع به غارت خانه کرد / خانه نابود شد
signal village_looted(village_id: int)
signal village_destroyed(village_id: int)

## مرگ دائمی (قانون آهنین: واحد/فرمانده هرگز برنمی‌گردد)
signal commander_died(commander: Node)
signal unit_permanently_died(unit: Node)

## پایان بازی — گام ۶R2 (بازخورد کاربر: «وقتی خانه‌ها کامل آتش گرفت کاربر می‌بازد»)
signal game_over(reason: String)

## تغییر دوره‌ی تاریخی (وراثت از سیستم Era پروژه‌ی قبلی)
signal era_changed(era_id: StringName)

## تغییر ذخیره‌ی آهن‌مرد (قانون: بدون ری‌استارت)
signal ironman_saved
