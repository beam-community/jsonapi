# Changelog

## 0.9.0 (2019-01-18)

This is the last release before 1.0. As such this release will feature a number
of deprecations that you'll want to either resolve before upgrading. Should
you have any trouble with these deprecations please file an issue.

- [Added](https://github.com/jeregrine/jsonapi/pull/151) Expand Build Matrix Again
- [Added](https://github.com/jeregrine/jsonapi/pull/155) Refactor String Manipulation Utility Module
- [Internal](https://github.com/jeregrine/jsonapi/pull/152) Move `QueryParser` Test
- [Added](https://github.com/jeregrine/jsonapi/pull/151) Expand Build Matrix
- [Added](https://github.com/jeregrine/jsonapi/pull/149) Add Plug to Transform Parameters
- [Fixed](https://github.com/jeregrine/jsonapi/pull/148) Namespace `Deprecation` module
- [Internal](https://github.com/jeregrine/jsonapi/pull/146) Consolidate Plug Locations
- [Fixed](https://github.com/jeregrine/jsonapi/pull/144) Set `Content-Type` for errors
- [Internal](https://github.com/jeregrine/jsonapi/pull/140) Improve `Application.env` handling in tests
- [Fixed](https://github.com/jeregrine/jsonapi/pull/139) Update regexes for underscore and dash
- [Internal](https://github.com/jeregrine/jsonapi/pull/135) Remove leading `is_` from `is_data_loaded?`
- [Fixed](https://github.com/jeregrine/jsonapi/pull/129) Remove warning about hidden being undefined
- [Added](https://github.com/jeregrine/jsonapi/pull/126) Allows for conditionally hiding fields
- [Fixed](https://github.com/jeregrine/jsonapi/pull/124) Omit non-Object meta

## v0.7.0-0.8.0 (2018-06-13)

(Sorry I missed 0.7.0)

- [Added](https://github.com/jeregrine/jsonapi/pull/117/commits/09faf424f47d46a9f2d24c3057c11c961d345990) Support for configuring your JSON Library, and defaulted to Jason going forward.
- [Fixed](https://github.com/jeregrine/jsonapi/pull/87) Fix nesting for includes
- [Added](https://github.com/jeregrine/jsonapi/pull/88) Removing Top Level if configured
- [Fixed](https://github.com/jeregrine/jsonapi/pull/90) Check headers according to spec
- [Added](https://github.com/jeregrine/jsonapi/pull/92) Add to view custom attribute
- [Added](https://github.com/jeregrine/jsonapi/pull/93) updates plug to allow data with only relationships enhancement
- [Added](https://github.com/jeregrine/jsonapi/pull/97) include meta as top level document member
- [Added](https://github.com/jeregrine/jsonapi/pull/102) Apply optional dash-to-underscore to include keys
- [Fixed](https://github.com/jeregrine/jsonapi/pull/103) Do not build relationships section for not loaded relationships
- [Fixed](https://github.com/jeregrine/jsonapi/pull/105) change try/rescue to function_exported? and update docs
- [Fixed](https://github.com/jeregrine/jsonapi/pull/106) Dasherize keys in relationship urls
- [Added](https://github.com/jeregrine/jsonapi/pull/107) Allows the view to add links
- [Fixed](https://github.com/jeregrine/jsonapi/pull/113) Serialize empty relationship
- [Fixed](https://github.com/jeregrine/jsonapi/pull/114) Handle dashed include for top-level relationship

## v0.6.0 (2017-11-17)

- [Added](https://github.com/jeregrine/jsonapi/commit/44888596461a1891376b937057bb504345cff8dc) Optional Data Links.
- [Added](https://github.com/jeregrine/jsonapi/commit/ba9d9cb84c10ef85a4b8e42df88a9e92f3809651) Paging Support
- [Added](https://github.com/jeregrine/jsonapi/commit/0c50bc60db9b8678f631ac274062150499e4fb8b) Option to replace underscores with dahses

## v0.5.1 (2017-07-07)

- [Added](https://github.com/jeregrine/jsonapi/commit/1f9e45aee4058ca6b3a8a55aaec6eebcada525a6) plug to make verifying reqeusts and their errors easier

## v0.5.0 (2017-07-07)

- [Added](https://github.com/jeregrine/jsonapi/commit/def022b327ac13e5e906a665321969b442048f3b) support for meta fields
- [Added](https://github.com/jeregrine/jsonapi/commit/1bbe4de86baec250d0b8dcc263bb41a94dea8063) support for custom hosts
- [Added](https://github.com/jeregrine/jsonapi/commit/3c73e870651f09ce8e09d4061111487db2e515f5) support for hidden attributes in views
- [Added](https://github.com/jeregrine/jsonapi/commit/45f0d14e9d700d32a8b20dc04a4fa300fa43da37) support converstion of underscore to dashes.
- [Fixed](https://github.com/jeregrine/jsonapi/commit/74b0d1914a3aceb792c753f2292002c10ac93005) issue with index.json
- Now uses Credo

## v0.4.2 (2017-04-17)

- Updated codebase for elixir 1.4
- Updated poison dep to 3.0
- Fixed failing travis tests

## v0.4.0 (2016-12-02)

- Removed PhoenixView

## v0.1.0 (2015-06-?)

- Made params optional

## v0.0.2 (2015-06-22)

- Made paging optional

## v0.0.1 (2015-06-21)

- Support for basic JSONAPI Docs. Links support still missing
