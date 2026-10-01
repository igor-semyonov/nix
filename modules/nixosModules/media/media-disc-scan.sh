# Scan an optical disc once and emit its label and title table as TSV. Shared by
# rip-titles and the rip worker so disc parsing lives in exactly one place; a
# Blu-ray scan takes the better part of a minute, so callers get everything they
# need from a single pass.
#
#   LABEL <tab> The Matrix
#   TITLE <tab> <index> <tab> <seconds> <tab> <h:mm:ss> <tab> <chapters> <tab> <size> <tab> <source> <tab> <segments>
#
# Three independent orderings exist and they disagree, so all three are
# emitted and none is authoritative:
#
#   <index>     MakeMKV's own numbering. Reordered by its main-title heuristic;
#               enumerated 00788.mpls before 00787.mpls on Dollhouse S1D1.
#   <source>    originating playlist/file (TINFO 16). Usually authoring order,
#               but Dollhouse S1D3 numbers Epitaph One 00799 ahead of the two
#               episodes that precede it.
#   <segments>  the .m2ts clip numbers the playlist draws from (TINFO 26),
#               i.e. physical layout. Correct on S1D3 where <source> was not.
#
# Episode numbering must never be inferred from one of these alone -- see the
# disagreement warning in rip-tv.

device=${1:?usage: media-disc-scan DEVICE MIN_LENGTH_SECONDS}
min_length=${2:?usage: media-disc-scan DEVICE MIN_LENGTH_SECONDS}

makemkvcon -r --cache=1 --noscan --minlength="$min_length" info "dev:$device" |
    awk '
    # Robot output is CODE:id,field,flags,"value"; values are the only quoted part.
    function unquote(s) { sub(/^[^"]*"/, "", s); sub(/"[[:space:]]*$/, "", s); return s }

    /^CINFO:2,/  { if (label == "") label = unquote($0) }
    /^CINFO:32,/ { if (volume == "") volume = unquote($0) }

    /^TINFO:/ {
      split(substr($0, 7), field, ",")
      id = field[1] + 0
      code = field[2] + 0
      if (code == 8)  chapters[id] = unquote($0)
      if (code == 9)  duration[id] = unquote($0)
      if (code == 10) size[id] = unquote($0)
      if (code == 16) src[id] = unquote($0)
      if (code == 26) seg[id] = unquote($0)
      seen[id] = 1
      if (id > highest) highest = id
    }

    END {
      printf "LABEL\t%s\n", (label != "" ? label : volume)
      for (i = 0; i <= highest; i++) {
        if (!(i in seen) || !(i in duration)) continue
        split(duration[i], hms, ":")
        printf "TITLE\t%d\t%d\t%s\t%s\t%s\t%s\t%s\n", \
          i, hms[1] * 3600 + hms[2] * 60 + hms[3], duration[i], chapters[i], size[i], \
          src[i], seg[i]
      }
    }
  '
