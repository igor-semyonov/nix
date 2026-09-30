# Install a MakeMKV registration key for the rip service, validating it before
# it replaces a working one. A key also revives a build that has passed its
# ~60-day self-expiry, so this is the usual fix when ripping suddenly stops.

usage() {
    cat <<EOF
Usage: sudo makemkv-update-key            # prompts for the key
       sudo makemkv-update-key -          # read the key from stdin
       sudo makemkv-update-key --force    # install even if validation fails

Installs the key at $MAKEMKV_KEY_FILE as $MEDIA_RIP_USER:$MEDIA_RIP_GROUP mode 0400.

The key is never passed as an argument, so it stays out of shell history and
the process list. Free beta keys come from the MakeMKV forum thread "MakeMKV is
free while in beta" and are superseded every couple of months; a purchased key
does not expire and also stops the build self-expiring.
EOF
}

force=false
from_stdin=false
while (($#)); do
    case $1 in
    -)
        from_stdin=true
        shift
        ;;
    -f | --force)
        force=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "makemkv-update-key: unexpected argument: $1" >&2
        echo "makemkv-update-key: the key is read from a prompt or stdin, never argv" >&2
        exit 2
        ;;
    esac
done

if [[ -z ${MAKEMKV_KEY_FILE:-} ]]; then
    echo "makemkv-update-key: igix.media-ripping.makemkvKeyFile is not set," >&2
    echo "  so the rip service would not read a key from anywhere." >&2
    exit 1
fi

if ((EUID != 0)); then
    echo "makemkv-update-key: must run as root to write $MAKEMKV_KEY_FILE" >&2
    echo "  try: sudo makemkv-update-key" >&2
    exit 1
fi

# `read` returns non-zero at EOF without a trailing newline, which under
# errexit would abort here before anything is validated -- so a key file or
# pipe lacking a final newline would fail silently. The variable is still
# populated in that case, so ignore the status and judge by content.
key=""
if [[ $from_stdin == true ]] || [[ ! -t 0 ]]; then
    IFS= read -r key || true
else
    printf 'Paste the MakeMKV key (input hidden): ' >&2
    IFS= read -rs key || true
    printf '\n' >&2
fi

key=$(tr -d '[:space:]' <<<"$key")
if [[ -z $key ]]; then
    echo "makemkv-update-key: no key was read (input was empty)" >&2
    echo "  if you redirected a file, check it is not empty; a file is" >&2
    echo "  preferable to a pipe from echo, which leaves the key in history:" >&2
    echo "    sudo makemkv-update-key < keyfile" >&2
    exit 1
fi

# Validate in a throwaway HOME. `reg` checks the key locally -- no disc and no
# network needed -- so a bad paste is caught before it displaces a working key.
probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT
if HOME=$probe makemkvcon -r reg "$key" >"$probe/out" 2>&1; then
    echo "makemkv-update-key: key accepted by makemkvcon"
else
    reason=$(sed -E 's/^MSG:[0-9]+,[^,]*,[^,]*,"([^"]*)".*/\1/' "$probe/out" |
        grep -m1 -v '^[[:space:]]*$' || true)
    echo "makemkv-update-key: key REJECTED -- ${reason:-makemkvcon reg returned failure}" >&2
    if [[ $force != true ]]; then
        echo "  refusing to install it; $MAKEMKV_KEY_FILE left untouched." >&2
        echo "  use --force to install anyway." >&2
        exit 1
    fi
    echo "  --force given, installing regardless" >&2
fi

install -d -m 0755 -o "$MEDIA_RIP_USER" -g "$MEDIA_RIP_GROUP" "$(dirname "$MAKEMKV_KEY_FILE")"
# install writes owner and mode at creation, so the key is never briefly
# world-readable the way a redirect followed by chmod would be.
printf '%s\n' "$key" |
    install -o "$MEDIA_RIP_USER" -g "$MEDIA_RIP_GROUP" -m 0400 /dev/stdin "$MAKEMKV_KEY_FILE"

echo "makemkv-update-key: installed $(stat -c '%A %U:%G' "$MAKEMKV_KEY_FILE") $MAKEMKV_KEY_FILE"
echo "makemkv-update-key: verifying as the service account..."
sudo -u "$MEDIA_RIP_USER" makemkv-status || true
