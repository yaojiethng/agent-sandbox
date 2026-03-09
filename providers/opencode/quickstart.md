# Quick Start

This guide explains how to run OpenCode safely using the sandboxing setup in this repository.

## Frequently used commands
```sh
docker run --rm -it opencode-agent-image:latest bash
docker exec -it opencode-agent-project-example bash

./build_agent.sh project-example
./start_agent.sh project-example safe --build --serve

./start_agent.sh project-example safe --build --serve

docker logs -f opencode-agent-agent-sandbox

cat -A /mnt/m/Projects/dotfiles/agent-sandbox/projects/agent-sandbox/opencode.wsl.conf
sed -i 's/\r//' /mnt/m/Projects/dotfiles/agent-sandbox/projects/agent-sandbox/opencode.wsl.conf

# debug makefile
make --debug=basic build 
```

