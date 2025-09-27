update:
	j=$(nproc) && sudo nixos-rebuild switch --flake . -j $((j + 1))
trace:
	sudo nixos-rebuild switch --flake . --show-trace
boot:
	j=$(nproc) && sudo nixos-rebuild boot --flake . -j $((j + 1))

clean:
	nix-collect-garbage -d

home: .FORCE
	home-manager  switch --flake .

home-backup: .FORCE
	home-manager  switch --flake . -b backup

.FORCE:
