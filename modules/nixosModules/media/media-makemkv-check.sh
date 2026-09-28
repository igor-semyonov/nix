# Report whether MakeMKV can decrypt a disc, and whether the key is real.
#
# Two independent clocks apply. The build self-expires ~60 days after release
# regardless of the key, and nixpkgs ships new versions only every two to six
# months, so on a flake-pinned system that one bites first. Separately the
# registration key can be superseded -- beta keys rotate.
#
# Neither shows up in a plain `info` probe: makemkvcon exits 0 even after
# failing, and it does not look at the key at all until a disc is opened. Key
# validity therefore has to go through `makemkvcon reg`, which checks the key
# locally and needs no disc and no network.

probe_home=$(mktemp -d)
trap 'rm -rf "$probe_home"' EXIT

msg_text() {
    sed -nE 's/^MSG:[0-9]+,[^,]*,[^,]*,"([^"]*)".*/\1/p'
}

# disc:9999 matches no drive, so this starts the program without needing a disc.
startup=$(HOME=$probe_home makemkvcon -r --cache=1 info disc:9999 2>&1 | msg_text || true)
version=$(grep -m1 -oE 'MakeMKV v[0-9.]+' <<<"$startup" || true)

key_state=unreadable
if [[ -z ${MAKEMKV_KEY_FILE:-} ]]; then
    key_state=absent
elif [[ -r ${MAKEMKV_KEY_FILE} ]]; then
    # `reg` writes the key on success, hence the throwaway HOME.
    if HOME=$probe_home makemkvcon -r reg "$(tr -d '[:space:]' <"$MAKEMKV_KEY_FILE")" \
        >"$probe_home/reg.out" 2>&1; then
        key_state=valid
    else
        key_state=invalid
    fi
fi

# The build reports its own expiry at startup; "expires on <date>" is the
# normal beta banner and must not trip this, only past-tense failures do.
build_trouble=$(grep -iE 'expired|too old' <<<"$startup" |
    grep -viE 'expires on|will expire' || true)

echo "makemkv-status: ${version:-version unknown}"

case $key_state in
valid) echo "makemkv-status: key OK -- ${MAKEMKV_KEY_FILE} accepted by makemkvcon reg" ;;
absent) echo "makemkv-status: no key configured; Blu-ray works only during the evaluation period" ;;
unreadable)
    echo "makemkv-status: key ${MAKEMKV_KEY_FILE} not readable by $(id -un);" \
        "run as ${MEDIA_RIP_USER:-media-rip} to check it"
    ;;
invalid)
    {
        # `reg` reports in plain text, unlike `info` which uses MSG lines, so
        # unwrap a MSG if there is one and otherwise take the line as-is.
        reason=$(sed -E 's/^MSG:[0-9]+,[^,]*,[^,]*,"([^"]*)".*/\1/' "$probe_home/reg.out" |
            grep -m1 -v '^[[:space:]]*$' || true)
        echo "makemkv-status: KEY REJECTED -- ${reason:-makemkvcon reg returned failure}"
        echo "makemkv-status:   ${MAKEMKV_KEY_FILE}"
        echo "makemkv-status:   Blu-ray will work only while the evaluation period lasts,"
        echo "makemkv-status:   then stop. DVD is unaffected. Install a working key with:"
        echo "makemkv-status:     sudo install -o ${MEDIA_RIP_USER:-media-rip} \\"
        echo "makemkv-status:       -g ${MEDIA_RIP_GROUP:-media} -m 0400 /dev/stdin \\"
        echo "makemkv-status:       ${MAKEMKV_KEY_FILE} <<<'THE-KEY'"
        echo "makemkv-status:   A purchased key (https://makemkv.com/buy/) also stops the"
        echo "makemkv-status:   build self-expiring; the rotating free beta key does not."
    } >&2
    ;;
esac

# Only a dead build is fatal. A rejected key still rips during the evaluation
# window, so blocking on it would refuse work that would have succeeded.
if [[ -n $build_trouble ]]; then
    {
        echo "makemkv-status: BUILD EXPIRED -- MakeMKV CANNOT DECRYPT DISCS AT ALL"
        while IFS= read -r line; do
            echo "makemkv-status:   $line"
        done <<<"$build_trouble"
        echo "makemkv-status:   No key fixes this: nixpkgs is behind upstream. Either"
        echo "makemkv-status:   register a purchased key, or override pkgs.makemkv with a"
        echo "makemkv-status:   newer version and its src hashes."
    } >&2
    exit 1
fi

echo "makemkv-status: build OK, not expired"
