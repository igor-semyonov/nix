nproc := `nproc`
actual_hostname := `uname -n`

switch:
    sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --flake . --cores {{ nproc }} --max-jobs {{ nproc }} --log-format bar-with-logs

boot:
    sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild boot --flake . --cores {{ nproc }} --max-jobs {{ nproc }} --log-format bar-with-logs

build target_hostname=actual_hostname:
    nixos-rebuild build --flake .#{{ target_hostname }} --cores {{ nproc }} --max-jobs {{ nproc }} --log-format bar-with-logs

switch-remote target_hostname target_host:
    nixos-rebuild switch --flake .#{{ target_hostname }} --target-host {{ target_host }} --use-remote-sudo --cores {{ nproc }} --max-jobs {{ nproc }} --log-format bar-with-logs

test-remote target_hostname target_host:
    nixos-rebuild test --flake .#{{ target_hostname }} --target-host {{ target_host }} --use-remote-sudo --cores {{ nproc }} --max-jobs {{ nproc }} --log-format bar-with-logs

# build and switch billy
billy:
    just switch-remote billy root@nalgor.com

# build and test billy
billy-test:
    just test-remote billy root@nalgor.com

billy-build:
    just build billy

clean:
    nix-collect-garbage -d

repl:
    nixos-rebuild repl --flake .

home:
    home-manager switch --flake .

home-backup:
    home-manager switch --flake . -b backup

dhome:
    home-manager switch --flake .#kdcadet@vin

d:
    sudo darwin-rebuild switch --flake .#vin

nh:
    nh os switch . --cores {{ nproc }} --max-jobs {{ nproc }}

nh-home:
    nh home switch . --cores {{ nproc }} --max-jobs {{ nproc }}
