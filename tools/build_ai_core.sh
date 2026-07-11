#!/bin/zsh
set -euo pipefail
if [[ -n "${DOTNET_ROOT:-}" && -x "$DOTNET_ROOT/dotnet" ]]; then
  export DOTNET_ROOT="$DOTNET_ROOT"
elif [[ -x "/opt/homebrew/opt/dotnet/libexec/dotnet" ]]; then
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
elif [[ -x "/tmp/dotnet10_root/dotnet" ]]; then
  export DOTNET_ROOT="/tmp/dotnet10_root"
elif [[ -x "/private/tmp/dotnet11_root/dotnet" ]]; then
  export DOTNET_ROOT="/private/tmp/dotnet11_root"
else
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet@9/libexec"
fi
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-Major}"
export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/sdk:/opt/homebrew/bin:$PATH"
project_root="/Volumes/AI/Codex/四川麻将工程_20260701_v2"
"$DOTNET_ROOT/dotnet" build "$project_root/dotnet/AI.Core/AI.Core.csproj" -c Release
"$DOTNET_ROOT/dotnet" build "$project_root/dotnet/AI.Core.Cli/AI.Core.Cli.csproj" -c Release
"$DOTNET_ROOT/dotnet" run --project "$project_root/dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj" -c Release
