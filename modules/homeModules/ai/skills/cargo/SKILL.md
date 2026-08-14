---
name: cargo
description: A comprehensive guide for interacting with Rust's Cargo build system, handling testing, linting, and dependency management.
---

# Cargo Mastery

## Build and Test

To build the project in release mode:

```bash
cargo build --release
```

To run tests with full output:

```bash
cargo test -- --nocapture
```

## Linting

Always run `clippy` to ensure idiomatic code:

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

## Dependency Management

To add a new dependency:

```bash
cargo add <crate_name>
```

To check for outdated dependencies (requires `cargo-outdated`):

```bash
cargo outdated
```
