NPROC := $(shell nproc)

#ACTUAL_HOSTNAME := $(shell uname -n)
PROVIDED_HOST := $(word 2,$(MAKECMDGOALS))
TARGET_HOST := $(if $(PROVIDED_HOST),$(PROVIDED_HOST),$(ACTUAL_HOSTNAME))
$(eval $(PROVIDED_HOST):;@:)

switch:
	sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
build:
	nixos-rebuild build --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
boot:
	sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild boot --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs

build-remote:
	nixos-rebuild build --flake .#$(TARGET_HOST --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
switch-remote:
	echo nixos-rebuild switch --flake .#$(TARGET_HOST) --target-host $(TARGET_HOST) --use-remote-sudo --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs

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
