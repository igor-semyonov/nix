{
  flake.homeModules.flatten-pdf = {
    pkgs,
    lib,
    ...
  }: let
    flatten-pdf = pkgs.writeShellApplication {
      name = "flatten-pdf";
      runtimeInputs = [pkgs.qpdf];
      text = ''
        usage() {
          cat <<'EOF'
        flatten-pdf — flatten annotations and form fields into page content.

          flatten-pdf [-o OUT] [-f] IN.pdf [-- qpdf-args...]

          -o OUT  output path (default: IN with ".pdf" replaced by "-flat.pdf")
          -f      overwrite OUT if it exists
          -h      this help

        Annotations lacking an /AP appearance stream cannot be flattened and are
        dropped; flatten-pdf warns when the annotation count changes unexpectedly.
        EOF
        }

        out=""
        force=0

        while getopts ":o:fh" opt; do
          case "$opt" in
            o) out="$OPTARG" ;;
            f) force=1 ;;
            h) usage; exit 0 ;;
            :) echo "flatten-pdf: -$OPTARG requires an argument" >&2; exit 2 ;;
            *) echo "flatten-pdf: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
          esac
        done
        shift $((OPTIND - 1))

        if [ $# -lt 1 ]; then
          usage >&2
          exit 2
        fi

        in=$1
        shift

        [ -r "$in" ] || { echo "flatten-pdf: cannot read '$in'" >&2; exit 1; }

        if [ -z "$out" ]; then
          out="''${in%.pdf}-flat.pdf"
          [ "$out" != "$in" ] || out="$in.flat.pdf"
        fi

        if [ "$(readlink -f -- "$in")" = "$(readlink -f -- "$out" 2>/dev/null || echo "$out")" ]; then
          echo "flatten-pdf: refusing to write output over input" >&2
          exit 1
        fi

        if [ -e "$out" ] && [ "$force" -ne 1 ]; then
          echo "flatten-pdf: '$out' exists (use -f to overwrite)" >&2
          exit 1
        fi

        # Count /Annot objects before and after to catch silently dropped markup.
        count_annots() {
          qpdf --warning-exit-0 --qdf --object-streams=disable "$1" - 2>/dev/null \
            | grep -c '/Type\s*/Annot' || true
        }

        before=$(count_annots "$in")

        qpdf --warning-exit-0 \
          --flatten-annotations=all \
          --generate-appearances \
          --object-streams=generate \
          "$in" "$out" "$@"

        after=$(count_annots "$out")

        if [ "$before" -gt 0 ] && [ "$after" -gt 0 ]; then
          echo "flatten-pdf: warning: $after of $before annotation(s) survived flattening;" >&2
          echo "  they likely lack /AP. Try: gs -sDEVICE=pdfwrite -dPreserveAnnots=false -o OUT IN" >&2
          echo "  or: pdftocairo -pdf IN OUT" >&2
        fi

        echo "$out"
      '';

      meta = {
        description = "Flatten PDF annotations into page content with qpdf";
        mainProgram = "flatten-pdf";
        license = lib.licenses.mit;
        platforms = lib.platforms.all;
      };
    };
  in {
    home.packages = [flatten-pdf];
  };
}
