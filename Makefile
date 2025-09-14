update:
	sudo nixos-rebuild switch --flake .
trace:
	sudo nixos-rebuild switch --flake . --show-trace

clean:
	nix-collect-garbage -d

home: .FORCE
	home-manager  switch --flake .

home-backup: .FORCE
	home-manager  switch --flake . -b backup

.FORCE:
