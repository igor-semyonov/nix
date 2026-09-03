# NixOS Configurations for My Machines


This repository contains NixOS configurations for my machines, managed through [Nix Flakes](https://nixos.wiki/wiki/Flakes) and structured using [flake-parts](https://github.com/hercules-ci/flake-parts).

It is structured to easily accommodate multiple machines and user configurations, leveraging [nixpkgs](https://github.com/NixOS/nixpkgs), [home-manager](https://github.com/nix-community/home-manager), [nix-darwin](https://github.com/LnL7/nix-darwin), and various other community contributions for a seamless experience across NixOS and macOS.

## Structure

- `flake.nix`: The flake itself, defining inputs and importing all modules.
- `modules/`: All the modules. All `*.nix` files are automatically imported from here, regardless of where they appear. File location does not matter.
  - `users.nix`: User level NixOS and Home options.
  - `hosts/`: NixOS, nix-darwin, and home-manager configurations for each machine, and which users to include.
  - `nixosModules/`: NixOS-specific modules
  - `homeModules/`: User-space configuration modules
  - `overlays.nix`: Custom Nix overlays for package modifications or additions
  - `secrets.nix`: Secrets managed by sops-nix
- `flake.lock`: Lock file ensuring reproducible builds by pinning input versions

## Usage

### Adding a New Machine with a New User

To add a new machine with a new user to your NixOS or nix-darwin configuration, follow these steps:

1. **Update `modules/users.nix`**:

Add the new user to the `users` attribute set. Best to copy an existing user.

2. **Create System Configuration**:

Copy an existing system in `modules/hosts/`, for example `boxy.nix`. Change the variables defined at the top as needed.
Only change things in the top let-in block.

- `hostname`: The hostname
- `hardware-configuration`: Get this by running `sudo nixos-generate-config --show-hardware-config`, although it is probably already at `/etc/nixos/hardware-configuration.nix`, if you just installed NixOS.
- `includedUsers`: list of users to be created on the system
- `nixosModules`: Modules to be included at the system level. Many of these come from other files. These can also be defined inline.
- `homeModules`: Modules to be included for all users on the system.
- `nixosHomeManagerModule`: True means build home manager in nixos module mode. False means build home manager in standalone mode.

To deploy the system configuration, run `make`. If you changed the hostname, you will need to run the full command, specifying the hostname `nixos-rebuild switch --flake .#<hostname>`

If home manager is installed in standalone mode, you will need to grab home-manager the first time by:

```sh
nix shell nixpkgs#home-manager
home-manager switch --flake .#<user>@<hostname>
```

After the first run, you can just run `make home`.

## License

This repository is licensed under the MIT License. Feel free to use, modify, and distribute according to the license terms.
