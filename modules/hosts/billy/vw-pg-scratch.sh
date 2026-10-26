# Throwaway PostgreSQL 18 cluster holding only fid's `vaultwarden` database,
# restored out of a pg_dumpall cluster dump.
#
# The cluster listens on a unix socket inside a 0700 scratch directory and never
# on TCP, and the default scratch directory is under XDG_RUNTIME_DIR so the
# restored vault rows live in tmpfs rather than on disk.
set -euo pipefail

scratch=''
cmd=''

die() {
    echo "vw-pg-scratch: $1" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: vw-pg-scratch <command> [args]

  up <cluster-dump.psql> [scratch-dir]   initdb, restore the vaultwarden db, start
  dsn [scratch-dir]                      print the libpq connection string
  psql [scratch-dir]                     interactive psql against the scratch db
  counts [scratch-dir]                   exact row count per table
  down [scratch-dir]                     stop the cluster, keep the data
  clean [scratch-dir]                    stop and delete the scratch directory
EOF
    exit 64
}

default_scratch() {
    echo "${XDG_RUNTIME_DIR:-/tmp}/vw-pg-scratch"
}

# Pulls just the `vaultwarden` database body out of a cluster dump: everything
# after `\connect vaultwarden` up to the next `\connect`, which keeps the eight
# other databases and the cluster-wide CREATE ROLE block (SCRAM verifiers for
# every service on fid) out of the scratch cluster entirely.
#
# \restrict/\unrestrict are dropped. They are psql 18's guard against meta-command
# injection from a hostile dump, but they come in pairs that straddle the
# `\connect` we cut on, so an extracted slice always has an unmatched one.
extract_db() {
    awk '
    /^\\connect /{
      if (seen) exit
      if ($2 == "vaultwarden") { seen = 1 }
      next
    }
    !seen { next }
    /^\\restrict /||/^\\unrestrict / { next }
    { print }
  ' "$1"
}

[ "$#" -ge 1 ] || usage
cmd="$1"
shift

case "$cmd" in
up)
    [ "$#" -ge 1 ] || usage
    dump="$1"
    scratch="${2:-$(default_scratch)}"
    [ -r "$dump" ] || die "cannot read dump: $dump"
    [ -e "$scratch" ] && die "scratch directory already exists: $scratch (use 'clean' first)"

    mkdir -p "$scratch"
    chmod 700 "$scratch"
    mkdir -p "$scratch/sock"

    extract_db "$dump" >"$scratch/vaultwarden.sql"
    [ -s "$scratch/vaultwarden.sql" ] || die "no vaultwarden database found in $dump"

    # --no-locale: the dump's own CREATE DATABASE asks for en_US.UTF-8, which a
    # scratch cluster has no reason to depend on. Collation never affects what
    # gets copied, so the database is created here instead of from the dump.
    initdb --username=postgres --auth=trust --no-locale --encoding=UTF8 \
        --pgdata="$scratch/data" >"$scratch/initdb.log" 2>&1 ||
        die "initdb failed, see $scratch/initdb.log"

    pg_ctl --pgdata="$scratch/data" --log="$scratch/postgres.log" \
        --options="-k $scratch/sock -h ''" --wait start ||
        die "cluster failed to start, see $scratch/postgres.log"

    export PGHOST="$scratch/sock" PGUSER=postgres

    # The dump's ALTER TABLE ... OWNER TO vaultwarden needs the role to exist;
    # it never logs in here, so it gets no password.
    psql --quiet --no-psqlrc --command='create role vaultwarden' postgres
    createdb --template=template0 vaultwarden

    psql --quiet --no-psqlrc --set=ON_ERROR_STOP=1 \
        --file="$scratch/vaultwarden.sql" vaultwarden

    echo "scratch cluster up: $scratch"
    echo "postgresql:///vaultwarden?host=$scratch/sock&user=postgres"
    ;;

dsn)
    scratch="${1:-$(default_scratch)}"
    [ -d "$scratch/data" ] || die "no scratch cluster at $scratch"
    echo "postgresql:///vaultwarden?host=$scratch/sock&user=postgres"
    ;;

psql)
    scratch="${1:-$(default_scratch)}"
    [ -d "$scratch/data" ] || die "no scratch cluster at $scratch"
    PGHOST="$scratch/sock" PGUSER=postgres exec psql vaultwarden
    ;;

counts)
    scratch="${1:-$(default_scratch)}"
    [ -d "$scratch/data" ] || die "no scratch cluster at $scratch"
    export PGHOST="$scratch/sock" PGUSER=postgres
    # n_live_tup is an estimate, so this builds a real count(*) per table.
    query=$(
        psql --quiet --no-psqlrc --tuples-only --no-align --command="
        select string_agg(
                 format('select %L as table_name, count(*) from public.%I', tablename, tablename),
                 ' union all ' order by tablename)
        from pg_tables where schemaname = 'public'" vaultwarden
    )
    psql --quiet --no-psqlrc --command="$query order by table_name" vaultwarden
    ;;

down)
    scratch="${1:-$(default_scratch)}"
    [ -d "$scratch/data" ] || die "no scratch cluster at $scratch"
    pg_ctl --pgdata="$scratch/data" --wait --mode=fast stop
    ;;

clean)
    scratch="${1:-$(default_scratch)}"
    [ -d "$scratch" ] || die "nothing to clean at $scratch"
    if [ -f "$scratch/data/postmaster.pid" ]; then
        pg_ctl --pgdata="$scratch/data" --wait --mode=immediate stop || true
    fi
    rm -rf -- "$scratch"
    echo "removed $scratch"
    ;;

*) usage ;;
esac
