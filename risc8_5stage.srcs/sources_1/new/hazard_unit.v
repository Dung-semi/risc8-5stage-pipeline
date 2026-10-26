// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// hazard_unit.v  -  forwarding selection and load-use stall
// ----------------------------------------------------------------------------
// Purely combinational.
//
// Forwarding (for the instruction in EX, separately for operand A and B):
//   1. MEM stage writes this register and is NOT a load -> take EX/MEM result
//   2. else WB stage writes this register                -> take MEM/WB result
//   3. else                                              -> value read in ID
//   fwd_*_sel : 2'd0 = ID value, 2'd1 = EX/MEM, 2'd2 = MEM/WB
//
// Load-use stall:
//   a load is in EX and the valid instruction in ID reads the register the
//   load will write -> stall = 1 for one cycle (hold PC and IF/ID, bubble
//   into ID/EX).
//
// Only operands the instruction really uses (uses_a / uses_b) are compared,
// so unused register fields never cause a false forward or stall.
// ============================================================================
`timescale 1ns / 1ps

module hazard_unit (
    // instruction in ID
    input  wire       ifid_valid,
    input  wire [2:0] id_ra,
    input  wire [2:0] id_rb,
    input  wire       id_uses_a,
    input  wire       id_uses_b,
    // instruction in EX
    input  wire       idex_valid,
    input  wire [2:0] idex_ra,
    input  wire [2:0] idex_rb,
    input  wire       idex_uses_a,
    input  wire       idex_uses_b,
    input  wire [2:0] idex_rd,
    input  wire       idex_reg_we,
    input  wire       idex_mem_to_reg,
    // instruction in MEM
    input  wire       exmem_valid,
    input  wire [2:0] exmem_rd,
    input  wire       exmem_reg_we,
    input  wire       exmem_mem_to_reg,
    // instruction in WB
    input  wire       memwb_valid,
    input  wire [2:0] memwb_rd,
    input  wire       memwb_reg_we,
    // outputs
    output reg  [1:0] fwd_a_sel,
    output reg  [1:0] fwd_b_sel,
    output wire       stall
);

    // can the MEM / WB stage supply a value?
    wire mem_can_fwd = exmem_valid & exmem_reg_we & ~exmem_mem_to_reg;
    wire wb_can_fwd  = memwb_valid & memwb_reg_we;

    // ---------------- operand A ----------------
    always @(*) begin
        fwd_a_sel = 2'd0;
        if (idex_valid && idex_uses_a) begin
            if (mem_can_fwd && (exmem_rd == idex_ra))
                fwd_a_sel = 2'd1;            // newest value wins
            else if (wb_can_fwd && (memwb_rd == idex_ra))
                fwd_a_sel = 2'd2;
        end
    end

    // ---------------- operand B ----------------
    always @(*) begin
        fwd_b_sel = 2'd0;
        if (idex_valid && idex_uses_b) begin
            if (mem_can_fwd && (exmem_rd == idex_rb))
                fwd_b_sel = 2'd1;
            else if (wb_can_fwd && (memwb_rd == idex_rb))
                fwd_b_sel = 2'd2;
        end
    end

    // ---------------- load-use stall ----------------
    wire load_in_ex = idex_valid & idex_reg_we & idex_mem_to_reg;

    assign stall = load_in_ex & ifid_valid &
                   ((id_uses_a & (id_ra == idex_rd)) |
                    (id_uses_b & (id_rb == idex_rd)));

endmodule