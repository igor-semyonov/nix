#!/usr/bin/env bash
# Secure pre-tool hook to prevent dangerous operations

# Prevent execution in restricted directories
if [[ $PWD == "/etc" || $PWD == "/var" ]]; then
    echo "Error: Modifying system directories is not allowed." >&2
    exit 1
fi

# We can perform generic sanitization or confirmation checks here
exit 0
