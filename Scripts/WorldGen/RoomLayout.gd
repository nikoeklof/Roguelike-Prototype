@tool
extends Node2D
class_name RoomLayout

# Normal exits (4-bit)
const N := 1;  const E := 2;  const S := 4;  const W := 8

# XL exits (8-bit) — matches FloorGenerator constants
const XL_N1 := 1;   const XL_N2 := 2
const XL_E1 := 4;   const XL_E2 := 8
const XL_S1 := 16;  const XL_S2 := 32
const XL_W1 := 64;  const XL_W2 := 128

const WALL := 16
const DOOR := 80

# Normal room
const ROOM_W := 800;   const ROOM_H := 800
# XL room
const XL_W   := 1600;  const XL_H   := 1600
# XL door centers along each edge
const XL_DOOR_A := 400;   const XL_DOOR_B := 1200

const COL_FLOOR   := Color(0.08, 0.08, 0.10, 0.20)
const COL_WALL    := Color(0.22, 0.22, 0.30, 0.90)
const COL_OPEN    := Color(0.25, 0.90, 0.35, 0.60)
const COL_GRID    := Color(1.00, 1.00, 1.00, 0.05)
const COL_OUTLINE := Color(0.90, 0.70, 0.20, 1.00)
const COL_LABEL   := Color(0.90, 0.90, 0.90, 0.80)

@export_group("Editor Preview")

@export var is_xl: bool = false:
	set(v): is_xl = v; queue_redraw()

## Normal room: N=1 E=2 S=4 W=8.
@export_flags("N:1", "E:2", "S:4", "W:8") var exits_mask: int = 15:
	set(v): exits_mask = v; queue_redraw()

## XL room: N1=1 N2=2 E1=4 E2=8 S1=16 S2=32 W1=64 W2=128.
@export_flags("N1:1","N2:2","E1:4","E2:8","S1:16","S2:32","W1:64","W2:128") var xl_exits_mask: int = 255:
	set(v): xl_exits_mask = v; queue_redraw()

@export var show_grid: bool = true:
	set(v): show_grid = v; queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if is_xl:
		_draw_xl()
	else:
		_draw_normal()


# --------------------------------------------------
# Normal 800×800
# --------------------------------------------------

func _draw_normal() -> void:
	var rw := ROOM_W
	var rh := ROOM_H
	var ds := rw / 2 - DOOR / 2   # door strip start = 360

	draw_rect(Rect2(0, 0, rw, rh), COL_FLOOR)
	_draw_grid(rw, rh)

	draw_rect(Rect2(0,         0,         rw,   WALL), COL_WALL)
	draw_rect(Rect2(0,         rh - WALL, rw,   WALL), COL_WALL)
	draw_rect(Rect2(rw - WALL, 0,         WALL, rh),   COL_WALL)
	draw_rect(Rect2(0,         0,         WALL, rh),   COL_WALL)

	if exits_mask & N: _open_h(ds, 0)
	if exits_mask & S: _open_h(ds, rh - WALL)
	if exits_mask & E: _open_v(rw - WALL, ds)
	if exits_mask & W: _open_v(0, ds)

	var font := ThemeDB.fallback_font
	var fs   := 18
	if exits_mask & N: draw_string(font, Vector2(ds + DOOR * 0.5, 30),      "N", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if exits_mask & S: draw_string(font, Vector2(ds + DOOR * 0.5, rh - 30), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if exits_mask & E: draw_string(font, Vector2(rw - 30, ds + DOOR * 0.5), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if exits_mask & W: draw_string(font, Vector2(18, ds + DOOR * 0.5),      "W", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)

	draw_rect(Rect2(0, 0, rw, rh), COL_OUTLINE, false, 2.0)


# --------------------------------------------------
# XL 1600×1600
# --------------------------------------------------

func _draw_xl() -> void:
	var rw := XL_W
	var rh := XL_H
	var da := XL_DOOR_A - DOOR / 2   # door A strip start = 360
	var db := XL_DOOR_B - DOOR / 2   # door B strip start = 1160

	draw_rect(Rect2(0, 0, rw, rh), COL_FLOOR)
	_draw_grid(rw, rh)

	draw_rect(Rect2(0,         0,         rw,   WALL), COL_WALL)
	draw_rect(Rect2(0,         rh - WALL, rw,   WALL), COL_WALL)
	draw_rect(Rect2(rw - WALL, 0,         WALL, rh),   COL_WALL)
	draw_rect(Rect2(0,         0,         WALL, rh),   COL_WALL)

	if xl_exits_mask & XL_N1: _open_h(da, 0)
	if xl_exits_mask & XL_N2: _open_h(db, 0)
	if xl_exits_mask & XL_S1: _open_h(da, rh - WALL)
	if xl_exits_mask & XL_S2: _open_h(db, rh - WALL)
	if xl_exits_mask & XL_E1: _open_v(rw - WALL, da)
	if xl_exits_mask & XL_E2: _open_v(rw - WALL, db)
	if xl_exits_mask & XL_W1: _open_v(0, da)
	if xl_exits_mask & XL_W2: _open_v(0, db)

	var font := ThemeDB.fallback_font
	var fs   := 24
	if xl_exits_mask & XL_N1: draw_string(font, Vector2(da + DOOR * 0.5, 40),      "N1", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_N2: draw_string(font, Vector2(db + DOOR * 0.5, 40),      "N2", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_S1: draw_string(font, Vector2(da + DOOR * 0.5, rh - 40), "S1", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_S2: draw_string(font, Vector2(db + DOOR * 0.5, rh - 40), "S2", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_E1: draw_string(font, Vector2(rw - 40, da + DOOR * 0.5), "E1", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_E2: draw_string(font, Vector2(rw - 40, db + DOOR * 0.5), "E2", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_W1: draw_string(font, Vector2(24, da + DOOR * 0.5),      "W1", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)
	if xl_exits_mask & XL_W2: draw_string(font, Vector2(24, db + DOOR * 0.5),      "W2", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, COL_LABEL)

	draw_rect(Rect2(0, 0, rw, rh), COL_OUTLINE, false, 2.0)


# --------------------------------------------------
# Helpers
# --------------------------------------------------

func _draw_grid(rw: int, rh: int) -> void:
	if not show_grid:
		return
	for x in range(0, rw + 1, WALL):
		draw_line(Vector2(x, 0), Vector2(x, rh), COL_GRID)
	for y in range(0, rh + 1, WALL):
		draw_line(Vector2(0, y), Vector2(rw, y), COL_GRID)


func _open_h(x: int, y: int) -> void:
	draw_rect(Rect2(x, y, DOOR, WALL), COL_OPEN)


func _open_v(x: int, y: int) -> void:
	draw_rect(Rect2(x, y, WALL, DOOR), COL_OPEN)
