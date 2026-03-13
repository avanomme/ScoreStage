# Setlist Feature

The Setlist feature allows musicians to organize scores into ordered performance lists.

## Package: `SetlistFeature`

### Setlist List (`SetlistListView`)

Main setlist management view:
- Lists all setlists sorted by most recently modified
- **Create**: Alert dialog for naming new setlists
- **Duplicate**: Context menu action copies setlist and all its items
- **Delete**: Swipe-to-delete or context menu
- **Empty state**: Animated prompt when no setlists exist
- Navigation to detail view via `NavigationLink(value:)`

### Setlist Detail (`SetlistDetailView`)

Individual setlist editor:
- **Description**: Editable text field for event description
- **Event date**: DatePicker for scheduling
- **Scores section**: Ordered list of scores in the setlist
  - Drag-to-reorder with `.onMove`
  - Swipe-to-delete with `.onDelete`
  - Edit button for batch editing (iOS)
- **Add scores**: Sheet presenting `AddScoresToSetlistView`

### Add Scores Sheet (`AddScoresToSetlistView`)

Multi-select score picker:
- Shows all scores in the library
- Tap to toggle selection (checkmark UI)
- Displays composer as subtitle
- "Add (N)" button shows selected count
- Inserts items at the end of existing setlist order

### SetListItem Row (`SetlistItemRow`)

Display for each item in a setlist:
- Score title (or "Unknown Score" if reference is broken)
- Performance notes (if any)
- Pause duration timer indicator (if > 0 seconds)

## Data Model

- **SetList**: `name`, `eventDescription`, `eventDate`, `items` relationship, `createdAt`, `modifiedAt`
- **SetListItem**: `sortOrder`, `performanceNotes`, `pauseDuration`, with relationships to `SetList` and `Score`
