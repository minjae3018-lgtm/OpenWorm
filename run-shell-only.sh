#!/bin/bash
set -e

version=$(<VERSION) # Read version of Dockerfile from file VERSION
image_tag="openworm/openworm:${version}-local"
container_name="openworm_${version}_local"

mount_local=0

while getopts ":m" opt; do
  case "${opt}" in
    m) mount_local=1
    ;;
    *) echo "Usage: $0 [-m]" >&2
       exit 1
    ;;
  esac
done

if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
    echo "Image $image_tag not found. Run ./build.sh first." >&2
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
    echo -e "\n**************\n  Docker container $container_name already exists.\n  Please stop and remove it before running a new one (run: ./stop.sh).\n**************"
    exit 1
fi

OW_OUT_DIR=/home/ow/shared
HOST_OUT_DIR=$PWD

if command -v xhost >/dev/null 2>&1; then
    xhost + || true
fi

DOCKER_ARGS=()

arch=$(uname -m)
if [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
    DOCKER_ARGS+=("--platform" "linux/amd64")
fi

if [ -d /dev/dri ]; then
    DOCKER_ARGS+=("--device=/dev/dri:/dev/dri")
fi

if [ -d /tmp/.X11-unix ]; then
    DOCKER_ARGS+=("-v" "/tmp/.X11-unix:/tmp/.X11-unix:rw")
fi

if [ "$mount_local" -eq 1 ]; then
    if [ ! -d "$PWD/c302/c302" ]; then
        echo "Error: $PWD/c302/c302 not found. Initialize the c302 submodule first." >&2
        exit 1
    fi
    DOCKER_ARGS+=("-v" "$PWD/c302:/home/ow/c302:rw")
    DOCKER_ARGS+=("-v" "$PWD/master_openworm.py:/home/ow/master_openworm.py:ro")
fi

docker run -ti \
  --name "$container_name" \
  -e "DISPLAY=${DISPLAY:-}" \
  -e "OW_OUT_DIR=$OW_OUT_DIR" \
  --privileged \
  -v "$HOST_OUT_DIR:$OW_OUT_DIR:rw" \
  "${DOCKER_ARGS[@]}" \
  "$image_tag" \
  bash
