{...}: {
  # Darwin is included because homeModules.git indexes
  # self.packages.<system>.git-worktree-scripts, and a mac home-manager config
  # consuming this flake needs that package to exist for its own system.
  systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
}
