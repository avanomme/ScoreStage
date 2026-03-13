# Annotation Feature

The Annotation feature provides freehand drawing tools for marking up scores.

## Package: `AnnotationFeature`

### Annotation Toolbar (`AnnotationToolbarView`)

Floating toolbar with tool selection:

| Tool | Description |
|---|---|
| **Pen** | Solid freehand strokes |
| **Pencil** | Lighter, textured strokes |
| **Highlighter** | Semi-transparent wide strokes |
| **Eraser** | Remove strokes |
| **Text** | Place text annotations |
| **Shape** | Draw shapes (planned) |

Controls:
- **Color palette**: 6 annotation colors (red, blue, green, orange, purple, black) from `ASColors.annotationPalette`
- **Line width slider**: 1-20pt range
- **Opacity slider**: 10%-100% opacity
- **Undo/Redo**: Full stroke-level undo/redo

### Annotation State (`AnnotationState`)

Observable state object tracking:
- `isAnnotating`: Whether annotation mode is active
- `selectedTool`: Current drawing tool
- `selectedColor`: Active stroke color
- `lineWidth`: Current stroke width
- `opacity`: Current stroke opacity
- `canUndo` / `canRedo`: Undo/redo availability

### Canvas View (`AnnotationCanvasView`)

SwiftUI Canvas-based drawing surface:
- Overlays on top of PDF pages
- DragGesture captures freehand stroke points
- Renders completed strokes and in-progress stroke
- Stroke style: round line cap and join for smooth curves
- Hit testing disabled when not in annotation mode or when text tool is selected
- Per-stroke opacity support

### Undo/Redo System

Stack-based undo/redo:
- Completed strokes stored in array
- Undo: pops last stroke to undone stack
- Redo: pops from undone stack back to completed
- Undone strokes cleared when new stroke is drawn
