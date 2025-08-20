{
  pkgs,
  lib,
  outputs,
  ...
}: {
  programs.matplotlib = {
    enable = true;
    extraConfig = ''
      axes.grid:          True   # display grid or not
      axes.grid.axis:     both    # which axis the grid should apply to
      axes.grid.which:    major   # grid lines at {major, minor, both} ticks

      polaraxes.grid: True  # display grid on polar axes
      axes3d.grid:    True  # display grid on 3D axes

      xtick.minor.visible: True   # visibility of minor ticks on x-axis
      ytick.minor.visible: True   # visibility of minor ticks on y-axis
      grid.alpha:     0.4        # transparency, between 0.0 and 1.0

      lines.color: white
      patch.edgecolor: white

      text.color: white

      axes.facecolor: black
      axes.edgecolor: white
      axes.labelcolor: white
      axes.prop_cycle: cycler('color', ['orange', 'blue', 'green', 'teal', 'yellow', 'purple', 'pink'])

      xtick.color: white
      ytick.color: white

      grid.color: white

      figure.facecolor: black
      figure.edgecolor: black

      savefig.facecolor: black
      savefig.edgecolor: black

      boxplot.boxprops.color: white
      boxplot.capprops.color: white
      boxplot.flierprops.color: white
      boxplot.flierprops.markeredgecolor: white
      boxplot.whiskerprops.color: white
    '';
  };
}
