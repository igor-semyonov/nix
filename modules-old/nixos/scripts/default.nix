{pkgs, ...}: let
  gen-password = pkgs.writeShellApplication {
    name = "gen-password";
    runtimeInputs = with pkgs; [
      openssl
      coreutils-full
    ];
    bashOptions = ["errexit" "nounset"]; # Excludes pipefail
    text = ''
      # shellcheck disable=SC1072,1056

      # https://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/
      # shellcheck disable=SC1073,1054,1083
      length=''${1:-32}

      openssl rand -base64 "$length"
      date +%s | sha256sum | base64 | head -c "$length" ; echo
      < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c"$length";echo;
      tr -cd '[:alnum:]' < /dev/urandom | fold -w"$length" | head -n1
      strings /dev/urandom | grep -o '[[:alnum:]]' | head -n "$length" | tr -d '\n'; echo
      < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c"$length"

      dd if=/dev/urandom bs=1 count="$length" 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev

      echo  Left hand, but not for colemak
      </dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c"$length"; echo

      echo Left Hand for Colemak
      </dev/urandom tr -dc '12345!@#$%qwfpgQWFPGarstdARSTDzxcvbZXCVB' | head -c"$length"; echo
    '';
  };
in {
  environment.systemPackages = [
    gen-password
  ];
}
