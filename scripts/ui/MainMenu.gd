extends Control
## منوی اصلی — دوزبانه (فارسی/انگلیسی) با فونت وزیرمتن و پالت هخامنشی.
## در گام‌های بعد، ادامه‌ی کمپین (نقشه‌ی ۶ جزیره‌ای) از همین منو شروع می‌شود.

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"
const TEST_SCENE := "res://scenes/dev/FlowFieldTest.tscn"
const ISLAND_SCENE := "res://scenes/dev/IslandTest.tscn"


func _ready() -> void:
        Engine.time_scale = 1.0

        var bg := ColorRect.new()
        bg.color = GameConstants.COL_NIGHT
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(bg)

        var margin := MarginContainer.new()
        margin.set_anchors_preset(Control.PRESET_FULL_RECT)
        margin.add_theme_constant_override("margin_top", 90)
        margin.add_theme_constant_override("margin_bottom", 60)
        add_child(margin)

        var vb := VBoxContainer.new()
        vb.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_theme_constant_override("separation", 12)
        margin.add_child(vb)

        var title := Label.new()
        title.text = "سرزمین مادری"
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 78)
        title.add_theme_color_override("font_color", GameConstants.COL_GOLD)
        _apply_font(title, FONT_BOLD)
        vb.add_child(title)

        var subtitle := Label.new()
        subtitle.text = "Sarzamin-e Madari — Motherland"
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        subtitle.add_theme_font_size_override("font_size", 24)
        subtitle.add_theme_color_override("font_color", GameConstants.COL_IVORY)
        _apply_font(subtitle, FONT_REGULAR)
        vb.add_child(subtitle)

        var tagline := Label.new()
        tagline.text = tr("app_subtitle")
        tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tagline.add_theme_font_size_override("font_size", 17)
        tagline.add_theme_color_override("font_color", Color("7fd4cc"))
        _apply_font(tagline, FONT_REGULAR)
        vb.add_child(tagline)

        vb.add_child(_spacer(34))

        var start_btn := _make_button(tr("menu_start"))
        start_btn.pressed.connect(_on_start_pressed)
        vb.add_child(start_btn)

        var island_btn := _make_button(tr("menu_island"))
        island_btn.pressed.connect(_on_island_pressed)
        vb.add_child(island_btn)

        var quit_btn := _make_button(tr("menu_quit"))
        quit_btn.pressed.connect(_on_quit_pressed)
        vb.add_child(quit_btn)

        # نوار وضعیت پایین
        var bottom := MarginContainer.new()
        bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
        bottom.add_theme_constant_override("margin_bottom", 16)
        add_child(bottom)
        var version := Label.new()
        version.text = "v0.2  |  build %s  |  گام ۱–۴: مسیریابی + جزیره‌ی WFC با کاشی‌های قابل‌کلیک  |  Steps 1–4: flow field + WFC island" % GameConstants.BUILD_ID
        version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        version.add_theme_font_size_override("font_size", 14)
        version.add_theme_color_override("font_color", Color(0.7, 0.8, 0.78, 0.8))
        _apply_font(version, FONT_REGULAR)
        bottom.add_child(version)


func _on_start_pressed() -> void:
        get_tree().change_scene_to_file(TEST_SCENE)


func _on_island_pressed() -> void:
        get_tree().change_scene_to_file(ISLAND_SCENE)


func _on_quit_pressed() -> void:
        get_tree().quit()


func _make_button(label_text: String) -> Button:
        var b := Button.new()
        b.text = label_text
        b.custom_minimum_size = Vector2(380, 54)
        b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        b.add_theme_font_size_override("font_size", 23)
        _apply_font(b, FONT_REGULAR)
        b.add_theme_color_override("font_color", GameConstants.COL_IVORY)
        b.add_theme_color_override("font_hover_color", GameConstants.COL_GOLD)
        b.add_theme_color_override("font_pressed_color", GameConstants.COL_GOLD)
        b.add_theme_color_override("font_focus_color", GameConstants.COL_GOLD)
        var style := StyleBoxFlat.new()
        style.bg_color = Color("123c44")
        style.border_color = GameConstants.COL_GOLD
        style.set_border_width_all(2)
        style.set_corner_radius_all(10)
        style.content_margin_left = 26.0
        style.content_margin_right = 26.0
        style.content_margin_top = 8.0
        style.content_margin_bottom = 8.0
        b.add_theme_stylebox_override("normal", style)
        var hover := style.duplicate()
        hover.bg_color = Color("1a4d57")
        b.add_theme_stylebox_override("hover", hover)
        b.add_theme_stylebox_override("pressed", hover)
        b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        return b


func _spacer(height: float) -> Control:
        var c := Control.new()
        c.custom_minimum_size = Vector2(0, height)
        return c


func _apply_font(node: Node, font_path: String) -> void:
        if ResourceLoader.exists(font_path):
                node.add_theme_font_override("font", load(font_path))
