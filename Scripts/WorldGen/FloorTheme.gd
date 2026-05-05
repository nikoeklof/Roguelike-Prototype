extends Resource
class_name FloorTheme

## Defines the visual identity of a floor depth range.
## FloorSpawner picks the active theme by matching current_depth against depth_range.

@export var theme_name: StringName = &"Dungeon"

## Floors this theme covers, inclusive. e.g. Vector2i(1, 3) = floors 1, 2, 3.
@export var depth_range: Vector2i = Vector2i(1, 3)

## Scene instantiated as a child of each room to provide themed wall visuals.
## Expects a Node2D root containing a TileMapLayer.
@export var wall_theme_scene: PackedScene

## TileSet swapped onto every TileMapLayer found in the room (floor palette).
## Palette swaps work as long as tile source IDs and atlas coords match across tilesets.
@export var floor_tileset: TileSet

## Texture swapped onto every Door node found in the room.
## Must be the same dungeon spritesheet variant as the rest of the theme.
@export var door_texture: Texture2D

## Spritesheet swapped onto every prop in the room.
## All prop variant sheets must share identical sprite layout so region_rects stay valid.
@export var prop_spritesheet: Texture2D


func covers_depth(depth: int) -> bool:
	return depth >= depth_range.x and depth <= depth_range.y
