# Phase 1 Implementation & Verification Plan (4x4 Mesh Architecture)
This execution plan breaks the project down into five modular stages to ensure complete coverage, clean Cadence Xcelium/SimVision verification, strict adherence to `Rules_for_student.txt`, and timing safety at 250 MHz (4.0 ns clock period).

---

## Step 1: Repository Structure & Design Specifications Review
Establish a clean directory layout and verify all top-level naming conventions and port interfaces.

### 1. Directory Structure
```plaintext
cardinal_router_nic/
├── Phase1_Report.pdf
├── rtl/
│   ├── router/
│   │   ├── router_node.v         # 5-port 2D mesh router instance (N, S, E, W, PE)
│   │   ├── router_input_ctrl.v   # Input controller & dual VC packet buffer
│   │   └── router_output_ctrl.v  # Output controller & rotating arbiter
│   ├── nic/
│   │   └── cardinal_nic.v        # Network Interface Component
│   └── mesh/
│       └── gold_mesh_4x4.v       # 16-node 4x4 2D mesh top-level module
├── tb/
│   ├── tb_router_node.v          # Standalone 5-port router unit testbench
│   ├── tb_nic.v                  # Standalone NIC unit testbench
│   └── tb_gold_mesh_4x4.v        # 16-node mesh system testbench
├── sim/                          # Simulation run scripts (xrun / xcelium / ncverilog)
├── docs/                         # Simulation waveforms, schematics, and notes
└── out/                          # Simulation results, logs, and report dumps
```

### 2. Hardware Invariants & TA Submission Rules
* **Clock & Timing**: Rising-edge active, fixed 4.0 ns period (250 MHz).
* **Reset**: Synchronous, active-high (`reset`).
* **Source Restrictions**: Do **not** use `` `include `` and do **not** depend on external `` `define `` macros in any submitted RTL file.
* **Coding Standards**: Zero artificial delays (`#delay`) in synthesizable modules; non-blocking assignments (`<=`) for sequential blocks, blocking assignments (`=`) for combinational blocks.
* **Top-Level Signature**: Must be declared exactly as:
  ```verilog
  module gold_mesh_4x4 #(parameter PACKET_SIZE = 64) (
      input clk,
      input reset,
      // Repeated for nodes N = 0 .. 15
      input                    nodeN_pesi,
      output                   nodeN_peri,
      input  [PACKET_SIZE-1:0] nodeN_pedi,
      output                   nodeN_peso,
      input                    nodeN_pero,
      output [PACKET_SIZE-1:0] nodeN_pedo,
      output                   nodeN_polarity
  );
  ```

---

## Step 2: Standalone 5-Port Mesh Router Implementation & Unit Verification

Build and test the individual 5-port mesh router (`router_node.v`) supporting North, South, East, West, and PE channels.

### 1. 64-Bit Packet Format
All packets injected by the testbench conform to the following layout:
* `[63]` — **VC**: Virtual channel selection (`0` = VC0, `1` = VC1).
* `[62]` — **Reserved**: Injected as `0`; must pass through unchanged.
* `[61:60]` — **Destination X**: Column index $0..3$ ($D \pmod 4$).
* `[59:58]` — **Destination Y**: Row index $0..3$ ($D / 4$).
* `[57:56]` — **Reserved**: Injected as `00`; must pass through unchanged.
* `[55:48]` — **Hop Field**: Manhattan distance $H = |dx| + |dy|$ in unary; ignored during routing and delivery check, passed through intact.
* `[47:32]` — **Source**: Origin node ID $0..15$; must pass through unchanged.
* `[31:0]` — **Payload**: Unique 32-bit packet tracking ID; must remain completely identical.

### 2. Submodule Architecture
* **Input Controller (`router_input_ctrl.v`)**:
  * Parameterized by node coordinates: `parameter [1:0] MY_X = 2'd0; parameter [1:0] MY_Y = 2'd0;`.
  * Two 64-bit storage registers per physical port: Even (`buf_even`) and Odd (`buf_odd`).
  * Flow control: Moore-style `ready_in` reflecting buffer readiness:
    * `polarity == 1'b0`: Ingestion targets Odd buffer (`VC1`).
    * `polarity == 1'b1`: Ingestion targets Even buffer (`VC0`).
  * **Dimension-Order (X-Y) Routing Decoder**:
    * Horizontal first: `dest_x > MY_X` requests East; `dest_x < MY_X` requests West.
    * Vertical second: when `dest_x == MY_X`, `dest_y > MY_Y` requests South; `dest_y < MY_Y` requests North.
    * Local ejection: when `dest_x == MY_X && dest_y == MY_Y`, requests PE.
* **Output Controller & Arbiter (`router_output_ctrl.v`)**:
  * Dual 64-bit output registers for Even (`buf_even`) and Odd (`buf_odd`) virtual channels.
  * Circular rotating priority arbiter: resolves contention between candidate inputs competing for the same output direction. Priority flips strictly upon granted conflict.
  * Direct payload passthrough: payload and header fields are preserved without decrementing.
  * Mealy flow control: combinational `send_out` driven by active output buffer fullness and downstream ready (`ready_in`) to maintain 2-cycle unblocked latency.
* **5-Port Router Wrapper (`router_node.v`)**:
  * Coordinates internal polarity.
  * Instantiates 5 input controllers and 5 output controllers (North, South, East, West, PE).
  * Wires the internal crossbar data and request/grant buses.

### 3. Standalone Verification (`tb_router_node.v`)
* Synchronous reset validation.
* Verification of X-Y routing decisions across all 5 directions.
* Contention scenarios demonstrating fair rotating priority arbitration.
* Backpressure testing verifying zero packet loss when downstream `ready_in = 0`.

---

## Step 3: Cardinal NIC Implementation & Unit Verification

Build and test the Network Interface Component (`cardinal_nic.v`) strictly adhering to the submission specification.

### 1. NIC Interface & Architecture
* **Module Declaration**:
  ```verilog
  module cardinal_nic (
      input         clk, reset,
      input  [1:0]  addr,
      input  [63:0] d_in,
      output [63:0] d_out,
      input         nicEn, nicEnWr,
      input         net_si,
      output        net_ri,
      input  [63:0] net_di,
      output        net_so,
      input         net_ro,
      output [63:0] net_do,
      input         net_polarity
  );
  ```
* **Storage Registers**:
  * 64-bit `net_in_buf` (network $\rightarrow$ processor) with 1-bit `net_in_status`.
  * 64-bit `net_out_buf` (processor $\rightarrow$ network) with 1-bit `net_out_status`.
* **Processor Memory Map (`nicEn` asserted)**:
  * `2'b00` — Read `net_in_buf` (reading clears the buffer and status).
  * `2'b01` — Read `net_in_status` on `d_out[0]` (upper bits zero-extended).
  * `2'b10` — Write `net_out_buf` (latches `d_in` when `nicEnWr` is asserted and buffer is empty).
  * `2'b11` — Read `net_out_status` on `d_out[0]` (upper bits zero-extended).
* **Network Flow Control**:
  * Transmission validates that packet VC (`net_out_buf[63]`) matches the current network phase (`VC == ~net_polarity`) and downstream router is ready (`net_ro`).

### 2. Standalone NIC Verification (`tb_nic.v`)
* Reset clearing of status flags and buffer contents.
* Processor-side memory read/write operations and status flag transitions.
* Read-to-clear verification on `net_in_buf`.
* Safe stalling under backpressure (`net_ro = 0`).

---

## Step 4: 16-Node 4x4 Mesh Integration & System Verification

Assemble the complete $4 \times 4$ network grid inside `gold_mesh_4x4.v` and verify end-to-end multi-node traffic.

### 1. Mesh Topology & Coordinate Mapping
Node index $N = 4 \times y + x$, with $(0,0)$ at top-left and $(3,3)$ at bottom-right:

```plaintext
           x=0   x=1   x=2   x=3
    y=0     0     1     2     3
    y=1     4     5     6     7
    y=2     8     9    10    11
    y=3    12    13    14    15
```

### 2. Boundary Port Terminations
Edge and corner nodes terminate out-of-bounds directions:
* **North Boundary ($y = 0$, Nodes 0, 1, 2, 3)**: North inputs tied inactive (`si = 0`, `di = 64'h0`, `ro = 0`); North outputs left unconnected.
* **South Boundary ($y = 3$, Nodes 12, 13, 14, 15)**: South inputs tied inactive (`si = 0`, `di = 64'h0`, `ro = 0`); South outputs left unconnected.
* **West Boundary ($x = 0$, Nodes 0, 4, 8, 12)**: West inputs tied inactive (`si = 0`, `di = 64'h0`, `ro = 0`); West outputs left unconnected.
* **East Boundary ($x = 3$, Nodes 3, 7, 11, 15)**: East inputs tied inactive (`si = 0`, `di = 64'h0`, `ro = 0`); East outputs left unconnected.

### 3. Testbench Protocol & Timing Verification
* **Global Polarity**: Initializes to `0` during reset and toggles every cycle on `posedge clk`; all 16 nodes must output the identical polarity value.
* **Injection Rule**: Testbench asserts `nodeN_pesi` and drives `nodeN_pedi` on negative clock edges only when `nodeN_peri = 1` and VC matches phase (`VC == ~polarity`).
* **Delivery & Ejection Rule**: `nodeN_peso` reacts combinationally to `nodeN_pero`. When `nodeN_peso = 1` at a rising edge, the packet is captured, and the destination PE output buffer must be cleared to prevent duplicate delivery.
* **No Self-Delivery**: Guaranteed $S \neq D$ across all test sequences.
* **Zero Corruption**: Verification script confirms that every bit (except the ignored hop field) matches the injected packet bit-for-bit.

---

## Step 5: Simulation Artifacts, Report Generation & Submission Packaging

Finalize regression runs and package deliverables according to EE577B submission rules.

* Execute batch simulations via Cadence Xcelium (`xrun`) to verify clean compilation without syntax warnings or inferred latches.
* Capture waveform dumps (`.shm`) in SimVision demonstrating:
  * Clean global reset and synchronized polarity across all 16 nodes.
  * Minimal-path X-Y multi-hop packet routing (e.g., Node 1 $(1,0)$ to Node 14 $(2,3)$).
  * Combinational Mealy handshake operation and backpressure handling.
* Confirm that output logs record zero dropped packets, zero payload corruptions, and zero duplicate deliveries.
* Package all un-included, macro-free Verilog files and technical documentation into the required submission archive.
