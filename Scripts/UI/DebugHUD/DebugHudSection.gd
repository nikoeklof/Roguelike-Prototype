extends Node
class_name DebugHUDSection
## Base class for all debug HUD sections.
## Each section is responsible for one block of text in the debug panel.
## Subclass this, override section_name() and build_text().

## Return the BBCode header for this section (e.g. "STATS", "SHIELD").
func section_name() -> String:
	return "UNNAMED"


## Build the BBCode body for this section.
## `ctx` is a DebugHUDContext with references to common nodes.
## Return "" to hide this section entirely for this frame.
func build_text(ctx: DebugHUDContext) -> String:
	return ""
