#!/bin/bash
set -ex

version=$(<VERSION) # Read version of Dockerfile from file VERSION
image_tag="openworm/openworm:${version}-local"
container_name="openworm_${version}_local"

duration=""
configuration=""
c302params=""
reference=""
noc302=0
mount_local=0

#from: https://unix.stackexchange.com/a/129401
while getopts ":d:c:np:r:m" opt; do
  case "${opt}" in
    d) duration="$OPTARG"
    ;;
    c) configuration="$OPTARG"
    ;;
    n) noc302=1
    ;;
    p) c302params="$OPTARG"
    ;;
    r) reference="$OPTARG"
    ;;
    m) mount_local=1
    ;;
    *) echo "Usage: $0 [-d duration_in_ms] [-c configuration] [-n] [-p c302params] [-r reference] [-m]" >&2
       exit 1
    ;;
  esac
done

if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
    echo "Image $image_tag not found. Run ./build.sh first." >&2
    exit 1
fi

OW_OUT_DIR=/home/ow/shared
HOST_OUT_DIR=$PWD

if command -v xhost >/dev/null 2>&1; then
    xhost + || true # allow connections to X server, don't throw an error if it fails
fi

# Check if the openworm container already exists
if docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
    echo -e "\n**************\n  Docker container $container_name already exists.\n  Please stop and remove it before running a new one (run: ./stop.sh).\n**************"
    exit 1
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

if [ -n "$configuration" ]; then
    DOCKER_ARGS+=("-e" "CONFIGURATION=$configuration")
fi

if [ -n "$duration" ]; then
    DOCKER_ARGS+=("-e" "DURATION=$duration")
fi

if [ "$noc302" -eq 1 ]; then
    DOCKER_ARGS+=("-e" "NOC302=1")
fi

if [ -n "$c302params" ]; then
    DOCKER_ARGS+=("-e" "C302_PARAMS=$c302params")
fi

if [ -n "$reference" ]; then
    DOCKER_ARGS+=("-e" "REFERENCE=$reference")
fi

if [ "$mount_local" -eq 1 ]; then
    if [ ! -d "$PWD/c302/c302" ]; then
        echo "Error: $PWD/c302/c302 not found. Initialize the c302 submodule first." >&2
        exit 1
    fi
    DOCKER_ARGS+=("-v" "$PWD/c302:/home/ow/c302:rw")
    DOCKER_ARGS+=("-v" "$PWD/master_openworm.py:/home/ow/master_openworm.py:ro")
fi

echo "Running Docker container $container_name ($image_tag)"

docker run -d \
  --name "$container_name" \
  -e "DISPLAY=${DISPLAY:-}" \
  -e "OW_OUT_DIR=$OW_OUT_DIR" \
  --privileged \
  -v "$HOST_OUT_DIR:$OW_OUT_DIR:rw" \
  "${DOCKER_ARGS[@]}" \
  "$image_tag" \
  bash -c "DISPLAY=:44 python3 master_openworm.py"

echo "Set running Docker container with Sibernetic in detached mode. Attaching to logs now..."

docker logs -f "$container_name"

echo "Finished running the Docker container"

last_dir=$(ls -td output/*/ | head -n 1)
echo "Last created simulation directory: $last_dir"

if [ -f "$last_dir/report.json" ] && grep -q "ompleted successfully" "$last_dir/report.json"; then
    echo "Simulation has completed successfully."
else
    echo "Simulation has exited with an error."
    exit 1
fi
