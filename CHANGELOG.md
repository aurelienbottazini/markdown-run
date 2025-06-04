## [Unreleased]

- Added `flamegraph` option for psql code blocks to generate PostgreSQL query execution plan flamegraphs as SVG images
- PostgreSQL flamegraphs provide interactive, color-coded visualization of query performance with hover tooltips
- Flamegraph SVG files follow same directory structure as mermaid diagrams (organized by markdown file basename)
- Added flamegraph option support to frontmatter defaults and language-specific configurations

## [0.1.11] - 2025-06-04

- options are customizable with the yaml frontmatter

## [0.1.10] - 2025-06-03

- standalone options for codeblocks (run instead of run=true)
- explain option for psql code blocks with Dalibo visualization links
- Fixed Dalibo URL generation to properly submit plans via HTTP POST
- Added result option to control result block visibility (result=false hides result blocks while still executing code)

## [0.1.9] - 2025-06-02

- mermaid codeblocks

## [0.1.8] - 2025-06-01

- Added run option

## [0.1.7] - 2025-06-01

- Added rerun functionality

## [0.1.6] - 2025-06-01

- Refactor code to state pattern
- Add yaml frontmatter to support aliases for code blocks

## [0.1.5] - 2025-05-19

- Remove gif files from release

## [0.1.4] - 2025-05-18

- Add support for zsh, bash, sh

## [0.1.3] - 2025-05-14

- Fix missing minitest dep

## [0.1.2] - 2025-05-14

- Gemfile update

## [0.1.1] - 2025-05-14

- Added checks for missing dependencies

## [0.1.0] - 2025-05-13

- Initial release
