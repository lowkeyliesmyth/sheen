## 0.1.0 (2026-07-30)

### Feat

- **tree**: update builtin branch enumerator style selection interface (#18)
- **table**: add tables creation including table styling, rendering, and example consumers (#16)
- **list**: add list creation with enumerators, styling overrides, and example consumers (#15)
- **tree**: add tree construction and rendering with example reference consumers (#14)
- **examples**: add example reference consumer framework with specific layout example (#12)
- **foundation**: add perceptual RGB blending via Lab interpolation (#9)
- **lab**: implement Lab#to_rgb inverse conversion
- **background**: add terminal background detection
- **ranges**: apply specific styles to selected runes and cell-ranges
- **stylepainter**: wire up transform and whitespace styling to the rendering engine
- **style**: add data layer transform and whitespace styling toggles
- **style**: add #inherit method to merge explicitly set properties from another style instance
- **style**: add unsetter methods for macro and manual generated properties
- **composition**: add string position placement helpers at the module level
- **sgr**: add foreground and background methods that dispatch to the correct SGR setters
- **composition**: add composition helpers for rendered block height/width measuring and joins
- **style**: add border rendering to style
- **style**: add border support to Sheen::Style with style setters and border size getters
- **border**: add border struct with prebuilt border styles
- **style**: add margin support to blocks
- **style**: implement post-styling block shaping
- **style**: add tab expansion and pre-styling normalization to render method
- **style**: add layout properties with a Position type to Sheen
- **style**: add Style rendering with truncation for visible cells
- **style**: add immutable Style constructor with chainable property setters
- **renderer**: add core Sheen color types and renderers
- **profile**: add profile-based color downsampling
- **profile**: add color profile detection and tests
- **palette**: add ANSI256 xterm color palette table
- **color_space**: implement color-space math lab and rgb types
- **wrapper**: implement wrapper to wrap text at word boundaries and breakpoints while preserving escapes
- **foundation-width**: ansi, hyperlink, and escape sequence preserving truncation helpers
- **foundation**: add a text and ANSI-escape segment scanner
- **foundation**: implement grapheme_width and string_width utilities
- **foundation**: add SGR parsing and color emission
- **ansi**: add hyperlink support with some required sequence character constants
- **ansi**: implement underline style constants and SGR encodings
- **ansi**: implement strip method to remove ansi escape sequences from a string
- **ansi**: scaffold ansi style builder for sgr escapes

### Bug Fixes

- **renderer**: wire terminal background detection into renderer (#11)
- **builder**: add explicit transform method forwarder for builder to style#transform (#5)
- **style**: fix unexpected edge case for multi-rune, multi-width top border fill
- **style**: add _set? accessors to track explicitly set style settings
- **style**: raise on invalid padding/margin shorthand args, intead of silently eating the error
- **unicode**: add canonical wide-character set data source and generator

### Refactor

- **tree**: re-scope tree types into its own module namespace (#17)
- **lab border**: fix record structs for crystal docs compatibility (#7)
- **style**: cleanup crystal idiom deviations (#6)
- **foundation**: cleanup crystal idiom deviations (#3)
- **style**: extract rendering into painters while keeping state and DSL in style  (#2)
- **style**: collapse apply_color to delegate to new foundation::style fg/bg setters
- **style**: refactor border rendering for implicit borders
- **spec-style**: consolidate style spec tests, randomize spec runs
- **ansi**: move attribute methods out of record macro to fix doc generation
- **style**: convert style to macro-based immutable storage struct and TerminalColors as classes (#1)
- **foundation**: relocate ANSI and SGR functionality under decoupled foundation namespace
- **init**: initial commit

### Docs

- **readme**: update readme with tables, lists, and trees info
- **readme**: update readme with real useful details, and a contributing guide (#10)
- **foundation sheen**: add TLDR headers across codebase explaining each files' role, use typos to fix misspellings
- **style**: cleanup docstring comments
- **style**: add usage docstrings for macro-generated property methods
- **foundation**: improve method docstrings for SGR color types and builder

### Tests

- **spec-style**: validate property unset_ method behaviors
- **foundation**: spec tests for SGR parsing and color emission

### Build System

- **shard**: align sheen version number with cz
- **shard**: include ameba linter development dependency

### CI

- **gha**: try to optimize gha cache save and restore actions
- **taskfile**: generate local API docs too
- **gha-coverage**: fix missing closing quote on pr-coverage action
- **gha**: fix shards install cache misses (#8)
- **gha**: add gha workflows for test, release, coverage, and doc generation (#4)
