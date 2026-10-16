# Phase 1 Implementation & Verification Plan
This execution plan breaks the project down into five modular stages to ensure complete coverage, clean Cadence NC-Sim/SimVision verification, and timing safety at 250 MHz.

### Step 1: Repository Structure & Design Specifications Review
Establish a clean directory layout and pin down all internal signal interfaces.

- **Directory Structure**:
  ```plaintext
  cardinal_router_nic/
  ├── Phase1_Report.pdf
  ├── rtl/
  │   ├── router/
  │   │   ├── gold_router.v         # Top-level standalone router
  │   │   ├── router_input_ctrl.v   # Input controller & packet buffer
  │   │   └── router_output_ctrl.v  # Output controller & rotating arbiter
  │   ├── nic/
  │   │   └── cardinal_nic.v        # Network Interface Component
  │   └── ring/
  │       └── gold_ring.v           # 4-node ring network instantiation
  ├── tb/
  │   ├── tb_router.v               # Standalone router unit testbench
  │   ├── tb_nic.v                  # Standalone NIC unit testbench
  │   └── tb_gold_ring.v            # 4-node ring gather testbench
  ├── sim/                          # Simulation run scripts (ncverilog / xrun / ModelSim)
  ├── docs/                         # Simulation waveforms screenshots & other documents
  └── out/                          # testing result store in .out file
  
  ```
- **Hardware Invariants & Conventions**:
  - Clock period: 4.0 ns (250 MHz).
  - Synchronous active-high `reset`.
  - Zero delays (`#delay`) in synthesizable RTL.
  - Non-blocking assignments (`<=`) for sequential logic, blocking assignments (`=`) for combinational logic.

### Step 2: Standalone Cardinal Router Implementation & Unit Verification
Build and test the individual router (`gold_router.v`).

#### 1. Submodule Architecture:
  - **Input Controller (`router_input_ctrl.v`)**:
    - Two 64-bit registers per port representing Even (VC0) and Odd (VC1) buffers.
    - Flow control: drives ready-in (`ri`) based on buffer availability for the active polarity. Latches packet data into the proper buffer when send-in (`si`) is asserted.
    - Routing & Address Decoding: decodes `dir` on the PE port and inspects hop count on network ports (`cw`/`ccw`). Generates request signals to target output controllers.
  - **Output Controller & Arbiter (`router_output_ctrl.v`)**:
    - Two 64-bit registers for Even and Odd output buffers.
    - Header update: decrements/right-shifts the hop count field for packets routed to CW/CCW channels.
    - Circular rotating priority arbiter: resolves conflicts between the two input candidates per output port (`cw` vs. `ccw` for PE; `cw` vs. `pe` for CW; `ccw` vs. `pe` for CCW) and swaps priority strictly upon granted contention.
    - Mealy state logic: evaluates downstream ready (`ro`) to drive send-out (`so`) and achieve 2-cycle unblocked latency.
  - **Top-Level Router (`gold_router.v`)**:
    - Coordinates the global toggling `polarity` signal.
    - Connects 3 input controllers (`cw`, `ccw`, `pe`) to 3 output controllers.
#### 2. Router Verification (`tb_router.v`):
  - Synchronous reset verification.
  - Hop count update verification across multiple hops.
  - 6 canonical routing scenarios: PE $\rightarrow$ CW, PE $\rightarrow$ CCW, CW $\rightarrow$ CW, CCW $\rightarrow$ CCW, CW $\rightarrow$ PE, CCW $\rightarrow$ PE.
  - Inter-router handshaking: non-blocking forward progress and backpressure when `ro` is negated.
  - Contention & rotating arbitration: concurrent request injections proving correct grant execution and priority flipping.

### Step 3: Cardinal NIC Implementation & Unit Verification
Build and test the Network Interface Component (`cardinal_nic.v`).

#### 1. NIC Microarchitecture:
  - Two 64-bit data registers: `net_in_buf` (network $\rightarrow$ processor) and `net_out_buf` (processor $\rightarrow$ network).
  - Two 1-bit status flags: `net_in_status` and `net_out_status`.
  - Processor memory bus decoding: handles reads/writes using `addr[0:1]` when `nicEn` is asserted:
    - `2'b00`: Read-only `net_in_buf`.
    - `2'b01`: Read-only `net_in_status` (returned on LSB `d_out[63]` with remaining bits zeroed).
    - `2'b10`: Write-only `net_out_buf` (ignored if already occupied).
    - `2'b11`: Read-only `net_out_status` (returned on LSB `d_out[63]`).
  - Router handshaking: matches packet VC bit against `net_polarity` and downstream `net_ro` before asserting `net_so`.
#### 2. NIC Verification (`tb_nic.v`):
  - Reset behavior on status registers and handshake signals.
  - Network side: packet reception from router via `net_si`/`net_ri`, and packet transmission into router under both non-blocking and blocked (`net_ro = 0`) conditions.
  - Processor side: 4 mandatory load/store scenarios:
    - Store to output buffer when available (status = 0).
    - Store to output buffer when full/unavailable (status = 1, verifying data retention).
    - Load from input buffer when available (status = 1).
    - Load from input status when empty (status = 0).

### Step 4: 4-Node Ring Network Integration & Gather Testbench
Integrate routers into `gold_ring.v` and execute the multi-phase gather benchmark.

#### 1. Top-Level Ring Construction (`gold_ring.v`):
  - Instantiate 4 router modules (Node 0, Node 1, Node 2, Node 3).
  - Wire CW and CCW ports point-to-point according to the Lecture 9 connection diagram.
  - Expose PE ports (`nodeK_pesi`, `nodeK_peri`, `nodeK_pedi`, `nodeK_peso`, `nodeK_pero`, `nodeK_pedo`) and `nodeK_polarity`.
#### 2. Gather Testbench Construction (`tb_gold_ring.v`):
  - Deadlock-free injection compliance: Nodes 0 and 1 inject exclusively on Even VCs; Nodes 2 and 3 inject exclusively on Odd VCs.
  - Shortest path routing: 1-hop minimal traversal, 2-hop traversals forced to CW.
  - Sequential 4-Phase Gather Sequence:
    - **Phase 0**: Nodes 1, 2, 3 concurrently transmit to Node 0. Wait for all 3 packets to eject at Node 0.
    - **Phase 1**: Nodes 0, 2, 3 concurrently transmit to Node 1.
    - **Phase 2**: Nodes 0, 1, 3 concurrently transmit to Node 2.
    - **Phase 3**: Nodes 0, 1, 2 concurrently transmit to Node 3.
  - Automated File Logging:
    - Output packet log per node: `gather_phase0.res` through `gather_phase3.res` formatted with `Phase=`, `Time=`, `Destination=`, `Source=`, `Packet Value=`.
    - Global phase timing log: `start_end_time.out`.

### Step 5: Simulation Artifacts, Report Generation & Submission Packaging
Finalize verification data and prepare the submission archive.

- Run regression tests under Cadence NC-Sim / SimVision to ensure clean compiles without warnings or inferred latches.
- Capture waveform dumps (`.shm` databases) for all required report test cases.
- Compile the short technical report documenting each waveform and verifying log correctness against expected results.
- Package all files into `Phase_1_Group_<N>.zip` following the submission guidelines.
Would you like to start with designing the internal request/grant interfaces for the router modules (`router_input_ctrl.v` and `router_output_ctrl.v`), or would you prefer setting up the module port definitions first?

