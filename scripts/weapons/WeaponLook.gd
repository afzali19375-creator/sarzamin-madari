class_name WeaponLook
extends RefCounted
## گام ۶R۹ — تسلیحاتِ چندقطعه‌ایِ واضح (بازخورد کاربر: «شمشیرها، نیزه‌ها و
## کمان‌ها قشنگ‌تر و واضح‌تر بشن»):
##   * شمشیر: تیغه‌ی فولادیِ روشنِ پخ‌دار + نوکِ برگ‌سان + محافظ + گویِ دسته
##   * نیزه: چوبِ بلند + گل‌میوه‌ی برنجی + سره‌ی برگ‌سانِ فولادی + بندِ چرمی
##   * کمان: شانه‌ی خمیده از بند‌های چوبی روی قوسِ واقعی + زهِ عاجی
##   * نیزه‌ی پرتاب: ساقِ استخوانی + سره‌ی هرمی + پرِ دُم
##
## مبدأ همه‌ی سازنده‌ها = «محلِ گرفتنِ دست» — سوئینگ روی پیوتِ دست (_hand)
## صحنه انجام می‌شود، پس هر سلاح بدون دانش از انیمیشن، همراهِ ضربه می‌چرخد.
## سلاح در راستای +Y ساخته می‌شود (تیغه/سره رو به بالا)؛ مونتاژ چرخش را
## تعیین می‌کند (نیزه: rotation.x = 90° → رو به جلو).

const STEEL := Color("e3e9ef")           # فولاد روشن — خوانا روی هر زمینه
const BRONZE := Color("c9963c")          # برنزِ تیغه‌ی دشمن (خانواده‌ی طلایی)
const WARM_WOOD := Color("7a5533")       # چوبِ گرمِ نیزه/کمان
const DARK_GRIP := Color("3c2a1c")       # دسته‌ی چرمی تیره
const STRING_IVORY := Color("f2ead8")    # زه‌ی کمان


static func _mat(col: Color, metallic := 0.0, rough := 0.6) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = col
        m.metallic = metallic
        m.roughness = rough
        return m


## متریالِ تیغه — فلزیِ براق + رگه‌ی emis خفیف تا در سایه هم دیده شود
static func _blade_mat(col: Color) -> StandardMaterial3D:
        var m := _mat(col, 0.72, 0.28)
        m.emission_enabled = true
        m.emission = col
        m.emission_energy_multiplier = 0.18
        return m


## شمشیر — مبدأ وسطِ دسته؛ تیغه رو به +Y. blade_col رنگِ تیغه (فولاد/برنزِ کم‌رنگ)
static func sword(blade_col: Color, blade_len := 0.5) -> Node3D:
        var root := Node3D.new()
        # تیغه‌ی پهنِ پخ‌دار
        var blade := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.056, blade_len, 0.018)
        blade.mesh = bm
        blade.position.y = 0.075 + blade_len * 0.5
        blade.material_override = _blade_mat(blade_col)
        root.add_child(blade)
        # نوکِ برگ‌سان
        var tip := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.002
        tm.bottom_radius = 0.027
        tm.height = 0.09
        tm.radial_segments = 8
        tip.mesh = tm
        tip.scale = Vector3(1.0, 1.0, 0.34)
        tip.position.y = 0.075 + blade_len + 0.045
        tip.material_override = _blade_mat(blade_col)
        root.add_child(tip)
        # خطِ وسطِ تیغه (fuller) — باریکه‌ی تیره، حسِ سه‌بعدی می‌دهد
        var fuller := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(0.012, blade_len * 0.8, 0.021)
        fuller.mesh = fm
        fuller.position.y = 0.075 + blade_len * 0.5
        fuller.material_override = _mat(blade_col.darkened(0.35), 0.5, 0.4)
        root.add_child(fuller)
        # محافظِ عرضی
        var guard := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(0.15, 0.028, 0.044)
        guard.mesh = gm
        guard.position.y = 0.062
        guard.material_override = _mat(BRONZE, 0.55, 0.4)
        root.add_child(guard)
        # دسته‌ی چرمی
        var grip := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.017
        pm.bottom_radius = 0.017
        pm.height = 0.13
        grip.mesh = pm
        grip.position.y = -0.015
        grip.material_override = _mat(DARK_GRIP, 0.0, 0.85)
        root.add_child(grip)
        # گویِ ته‌دسته
        var pommel := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.027
        sm.height = 0.054
        pommel.mesh = sm
        pommel.position.y = -0.09
        pommel.material_override = _mat(BRONZE, 0.6, 0.35)
        root.add_child(pommel)
        return root


## نیزه — مبدأ «جای دست» (۰٫۳۵ متر بالاتر از تهِ چوب)؛ سره رو به +Y
static func spear(total_len: float, shaft_col: Color, tip_col: Color) -> Node3D:
        var root := Node3D.new()
        var butt := -0.35
        var shaft := MeshInstance3D.new()
        var sm := CylinderMesh.new()
        sm.top_radius = 0.021
        sm.bottom_radius = 0.028
        sm.height = total_len
        shaft.mesh = sm
        shaft.position.y = butt + total_len * 0.5
        shaft.material_override = _mat(shaft_col, 0.0, 0.8)
        root.add_child(shaft)
        # گل‌میوه‌ی برنجی زیر سره
        var collar := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.032
        cm.bottom_radius = 0.032
        cm.height = 0.05
        collar.mesh = cm
        collar.position.y = butt + total_len - 0.1
        collar.material_override = _mat(BRONZE, 0.6, 0.35)
        root.add_child(collar)
        # سره‌ی برگ‌سانِ فولادی (پخ‌خورده در محور Z)
        var tip := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.002
        tm.bottom_radius = 0.052
        tm.height = 0.2
        tm.radial_segments = 10
        tip.mesh = tm
        tip.scale = Vector3(1.0, 1.0, 0.4)
        tip.position.y = butt + total_len + 0.075
        tip.material_override = _blade_mat(tip_col)
        root.add_child(tip)
        # بندِ چرمیِ جای دست
        var wrap := MeshInstance3D.new()
        var wm := CylinderMesh.new()
        wm.top_radius = 0.032
        wm.bottom_radius = 0.032
        wm.height = 0.1
        wrap.mesh = wm
        wrap.position.y = -0.02
        wrap.material_override = _mat(DARK_GRIP, 0.0, 0.9)
        root.add_child(wrap)
        return root


## کمان — شانه‌ی خمیده روی قوسِ واقعی + زه؛ مبدأ وسطِ دسته (کمان رو به ±X باز می‌شود)
static func bow(radius := 0.3) -> Node3D:
        var root := Node3D.new()
        var segs := 7
        var arc_deg := 132.0
        var step := deg_to_rad(arc_deg) / float(segs - 1)
        var wood := _mat(WARM_WOOD, 0.0, 0.78)
        var tip_a := Vector2.ZERO
        var tip_b := Vector2.ZERO
        for i in segs:
                var ang := -deg_to_rad(arc_deg) * 0.5 + step * float(i)
                var p := Vector2(sin(ang), cos(ang)) * radius
                if i == 0:
                        tip_a = p
                if i == segs - 1:
                        tip_b = p
                if i == 0 or i == segs - 1:
                        continue
                var seg := MeshInstance3D.new()
                var cm := CylinderMesh.new()
                cm.top_radius = 0.015
                cm.bottom_radius = 0.015
                cm.height = radius * step + 0.035
                seg.mesh = cm
                seg.position = Vector3(p.x, p.y, 0.0)
                # هر بند روی مماسِ قوس می‌نشیند
                seg.rotation_degrees.z = -rad_to_deg(ang)
                seg.material_override = wood
                root.add_child(seg)
        # زه‌ی عاجی — از نوکِ بالا تا نوکِ پایین
        var sl := tip_a.distance_to(tip_b)
        var strg := MeshInstance3D.new()
        var bm2 := BoxMesh.new()
        bm2.size = Vector3(0.008, sl, 0.008)
        strg.mesh = bm2
        strg.position = Vector3((tip_a.x + tip_b.x) * 0.5, 0.0, 0.0)
        var stmat := _mat(STRING_IVORY, 0.0, 0.5)
        stmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        strg.material_override = stmat
        root.add_child(strg)
        # نقشِ طلاییِ دسته
        var grip := MeshInstance3D.new()
        var gm := CylinderMesh.new()
        gm.top_radius = 0.02
        gm.bottom_radius = 0.02
        gm.height = 0.09
        grip.mesh = gm
        grip.rotation_degrees.z = 90.0
        grip.position = Vector3(0.0, -0.02, 0.0)
        grip.material_override = _mat(BRONZE, 0.55, 0.4)
        root.add_child(grip)
        return root


## نیزه‌ی پرتاب — ساقِ استخوانی + سره‌ی هرمی + پرِ دم؛ مبدأ جای دست
static func javelin(total_len := 0.66, bone_col: Color = Color("d8d8c4")) -> Node3D:
        var root := Node3D.new()
        var butt := -0.26
        var shaft := MeshInstance3D.new()
        var sm := CylinderMesh.new()
        sm.top_radius = 0.014
        sm.bottom_radius = 0.018
        sm.height = total_len
        shaft.mesh = sm
        shaft.position.y = butt + total_len * 0.5
        shaft.material_override = _mat(bone_col, 0.0, 0.65)
        root.add_child(shaft)
        # سره‌ی هرمی
        var tip := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.001
        tm.bottom_radius = 0.026
        tm.height = 0.1
        tip.mesh = tm
        tip.scale = Vector3(1.0, 1.0, 0.45)
        tip.position.y = butt + total_len + 0.045
        tip.material_override = _blade_mat(Color("cfcfc2"))
        root.add_child(tip)
        # پرِ دم — دو ورقِ متقاطع
        for ry in [0.0, 90.0]:
                var fl := MeshInstance3D.new()
                var fm2 := BoxMesh.new()
                fm2.size = Vector3(0.05, 0.09, 0.004)
                fl.mesh = fm2
                fl.position.y = butt + 0.045
                fl.rotation_degrees.y = ry
                fl.material_override = _mat(bone_col.lightened(0.25), 0.0, 0.7)
                root.add_child(fl)
        return root
