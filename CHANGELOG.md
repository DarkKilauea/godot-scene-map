# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6] - 2021-08-11

### Added

- Visual grid to help space out tiles.
- Support for rotating items.

### Changed

- Cursor will stay in the same location when changing edit axis.

### Fixed

- "Cannot get class 'ScenePalette'." error.

## [0.5] - 2021-02-27

- Initial preview release.

### Added

- `ScenePalette` to manage collections of scenes.
- `SceneMap` to lay those scenes out in a grid.
- Editor plugin for managing `ScenePalette` and editing `SceneMap`.
- Support for painting scenes.
- Support for erasing painted scenes.
- Support for undo/redo.
- Ability to edit on different axes (X/Y/Z).

[Unreleased]: https://github.com/DarkKilauea/godot-scene-map/compare/0.6...HEAD
[0.6]: https://github.com/DarkKilauea/godot-scene-map/compare/0.5...0.6
[0.5]: https://github.com/DarkKilauea/godot-scene-map/compare/566cb8666ad7331abb1b508e7fe4147b64b35942...0.5
