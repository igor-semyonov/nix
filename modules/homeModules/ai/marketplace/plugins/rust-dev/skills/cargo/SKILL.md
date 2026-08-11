---
name: cargo
description: Rust's Cargo build system — building, testing, linting, benchmarking, and dependency management. Use when working in a Cargo project.
---

# Cargo

## Build & run

```bash
cargo build              # debug
cargo build --release    # optimized
cargo run -- <args>
cargo check              # fast type-check without codegen
```

## Test

```bash
cargo test                       # all tests
cargo test -- --nocapture        # show stdout
cargo test <name>                # filter by name
cargo test --doc                 # doctests
```

## Lint & format

```bash
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --all
cargo fmt --all -- --check       # CI: fail on unformatted
```

## Dependencies

```bash
cargo add <crate>
cargo add <crate> --features foo
cargo update                     # update within semver
cargo tree                       # dependency graph
cargo outdated                   # needs cargo-outdated
```

## Benchmark

Use `criterion` (stable) for reliable microbenchmarks:

```bash
cargo bench
```

## Tips

- `cargo build --timings` finds slow-compiling crates.
- On Nix, use `buildRustPackage` with a correct `cargoHash`, or a dev shell with `rustc`/`cargo`/`clippy`/`rustfmt` for local work.
