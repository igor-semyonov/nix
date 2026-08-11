---
description: Ensure security best practices are followed.
---

# Security Rules

- **Never** commit hardcoded secrets, passwords, or API keys.
- Always use environment variables for sensitive data.
- Validate all user input before processing.
- When generating cryptography code, ensure to use established libraries (like `ring` or `rust-crypto` in Rust) and avoid implementing custom cryptography algorithms unless specifically requested for research purposes.
- Use memory-safe practices in Rust; avoid `unsafe` blocks unless absolutely necessary and thoroughly documented.
- Always check that file permissions are least privilege, e.g., 0600 for secrets.
