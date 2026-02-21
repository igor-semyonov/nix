import subprocess
import sys


def main():
    current_zoom_factor = get_current_zoom_factor()
    direction, amount = sys.argv[1:]
    amount = float(amount)
    new_zoom_factor = current_zoom_factor + (1 if direction == "in" else -1) * amount
    new_zoom_factor = max(new_zoom_factor, 1.0)
    new_zoom_factor = min(new_zoom_factor, 10.0)
    subprocess.run(
        [
            "hyprctl",
            "--batch",
            "keyword",
            "cursor:zoom_factor",
            str(new_zoom_factor),
        ]
    )


def get_current_zoom_factor():
    stdout = (
        subprocess.run(
            ["hyprctl", "--batch", "getoption", "cursor:zoom_factor"],
            capture_output=True,
        )
        .stdout.decode("utf-8")
        .split("\n")
    )
    for line in stdout:
        try:
            key, value = line.split(":")
        except ValueError:
            continue
        key = key.strip()
        value = value.strip()
        if key == "float":
            return float(value)


if __name__ == "__main__":
    main()
