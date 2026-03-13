# Library Feature

The Library feature handles score import, browsing, metadata editing, and organization.

## Package: `LibraryFeature`

### Score Import (`ScoreImportService`)

- **File sources**: Files app picker via `.fileImporter()`, supports PDF, MusicXML, MEI, MIDI, audio, and image formats
- **Dedup detection**: SHA256 hash comparison prevents duplicate imports
- **File storage**: Copies files to `Application Support/ScoreStageScores/` directory
- **Metadata extraction**: Parses "Composer - Title" pattern from filename
- **PDF page count**: Automatically reads page count from imported PDFs
- **Bulk import**: Accepts multiple URLs in a single operation

Key method: `importFiles(from: [URL], into: ModelContext)`

### Library Home (`LibraryHomeView`)

Main browsing interface with:
- **Grid/List toggle**: Adaptive grid (140-200pt items) or standard list layout
- **Search**: Filters by title, composer, and tags (case-insensitive)
- **Sort options**: Recent, Title, Composer, Genre, Difficulty
- **Favorites filter**: Toggle to show only favorited scores
- **Context menus**: Favorite/unfavorite, edit metadata, delete
- **Empty state**: Animated empty state with import CTA when no scores exist
- **Hover effects**: Grid items scale slightly on hover (macOS)

### Metadata Editor (`ScoreMetadataEditor`)

Form-based editor in a sheet for:
- Title, composer, arranger
- Genre, key, instrumentation
- Difficulty (1-10 picker), duration
- Notes (multiline text)
- Custom tags (add/remove with inline TagsEditor)

### Collections Browser (`CollectionsBrowserView`)

Browse scores organized by:
- **Tags**: All unique tags across library
- **Composers**: Grouped by composer name
- **Genres**: Grouped by genre

Each category shows a count badge and navigates to a filtered list.

### Score Detail (`ScoreDetailView`)

Full detail page featuring:
- Header with thumbnail placeholder, title, composer, arranger, page count, difficulty
- Metadata card (GlassCard) with genre, key, instrumentation, duration
- Tags section with FlowLayout wrapping
- Assets/files list with type icons and file sizes
- "Open Score" action button
