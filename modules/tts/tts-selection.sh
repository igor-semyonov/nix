function tts-x() {
  echo x11
  tmp_dir=~/tmp-tts-dir
  mkdir $tmp_dir
  cd $tmp_dir
  xclip -o | ~/scripts/tts >~/scripts/tts.sh.out 2>&1
  cd ~
  rm -rf $tmp_dir
}

function tts-wayland() {
  echo wayland
  wl-paste -p | tts
}

# wl-paste && tts-wayland || tts-x
tts-wayland
