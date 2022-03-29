# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2022-03-29

### Added

- Base classes
- Custom exception handler on `Context`
- BigInt scalar
- Instance vars support

### Fixed

- Fixed enums in input objects
- Arrays can now be nested
- Array members are now marked as non-null unless nilable

### Changed

- Removed implicit Int64 conversion
