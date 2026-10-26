// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// control_unit.v  -  hard-wired decoder  (Stage 2, ID)
// ----------------------------------------------------------------------------
// Purely combinational lookup table: opcode -> control signals.
// Every signal starts at 0 (= NOP) and each instruction switches on only what
// it needs, so no latches can be inferred.
//
// alu_op: 0 ADD 1 SUB 2 AND 3 OR 4 XOR 5 SHL 6 SHR 7 PASS-B
// ============================================================================
`timescale 1ns / 1ps

module control_unit (
    input  wire [3:0] opcode,
    output reg  [2:0] alu_op,       // ALU operation
    output reg        alu_src_imm,  // ALU B input = imm8
    output reg        ra_is_rd,     // read port A reads rd (ADDI)
    output reg        rb_is_rd,     // read port B reads rd (ST)
    output reg        uses_a,       // instruction really reads port A
    output reg        uses_b,       // instruction really reads port B
    output reg        reg_we,       // write rd in WB
    output reg        mem_to_reg,   // result comes from data memory (LD)
    output reg        mem_we,       // write data memory in MEM (ST)
    output reg        flag_we,      // update Z and C in EX
    output reg        jump,         // JMP
    output reg        br_z,         // BZ
    output reg        br_nz,        // BNZ
    output reg        halt          // HLT
);

    // opcode constants
    localparam OP_NOP  = 4'h0, OP_ADD = 4'h1, OP_SUB = 4'h2, OP_AND  = 4'h3,
               OP_OR   = 4'h4, OP_XOR = 4'h5, OP_SHL = 4'h6, OP_SHR  = 4'h7,
               OP_LDI  = 4'h8, OP_ADDI= 4'h9, OP_LD  = 4'hA, OP_ST   = 4'hB,
               OP_JMP  = 4'hC, OP_BZ  = 4'hD, OP_BNZ = 4'hE, OP_HLT  = 4'hF;

    always @(*) begin
        // ---- defaults: everything off (NOP) ----
        alu_op      = 3'd0;
        alu_src_imm = 1'b0;
        ra_is_rd    = 1'b0;
        rb_is_rd    = 1'b0;
        uses_a      = 1'b0;
        uses_b      = 1'b0;
        reg_we      = 1'b0;
        mem_to_reg  = 1'b0;
        mem_we      = 1'b0;
        flag_we     = 1'b0;
        jump        = 1'b0;
        br_z        = 1'b0;
        br_nz       = 1'b0;
        halt        = 1'b0;

        case (opcode)
            OP_ADD: begin alu_op = 3'd0; uses_a = 1'b1; uses_b = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_SUB: begin alu_op = 3'd1; uses_a = 1'b1; uses_b = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_AND: begin alu_op = 3'd2; uses_a = 1'b1; uses_b = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_OR : begin alu_op = 3'd3; uses_a = 1'b1; uses_b = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_XOR: begin alu_op = 3'd4; uses_a = 1'b1; uses_b = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_SHL: begin alu_op = 3'd5; uses_a = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_SHR: begin alu_op = 3'd6; uses_a = 1'b1;
                          reg_we = 1'b1; flag_we = 1'b1; end
            OP_LDI: begin alu_op = 3'd7; alu_src_imm = 1'b1;
                          reg_we = 1'b1; end
            OP_ADDI:begin alu_op = 3'd0; alu_src_imm = 1'b1; ra_is_rd = 1'b1;
                          uses_a = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end
            OP_LD : begin uses_a = 1'b1; reg_we = 1'b1; mem_to_reg = 1'b1; end
            OP_ST : begin rb_is_rd = 1'b1; uses_a = 1'b1; uses_b = 1'b1;
                          mem_we = 1'b1; end
            OP_JMP: begin jump  = 1'b1; end
            OP_BZ : begin br_z  = 1'b1; end
            OP_BNZ: begin br_nz = 1'b1; end
            OP_HLT: begin halt  = 1'b1; end
            OP_NOP: ;   // all signals stay 0
            default: ;
        endcase
    end

endmodule