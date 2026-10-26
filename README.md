# RISC8 – 8-bit 5-Stage Pipelined RISC Processor

An 8-bit RISC processor with a classic five-stage pipeline (**IF → ID → EX → MEM → WB**),
written in synthesisable Verilog-2001, verified with a self-checking testbench and
implemented with **AMD Vivado 2026.1** for a Xilinx Artix-7 FPGA (`xc7a35tcpg236-1`).

**Author:** Lê Kỳ Dũng – Student ID **SE190745**

---

## Features

- 8 general-purpose 8-bit registers (`R0`–`R7`) and two flags: **Z** (zero) and **C** (carry)
- 16 instructions, fixed 16-bit instruction format, Harvard architecture
- 256 × 16-bit instruction memory, 256 × 8-bit data memory
- **Data forwarding** from EX/MEM and MEM/WB, plus a write-through register file
- **One-cycle stall** for load-use hazards
- **Two-cycle flush** for taken branches and jumps (static predict-not-taken)
- Self-checking testbench that prints the pipeline state every cycle

## Results

| Metric | Value |
|---|---|
| Test program | 34 instructions in 51 cycles, **CPI = 1.50** |
| Simulation | **9 / 9 checks PASS** (`*** ALL TESTS PASSED ***` at 526 ns) |
| Slice LUTs | 240 (≈ 1.2 % of the device) |
| Flip-flops | 186 (≈ 0.4 %) |
| Block RAM / DSP | 0 / 0 |
| Timing @ 100 MHz | WNS = **+1.747 ns**, WHS = +0.040 ns |
| Estimated max clock | **≈ 121 MHz** |
| Total on-chip power | 0.084 W |

The cycle count is fully explained:
`34 instructions + 4 pipeline fill + 1 load-use stall + 6 taken branches × 2 = 51 cycles`.



## Pipeline

| Stage | Work |
|---|---|
| **IF** | Fetch the instruction at `PC` from instruction memory |
| **ID** | Decode the opcode, generate control signals, read registers |
| **EX** | ALU operation, update Z/C flags, resolve branches and jumps |
| **MEM** | Load / store data memory |
| **WB** | Write the result back to the register file |

## Hazard handling

| Hazard | Solution | Cost |
|---|---|---|
| RAW, distance 1–2 | Forward from EX/MEM or MEM/WB to the ALU inputs | 0 cycles |
| RAW, distance 3 | Write-through bypass in the register file | 0 cycles |
| Load-use | Stall: hold PC and IF/ID, insert a bubble | 1 cycle |
| Taken branch / jump | Flush the two wrong-path instructions | 2 cycles |

## Instruction set

| Opcode | Instr. | Operation | Opcode | Instr. | Operation |
|---|---|---|---|---|---|
| 0 | NOP  | no operation          | 8 | LDI  | rd ← imm8 |
| 1 | ADD  | rd ← rs1 + rs2        | 9 | ADDI | rd ← rd + imm8 |
| 2 | SUB  | rd ← rs1 − rs2        | A | LD   | rd ← MEM[rs1] |
| 3 | AND  | rd ← rs1 & rs2        | B | ST   | MEM[rs1] ← rd |
| 4 | OR   | rd ← rs1 \| rs2       | C | JMP  | PC ← addr8 |
| 5 | XOR  | rd ← rs1 ^ rs2        | D | BZ   | if Z = 1: PC ← addr8 |
| 6 | SHL  | rd ← rs1 << 1         | E | BNZ  | if Z = 0: PC ← addr8 |
| 7 | SHR  | rd ← rs1 >> 1         | F | HLT  | stop |

Instruction formats (16 bits):

```
R-type : opcode[15:12] rd[11:9] rs1[8:6] rs2[5:3] 000
R1-type: opcode[15:12] rd[11:9] rs1[8:6] 000000
I-type : opcode[15:12] rd[11:9] 0        imm8[7:0]
J-type : opcode[15:12] 0000              addr8[7:0]
```

Example: `0x823C` = `1000 001 0 00111100` → **LDI R1, 0x3C**

## Repository structure


## How to run in Vivado

1. Create a new **RTL Project** and select the part `xc7a35tcpg236-1`.
2. Add the 7 files in `design_sources/` as design sources, `constraints/risc8.xdc`
   as a constraint, and `sim_sources/tb_risc8_5stage.v` as a simulation source.
3. Set `risc8_5stage_core` as the design top and `tb_risc8_5stage` as the simulation top.
4. **Run Simulation → Run Behavioral Simulation**.
   The Tcl Console must end with `*** ALL TESTS PASSED ***`.
5. **Run Synthesis → Run Implementation → Report Timing Summary** (WNS must be positive).

## Documentation

- Full report: [`docs/report.pdf`](docs/report.pdf)
- Slides: [`docs/slides.pptx`](docs/slides.pptx)
