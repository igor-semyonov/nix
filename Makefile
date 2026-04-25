NPROC := $(shell nproc)

switch:
	sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
boot:
	sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild boot --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
build:
	sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild build --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
trace:
	sudo nixos-rebuild switch --flake . --show-trace

clean:
	nix-collect-garbage -d

repl:
	nixos-rebuild repl --flake .

home: .FORCE
	home-manager switch --flake .

home-backup: .FORCE
	home-manager switch --flake . -b backup

dhome: .FORCE
	home-manager switch --flake .#kdcadet@vin

d: .FORCE
	sudo darwin-rebuild switch --flake .#vin

nh:
	nh os switch . --cores $(NPROC) --max-jobs $(NPROC)

nh-home:
	nh home switch . --cores $(NPROC) --max-jobs $(NPROC)

.FORCE:
