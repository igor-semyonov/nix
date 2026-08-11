---
description: Rust code style and conventions.
---

# Rust Style

- Format with `rustfmt` and keep `cargo clippy --all-targets --all-features -- -D warnings` clean.
- Handle errors with `Result` and `?`; use `thiserror` for library errors and `anyhow` for applications. Avoid `unwrap`/`expect` outside tests and provably-infallible cases.
- Avoid `unsafe`; when unavoidable, isolate it, document the invariants, and justify soundness.
- Prefer borrowing over cloning; reach for iterators and zero-cost abstractions before manual loops.
- Derive `Debug` widely; derive `Clone`/`Copy` only when cheap and meaningful.
- Write unit tests next to code (`#[cfg(test)]`) and integration tests under `tests/`.
- Keep modules small and public APIs minimal; document public items with `///`.
