{pkgs, ...}: {
  programs.anyrun = {
    enable = true;
    config = {
      x.fraction = 0.5;
      y.fraction = 0.3;
      width.fraction = 0.7;
      height.fraction = 0.3;

      closeOnClick = true;
      showResultsImmediately = false;
      plugins = [
        "libapplications.so"
        "libsymbols.so"
      ];
      maxEntries = 5;
      margin = 1;
    };
    extraCss = ''
      @define-color accent #5599d2;
      @define-color bg-color #161616;
      @define-color fg-color #eeeeee;
      @define-color desc-color #cccccc;

      window {
        background: transparent;
      }

      box.main {
        padding: 5px;
        margin: 10px;
        border-radius: 10px;
        border: 2px solid @accent;
        background-color: @bg-color;
        box-shadow: 0 0 5px black;
      }


      text {
        min-height: 30px;
        padding: 5px;
        border-radius: 5px;
        color: @fg-color;
      }

      .matches {
        background-color: rgba(0, 0, 0, 0);
        border-radius: 10px;
      }

      box.plugin:first-child {
        margin-top: 5px;
      }

      box.plugin.info {
        min-width: 200px;
      }

      list.plugin {
        background-color: rgba(0, 0, 0, 0);
      }

      label.match {
        font-size: 72px;
        color: @fg-color;
        icon-size: 64;
      }

      label.match.description {
        font-size: 64px;
        color: @desc-color;
      }

      label.plugin.info {
        font-size: 72px;
        color: @fg-color;
      }

      .match {
        background: transparent;
      }

      .match:selected {
        border-left: 4px solid @accent;
        background: transparent;
        animation: fade 0.1s linear;
      }

      @keyframes fade {
        0% {
          opacity: 0;
        }

        100% {
          opacity: 1;
        }
      }
    '';
  };
}
