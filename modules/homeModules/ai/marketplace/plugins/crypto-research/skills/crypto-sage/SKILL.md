---
name: crypto-sage
description: Cryptography research with SageMath — number theory, finite fields, elliptic curves, lattices. Use for prototyping and analyzing crypto primitives.
---

# Cryptography with SageMath

Run with `sage script.sage` or interactively via `sage`.

## Finite fields & modular arithmetic

```python
F = GF(2^8, 'a')
Zn = Integers(3233)
pow(2, 10, 3233)
inverse_mod(17, 3120)
```

## Number theory

```python
is_prime(2**127 - 1)
factor(3233)          # 61 * 53
euler_phi(3233)
next_prime(2^256)
```

## Elliptic curves

```python
E = EllipticCurve(GF(101), [2, 3])
E.order()
P = E.random_point()
2 * P
```

## Lattices (LLL)

```python
M = random_matrix(ZZ, 5, 5)
M.LLL()
```

## Guidance

Never ship hand-rolled crypto — prototype/analyze in Sage, deploy with vetted libraries (`RustCrypto`, `ring`, Python `cryptography`). Use constant-time primitives in production. Format results in LaTeX.
