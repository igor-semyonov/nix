"""PreToolUse gate for Claude Code's WebFetch.

Approves a fetch only when it can carry no more than its host's rules allow,
to a host the user has vetted: https on the default port, no credentials, an
allowlisted host, and a query that is absent or matches that host's parameter
rules. Everything else is put to the user, whatever the permission mode.

argv[1] is the rules file written by claude-web-fetch.nix; the hook event
arrives on stdin.
"""

import json
import re
import sys
from urllib.parse import parse_qsl, urlsplit


def check(url, rules):
    """Return (matched host entry, None) to allow, or (None, reason) to ask."""
    if len(url) > rules["maxUrlLength"]:
        return None, f"URL is longer than {rules['maxUrlLength']} characters"
    # Only plain printable ASCII: no room for the URL to mean one host here and
    # another to the fetcher's parser (backslashes, whitespace, IDNA folding).
    if not (url.isascii() and url.isprintable()) or any(c in url for c in " \\"):
        return None, "URL has whitespace, a backslash or non-ASCII characters"
    try:
        parts = urlsplit(url)
        port = parts.port
    except ValueError:
        return None, "URL does not parse"
    if parts.scheme != "https":
        return None, "not https"
    if "@" in parts.netloc:
        return None, "URL carries credentials"
    if port not in (None, 443):
        return None, f"non-default port {port}"
    host = (parts.hostname or "").rstrip(".")
    if not host:
        return None, "URL has no host"

    hosts = rules["hosts"]
    matches = [
        name
        for name, rule in hosts.items()
        if host == name or (rule["subdomains"] and host.endswith("." + name))
    ]
    if not matches:
        return None, f"{host} is not an allowlisted host"
    # The most specific entry decides, so a subdomain can be stricter or looser
    # than its parent domain.
    name = max(matches, key=len)
    query = hosts[name]["query"]

    # The fragment never leaves the machine, so only the query is checked.
    if not parts.query or query == "any":
        return name, None
    if query == "none":
        return None, f"{name} takes no query string"
    try:
        params = parse_qsl(parts.query, keep_blank_values=True, strict_parsing=True)
    except ValueError:
        return None, "query string does not parse"
    for key, value in params:
        if key not in query:
            return None, f"{name} does not allow query parameter {key!r}"
        if not re.fullmatch(query[key], value):
            return None, f"{name}: {key}={value!r} does not match {query[key]}"
    return name, None


def main():
    with open(sys.argv[1]) as f:
        rules = json.load(f)
    event = json.load(sys.stdin)
    url = (event.get("tool_input") or {}).get("url") or ""
    host, reason = check(url, rules)
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow" if host else "ask",
                "permissionDecisionReason": (
                    f"allowlisted host {host}" if host else f"WebFetch gate: {reason}"
                ),
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
