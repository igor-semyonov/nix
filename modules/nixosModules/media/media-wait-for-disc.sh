# Block until DEVICE holds a readable disc, or fail after TIMEOUT seconds.
# Lets a rip be queued before the disc goes in.

device=${1:?usage: media-wait-for-disc DEVICE TIMEOUT_SECONDS}
timeout=${2:?usage: media-wait-for-disc DEVICE TIMEOUT_SECONDS}
waited=0

# The UDF filesystem is readable even on an AACS-encrypted disc, so a
# one-sector read distinguishes loaded-and-spun-up from empty or still
# spinning up.
while ! dd if="$device" of=/dev/null bs=2048 count=1 status=none 2>/dev/null; do
    if ((waited >= timeout)); then
        echo "no readable disc in $device after ${timeout}s" >&2
        exit 1
    fi
    ((waited == 0)) && echo "waiting for a disc in $device..." >&2
    sleep 5
    waited=$((waited + 5))
done
