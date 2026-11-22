# Custom `c302` Workflows & Multi-Level Simulation Commands

This repository uses your custom [`c302`](https://github.com/minjae3018-lgtm/c302) fork as a git submodule at [`./c302`](c302) and builds a fast layered Docker image (`openworm/openworm:0.9.8-local`) via [`Dockerfile.local`](Dockerfile.local).

For a complete breakdown of the biophysical equations (`C`/`C2` vs. 3D multicompartmental `D`/`D1`), inputs/outputs at every level, and parameter mappings for neurodegenerative disease modeling, see **[`SIMULATION_GUIDE.md`](SIMULATION_GUIDE.md)**.

---

## 1. Development & Git Workflows

How [`./build.sh`](build.sh) works with [`./c302`](c302):
- **Builds from local `./c302`**: `./build.sh` copies your local `./c302` folder directly into the Docker image (`COPY ./c302 /home/ow/c302`) in ~5 seconds. You do **not** need to commit or push to GitHub before testing locally.
- **Auto-pull from GitHub (`./build.sh --pull`)**: Passing `--pull` tells `./build.sh` to run `git -C ./c302 pull --ff-only` first (pulling any commits pushed to `minjae3018-lgtm/c302`) and then rebuild the Docker image.
- **Zero-rebuild live mount (`-m`)**: Passing `-m` to `./run-c302.sh` or `./run.sh` bind-mounts your local `./c302` folder directly into the running container, so local parameter edits take effect immediately without running `./build.sh`.

### Workflow A: Fast Local Iteration (No Rebuild or Git Push Needed)
1. Edit parameters or equations in `c302/c302/` (e.g., `parameters_C.py`, `parameters_C2.py`, `parameters_D.py`, `parameters_D1.py`, `cell_C.xml`, `custom_synapses.xml`).
2. Run with `-m` (live-mounts `./c302` into the container):
   ```bash
   # Level 1 / Level 2 (standalone c302 + NEURON electrophysiology)
   ./run-c302.sh -m -p C2 -r IClamp -d 500

   # Level 3 (3D worm body in Sibernetic + c302)
   ./run.sh -m -p C2 -r FW -d 15
   ./stop.sh
   ```
3. Inspect the generated plots, `.dat` files, and videos in `output/`.

### Workflow B: Commit, Push & Rebuild Baked Image
1. Modify files in `c302/c302/`, commit, and push to your `c302` repository (`minjae3018-lgtm/c302`):
   ```bash
   cd c302
   git add -A
   git commit -m "Modify C/D parameters for neurodegenerative simulation"
   git push origin master
   cd ..
   ```
2. Update the submodule pointer in `OpenWorm`, commit, and push:
   ```bash
   git add c302
   git commit -m "Update c302 submodule pointer"
   git push origin master
   ```
3. Build the updated Docker image (~5 seconds):
   ```bash
   ./build.sh          # builds from your local ./c302 directory
   # OR, if pulling changes pushed to GitHub from another machine/branch:
   ./build.sh --pull   # runs 'git -C ./c302 pull --ff-only' then builds
   ```
4. Run simulations using the baked image (no `-m` needed):
   ```bash
   ./run-c302.sh -p C2 -r FW -d 500
   # or
   ./run.sh -p C2 -r FW -d 15 && ./stop.sh
   ```

---

## 2. Detailed Commands to Run Each Simulation Level

### Level 1: Neuron-Only / Neural Circuit Simulation (`./run-c302.sh`)
Runs single neurons, small circuits (`IClamp`, `Syns`, `Pharyngeal`, `Oscillator`), or the 302-neuron connectome (`Full`) in **NEURON** without 3D body mechanics (completes in **seconds**).
- **Outputs** (in `output/c302_<Params>_<Ref>_<Timestamp>/`):
  - `c302_<Params>_<Ref>.dat`: Neuron soma membrane potentials $V(t)$ (Volts).
  - `c302_<Params>_<Ref>.activity.dat`: Neuron intracellular calcium concentrations $[\text{Ca}^{2+}]_i(t)$.
  - `neurons_<Params>_<Ref>.png`, `neuron_activity_<Params>_<Ref>.png`, `traces_neuron_*.png`: Heatmaps and voltage/calcium line traces.

```bash
# Single neuron current-clamp responses in Layer C, C2, D (3D multicompartment), or D1
./run-c302.sh -m -p C  -r IClamp -d 500
./run-c302.sh -m -p C2 -r IClamp -d 500
./run-c302.sh -m -p D  -r IClamp -d 500
./run-c302.sh -m -p D1 -r IClamp -d 500

# Synaptic transmission test (excitatory, inhibitory, and gap-junction pairs)
./run-c302.sh -m -p C2 -r Syns -d 500

# Pharyngeal circuit (20 neurons) in Layer C2 or multicompartmental D/D1
./run-c302.sh -m -p C2 -r Pharyngeal -d 500
./run-c302.sh -m -p D1 -r Pharyngeal -d 500

# Motor neuron oscillator circuit (DB/VB/DD/VD/DA/VA + command interneurons)
./run-c302.sh -m -p C2 -r Oscillator -d 1000

# Full 302-neuron connectome electrophysiology
./run-c302.sh -m -p C2 -r Full -d 500
./run-c302.sh -m -p D1 -r Full -d 500
```

### Level 2: Neuron + Attached Muscle Electrophysiology (`./run-c302.sh`)
Simulates neurons **plus the 95/96 body-wall muscle cells** (`MDR01..24`, `MVR01..24`, `MVL01..23`, `MDL01..24`) wired via excitatory/inhibitory neuromuscular junctions in NEURON (no 3D fluid mechanics; completes in **~10–40 seconds**).
- **Outputs** (in `output/c302_<Params>_<Ref>_<Timestamp>/`):
  - All Level 1 neuronal outputs **plus**:
  - `c302_<Params>_<Ref>.muscles.dat`: Muscle membrane potentials $V_m(t)$ (Volts) for all 96 muscles.
  - `c302_<Params>_<Ref>.muscles.activity.dat`: Muscle intracellular $[\text{Ca}^{2+}]_i(t)$ (the signal that drives physical contraction).
  - `muscles_<Params>_<Ref>.png`, `muscle_activity_<Params>_<Ref>.png`, `traces_muscles_*.png`: 96-muscle heatmaps and traces showing head-to-tail dorsal/ventral travelling waves.

```bash
# Forward crawling neuromuscular circuit (FW) with Layer C2
./run-c302.sh -m -p C2 -r FW -d 1000

# All motor neurons + 96 body-wall muscles (Muscles) in Layer C, C2, D, or D1
./run-c302.sh -m -p C  -r Muscles -d 1000
./run-c302.sh -m -p C2 -r Muscles -d 1000
./run-c302.sh -m -p D  -r Muscles -d 500
./run-c302.sh -m -p D1 -r Muscles -d 500

# Sine-wave stimulated muscles or Tap-Withdrawal reflex circuit
./run-c302.sh -m -p C2 -r MusclesSine -d 1000
./run-c302.sh -m -p C2 -r TapWithdrawal -d 500
```

### Level 3: Full 3D Worm Body Crawling on Surface or Swimming in Water (`./run.sh`)
Couples `c302` (NEURON) step-by-step with `Sibernetic` (3D SPH continuum mechanics of the worm body + environment). At every `0.005 ms` step, each of the 96 muscles' intracellular $[\text{Ca}^{2+}]_i$ (`soma.cai`) is normalized into a contraction force in $[0, 1]$ applied to the 3D worm body. Always run `./stop.sh` after `./run.sh` completes.
- **Outputs** (in `output/<Params>_<Ref>_<Timestamp>/`):
  - All Level 1 & Level 2 `.dat` and `.png` files **plus**:
  - `muscles_activity_buffer.txt` & `.png`: 96-muscle $[0, 1]$ contraction force time series.
  - `worm_motion_log.wcon`, `worm_motion_log.txt`, `worm_motion_1..3.png`: 3D body midline skeleton posture and center-of-mass trajectory.
  - `position_buffer.txt`, `pressure_buffer.txt`, `connection_buffer.txt`, `membranes_buffer.txt`: 3D SPH particle states.
  - `<sim>.mp4`, `cut_<sim>.mp4`, `speeded_<sim>.mp4`: Rendered 3D video of the worm moving.

```bash
# 1. 3D Worm Crawling on surface (default configuration; use -d 15 for quick test, -d 5000 for full 5s movie)
./run.sh -m -p C2 -r FW -c worm_crawl_half_resolution -d 15
./stop.sh

# 2. 3D Worm Swimming in Water (half-resolution 3D fluid tank)
./run.sh -m -p C2 -r FW -c worm_swim_half_resolution -d 50
./stop.sh

# 3. 3D Worm Swimming Immersed in Deep Water
./run.sh -m -p C2 -r FW -c worm_deep_water -d 50
./stop.sh

# 4. 3D Worm Body Mechanics without External Water
./run.sh -m -p C2 -r FW -c worm_no_water -d 50
./stop.sh
```
