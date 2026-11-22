# OpenWorm & `c302` Multi-Level Simulation Guide (Neurodegenerative Disease Modeling)

In OpenWorm, simulations are organized along **two axes**:
1. **Biophysical detail layer (`c302` parameters `A` → `B` → `C`/`C2` → `D`/`D1`)**: the mathematical equations and 3D morphology inside each cell.
2. **System scope (Execution Level 1 → Level 2 → Level 3)**: whether you simulate isolated neurons/circuits, neurons + electrical muscle cells, or the full 3D physical worm body crawling on a surface or swimming in water.

---

## 1. Biophysical Layers: What `C` (`C`/`C2`) and `D` (`D`/`D1`) Model

Both `C` and `D` use **conductance-based Hodgkin–Huxley-style equations** (defined in [`c302/c302/cell_C.xml`](c302/c302/cell_C.xml) and [`c302/c302/custom_synapses.xml`](c302/c302/custom_synapses.xml)) solved by **NEURON**:

$$C_m \frac{dV}{dt} = -g_{\text{Leak}}(V - E_{\text{Leak}}) - I_{\text{K,slow}}(V) - I_{\text{K,fast}}(V) - I_{\text{Ca,Boyle}}(V) - I_{\text{syn}} - I_{\text{gap}} + I_{\text{stim}}$$

$$\frac{d[\text{Ca}^{2+}]_i}{dt} = \rho \, I_{\text{Ca,Boyle}} - \frac{[\text{Ca}^{2+}]_i}{\tau_{\text{Ca}}}$$

| Feature | Layer `C` ([`c302/c302/parameters_C.py`](c302/c302/parameters_C.py)) | Layer `C2` ([`c302/c302/parameters_C2.py`](c302/c302/parameters_C2.py)) *(Default)* | Layer `D` ([`c302/c302/parameters_D.py`](c302/c302/parameters_D.py)) | Layer `D1` ([`c302/c302/parameters_D1.py`](c302/c302/parameters_D1.py)) |
| :--- | :--- | :--- | :--- | :--- |
| **Neuron Morphology** | **Single compartment** (1 point-like cylinder per neuron) | **Single compartment** | **3D Multicompartmental** (full reconstructed soma + dendrites + axon from [`c302/c302/NeuroML2/*.cell.nml`](c302/c302/NeuroML2)) | **3D Multicompartmental** |
| **Intracellular Axial Resistance ($R_a$)** | Not used (isopotential cell) | Not used (isopotential cell) | **`resistivity` ($12\text{ k}\Omega\cdot\text{cm}$)**: voltage propagates spatially along 3D neurite cable | **`resistivity` ($3\text{ k}\Omega\cdot\text{cm}$)**: voltage propagates spatially along 3D neurite cable |
| **Chemical Synapses** | Event/spike-triggered (`ExpTwoSynapse`: rise/decay time constants) | **Analogue / graded** (`GradedSynapse`: continuous voltage-dependent transmission) | Event/spike-triggered (`ExpTwoSynapse`) | **Analogue / graded** (`GradedSynapse`) |
| **Gap Junctions** | Ohmic electrical (`GapJunction`) | Ohmic + delayed electrical | Ohmic electrical | Ohmic electrical |
| **Muscle Cells** | Single compartment (`GenericMuscleCell`) with $\text{Ca}^{2+}$, $\text{K}^+$, Leak | Single compartment with tuned muscle parameters | Single compartment (`GenericMuscleCell`) | Single compartment (`GenericMuscleCell`) |

---

## 2. The Three Levels of Simulation: Inputs, Outputs & Commands

### Level 1: Neuron-Only / Neural Circuit Simulation (`c302` + NEURON standalone)

Simulates a single neuron, a small functional circuit (`IClamp`, `Syns`, `Pharyngeal`, `Oscillator`), or the entire 302-neuron connectome (`Full`) **without physical 3D mechanics** (runs in **seconds** via `./run-c302.sh`).

- **Commands**:
  ```bash
  # Single neuron / current-clamp test in Layer C or D (500 ms)
  ./run-c302.sh -m -p C -r IClamp -d 500
  ./run-c302.sh -m -p D -r IClamp -d 500

  # Synaptic pair test (1 excitatory + 1 inhibitory + 1 gap-junction pair)
  ./run-c302.sh -m -p C2 -r Syns -d 500

  # Pharyngeal nervous system (20 neurons) in Layer C2 or multicompartmental D/D1
  ./run-c302.sh -m -p C2 -r Pharyngeal -d 500
  ./run-c302.sh -m -p D1 -r Pharyngeal -d 500

  # Motor circuit oscillator (DB/VB/DD/VD/DA/VA motor neurons + command interneurons)
  ./run-c302.sh -m -p C2 -r Oscillator -d 1000

  # Full 302-neuron connectome (no 3D body physics)
  ./run-c302.sh -m -p C2 -r Full -d 500
  ./run-c302.sh -m -p D1 -r Full -d 500
  ```
- **Inputs**:
  1. **Connectome graph**: neuron-to-neuron chemical synapse and gap-junction counts/weights (from [`c302/c302/UpdatedSpreadsheetDataReader2.py`](c302/c302/UpdatedSpreadsheetDataReader2.py)).
  2. **Bioparameters** (`parameters_C.py`, `parameters_C2.py`, `parameters_D.py`, `parameters_D1.py`): membrane capacitance $C_m$, ion channel conductances (`neuron_ca_boyle_cond_density`, `neuron_k_slow_cond_density`, `neuron_k_fast_cond_density`, `neuron_leak_cond_density`), reversal potentials ($E_{\text{rev}}$), calcium decay $\tau_{\text{Ca}}$ (`ca_conc_decay_time`) & $\rho$ (`ca_conc_rho`), synaptic conductances (`*_syn_conductance` / `*_gbase`), and in `D`/`D1`, axial cytoplasmic `resistivity` ($R_a$) + 3D morphology segments.
  3. **External stimuli**: current-clamp pulses (`PulseGenerator`, `unphysiological_offset_current`) applied to specific command/sensory neurons (e.g., `AVBL`, `AVBR`, `PVCL`, `ADAL`).
- **Outputs** (saved in `output/c302_<Params>_<Ref>_<Timestamp>/`):
  - **`c302_<Params>_<Ref>.dat`**: Time series of **soma membrane potential $V(t)$ (in Volts)** for every simulated neuron at each time step `dt`.
  - **`c302_<Params>_<Ref>.activity.dat`**: Time series of **intracellular calcium concentration $[\text{Ca}^{2+}]_i(t)$** for every neuron (proxy for neural firing / calcium imaging fluorescence).
  - **Plots (`*.png`)**:
    - `neurons_<Params>_<Ref>.png`: Heatmap matrix of all neurons' membrane potentials $V(t)$ over time.
    - `neuron_activity_<Params>_<Ref>.png`: Heatmap matrix of all neurons' $[\text{Ca}^{2+}]_i(t)$ over time.
    - `traces_neuron_<Ref>_<Params>.png` & `traces_neuron_activity_<Ref>_<Params>.png`: Overlapping line traces of $V(t)$ and $[\text{Ca}^{2+}]_i(t)$.
  - **Generated model files**: `c302_<Params>_<Ref>.net.nml`, `LEMS_c302_<Params>_<Ref>.xml`, and NEURON `.hoc` / `.mod` files.

---

### Level 2: Neuron + Attached Muscle Electrophysiology (`c302` + NEURON standalone)

Simulates neurons **plus the 95/96 body-wall muscle cells** (arranged in 4 quadrants: dorsal-right `MDR01..24`, ventral-right `MVR01..24`, ventral-left `MVL01..23`, dorsal-left `MDL01..24`) connected via neuromuscular junctions (NMJs). Runs purely in `c302`/NEURON without 3D fluid mechanics (takes **~10–40 seconds** via `./run-c302.sh`).

- **Commands**:
  ```bash
  # Forward crawling neuromuscular network (FW) in Layer C2
  ./run-c302.sh -m -p C2 -r FW -d 1000

  # Full motor neurons + 96 body-wall muscles network in Layer C, C2, D, or D1
  ./run-c302.sh -m -p C2 -r Muscles -d 1000
  ./run-c302.sh -m -p D1 -r Muscles -d 500

  # Sine-wave driven neuromuscular test or Tap-Withdrawal reflex circuit
  ./run-c302.sh -m -p C2 -r MusclesSine -d 1000
  ./run-c302.sh -m -p C2 -r TapWithdrawal -d 500
  ```
- **Inputs**:
  - All Level 1 neuronal inputs **plus**:
  - **Neuromuscular connectivity**: excitatory (cholinergic: `DB*`, `VB*`, `DA*`, `VA*`) and inhibitory (GABAergic: `DD*`, `VD*`) synapses from motor neurons onto the 96 muscle cells.
  - **Muscle bioparameters**: `muscle_ca_boyle_cond_density`, `muscle_k_slow_cond_density`, `muscle_k_fast_cond_density`, `muscle_leak_cond_density`, `ca_conc_decay_time_muscle`, `neuron_to_muscle_exc_syn_conductance`, `neuron_to_muscle_inh_syn_conductance`.
- **Outputs** (saved in `output/c302_<Params>_<Ref>_<Timestamp>/`):
  - All Level 1 neuronal files (`*.dat`, `*.activity.dat`, `neurons_*.png`, `traces_neuron_*.png`) **plus**:
  - **`c302_<Params>_<Ref>.muscles.dat`**: Time series of **muscle membrane potential $V_m(t)$ (in Volts)** for all 96 muscles.
  - **`c302_<Params>_<Ref>.muscles.activity.dat`**: Time series of **muscle intracellular calcium $[\text{Ca}^{2+}]_i(t)$** for all 96 muscles — the direct physiological trigger for muscle contraction.
  - **Muscle plots (`*.png`)**:
    - `muscles_<Params>_<Ref>.png` & `muscle_activity_<Params>_<Ref>.png`: 96-row heatmaps showing the dorsal/ventral alternating travelling waves of voltage and $[\text{Ca}^{2+}]_i$ from head (`01`) to tail (`24`).
    - `traces_muscles_<Ref>_<Params>.png` & `traces_muscles_activity_<Ref>_<Params>.png`: Line traces of individual muscle potentials and calcium waves.

---

### Level 3: Full 3D Worm Body Movement on Surface or in Water (`c302` + NEURON + `Sibernetic`)

Executes NEURON (`c302`) and `Sibernetic` (a 3D Smoothed Particle Hydrodynamics / continuum mechanics solver) in a **tight step-by-step co-simulation loop** via `./run.sh`.

- **How `c302` couples to the 3D worm body**:
  1. At every physics step (`dt = 0.005 ms`), `Sibernetic` advances NEURON by one step and reads the **intracellular calcium concentration (`soma.cai`) of all 96 body-wall muscle cells** from `c302`.
  2. It normalizes each muscle's $[\text{Ca}^{2+}]_i$ by `max_ca = 4e-7` into a dimensionless **muscle contraction force in $[0, 1]$**.
  3. Those 96 contraction forces pull on the elastic 3D SPH particle mesh of the worm's body wall, which interacts physically with the surrounding environment (viscous agar surface or 3D water particles).
- **Commands**:
  ```bash
  # 1. Default 3D Worm Crawling on surface (15 ms quick run, or 5000 ms for full movie)
  ./run.sh -m -p C2 -r FW -c worm_crawl_half_resolution -d 15
  ./stop.sh

  # 2. 3D Worm Swimming in Water (half-resolution water tank)
  ./run.sh -m -p C2 -r FW -c worm_swim_half_resolution -d 50
  ./stop.sh

  # 3. 3D Worm Swimming Immersed in Deep Water
  ./run.sh -m -p C2 -r FW -c worm_deep_water -d 50
  ./stop.sh

  # 4. 3D Worm Body in Isolation (no external water particles)
  ./run.sh -m -p C2 -r FW -c worm_no_water -d 50
  ./stop.sh
  ```
- **Inputs**:
  - All Level 1 & Level 2 `c302` inputs (`-p <c302params> -r <reference>`).
  - **3D Mechanical & Environment Configuration (`-c <configuration>`)**:
    - `worm_crawl_half_resolution` *(default)* or `worm_crawling`: Crawling on a surface with friction.
    - `worm_swim_half_resolution`, `worm_swim_half_resolution_immersed`, or `worm_deep_water`: **Worm immersed in 3D water particles**, simulating fluid drag, hydrodynamics, and swimming locomotion.
    - `worm_alone_half_resolution` / `worm_no_water`: 3D worm body mechanics in isolation.
- **Outputs** (saved in `output/<Params>_<Ref>_<Timestamp>/`):
  - **All Level 1 & Level 2 electrophysiological files** (`*.dat`, `*.activity.dat`, `*.muscles.dat`, `*.muscles.activity.dat`, and all 8 neuron/muscle `.png` plots).
  - **`muscles_activity_buffer.txt` & `muscles_activity_buffer.txt.png`**: The exact `[0, 1]` contraction force signals sent to the 96 3D muscles at each step.
  - **3D Physical Buffers**:
    - `position_buffer.txt`: 3D $(x, y, z)$ coordinates of all SPH particles (worm body + water) over time.
    - `pressure_buffer.txt`, `connection_buffer.txt`, `membranes_buffer.txt`: internal hydrostatic pressure and elastic tissue tension.
  - **Whole-Worm Kinematics & Posture**:
    - `worm_motion_log.txt` & **`worm_motion_log.wcon`** (Worm Tracker Commons Object Notation): midline skeleton coordinates $(x, y, z)$ along the worm's body over time.
    - `worm_motion_1.png`, `worm_motion_2.png`, `worm_motion_3.png`: Center-of-mass trajectory, body posture skeletons, and head/midbody/tail displacement graphs.
  - **3D Videos (`*.mp4`)**:
    - `<sim>.mp4`, `cut_<sim>.mp4`, `speeded_<sim>.mp4`: Rendered 3D movie of the worm crawling or swimming in water.

---

## 3. Neurodegenerative Disease Modeling: Parameter Changes & Expected Outcomes

When you modify parameters in `C`/`C2` or `D`/`D1` (even to extreme or arbitrary values), here is how each neurodegenerative mechanism manifests across the three simulation levels:

| Disease Mechanism | Parameters to Modify in `c302/c302/parameters_*.py` | Outcome at **Level 1 & 2 (Neuron / Muscle Electrophysiology)** | Outcome at **Level 3 (3D Worm Movement in Water / on Surface)** |
| :--- | :--- | :--- | :--- |
| **1. Intrinsic Neuronal Hypoexcitability / Channel Loss** (loss of voltage-gated $\text{Ca}^{2+}$ channels or excessive membrane leak due to membrane breakdown) | Decrease `neuron_ca_boyle_cond_density` (e.g., $\to 0$) or increase `neuron_leak_cond_density` ($10\times$–$100\times$) | Neurons fail to depolarize or spike; $V(t)$ flatlines near `leak_erev` ($-50$ to $-60\text{ mV}$); neuronal $[\text{Ca}^{2+}]_i \to 0$; motor neurons stop driving muscles ($[\text{Ca}^{2+}]_{\text{muscle}} \to 0$). | **Flaccid paralysis**: Muscle force buffer stays near $0$; the 3D worm body remains limp and stationary in `speeded_*.mp4` and `worm_motion_log.wcon`. |
| **2. Hyperexcitability / Potassium Channel Loss / Excitotoxic $\text{Ca}^{2+}$ Overload** | Decrease `neuron_k_slow_cond_density` / `neuron_k_fast_cond_density` or decrease `ca_conc_decay_time` / increase `ca_conc_rho` | Neurons fail to repolarize (**depolarization block**: $V(t)$ locks near $-10$ to $+10\text{ mV}$); intracellular $[\text{Ca}^{2+}]_i$ saturates continuously instead of oscillating. | **Tonic spastic lock**: Downstream muscles receive continuous rather than alternating drive; the worm locks into a static bend and cannot propagate a forward wave. |
| **3. Axonal / Neurite Conduction Block** *(Unique to 3D multicompartmental **`D` / `D1`**)* | Increase intracellular axial `resistivity` ($R_a$, e.g. from $3\text{–}12\text{ k}\Omega\cdot\text{cm}$ to $100\text{–}1000\text{ k}\Omega\cdot\text{cm}$) in `parameters_D.py` / `parameters_D1.py` | **Spatial conduction failure**: The soma still fires normal spikes when stimulated, but the voltage decays along the 3D neurite compartments before reaching distal synapses, silencing postsynaptic neurons. | Loss of coordination between head and tail segments. |
| **4. Cholinergic / Excitatory Synaptic Degeneration or NMJ Denervation** (ALS / motor-neuron-disease-like loss of neuromuscular drive) | Reduce `neuron_to_neuron_exc_syn_conductance` or `neuron_to_muscle_exc_syn_conductance` (or `*_gbase`) | Motor neurons still oscillate, but muscle $V_m(t)$ and muscle $[\text{Ca}^{2+}]_i$ amplitude in `*.muscles.activity.dat` drop proportionally. | **Weak / bradykinetic locomotion**: Reduced body bend amplitude, slower swimming/crawling speed, and shortened travel distance in `worm_motion_1.png`. |
| **5. GABAergic Cross-Inhibition Loss** (loss of inhibitory `DD`/`VD` synapses onto opposing muscles) | Reduce `neuron_to_muscle_inh_syn_conductance` / `neuron_to_neuron_inh_syn_conductance` $\to 0$ | Both dorsal (`MDR`/`MDL`) and ventral (`MVR`/`MVL`) muscles fire **simultaneously** instead of in anti-phase in `muscle_activity_*.png`. | **"Shrinker" / co-contraction phenotype**: Dorsal and ventral muscles pull against each other simultaneously; the worm stiffens/shortens axially instead of bending smoothly. |

---

## 4. Development & Git Workflows

### How `./build.sh` and `-m` Work with Your `c302` Submodule

- **Local files first**: `./build.sh` copies directly from your local `./c302/` directory on your Mac (`COPY ./c302 /home/ow/c302`). You do **not** have to commit or push to GitHub just to test a change locally.
- **Instant live-mount (`-m`)**: Passing `-m` to `./run-c302.sh` or `./run.sh` bind-mounts your local `./c302` folder directly into the running container, so you don't even need to run `./build.sh` while iterating on parameters.
- **Auto-pull from GitHub (`./build.sh --pull`)**: If you pushed changes to `minjae3018-lgtm/c302` (or want `./build.sh` to pull the latest pushed commit from your `c302` GitHub repo before building), run `./build.sh --pull`.

### Workflow A: Fast Local Experimentation (No Rebuild or Git Push Needed)
1. Edit parameters or equations in `c302/c302/parameters_C2.py`, `parameters_C.py`, `parameters_D.py`, `parameters_D1.py`, or `cell_C.xml`.
2. Run your simulation with `-m`:
   - **Level 1 / Level 2**: `./run-c302.sh -m -p C2 -r FW -d 500`
   - **Level 3 (3D Body)**: `./run.sh -m -p C2 -r FW -d 20 && ./stop.sh`
3. Inspect the generated plots/data in `output/`.

### Workflow B: Bake Changes into the Local Docker Image + Push to GitHub
1. Edit files inside `c302/c302/`.
2. Commit and push your `c302` changes to your `c302` fork (`minjae3018-lgtm/c302`):
   ```bash
   cd c302
   git add -A
   git commit -m "Describe parameter/equation change"
   git push origin master
   cd ..
   ```
3. Record the updated `c302` submodule commit in your `OpenWorm` repo and push:
   ```bash
   git add c302
   git commit -m "Update c302 submodule pointer"
   git push origin master
   ```
4. Rebuild the local Docker image (~5 seconds):
   ```bash
   ./build.sh          # uses local ./c302
   # OR:
   ./build.sh --pull   # pulls latest origin/master in ./c302 first, then builds
   ```
5. Run simulations from the baked image (no `-m` needed):
   ```bash
   ./run-c302.sh -p C2 -r FW -d 500
   # or
   ./run.sh -p C2 -r FW -d 20 && ./stop.sh
   ```
