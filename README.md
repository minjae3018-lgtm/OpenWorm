![OpenWorm](http://www.openworm.org/img/OpenWormLogo.png)

[![Docker Image CI](https://github.com/openworm/OpenWorm/actions/workflows/docker-image.yml/badge.svg)](https://github.com/openworm/OpenWorm/actions/workflows/docker-image.yml) [![Docker Image Test - quick](https://github.com/openworm/OpenWorm/actions/workflows/docker-image-quickrun.yml/badge.svg)](https://github.com/openworm/OpenWorm/actions/workflows/docker-image-quickrun.yml) [![Docker Image Test Build - Intel drivers](https://github.com/openworm/OpenWorm/actions/workflows/docker-image-intel.yml/badge.svg)](https://github.com/openworm/OpenWorm/actions/workflows/docker-image-intel.yml)

## Custom `c302` Workflows & Multi-Level Simulation Guide

This repository uses your custom [`c302`](https://github.com/minjae3018-lgtm/c302) fork as a git submodule at [`./c302`](c302) and builds a fast layered Docker image (`openworm/openworm:0.9.8-local`) via [`Dockerfile.local`](Dockerfile.local).

For a complete breakdown of the biophysical equations (`C`/`C2` vs. 3D multicompartmental `D`/`D1`), inputs/outputs at every level, and parameter mappings for neurodegenerative disease modeling, see **[`SIMULATION_GUIDE.md`](SIMULATION_GUIDE.md)**.

---

### 1. Development & Git Workflows

How [`./build.sh`](build.sh) works with [`./c302`](c302):
- **Builds from local `./c302`**: `./build.sh` copies your local `./c302` folder directly into the Docker image (`COPY ./c302 /home/ow/c302`) in ~5 seconds. You do **not** need to commit or push to GitHub before testing locally.
- **Auto-pull from GitHub (`./build.sh --pull`)**: Passing `--pull` tells `./build.sh` to run `git -C ./c302 pull --ff-only` first (pulling any commits pushed to `minjae3018-lgtm/c302`) and then rebuild the Docker image.
- **Zero-rebuild live mount (`-m`)**: Passing `-m` to `./run-c302.sh` or `./run.sh` bind-mounts your local `./c302` folder directly into the running container, so local parameter edits take effect immediately without running `./build.sh`.

#### Workflow A: Fast Local Iteration (No Rebuild or Git Push Needed)
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

#### Workflow B: Commit, Push & Rebuild Baked Image
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

### 2. Detailed Commands to Run Each Simulation Level

#### Level 1: Neuron-Only / Neural Circuit Simulation (`./run-c302.sh`)
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

#### Level 2: Neuron + Attached Muscle Electrophysiology (`./run-c302.sh`)
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

#### Level 3: Full 3D Worm Body Crawling on Surface or Swimming in Water (`./run.sh`)
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

---

## About **OpenWorm**

[OpenWorm](http://openworm.org) aims to build the first comprehensive computational model of *Caenorhabditis elegans* (*C. elegans*), a microscopic roundworm. With only a thousand cells, it solves basic problems such as feeding, mate-finding and predator avoidance. Despite being extremely well-studied in biology, a deep, principled understanding of the biology of this organism remains elusive.

We are using a bottom-up approach, aimed at observing the worm behavior emerge from a simulation of data derived from scientific experiments carried out over the past decade. To do so, we are incorporating the data available from the scientific community into software models. We are also forging new collaborations with universities and research institutes to collect data that fill in the gaps.

You can earn a badge with us simply by trying out this package! Click on the image below to get started.
[![OpenWorm Docker Badge](https://raw.githubusercontent.com/openworm/OpenWorm/master/img/ow-docker-badge.png)](https://www.badgelist.com/OpenWorm/OpenWorm-Docker-Apprentice)

## Quickstart

We have put together a [Docker container](https://hub.docker.com/r/openworm/openworm) that pulls together the major components of our simulation and runs it on your machine. When you get it all running, it does the following:

1. Run our nervous system model, known as [c302](https://github.com/openworm/c302), on your computer.
2. In parallel, run our 3D worm body model, known as [Sibernetic](https://github.com/openworm/sibernetic), on your computer, using the output of the nervous system model.
3. Produce graphs from the nervous system and body model that demonstrate its behavior on your computer for you to inspect.
4. Produce a movie showing the output of the body model.

**Example Output**

![Worm Crawling](https://raw.githubusercontent.com/openworm/OpenWorm/master/img/worm-crawling.gif)

<img src="https://raw.githubusercontent.com/openworm/OpenWorm/master/img/muscle-activity.png" width="250"><img src="https://raw.githubusercontent.com/openworm/OpenWorm/master/img/neuron-activity.png" width="350">

**NOTE**: Running the simulation for the full amount of time would produce content like the above. However, in order to run in a reasonable amount of time, **the default run time for the simulation is limited**. As such, you will see only a partial output, equivalent to about 5% of run time, compared to the examples above. To extend the run time, use the `-d` argument as described below.

## Installation

### Pre-requisites

1. At least 60 GB of free space on your machine and at least 2GB of RAM.
2. Ability to clone git repositories on your machine. [Install git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), or use [this GUI](https://desktop.github.com/).

### To Install

1. Install [Docker](http://docker.com) on your system.
2. If your system does not have enough free space, you can use an external hard disk. On MacOS X, the location for image storage can be specified in the [Advanced Tab](https://forums.docker.com/t/change-docker-image-directory-for-mac/18891/15) in Preferences. See [this thread](https://forums.docker.com/t/how-do-i-change-the-docker-image-installation-directory/1169/18) for Linux instructions.

## Running

1. Ensure the Docker daemon is running in the background (on MacOS/Windows there should be an icon with the Docker whale logo showing in the menu bar/system tray). 
2. Open a terminal and run:
   ```bash
   git clone http://github.com/openworm/openworm
   cd openworm
   ```
3. Optional: Run `./build.sh` (`build.cmd` on Windows or `.\build.cmd` on [PowerShell](https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-2.0)). If you skip this step, it will download the latest released Docker image from the [OpenWorm Docker hub](https://hub.docker.com/r/openworm/openworm).
4. Run `./run.sh` (`run.cmd` on Windows or `.\run.cmd` in PowerShell).
5. About 5-10 minutes of output will display on the screen as the steps run.
6. The simulation will end. Run `stop.sh` (`stop.cmd` on Windows or `.\stop.cmd` in PowerShell) on your system to clean up the running container.
7. Inspect the output in the `output` directory on your local machine.

## Advanced

### Arguments

- `-d [num]`: Use to modify the duration of the simulation in milliseconds. Default is 15. Use 5000 to run for time to make the full movie above (i.e. 5 seconds).

### Other Things to Try

- Open a terminal and run `./run-shell-only.sh` (`run-shell-only.cmd` on Windows or `.\run-shell-only.cmd` in PowerShell). This will let you log into the container before it has run `master_openworm.py`. From here you can inspect the internals of the various checked out code bases and installed systems and modify things. Afterwards, you'll still need to run `./stop.sh` to clean up.
- If you wish to modify what gets installed, you should modify `Dockerfile`. If you want to modify what runs, you should modify `master_openworm.py`. Either way you will need to run `build.sh` in order to rebuild the image locally. Afterwards, you can run normally.

## FAQ

### What is the Docker container?

The Docker container is a self-contained environment in which you can run OpenWorm simulations. It's fully set up to get you started by following the steps above. At the moment, it runs simulations and produces visualizations for you, but these visualizations must be viewed outside of the Docker container. While you do not need to know much about Docker to use OpenWorm, if you are planning on working extensively with the platform, you may benefit from understanding some basics. [Docker Curriculum](https://docker-curriculum.com) is an excellent tutorial for beginners that is straightforward to work through (Sections 1 - 2.5 are plenty sufficient).

### Is it possible to modify the simulation without having to run `build.sh`?

Yes, but it is marginally more complex. The easiest way is to modify anything in the Docker container once you are inside of it - it will work just like a bash shell. If you want to modify any code in the container, you'll need to use an editor that runs in the terminal, like nano. Once you've modified something in the container, you don't need to re-build. However, if you run `stop.sh` once you exit, those changes will be gone.

### How do I access more data than what is already output?

The simulation by default outputs only a few figures and movies to your home system (that is, outside of the Docker container). If you want to access the entire output of the simulation, you will need to copy it from the Docker container.

For example, say you want to extract the worm motion data. This is contained in the file `worm_motion_log.txt`, which is found in the `/home/ow/sibernetic/simulations/[SPECIFIC_TIMESTAMPED_DIRECTORY]/worm_motion_log.txt`. The directory `[SPECIFIC_TIMESTAMPED_DIRECTORY]` will have a name like `C2_FW_2018_02-12_18-36-32`, and its name can be found by checking the `output` directory. This is actually the main output directory for the simulation, and contains all output, including cell modelling and worm movement.

Once the simulation ends and you exit the container with `exit`, but before you run `stop.sh`, run the following command from the openworm-docker-master folder:

```bash
docker cp openworm:/home/ow/sibernetic/simulations/[SPECIFIC_TIMESTAMPED_DIRECTORY]/worm_motion_log.txt ./worm_motion_log.txt
```

This will copy the file from the Docker container, whose default name is `openworm`. **It is crucial that you do not run `stop.sh` before trying to get your data out (see below)**

### What is the difference between `exit` and `stop.sh`?

When you are in the Docker Container `openworm`, and are done interacting with it, you type `exit` to return to your system's shell. This stops execution of anything in the container, and that container's status is now `Exited`. If you try to re-start the process using `run-shell-only.sh`, you will get an error saying that the container already exists. You can choose, at this point, to run `stop.sh`. Doing so will remove the container and any files associated with it, allowing you to run a new simulation. However, if you don't want

 to remove that container, you will instead want to re-enter it.

### How do I enter a container I just exited?

If you run `stop.sh` you'll delete your data and reset the container for a new run. If, however, you don't want to do that, you can re-enter the Docker container like this:

```bash
docker start openworm                 # Restarts the container
docker exec -it openworm /bin/bash    # Runs bash inside the container
```

This tells Docker to start the container, to *execute* commands (`exec`) with an *interactive, tty* (`-it`) bash (`bash`) shell in the container `openworm`.

You'll be able to interact with the container as before.

## Documentation

To find out more about OpenWorm, please see the documentation at [http://docs.openworm.org](http://docs.openworm.org) or [get in contact](https://openworm.org/contacts.html).

This repository also contains project-wide tracking via high-level [issues](https://github.com/openworm/OpenWorm/issues) and [milestones](https://github.com/openworm/OpenWorm/milestones).