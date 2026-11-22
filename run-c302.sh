#!/bin/bash
set -e

version=$(<VERSION)
image_tag="openworm/openworm:${version}-local"

c302params="C2"
reference="IClamp"
duration="100"
dt="0.05"
mount_local=0

while getopts ":p:r:d:t:m" opt; do
  case "${opt}" in
    p) c302params="$OPTARG"
    ;;
    r) reference="$OPTARG"
    ;;
    d) duration="$OPTARG"
    ;;
    t) dt="$OPTARG"
    ;;
    m) mount_local=1
    ;;
    *) echo "Usage: $0 [-p c302params (A|B|C|C2|D|D1)] [-r reference (IClamp|Syns|Pharyngeal|Oscillator|Full|Muscles|FW|...)] [-d duration_in_ms] [-t dt_in_ms] [-m]" >&2
       exit 1
    ;;
  esac
done

if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
    echo "Image $image_tag not found. Run ./build.sh first." >&2
    exit 1
fi

DOCKER_ARGS=()

arch=$(uname -m)
if [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
    DOCKER_ARGS+=("--platform" "linux/amd64")
fi

if [ "$mount_local" -eq 1 ]; then
    if [ ! -d "$PWD/c302/c302" ]; then
        echo "Error: $PWD/c302/c302 not found. Initialize the c302 submodule first." >&2
        exit 1
    fi
    DOCKER_ARGS+=("-v" "$PWD/c302:/home/ow/c302:rw")
fi

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
rel_out_dir="output/c302_${c302params}_${reference}_${timestamp}"
mkdir -p "$PWD/$rel_out_dir"

echo "Running standalone c302 simulation: params=$c302params, reference=$reference, duration=${duration}ms, dt=${dt}ms"
echo "Output directory: $rel_out_dir"

docker run --rm \
  -e MPLBACKEND=Agg \
  -e C302_PARAMS="$c302params" \
  -e REFERENCE="$reference" \
  -e DURATION="$duration" \
  -e DT="$dt" \
  -e REL_OUT_DIR="$rel_out_dir" \
  -v "$PWD:/home/ow/shared:rw" \
  "${DOCKER_ARGS[@]}" \
  "$image_tag" \
  bash -c 'python3 - << "PYEOF"
import os
import glob
import shutil
import c302
import c302.runAndPlot as rp

params = os.environ["C302_PARAMS"]
ref = os.environ["REFERENCE"]
duration = float(os.environ["DURATION"])
dt = float(os.environ["DT"])
host_out = os.path.join("/home/ow/shared", os.environ["REL_OUT_DIR"])
work_dir = "/tmp/c302_sim_work"

print("Using c302 v%s from %s" % (c302.__version__, c302.__file__))
os.makedirs(work_dir, exist_ok=True)
os.makedirs(host_out, exist_ok=True)

data_reader = c302.FW_DATA_READER if ref == "FW" else c302.DEFAULT_DATA_READER

rp.save_image_full_dir = work_dir
rp.run_c302(
    ref,
    params,
    "",
    duration,
    dt,
    "jNeuroML_NEURON",
    save=True,
    show_plot_already=False,
    data_reader=data_reader,
    target_directory=work_dir,
    save_fig_to=work_dir,
)

patterns = ["*.png", "*.dat", "*.nml", "*.xml", "*.hoc", "*.mod", "*_nrn.py"]
copied = 0
for pattern in patterns:
    for fpath in glob.glob(os.path.join(work_dir, pattern)):
        shutil.copy2(fpath, host_out)
        copied += 1

print("Saved %d simulation output files to %s" % (copied, os.environ["REL_OUT_DIR"]))
PYEOF'

echo "Standalone c302 simulation completed. Results saved in: $rel_out_dir"
