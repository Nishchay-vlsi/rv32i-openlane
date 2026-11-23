# RV32I RISC-V Core: RTL to GDSII (OpenLane + Sky130)

A 32-bit RISC-V (RV32I) single-cycle processor core written in Verilog, verified in simulation, and taken through the complete RTL-to-GDSII flow with OpenLane on the SkyWater 130 nm PDK.

## Results

Frequency sweep, same design and floorplan settings (core utilization 35%, placement density 0.45), only the clock period changed. Timing numbers are from post-route signoff STA (typical corner).

| Clock | Frequency | Setup slack | Hold slack | Result |
|---|---|---|---|---|
| 20 ns | 50 MHz | met | met | Pass |
| 16 ns | 62.5 MHz | +1.16 ns | +0.45 ns | Pass |
| **15 ns** | **66.7 MHz** | **+0.61 ns** | **+0.46 ns** | **Pass** |
| 14 ns | 71.4 MHz | about -0.09 ns | met | Fail |
| 10 ns | 100 MHz | -3.64 ns (flow WNS) | met | Fail |

- Maximum closed frequency: **66.7 MHz (15 ns)**
- Die area: 0.219 mm2, about 6.4K synthesized standard cells
- Magic DRC: clean. LVS: 0 errors. Routing (TritonRoute) violations: 0
- Known open items: 10-13 antenna violations and max-fanout/slew warnings in default runs

## Critical path analysis

The worst path runs from the instruction input (`imem_rdata`) through decode, register file read and the ALU to the data memory address output (`dmem_addr`), all in one cycle. OpenLane reserves 20% of the period for input and output delay, so the logic gets about 60% of the clock period. This single long path limits the frequency, which is the motivation for a 5-stage pipeline (next step).

## Design

| Module | Function |
|---|---|
| `regfile.v` | 32 x 32-bit register file, x0 hardwired to zero |
| `alu.v` | 10 operations: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| `imm_gen.v` | I, S, B, U, J immediate generator |
| `control.v` | Main decoder and ALU control |
| `rv32i_core.v` | Single-cycle core: PC, branch logic, write-back |

Instruction and data memories are external to the core (ports `imem_*` / `dmem_*`).

## Verification

Icarus Verilog testbenches for the register file, ALU, decoder and full core. The core testbench runs a small program (addi, add, sw, lw, beq) and checks registers, memory and PC.

## Status
- [x] Register file + testbench
- [x] ALU, decoder, control, branch logic
- [x] Single-cycle core
- [x] OpenLane runs and frequency sweep
- [ ] Fix antenna violations
- [ ] 5-stage pipeline with hazard handling and forwarding
- [ ] Pipelined core OpenLane run and comparison

## Tools
Icarus Verilog, GTKWave, OpenLane, Sky130 PDK, Magic, KLayout
