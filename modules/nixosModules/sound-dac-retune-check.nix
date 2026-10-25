{
  self,
  lib,
  ...
}: {
  # VM test of dac-retune against real pipewire/wireplumber. snd-aloop clocks up to
  # 192k, snd-dummy stops at 48k, and /proc/asound hw_params is the ground truth for
  # what the device actually runs at. Linux VMs only, so x86_64-linux alone.
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      sound-dac-retune = let
        interval = 1;
        cooldown = 2;
        aloop = "~alsa_output\\..*snd_aloop.*";
        dummy = "~alsa_output\\..*snd_dummy.*";

        # Independent of dac-retune: logs each restart of the card's playback PCM,
        # i.e. each new trigger_time in /proc/asound status, with the states passed
        # through on the way. A retune does not always close the PCM or change its
        # hw_params -- with the rate unchanged it is only re-prepared -- so neither
        # of those is a reliable count.
        hwRestarts = pkgs.writers.writePython3Bin "hw-restarts" {} ''
          import sys
          import time

          path = f"/proc/asound/{sys.argv[1]}/pcm0p/sub0/status"


          def status():
              with open(path) as f:
                  pairs = [x.split(":", 1) for x in f if ":" in x]
              return {k.strip(): v.strip() for k, v in pairs}


          now = status()
          last = now.get("trigger_time") if now.get("state") == "RUNNING" else None
          via = set()
          with open(sys.argv[2], "a", buffering=1) as log:
              while True:
                  now = status()
                  state = now.get("state", "closed")
                  if state != "RUNNING":
                      via.add(state)
                  elif now.get("trigger_time") != last:
                      log.write(f"restart via {sorted(via)}\n")
                      last, via = now.get("trigger_time"), set()
                  time.sleep(0.001)
        '';

        # Runs the sink_allowed function out of a built dac-retune script.
        sinkAllowed = pkgs.writeShellApplication {
          name = "sink-allowed";
          runtimeInputs = [pkgs.gnused pkgs.gawk pkgs.pulseaudio];
          text = ''
            eval "$(sed -n '/^sink_allowed() {/,/^}/p' "$1")"
            sink_allowed "$2"
          '';
        };
      in
        pkgs.testers.runNixOSTest {
          name = "sound-dac-retune";

          defaults = {
            imports = [self.nixosModules.sound];
            boot.kernelModules = ["snd-aloop" "snd-dummy"];
            igix.sound.autoRetune = {inherit interval cooldown;};
            users.users.alice = {
              isNormalUser = true;
              linger = true;
              extraGroups = ["audio"];
            };
            # mpv --pause is the corked stream.
            environment.systemPackages = [pkgs.mpv hwRestarts sinkAllowed];
            virtualisation = {
              vlans = [];
              # Headroom for the 1ms /proc/asound poll next to pipewire.
              cores = 2;
            };
          };

          nodes = {
            # S1 S2 S5 S6
            declared = {
              igix.sound.devices = {
                loop = {
                  match = aloop;
                  allowedRates = [44100 48000 96000];
                };
                dummy = {
                  match = dummy;
                  allowedRates = [48000];
                  rate = 48000;
                };
              };
            };
            # S3: the node allows 96k but the graph clock cannot select it.
            narrow = {
              igix.sound.devices.loop = {
                match = aloop;
                allowedRates = [44100 48000 96000];
              };
              igix.sound.allowedRates = [44100 48000];
            };
            # S4: nothing declared, so the graph list (with 96k) is all the watcher
            # knows, and the dummy cannot clock 96k.
            undeclared = {};
          };

          testScript = {nodes, ...}: ''
            import json
            import re
            import time

            INTERVAL = ${toString interval}
            COOLDOWN = ${toString cooldown}
            SETTLE = 3 * (COOLDOWN + INTERVAL)
            RETUNE = "${nodes.declared.systemd.user.services.dac-retune.serviceConfig.ExecStart}"


            class Fail(Exception):
                pass


            def check(ok, msg):
                if not ok:
                    raise Fail(msg)


            def u(cmd):
                return (
                    "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 "
                    "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus " + cmd
                )


            def boot(m):
                m.wait_for_unit("user@1000.service")
                m.succeed(u("systemctl --user start pipewire wireplumber pipewire-pulse"))
                for drv in ("snd_aloop", "snd_dummy"):
                    m.wait_until_succeeds(u(f"pactl list short sinks | grep -q {drv}"), timeout=120)
                m.wait_until_succeeds(u("systemctl --user is-active dac-retune"), timeout=60)


            def use_sink(m, drv):
                for line in m.succeed(u("pactl list short sinks")).splitlines():
                    f = line.split("\t")
                    if drv in f[1]:
                        m.succeed(u(f"pactl set-default-sink {f[1]}"))
                        return f[0], f[1]
                raise Fail(f"no {drv} sink")


            def hw_rate(m, card):
                hw = m.succeed(f"cat /proc/asound/{card}/pcm0p/sub0/hw_params")
                r = re.search(r"^rate: (\d+)", hw, re.M)
                return int(r.group(1)) if r else hw.strip()


            def field(pattern, text):
                found = re.search(pattern, text, re.M)
                if found is None:
                    raise Fail(f"no {pattern!r} in {text!r}")
                return found.group(1)


            def inputs(m):
                found = []
                for block in m.succeed(u("pactl list sink-inputs")).split("Sink Input #")[1:]:
                    found.append((
                        field(r"^\s*Sink: (\d+)", block),
                        int(field(r"Sample Specification: .* (\d+)Hz", block)),
                        field(r"^\s*Corked: (\w+)", block),
                    ))
                return found


            def expect_input(m, idx, rate, corked):
                deadline = time.monotonic() + 30
                while (idx, rate, corked) not in inputs(m):
                    check(
                        time.monotonic() < deadline,
                        f"precondition: no {rate} Hz stream with Corked: {corked} on sink #{idx}: {inputs(m)}",
                    )
                    time.sleep(0.2)


            def journal(m):
                lines = m.execute("journalctl -q -o cat _SYSTEMD_USER_UNIT=dac-retune.service")[1].splitlines()
                return (
                    [l for l in lines if l.startswith("retune ")],
                    [l for l in lines if l.startswith("give up ")],
                )


            class Watch:
                """Retune and give-up lines since start, and PCM restarts seen by hw-restarts."""

                def __init__(self, m, card, tag):
                    self.m, self.card = m, card
                    self.log, self.unit = f"/tmp/restarts-{tag}", f"restarts-{tag}"
                    self.retunes, self.giveups = (len(x) for x in journal(m))
                    m.succeed(f"rm -f {self.log} && touch {self.log}")
                    m.succeed(f"systemd-run --unit={self.unit} hw-restarts {card} {self.log}")

                def counts(self):
                    time.sleep(0.5)
                    self.m.succeed(f"systemctl is-active {self.unit}")
                    r, g = journal(self.m)
                    restarts = self.m.succeed(f"cat {self.log}").splitlines()
                    # An xrun recovery restarts the PCM too, but is not a retune. One quick
                    # enough to fall between polls shows no state at all, which a retune --
                    # 0.3 s suspended -- never does.
                    n = sum("XRUN" not in x and "[]" not in x for x in restarts)
                    print(
                        f"{self.unit}: journal {r[self.retunes:] + g[self.giveups:]}, restarts {restarts}, "
                        f"hw {hw_rate(self.m, self.card)}, pactl {self.m.succeed(u('pactl list short sinks'))!r}"
                    )
                    return len(r) - self.retunes, len(g) - self.giveups, n

                def stop(self):
                    self.m.succeed(f"systemctl stop {self.unit}")


            def play(m, unit, rate, channels=2):
                m.succeed(u(
                    f"systemd-run --user --unit={unit} pacat --playback --raw --rate={rate} "
                    f"--channels={channels} --format=s16le /dev/zero"
                ))


            def play_corked(m, unit, rate):
                m.succeed(u(
                    f"systemd-run --user --unit={unit} mpv --no-config --no-terminal --no-video "
                    f"--pause --ao=pulse av://lavfi:sine=frequency=440:sample_rate={rate}"
                ))


            def stop(m, *units):
                m.succeed(u("systemctl --user stop " + " ".join(units)))


            def wait_rate(m, card, rate, timeout=30):
                deadline = time.monotonic() + timeout
                while hw_rate(m, card) != rate and time.monotonic() < deadline:
                    time.sleep(0.2)
                return hw_rate(m, card)


            def s6():
                m = declared
                idx, name = use_sink(m, "snd_aloop")
                check(inputs(m) == [], f"precondition: streams present: {inputs(m)}")
                node = [
                    o for o in json.loads(m.succeed(u("pw-dump")))
                    if o["type"] == "PipeWire:Interface:Node"
                    and o["info"]["props"].get("node.name") == name
                ][0]["info"]
                props = node["props"]
                check(props.get("session.suspend-timeout-seconds") == 0,
                      f"session.suspend-timeout-seconds = {props.get('session.suspend-timeout-seconds')!r}")
                check(props.get("node.always-process") is True,
                      f"node.always-process = {props.get('node.always-process')!r}")
                state = [l.split("\t")[4] for l in m.succeed(u("pactl list short sinks")).splitlines() if name in l]
                print(f"S6: pw-dump state {node['state']}, pactl state {state}")
                check(node["state"] == "running", f"idle sink state {node['state']}")
                check(hw_rate(m, "Loopback") == 44100, f"idle hw_params {hw_rate(m, 'Loopback')}")
                allowed = m.succeed(u(f"sink-allowed {RETUNE} {name}")).split()
                check(allowed == ["44100", "48000", "96000"], f"sink_allowed printed {allowed}")


            def s5():
                m = declared
                idx, name = use_sink(m, "snd_aloop")
                check(hw_rate(m, "Loopback") == 44100, f"precondition: hw {hw_rate(m, 'Loopback')}")
                w = Watch(m, "Loopback", "s5")
                play(m, "s5-16k", 16000, channels=1)
                play_corked(m, "s5-96k", 96000)
                try:
                    expect_input(m, idx, 16000, "no")
                    expect_input(m, idx, 96000, "yes")
                    time.sleep(SETTLE)
                    r, g, n = w.counts()
                    check((r, g, n) == (0, 0, 0), f"retunes {r}, give-ups {g}, restarts {n}; want 0 0 0")
                    check(hw_rate(m, "Loopback") == 44100, f"hw {hw_rate(m, 'Loopback')}")
                finally:
                    stop(m, "s5-16k", "s5-96k")
                    w.stop()


            def s2():
                m = declared
                idx, name = use_sink(m, "snd_dummy")
                check(hw_rate(m, "Dummy") == 48000, f"precondition: hw {hw_rate(m, 'Dummy')}")
                w = Watch(m, "Dummy", "s2")
                play(m, "s2-44k", 44100)
                try:
                    expect_input(m, idx, 44100, "no")
                    time.sleep(SETTLE)
                    r, g, n = w.counts()
                    check((r, g, n) == (0, 0, 0), f"retunes {r}, give-ups {g}, restarts {n}; want 0 0 0")
                    check(hw_rate(m, "Dummy") == 48000, f"hw {hw_rate(m, 'Dummy')}")
                finally:
                    stop(m, "s2-44k")
                    w.stop()


            def s1():
                m = declared
                idx, name = use_sink(m, "snd_aloop")
                check(hw_rate(m, "Loopback") == 44100, f"precondition: hw {hw_rate(m, 'Loopback')}")
                w = Watch(m, "Loopback", "s1")
                play(m, "s1-96k", 96000)
                try:
                    expect_input(m, idx, 96000, "no")
                    check(wait_rate(m, "Loopback", 96000) == 96000, f"hw {hw_rate(m, 'Loopback')}")
                    time.sleep(SETTLE)
                    r, g, n = w.counts()
                    check((r, g, n) == (1, 0, 1), f"retunes {r}, give-ups {g}, restarts {n}; want 1 0 1")
                    check(hw_rate(m, "Loopback") == 96000, f"hw {hw_rate(m, 'Loopback')}")
                finally:
                    stop(m, "s1-96k")
                    w.stop()


            def s3():
                m = narrow
                idx, name = use_sink(m, "snd_aloop")
                check(hw_rate(m, "Loopback") == 44100, f"precondition: hw {hw_rate(m, 'Loopback')}")
                w = Watch(m, "Loopback", "s3")
                play(m, "s3-96k", 96000)
                try:
                    expect_input(m, idx, 96000, "no")
                    time.sleep(SETTLE)
                    r, g, n = w.counts()
                    check((r, g, n) == (0, 0, 0), f"retunes {r}, give-ups {g}, restarts {n}; want 0 0 0")
                finally:
                    stop(m, "s3-96k")
                    w.stop()


            def s4():
                m = undeclared
                idx, name = use_sink(m, "snd_dummy")
                check(hw_rate(m, "Dummy") == 44100, f"precondition: hw {hw_rate(m, 'Dummy')}")
                w = Watch(m, "Dummy", "s4")
                play(m, "s4-96k", 96000)
                try:
                    expect_input(m, idx, 96000, "no")
                    # Debounce, one attempt, cooldown and the verifying poll take ~5 s, more on
                    # a loaded builder. Bounded, as a watcher that never gives up logs nothing.
                    deadline = time.monotonic() + 60
                    while len(journal(m)[1]) == w.giveups and time.monotonic() < deadline:
                        time.sleep(0.5)
                    first = w.counts()
                    time.sleep(SETTLE)
                    r, g, n = w.counts()
                    check(r == n, f"retune lines {r} but restarts {n}")
                    check(r <= 1 and g == 1, f"retunes {r}, give-ups {g}; want at most 1 and exactly 1")
                    check((r, g, n) == first, f"still acting after the give-up: {first} -> {(r, g, n)}")
                    check(hw_rate(m, "Dummy") != 96000, f"hw {hw_rate(m, 'Dummy')}")
                finally:
                    stop(m, "s4-96k")
                    w.stop()


            start_all()
            for m in (declared, narrow, undeclared):
                boot(m)

            results = {}
            for name, fn in (("S6", s6), ("S5", s5), ("S2", s2), ("S1", s1), ("S3", s3), ("S4", s4)):
                try:
                    fn()
                    results[name] = "PASS"
                except Exception as e:
                    results[name] = f"FAIL: {e}"
                print(f"{name} {results[name]}")

            for name in sorted(results):
                print(f"RESULT {name} {results[name]}")
            failed = sorted(n for n, r in results.items() if r != "PASS")
            assert not failed, f"failed scenarios: {failed}"
          '';
        };
    };
  };
}
