// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// imem.v  -  256 x 16-bit instruction ROM  (Stage 1, IF)
// ----------------------------------------------------------------------------
// The test program is built into this file, so Vivado can never lose it.
// Asynchronous read: the instruction appears in the same cycle as the PC.
//
// Encoding reminder
//   R-type : opcode[15:12] rd[11:9] rs1[8:6] rs2[5:3] 000
//   R1-type: opcode[15:12] rd[11:9] rs1[8:6] 000000
//   I-type : opcode[15:12] rd[11:9] 0        imm8[7:0]
//   J-type : opcode[15:12] 0000              addr8[7:0]
//
// Opcodes: 0 NOP 1 ADD 2 SUB 3 AND 4 OR 5 XOR 6 SHL 7 SHR
//          8 LDI 9 ADDI A LD B ST C JMP D BZ E BNZ F HLT
//
// To run your own program: replace the case items below (unused addresses
// return NOP). Remember to update the expected values in the testbench.
// ============================================================================
`timescale 1ns / 1ps

module imem (
    input  wire [7:0]  addr,
    output reg  [15:0] instr
);

    always @(*) begin
        case (addr)
            // ---- forwarding at distances 1, 2 and 3 -------------------------
            8'h00: instr = 16'h823C; // LDI  R1, 0x3C      R1 = 0x3C
            8'h01: instr = 16'h840F; // LDI  R2, 0x0F      R2 = 0x0F
            8'h02: instr = 16'h3650; // AND  R3, R1, R2    R3 = 0x0C (R2 d1, R1 d2)
            8'h03: instr = 16'h4850; // OR   R4, R1, R2    R4 = 0x3F (R1 d3 bypass)
            8'h04: instr = 16'h5CE0; // XOR  R6, R3, R4    R6 = 0x33
            8'h05: instr = 16'h6D80; // SHL  R6, R6        R6 = 0x66, C = 0
            8'h06: instr = 16'h2FB0; // SUB  R7, R6, R6    R7 = 0x00, Z = 1
            // ---- taken BZ with two wrong-path instructions ------------------
            8'h07: instr = 16'hD00A; // BZ   0x0A          taken
            8'h08: instr = 16'h8EFF; // LDI  R7, 0xFF      wrong path (flushed)
            8'h09: instr = 16'h8C00; // LDI  R6, 0x00      wrong path (flushed)
            // ---- loop: R2 = 5 + 4 + 3 + 2 + 1 ------------------------------
            8'h0A: instr = 16'h8205; // LDI  R1, 5
            8'h0B: instr = 16'h8400; // LDI  R2, 0
            8'h0C: instr = 16'h1488; // loop: ADD R2, R2, R1
            8'h0D: instr = 16'h92FF; //       ADDI R1, 0xFF   (R1 - 1)
            8'h0E: instr = 16'hE00C; //       BNZ  loop       taken 4 times
            // ---- shift right with carry, then a jump -----------------------
            8'h0F: instr = 16'h8603; // LDI  R3, 0x03
            8'h10: instr = 16'h76C0; // SHR  R3, R3        R3 = 0x01, C = 1
            8'h11: instr = 16'hC014; // JMP  0x14          taken
            8'h12: instr = 16'h8E11; // LDI  R7, 0x11      wrong path (flushed)
            8'h13: instr = 16'h8699; // LDI  R3, 0x99      wrong path (flushed)
            // ---- store, load, load-use stall, carry -------------------------
            8'h14: instr = 16'h8820; // LDI  R4, 0x20
            8'h15: instr = 16'hB500; // ST   R2, [R4]      mem[0x20] = 0x0F
            8'h16: instr = 16'hAB00; // LD   R5, [R4]      R5 = 0x0F
            8'h17: instr = 16'h9AF0; // ADDI R5, 0xF0      load-use: 1 stall, R5 = 0xFF
            8'h18: instr = 16'h9A01; // ADDI R5, 1         R5 = 0x00, Z = 1, C = 1
            8'h19: instr = 16'hF000; // HLT
            default: instr = 16'h0000; // NOP
        endcase
    end

endmodule