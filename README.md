# Building Containerfiles with Podman

This repo includes 2 Containerfiles:

- `golang-node-omz.Containerfile` - use for development fullstack golang + node pnpm + oh-my-zsh
- `uv-node-omz.Containerfile` - use for development fullstack astral-uv + node pnpm + oh-my-zsh

The steps below show how to build and run images with Podman on Windows (Podman Desktop/WSL2) or Linux.

## Prerequisites

- Podman installed
  - Windows: Install Podman Desktop (uses WSL2 under the hood)
  - Linux/macOS: Install Podman via your package manager
- If using Podman Desktop or `podman machine`, ensure the VM is running:

```bash
podman version
podman machine start
podman info
```

## Quick Start (build both images)

From the repo root, run:

```bash
# Build Go + Node + oh-my-zsh image
podman build -f golang-node-omz.Containerfile -t dev/golang-node-omz:latest .

# Build uv + Node + oh-my-zsh image
podman build -f uv-node-omz.Containerfile -t dev/uv-node-omz:latest .

# (optional) include your .ssh folder to serve your keys
podman build -f <Containerfile> -t <ImageName> . -v %USERPROFILE%\.ssh:/var/.ssh

# List images
podman images
```

## Run and verify

Run an interactive shell in each image (adjust shell to your preference):

```bash
# Go + Node image
podman run --rm -it dev/golang-node-omz:latest /bin/bash
# or, if the image config uses zsh
# podman run --rm -it dev/golang-node-omz:latest zsh

# uv + Node image
podman run --rm -it dev/uv-node-omz:latest /bin/bash
# podman run --rm -it dev/uv-node-omz:latest zsh
```

Inside the container, you can quickly verify tools (examples):

```bash
go version
node --version
npm --version
# If uv is included in the image
uv --version
```

Exit the container with `exit`.

## Tagging and pushing (optional)

If you want to push to a registry:

```bash
# Tag for your registry
podman tag dev/golang-node-omz:latest myregistry.example.com/dev/golang-node-omz:latest
podman tag dev/uv-node-omz:latest myregistry.example.com/dev/uv-node-omz:latest

# Login and push
podman login myregistry.example.com
podman push myregistry.example.com/dev/golang-node-omz:latest
podman push myregistry.example.com/dev/uv-node-omz:latest
```

## Build tips

- Choose a specific tag per build:
  ```bash
  podman build -f golang-node-omz.Containerfile -t dev/golang-node-omz:v1 .
  ```
- Rebuild with fresh layers:
  ```bash
  podman build --no-cache -f uv-node-omz.Containerfile -t dev/uv-node-omz:rebuild .
  ```
- Always pull newer bases:
  ```bash
  podman build --pull=newer -f golang-node-omz.Containerfile -t dev/golang-node-omz:latest .
  ```
- Select a target platform (if supported by your Podman/QEMU setup):
  ```bash
  podman build --platform linux/amd64 -f uv-node-omz.Containerfile -t dev/uv-node-omz:amd64 .
  ```

## Windows/WSL notes

- When using Podman Desktop, commands run in a managed Linux VM. Use the Podman Desktop terminal or any shell where `podman` is available.
- Ensure your workspace is accessible to the Podman VM. If building from Windows paths, Podman Desktop handles mounting automatically; otherwise, build from within WSL in the repo directory.
- If you see file mount errors, start the machine: `podman machine start` and retry.

## Import image into WSL

You can convert a Podman container into a WSL distro by exporting its root filesystem to a tar file and importing it with WSL.

```bash
# 1) Run the image to create/replace a named container
podman run --name <ContainerName> --replace <ImageName>

# 2) Export the container rootfs to a tar file
podman export -o <TarFile>.tar <ContainerName>

# (optional) Ensure WSL2 is used
wsl --set-version <DistroName> 2

# 3) Import the tar into WSL as a new distro
wsl --import <DistroName> <InstallLocation> <TarFile>.tar

# (optional) Launch the new distro
wsl -d <DistroName>

# (optional) Set as default
wsl --set-default <DistroName>

# Set toor as default user
wsl --manage <DistroName> --set-default-user toor
```

Notes:
- The imported distro typically starts as `root`. Configure users inside WSL as needed.
- `<InstallLocation>` should be an empty folder path on a Windows drive (e.g., `C:\Distros\mydev`).
- Use meaningful names for `<ContainerName>`/`<DistroName>` to keep multiple environments organized.

## Clean up

```bash
# Remove containers (none running due to --rm above)
# Remove images
podman rmi dev/golang-node-omz:latest dev/uv-node-omz:latest

# Prune dangling layers
podman system prune -f
```

## Troubleshooting

- "Cannot connect to Podman": run `podman machine start` (Podman Desktop) or ensure Podman service is active (Linux).
- Build context issues: run commands from the repo root; pass `-f <file>` explicitly since files are named `*.Containerfile`.
- Network timeouts during build: try `--pull=newer` or retry later; ensure VPN/proxy allows registry access.

---

If you'd like, you can ask to automate builds via a simple script or `Taskfile/Makefile` next.