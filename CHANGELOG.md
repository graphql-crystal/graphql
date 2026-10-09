# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.3] - 2026-10-09

### Fixed

- A fragment that spreads itself, directly or through other fragments, now
  returns a "fragment X spreads itself" error. Previously it recursed until
  the process died of a stack overflow
- `@skip` and `@include` with a missing `if` argument, a non-boolean value,
  or a null variable now return an error for that selection instead of
  raising a `TypeCastError` out of `Schema#execute`

## [0.5.2] - 2026-10-09

### Fixed

- Nullable variables may be omitted or set to `null`, and defaults declared in
  the operation (`query ($n: Int = 1)`) are applied. Previously every omitted
  variable failed the whole request with "missing variable"
- `null` literals and `null` variable values are accepted for nullable
  arguments instead of failing with "bad type for argument"
- Omitting a non-null variable now reports "missing required variable", and a
  variable whose value cannot be converted reports the conversion error
  instead of "missing variable"
- Syntax errors in a query are returned in the `errors` array instead of
  raising `GraphQL::ParserError` out of `Schema#execute`
- Unsupported operation types such as `subscription` return an error instead
  of an empty response
- Error paths for list elements no longer repeat the field name
  (`["items", 0, "items", "boom"]` is now `["items", 0, "boom"]`), and nested
  lists include every index
- Root mutation fields are resolved serially even when `max_concurrency` is
  set, as the spec requires. Nested fields still run concurrently
- Fields selected through fragment spreads and inline fragments keep their
  position in the response, and fields sharing a response key are merged
  instead of emitting duplicate keys

## [0.5.1] - 2026-10-09

### Fixed

- Array and array-of-enum default values on field arguments and input object
  fields no longer fail to compile (#39)

## [0.5.0] - 2026-10-09

### Added

- Concurrent resolution of fields and array elements, opt-in via
  `Context#max_concurrency`
- `Context#in_flight` reports how many resolver fibers are still running
- Unhandled exceptions raised from `Context#handle_exception` now bubble up
  through `Schema#execute` instead of being swallowed
- Directives are now parsed on schema definitions

### Fixed

- Resolver fibers no longer leak when a sibling field or array element raises
  an exception that bubbles up (#48, #52)
- Output object types that are only referenced implicitly, such as the element
  type of a nested array, are now generated in the schema (#41)
- Introspection now includes fields inherited from parent classes
- Block strings containing `"` characters are now lexed correctly
- Quotes in descriptions are escaped in the generated schema
- "Field is not defined" errors now name the field

### Changed

- Fields and array elements are resolved sequentially unless
  `Context#max_concurrency` is set. Earlier unreleased builds spawned one fiber
  per field and array element with no limit
- CI no longer runs on a schedule, and now checks formatting

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
