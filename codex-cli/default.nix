{
  pkgs,
  monorepo-deps,
  ...
}:
let
  node = pkgs.nodejs_22;
  pnpm = pkgs.pnpm;
in
rec {
  package = pkgs.stdenv.mkDerivation {
    pname = "codex-cli";
    version = "0.1.0";
    # Use parent directory to include workspace files
    src = ../.;

    nativeBuildInputs = [
      node
      pnpm.configHook
      pkgs.typescript
    ];

    pnpmDeps = pnpm.fetchDeps {
      inherit (package) pname version;
      src = package.src;
      hash = "sha256-SyKP++eeOyoVBFscYi+Q7IxCphcEeYgpuAj70+aCdNA=";
    };

    buildPhase = ''
      runHook preBuild
      # Build the specific workspace package
      pnpm --filter @openai/codex run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin

      # Copy the built files
      cp -r codex-cli/dist $out/
      cp -r codex-cli/bin $out/
      cp codex-cli/package.json $out/

      # Make the binary executable and link it
      chmod +x $out/bin/codex.js
      ln -s $out/bin/codex.js $out/bin/codex

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "OpenAI Codex command‑line interface";
      license = licenses.asl20;
      homepage = "https://github.com/openai/codex";
    };
  };

  devShell = pkgs.mkShell {
    name = "codex-cli-dev";
    buildInputs = monorepo-deps ++ [
      node
      pnpm
    ];
    shellHook = ''
      echo "Entering development shell for codex-cli"
      if [ -f pnpm-lock.yaml ]; then
        pnpm install || echo "pnpm install failed"
      else
        echo "No pnpm-lock.yaml found"
      fi
      pnpm --filter @openai/codex run build || echo "pnpm build failed"
      export PATH=$PWD/node_modules/.bin:$PATH
      alias codex="node $PWD/codex-cli/dist/cli.js"
    '';
  };

  app = {
    type = "app";
    program = "${package}/bin/codex";
  };
}
