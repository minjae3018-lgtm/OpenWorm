#!/bin/bash
set -e

version=$(<VERSION) # Read version of Dockerfile from file VERSION

if [ ! -f "./c302/setup.py" ]; then
    echo "Error: ./c302/setup.py not found." >&2
    echo "Initialize the c302 submodule first: git submodule update --init --recursive" >&2
    exit 1
fi

# Set the platform flag if we're on ARM
PLATFORM_ARGS=()
arch=$(uname -m)
if [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
    PLATFORM_ARGS=("--platform" "linux/amd64")
fi

dockerfile="Dockerfile.local"
extra_args=("--build-arg" "BASE_IMAGE=openworm/openworm:$version")
pull_c302=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pull)
            pull_c302=1
            shift
            ;;
        --full)
            dockerfile="Dockerfile"
            extra_args=()
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$pull_c302" -eq 1 ]; then
    echo "Pulling latest changes in ./c302 from origin..."
    git -C ./c302 pull --ff-only
fi

if [[ "$dockerfile" == "Dockerfile.local" ]] && ! docker image inspect "openworm/openworm:$version" >/dev/null 2>&1; then
    echo "Base image openworm/openworm:$version not found locally; Docker will pull it (or pass --full to build from scratch)."
fi

image_tag="openworm/openworm:${version}-local"

# Build the Docker image
docker build "${PLATFORM_ARGS[@]}" -f "$dockerfile" "${extra_args[@]}" "$@" -t "$image_tag" .
