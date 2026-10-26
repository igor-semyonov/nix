#!/usr/bin/env python3
"""Copy Vaultwarden's rows from PostgreSQL into a Vaultwarden-created SQLite file.

The SQLite file must already exist and must have been created by Vaultwarden
itself, so that diesel owns `__diesel_schema_migrations`. The two backends have
divergent migration histories -- 47 names under migrations/postgresql, 57 under
migrations/sqlite, three of the shared ones spelled differently -- so that table
is never copied and the schema is never hand-written.

Reading through a driver rather than munging dump text is deliberate: bytea,
boolean and timestamp decoding is then libpq's problem, and the same script runs
unchanged against a live source for the real migration.
"""

from __future__ import annotations

import argparse
import datetime
import re
import sqlite3
import sys

import psycopg

# Vaultwarden's 28 data tables, ordered so that a table's referents always load
# first. SQLite defaults foreign_keys to OFF per connection so this cannot
# actually fail, but loading in order means PRAGMA foreign_key_check afterwards
# is a real test of the data rather than of the insert sequence.
TABLE_ORDER = [
    # Referenced by others, referencing nothing.
    "users",
    "organizations",
    "invitations",
    "sso_auth",
    "twofactor_duo_ctx",
    # Reference the tier above.
    "ciphers",
    "collections",
    "folders",
    "devices",
    "twofactor",
    "sso_users",
    "auth_requests",
    "emergency_access",
    "groups",
    "org_policies",
    "organization_api_key",
    "sends",
    "twofactor_incomplete",
    # Attachments and the join tables.
    "attachments",
    "users_organizations",
    "ciphers_collections",
    "folders_ciphers",
    "users_collections",
    "collections_groups",
    "archives",
    "favorites",
    # Reference the join tables.
    "event",
    "groups_users",
]

DIESEL_MIGRATIONS = "__diesel_schema_migrations"

# Every column type fid's schema actually uses. Anything outside this set needs a
# deliberate encoding rule before it can be trusted through this script, so an
# unexpected type is a hard failure rather than a silent str() fallback.
KNOWN_PG_TYPES = frozenset(
    {
        "bigint",
        "boolean",
        "bytea",
        "character",
        "character varying",
        "integer",
        "text",
        "timestamp without time zone",
    }
)

# `character` is CHAR(36) throughout -- UUIDs, which exactly fill the column, so
# Postgres' blank padding is a no-op. That is a property of the data, not of the
# type, and a padded value copied into SQLite's TEXT would break every join that
# UUID takes part in, silently. So it gets checked rather than assumed.
PADDED_TYPES = frozenset({"character"})

# What diesel's ENCODE_NAIVE_DATETIME_FORMAT can emit; see encode_datetime.
TIMESTAMP_RE = re.compile(r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(\.\d{3}|\.\d{6})?$")


class Failure(Exception):
    """A check that must hold before the load is allowed to proceed."""


def encode_datetime(value: datetime.datetime) -> str:
    """Reproduce diesel's `"%F %T%.f"` byte for byte.

    chrono's `%.f` prints nothing for a whole second, three digits when the
    fraction is whole milliseconds, and six otherwise. Diesel's reader accepts
    all three, but matching the writer exactly keeps the stored text
    indistinguishable from a row Vaultwarden wrote itself.
    """
    if value.tzinfo is not None:
        raise Failure(f"expected a naive timestamp, got {value!r}")
    text = value.strftime("%Y-%m-%d %H:%M:%S")
    micros = value.microsecond
    if micros == 0:
        return text
    if micros % 1000 == 0:
        return f"{text}.{micros // 1000:03d}"
    return f"{text}.{micros:06d}"


def to_sqlite(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (bytes, bytearray, memoryview)):
        return sqlite3.Binary(bytes(value))
    if isinstance(value, datetime.datetime):
        return encode_datetime(value)
    if isinstance(value, (str, int, float)):
        return value
    raise Failure(f"no SQLite encoding for {type(value).__name__}: {value!r}")


def pg_table_names(pg) -> set[str]:
    rows = pg.execute(
        """
        select table_name from information_schema.tables
        where table_schema = 'public' and table_type = 'BASE TABLE'
        """
    ).fetchall()
    return {name for (name,) in rows}


def pg_columns(pg, table: str) -> list[tuple[str, str]]:
    return pg.execute(
        """
        select column_name, data_type from information_schema.columns
        where table_schema = 'public' and table_name = %s
        order by ordinal_position
        """,
        (table,),
    ).fetchall()


def sqlite_table_names(lite) -> set[str]:
    rows = lite.execute("select name from sqlite_master where type = 'table'")
    return {name for (name,) in rows if not name.startswith("sqlite_")}


def sqlite_columns(lite, table: str) -> list[tuple[str, str]]:
    rows = lite.execute(f'pragma table_info("{table}")')
    return [(row[1], row[2]) for row in rows]


def preflight(pg, lite, *, expect_empty: bool) -> None:
    """Refuse to touch the target unless both schemas line up exactly."""
    expected = set(TABLE_ORDER)

    found_pg = pg_table_names(pg) - {DIESEL_MIGRATIONS}
    if found_pg != expected:
        raise Failure(
            "postgres tables do not match the expected set"
            f"\n  only in postgres: {sorted(found_pg - expected)}"
            f"\n  only in script:   {sorted(expected - found_pg)}"
        )

    found_lite = sqlite_table_names(lite) - {DIESEL_MIGRATIONS}
    if found_lite != expected:
        raise Failure(
            "sqlite tables do not match the expected set -- is this really a"
            " Vaultwarden-created database of the same version?"
            f"\n  only in sqlite: {sorted(found_lite - expected)}"
            f"\n  only in script: {sorted(expected - found_lite)}"
        )

    problems = []
    for table in TABLE_ORDER:
        pg_cols = pg_columns(pg, table)
        lite_cols = sqlite_columns(lite, table)

        unknown = {t for _, t in pg_cols} - KNOWN_PG_TYPES
        if unknown:
            problems.append(f"{table}: unhandled postgres types {sorted(unknown)}")

        pg_names = {name for name, _ in pg_cols}
        lite_names = {name for name, _ in lite_cols}
        if pg_names != lite_names:
            problems.append(
                f"{table}: column mismatch"
                f"\n    only in postgres: {sorted(pg_names - lite_names)}"
                f"\n    only in sqlite:   {sorted(lite_names - pg_names)}"
            )

        # bpchar comparisons ignore trailing spaces, so the padding is only
        # visible through an explicit cast to text.
        for name, kind in pg_cols:
            if kind not in PADDED_TYPES:
                continue
            (padded,) = pg.execute(
                f'select count(*) from public."{table}"'
                f' where length("{name}"::text) <> length(rtrim("{name}"::text))'
            ).fetchone()
            if padded:
                problems.append(
                    f"{table}.{name}: {padded} values carry CHAR(n) blank padding"
                )

        if expect_empty:
            (count,) = lite.execute(f'select count(*) from "{table}"').fetchone()
            if count:
                problems.append(f"{table}: target is not empty ({count} rows)")

    if problems:
        raise Failure("schema preflight failed:\n  " + "\n  ".join(problems))


def load(pg, lite) -> None:
    for table in TABLE_ORDER:
        cursor = pg.execute(f'select * from public."{table}"')
        names = [desc.name for desc in cursor.description]
        rows = [tuple(to_sqlite(value) for value in row) for row in cursor]
        if not rows:
            print(f"  {table:<22} 0")
            continue
        columns = ", ".join(f'"{name}"' for name in names)
        placeholders = ", ".join("?" * len(names))
        lite.executemany(
            f'insert into "{table}" ({columns}) values ({placeholders})', rows
        )
        print(f"  {table:<22} {len(rows)}")
    lite.commit()


def verify(pg, lite) -> list[str]:
    """Every check that must pass before this database is trusted."""
    failures = []

    print("\nrow counts (postgres -> sqlite):")
    for table in TABLE_ORDER:
        (want,) = pg.execute(f'select count(*) from public."{table}"').fetchone()
        (got,) = lite.execute(f'select count(*) from "{table}"').fetchone()
        flag = "" if want == got else "  MISMATCH"
        if want != got:
            failures.append(f"{table}: postgres has {want} rows, sqlite has {got}")
        print(f"  {table:<22} {want:>6} -> {got:>6}{flag}")

    orphans = lite.execute("pragma foreign_key_check").fetchall()
    if orphans:
        failures.append(f"foreign_key_check reported {len(orphans)} orphaned rows")
        for row in orphans[:10]:
            print(f"  orphan: {row}")
    print(f"\nforeign_key_check: {len(orphans)} violations")

    integrity = [row[0] for row in lite.execute("pragma integrity_check")]
    if integrity != ["ok"]:
        failures.append(f"integrity_check: {integrity}")
    print(f"integrity_check:   {', '.join(integrity)}")

    # The four bytea columns are the only ones where a silent encoding bug
    # produces a database that looks fine and cannot be logged into.
    print("\nmaster-password verifiers (octet_length -> length):")
    want = dict(
        pg.execute(
            "select email, octet_length(password_hash) || '/' || octet_length(salt)"
            " from public.users"
        ).fetchall()
    )
    got = dict(
        lite.execute(
            "select email, length(password_hash) || '/' || length(salt) from users"
        ).fetchall()
    )
    for email in sorted(want):
        same = want[email] == got.get(email)
        if not same:
            failures.append(
                f"{email}: verifier bytes {want[email]} became {got.get(email)}"
            )
        note = "" if same else "  MISMATCH"
        empty = "  (empty hash on the source too)" if want[email].startswith("0/") else ""
        print(f"  {email:<34} {want[email]:>8} -> {str(got.get(email)):>8}{note}{empty}")

    for table in ("sends",):
        (count,) = lite.execute(f"select count(*) from {table}").fetchone()
        if count:
            print(f"\n{table}: {count} rows carry password_hash/password_salt blobs")

    # Stored timestamps must be in a shape diesel's reader accepts, in every
    # table, not just the ones that happen to get inspected by hand.
    print("\ntimestamp format:")
    checked = 0
    for table in TABLE_ORDER:
        stamps = [
            name
            for name, kind in pg_columns(pg, table)
            if kind == "timestamp without time zone"
        ]
        for column in stamps:
            bad = lite.execute(
                f'select count(*) from "{table}" where "{column}" is not null'
                f' and "{column}" not glob'
                " '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]*'"
            ).fetchone()[0]
            if bad:
                failures.append(f"{table}.{column}: {bad} values are not datetime text")
            for (value,) in lite.execute(
                f'select "{column}" from "{table}" where "{column}" is not null'
            ):
                checked += 1
                if not TIMESTAMP_RE.match(value):
                    failures.append(f"{table}.{column}: unparseable value {value!r}")
                    break
    print(f"  {checked} values match diesel's \"%F %T%.f\"")

    print("\n2FA enrolments (0 TOTP, 1 Email, 2 Duo, 3 YubiKey, 7 WebAuthn, 8 Recovery):")
    for email, atype, enabled in lite.execute(
        "select u.email, t.atype, t.enabled from twofactor t"
        " join users u on u.uuid = t.user_uuid order by u.email, t.atype"
    ):
        print(f"  {email:<34} atype={atype} enabled={enabled}")

    print("\nstructure:")
    for label, query in (
        ("users", "select count(*) from users"),
        ("organizations", "select count(*) from organizations"),
        ("memberships", "select count(*) from users_organizations"),
        ("collections", "select count(*) from collections"),
        ("user_collections", "select count(*) from users_collections"),
        ("ciphers", "select count(*) from ciphers"),
        ("attachments", "select count(*) from attachments"),
    ):
        (count,) = lite.execute(query).fetchone()
        print(f"  {label:<18} {count}")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dsn", help="libpq connection string for the source database")
    parser.add_argument("sqlite_path", help="Vaultwarden-created db.sqlite3 to load into")
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="re-run the checks against an already loaded database",
    )
    args = parser.parse_args()

    with psycopg.connect(args.dsn) as pg, sqlite3.connect(args.sqlite_path) as lite:
        pg.read_only = True
        try:
            preflight(pg, lite, expect_empty=not args.verify_only)
        except Failure as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

        if not args.verify_only:
            print("loading:")
            try:
                load(pg, lite)
            except Failure as exc:
                lite.rollback()
                print(f"error: {exc}", file=sys.stderr)
                return 1

        failures = verify(pg, lite)

    if failures:
        print("\nFAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1

    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
