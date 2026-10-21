# Cardinal NoC Router & Network Interface Component (NIC)

## Project Overview
This repository contains the synthesizable Verilog RTL implementation and comprehensive verification testbenches for **Phase I** of the USC EE577B course project. The objective is to design, implement, and verify the communication backbone for a chip multiprocessor (CMP), consisting of:
1. **Cardinal 4x4 2D Mesh Network-on-Chip (NoC)**: A packet-switched on-chip network utilizing dimension-order ($X-Y$) routing, 2-virtual-channel (VC) multiplexing for deadlock freedom, rotating-priority arbitration, and a virtual cut-through switching architecture.
2. **Cardinal Network Interface Component (NIC)**: A memory-mapped coprocessor interface bridging processing elements (PEs) and the local NoC router ports with hardware-managed handshaking and polarity-phase alignment.

---

## Architectural Specifications

### 1. Packet & Flit Format (64-Bit Fixed Length)
All packets across the NoC are single-flit, 64 bits wide, adhering strictly to `Rules_for_student.txt`:

| Bit Range | Field Name | Description |
| :--- | :--- | :--- |
| `[63]` | **VC** | Virtual Channel indicator: `0` = VC0 (Even), `1` = VC1 (Odd) |
| `[62]` | **Reserved** | Reserved field (tied to `0`) |
| `[61:60]` | **Dest X** | Destination Column index ($x \in [0, 3]$) |
| `[59:58]` | **Dest Y** | Destination Row index ($y \in [0, 3]$) |
| `[57:56]` | **Reserved** | Reserved field (tied to `0`) |
| `[55:48]` | **Hop Field** | Unary-encoded Manhattan distance ($H = \Vert{}dx\Vert{} + \Vert{}dy\Vert{}$) |
| `[47:32]` | **Source** | Source Node ID ($S \in [0, 15]$) |
| `[31:0]` | **Payload** | Unique packet ID / transaction data |

### 2. Network Topology: 4x4 2D Mesh (`gold_mesh_4x4`)
The top-level entity arranges 16 `router_node` instances in a row-major Cartesian layout:
* **Node Indexing**: $\text{Node ID } N = 4 \times y + x$
* **Origin $(0,0)$**: Upper-Left corner (Node 0); $(3,3)$ is the Bottom-Right corner (Node 15).
* **Dimension-Order Routing**: Strictly routes along $X$ first (East/West) until $x_{\text{dest}} == x_{\text{current}}$, then routes along $Y$ (North/South) until local arrival at the PE port.
* **Perimeter Tie-Offs**: All external-facing boundary ports (Row 0 Up, Row 3 Down, Col 0 Left, Col 3 Right) are cleanly tied off to `0` to prevent floating nets or spurious backpressure.

### 3. Cardinal NIC (`cardinal_nic`)
* **Processor Memory Map**:
  * `addr = 2'b00`: Input Buffer Read (synchronously outputs 64-bit packet onto `d_out`; clears `in_buf_full` flag upon read).
  * `addr = 2'b01`: Input Status Read (returns `d_out = {63'h0, in_buf_full}`).
  * `addr = 2'b10`: Output Buffer Write (synchronously latches `d_in` when `nicEn && nicEnWr`; writes to occupied buffers are ignored).
  * `addr = 2'b11`: Output Status Read (returns `d_out = {63'h0, out_buf_full}`).
* **Virtual Channel Phase Matching**:
  * Packets with `VC = 0` (`out_buf[63] == 0`) are transmitted only when `net_polarity == 1`.
  * Packets with `VC = 1` (`out_buf[63] == 1`) are transmitted only when `net_polarity == 0`.
  * Evaluated combinationally via: `net_so = out_buf_full & net_ro & (out_buf[63] == ~net_polarity)`.

---

## Repository Directory Structure

```text
├── docs/
│   ├── cardinal_nic diagram.png            # Microarchitecture block diagram for NIC
│   ├── gold_mesh_4x4 diagram.png           # Interconnect diagram for 4x4 mesh
│   ├── router_node diagram.jpg             # Router node datapath and control diagram
│   ├── router_input_ctrl diagram.jpg       # Input controller and VC buffer schematic
│   └── router_output_ctrl diagram.jpg      # Output arbiter and crossbar schematic
├── out/
│   ├── cardinal_nic.out                    # Automated test execution log for NIC
│   ├── tb_gold_mesh_4x4.out                # Gather simulation log for 4x4 mesh
│   └── tb_router_node.out                  # Unit simulation log for standalone router node
├── rtl/
│   ├── mesh/
│   │   └── gold_mesh_4x4.v                 # Top-level 16-node 4x4 mesh entity
│   ├── nic/
│   │   └── cardinal_nic.v                  # Network Interface Component RTL
│   └── router/
│       ├── router_input_ctrl.v             # Input controller with dual-VC buffers
│       ├── router_output_ctrl.v            # Rotating-priority output controller
│       └── router_node.v                   # 5-port Cardinal router node
├── tb/
│   ├── tb_cardinal_nic.v                   # Self-checking testbench for NIC
│   ├── tb_gold_mesh_4x4.v                  # Top-level mesh gather testbench
│   └── tb_router_node.v                    # Standalone unit testbench for router node
├── .gitignore                              # Ignores CAD logs, waveforms, and lockfiles
├── EE577B-Phase-1-(Group-Project).md       # Initial project plan, architectural notes, and specifications
└── README.md                               # Project documentation and quickstart guide

```

## Verification & Simulation Guide
Simulations are configured for **Cadence Xcelium (`xrun`)** on Linux/SCF environments using a $250\text{ MHz}$ ($4.0\text{ ns}$) clock period and synchronous active-high reset.

### 1. Compile & Simulate the 4x4 Mesh Network
Run the full gather transaction suite across all 16 mesh nodes:

```bash
xrun -64bit -access +rwc \
  rtl/router/router_input_ctrl.v \
  rtl/router/router_output_ctrl.v \
  rtl/router/router_node.v \
  rtl/mesh/gold_mesh_4x4.v \
  tb/tb_gold_mesh_4x4.v
```
*Output logs are saved to `out/tb_gold_mesh_4x4.out`.*

### 2. Compile & Simulate the Cardinal NIC
Verify single-node switching, dual-VC buffers, and rotating-priority arbitration:
```bash
xrun -64bit -access +rwc \
  rtl/router/router_input_ctrl.v \
  rtl/router/router_output_ctrl.v \
  rtl/router/router_node.v \
  tb/tb_router_node.v
```
*Output logs are saved to `out/tb_router_node.out`.*

### 3. Compile & Simulate the Cardinal NIC
Run the self-checking unit verification testbench for the NIC:

```bash
xrun -64bit -access +rwc tb/tb_cardinal_nic.v rtl/nic/cardinal_nic.v
```
*Output logs are saved to `out/cardinal_nic.out`.*

### 4. Interactive Debugging & Waveform Inspection with SimVision
To launch the Cadence SimVision waveform GUI:

```bash
xrun -64bit -gui -access +rwc tb/tb_cardinal_nic.v rtl/nic/cardinal_nic.v
```

#### Key SimVision Waveform Windows:

- **Reset Operation**: `0 ps` to `20,000 ps` (verifies `reset` deassertion, `net_polarity` initialization to `0`, `net_so = 0`, and `net_ri = 1`).
- **Handshake (Blocking vs. Non-Blocking)**: `35,000 ps` to `55,000 ps` (shows backpressure when `net_ro = 0` and phase-matched injection when `net_ro = 1`).
- **Processor Store (Available vs. Blocked)**: `20,000 ps` to `40,000 ps` (verifies valid buffer storage and rejection of illegal overwrites).
- **Processor Load (Available vs. Empty)**: `85,000 ps` to `110,000 ps` (verifies packet data reception and pop-on-read buffer status clearing).

<p align="center">
  <img src="docs/Cardinal NIC Module Waveform.png" alt="Cardinal NIC Module Waveform" width="1000"/>
  <br/>
  <em>Figure 1: Cardinal NIC Module Waveform</em>
</p>

## Authors & Acknowledgments

- **Course**: EE577B - VLSI System Design, University of Southern California (USC)
- **Author**: [Kevelyn Lin](https://github.com/WanYing1224), [Yuxiang Luo](https://github.com/lllyxxxx)

