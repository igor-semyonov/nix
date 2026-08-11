---
name: crypto-sage
description: Cryptography research and computation with SageMath and Python. Use for number theory, elliptic curves, finite fields, lattices, and prototyping crypto primitives.
---

# Cryptography with SageMath

SageMath bundles number theory, algebra, and crypto tooling. Run scripts with `sage script.sage` or interactively with `sage`.

## Finite fields and modular arithmetic

```python
F = GF(2^8, 'a')                 # finite field GF(256)
Zn = Integers(3233)              # Z/nZ
pow(2, 10, 3233)                 # fast modular exponentiation
inverse_mod(17, 3120)            # modular inverse
```

## Number theory

```python
is_prime(2**127 - 1)
factor(3233)                     # -> 61 * 53
euler_phi(3233)
next_prime(2^256)
```

## Elliptic curves

```python
E = EllipticCurve(GF(2^255 - 19), [0, 486662, 0, 1, 0])  # Montgomery-like example
E.order()
P = E.random_point()
(2 * P), (P + P)                 # group law
```

## Lattices (post-quantum / LLL)

```python
M = random_matrix(ZZ, 5, 5)
M.LLL()                          # lattice basis reduction
```

## Guidance for real crypto

- **Never** roll your own crypto for production. Prototype and analyze in Sage; ship with vetted libraries (`ring`, `RustCrypto` crates in Rust; `cryptography` in Python).
- Use constant-time primitives in production code; Sage is for research/analysis, not timing-safe implementations.
- When presenting results, format math and complexity in LaTeX.
- For classical Python without Sage, `sympy.ntheory` and `pycryptodome` cover much of the number theory.
