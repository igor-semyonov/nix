NPROC := $(shell nproc)

update:
	sudo nixos-rebuild switch --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs
trace:
	sudo nixos-rebuild switch --flake . --show-trace
boot:
	j=$(nproc) && sudo nixos-rebuild boot --flake . --cores $(NPROC) --max-jobs $(NPROC) --log-format bar-with-logs

clean:
	nix-collect-garbage -d

home: .FORCE
	home-manager  switch --flake .

home-backup: .FORCE
	home-manager  switch --flake . -b backup

.FORCE:
