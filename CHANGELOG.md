# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added a release for Pesde. This replaces the Wally release.

### Changed

- Update to Pack v0.11.0

### Removed

- Removed release pipeline for Wally. Starting from this version, PakNet will no longer be published to Wally. Existing versions are still available.

## [0.7.1] - 2025-12-08

### Fixed

- Infinite yielding due to invalid instance names. The hashed remote names are now passed through HttpService:UrlEncode.
- Fix debug mode always being on in studio by updating to Pack v0.10.1

[unreleased]: https://github.com/isoopod/PakNet/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/isoopod/PakNet/compare/c2f663e5b3ead31af025b5b45e827bfdf8e22b17...v0.7.1
