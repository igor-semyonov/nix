# Report whether MakeMKV can actually decrypt a disc right now.
#
# Two independent clocks can stop it: the registration key, and the build
# itself, which self-expires roughly 60 days after release regardless of the
# key. nixpkgs ships new versions every two to six months, so the second one
# bites on a flake-pinned system and does it silently -- makemkvcon exits 0
# even when it has failed, so only the MSG lines say anything useful.

probe_home=$(mktemp -d)
trap 'rm -rf "$probe_home"' EXIT

# Self-contained: build the key into a throwaway HOME rather than relying on
# the worker having written one, so this is also meaningful run by hand.
if [[ -n ${MAKEMKV_KEY_FILE:-} && -r ${MAKEMKV_KEY_FILE:-} ]]; then
    mkdir -p "$probe_home/.MakeMKV"
    printf 'app_Key = "%s"\n' "$(tr -d '[:space:]' <"$MAKEMKV_KEY_FILE")" \
        >"$probe_home/.MakeMKV/settings.conf"
    chmod 0600 "$probe_home/.MakeMKV/settings.conf"
    key_state="key: $MAKEMKV_KEY_FILE"
elif [[ -n ${MAKEMKV_KEY_FILE:-} ]]; then
    key_state="key: $MAKEMKV_KEY_FILE not readable by $(id -un), checking build expiry only"
else
    key_state="key: none configured, running unregistered"
fi

# disc:9999 never matches a drive, so this probes the program without needing
# a disc or spinning anything up.
output=$(HOME=$probe_home makemkvcon -r --cache=1 info disc:9999 2>&1 || true)

# MSG:<code>,<flags>,<count>,"<text>",... -- the first quoted field is the text.
messages=$(sed -nE 's/^MSG:[0-9]+,[^,]*,[^,]*,"([^"]*)".*/\1/p' <<<"$output")

version=$(grep -m1 -oE 'MakeMKV v[0-9.]+' <<<"$messages" || true)
echo "makemkv-status: ${version:-version unknown} -- $key_state"

# "expires on <date>" is the normal beta banner and must not trip this; only
# past-tense failures do.
trouble=$(grep -iE 'expired|too old|registration key|not activated|evaluation period' <<<"$messages" |
    grep -viE 'expires on|will expire' || true)

if [[ -z $trouble ]]; then
    echo "makemkv-status: OK, no expiry or registration problem reported"
    exit 0
fi

{
    echo "makemkv-status: MakeMKV CANNOT DECRYPT DISCS RIGHT NOW"
    while IFS= read -r line; do
        echo "makemkv-status:   $line"
    done <<<"$trouble"
    echo "makemkv-status:"
    echo "makemkv-status: fixes, most durable first:"
    echo "makemkv-status:  1. buy a key (https://makemkv.com/buy/) -- a registered"
    echo "makemkv-status:     build does not self-expire, then install it with:"
    echo "makemkv-status:       sudo install -o ${MEDIA_RIP_USER:-media-rip} \\"
    echo "makemkv-status:         -g ${MEDIA_RIP_GROUP:-media} -m 0400 /dev/stdin \\"
    echo "makemkv-status:         ${MAKEMKV_KEY_FILE:-/var/lib/media-ripping/makemkv.key} <<<'THE-KEY'"
    echo "makemkv-status:  2. refresh the free beta key from the MakeMKV forum"
    echo "makemkv-status:     (thread 'MakeMKV is free while in beta'), same command"
    echo "makemkv-status:  3. if the BUILD expired rather than the key, no key helps:"
    echo "makemkv-status:     nixpkgs is behind upstream. Override pkgs.makemkv with a"
    echo "makemkv-status:     newer version and its src hashes."
} >&2

exit 1
