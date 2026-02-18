{
  pkgs,
  inputs,
  userConfig,
  ...
}: let
  journal = pkgs.writeShellApplication {
    name = "journal";
    runtimeInputs = [
      inputs.my-nvim.packages.${pkgs.system}.nvim-nixcats
    ];
    text = ''
      # shellcheck disable=SC1056,1072
      journal_dir=~/journals
      mkdir -p $journal_dir
      # shellcheck disable=SC1073,1054,1083
      fn=''${1:-$(date -I)}
      fn="$journal_dir"/"$fn".md

      if [ ! -f "$fn" ]; then
          echo -e "# $(date --rfc-3339=sec)  " > "$fn"
      else
          echo -e "\n# $(date --rfc-3339=sec)  " >> "$fn"
      fi

      vim '+ normal Go' "$fn" +startinsert
    '';
  };
in {
  users.users.${userConfig.name}.packages = [journal];
}
