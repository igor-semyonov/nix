# Tooling for the Postgres -> SQLite migration described in
# vaultwarden-migration.md. Rehearsed on boxy against fid's nightly cluster
# dumps; the same scripts run against fid's live database at cutover.
{...}: {
  perSystem = {pkgs, ...}: let
    # 18 to match fid: the dumps are from 18.6 and carry psql 18's
    # \restrict markers, which an older psql does not understand.
    postgresql = pkgs.postgresql_18;

    python = pkgs.python3.withPackages (ps: [ps.psycopg]);

    vw-pg-scratch = pkgs.writeShellApplication {
      name = "vw-pg-scratch";
      runtimeInputs = [postgresql pkgs.gawk pkgs.coreutils];
      text = builtins.readFile ./vw-pg-scratch.sh;
    };

    vw-pg-to-sqlite = pkgs.writeShellApplication {
      name = "vw-pg-to-sqlite";
      runtimeInputs = [python];
      # -I: the script is run from whatever directory holds the dumps, and must
      # not pick up modules from it.
      text = ''exec python3 -I ${./vw-pg-to-sqlite.py} "$@"'';
    };
  in {
    devShells.vaultwarden-migrate = pkgs.mkShellNoCC {
      packages = [
        vw-pg-scratch
        vw-pg-to-sqlite
        postgresql
        pkgs.sqlite
        python
      ];
    };
  };
}
