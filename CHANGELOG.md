# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Infinite yielding due to invalid instance names. The hashed remote names are now passed through HttpService:UrlEncode.
- Fix debug mode always being on in studio by updating to Pack v0.10.1
