{
  packageOverrides = pkgs: with pkgs; {
    myPackages =
      pkgs.buildEnv {
        name = "dev-tools";
        paths = [
          python3
          uv
          jq
          lsof
          go
          nodejs_22
          tmux
          zsh-autosuggestions
          zsh-syntax-highlighting
        ];
      };
  };
}
