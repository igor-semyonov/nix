---
name: scientific-python
description: Numerical and symbolic computing with numpy, scipy, and sympy. Use for array math, linear algebra, optimization, and symbolic manipulation.
---

# Scientific Python

## NumPy — arrays and vectorization

```python
import numpy as np

a = np.linspace(0, 1, 100)
b = np.sin(2 * np.pi * a)        # vectorized; avoid Python loops
M = np.random.default_rng(0).standard_normal((3, 3))
np.linalg.solve(M, np.ones(3))   # solve Mx = 1
```

- Prefer vectorized operations and broadcasting over loops.
- Use `np.random.default_rng(seed)` (the modern Generator API), not the legacy `np.random.*`.
- Watch dtypes; integer arrays silently truncate.

## SciPy — heavier numerics

```python
from scipy import optimize, integrate, linalg

optimize.minimize(f, x0, method="BFGS")
integrate.quad(f, 0, 1)
linalg.eig(M)                    # scipy.linalg is more complete than numpy.linalg
```

## SymPy — symbolic math

```python
import sympy as sp

x = sp.symbols("x")
expr = sp.integrate(sp.sin(x) * sp.exp(x), x)
sp.simplify(expr)
sp.latex(expr)                   # emit LaTeX for a paper
sp.solve(sp.Eq(x**2 - 2, 0), x)  # exact roots
```

- Use `sp.symbols` with assumptions (`positive=True`, `real=True`) to enable simplifications.
- `sp.lambdify(x, expr, "numpy")` turns a symbolic expression into a fast numeric function.

## Tips

- Profile before optimizing (`%timeit` in IPython, or `cProfile`).
- Manage the environment with `uv` (see the `python-uv` skill).
