// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// risc8_5stage_core.v  -  top level of the 8-bit 5-stage RISC processor
// ----------------------------------------------------------------------------
//   IF  -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> WB
//
// Contains: PC, the four pipeline registers, the Z/C flag register, the
// branch and halt logic, the forwarding multiplexers, and instantiates
//   imem, control_unit, regfile, hazard_unit, alu, dmem.
//
// Pipeline-register update priority (one clocked block):
//   halted (freeze)  >  flush (taken branch)  >  halt in pipe  >  stall  >  normal
//
// Hazards
//   * RAW at distance 1/2 : forwarding EX/MEM -> EX and MEM/WB -> EX
//   * RAW at distance 3   : register-file write-through bypass
//   * load-use            : 1-cycle stall, then MEM/WB forwarding
//   * taken branch / jump : resolved in EX, 2 younger instructions flushed
// ============================================================================
`timescale 1ns / 1ps

module risc8_5stage_core (
    input  wire       clk,
    input  wire       rst,          // synchronous, active high
    output wire       halted,       // HLT has reached WB; pipeline frozen
    output wire [7:0] pc_out,       // current PC
    output wire [1:0] flags_out,    // {Z, C}
    output wire       instr_done    // 1 when a valid instruction is in WB
);

    // =========================================================================
    // Pipeline registers and architectural state
    // =========================================================================
    reg  [7:0]  pc;
    reg         z_flag, c_flag;
    reg         halt_done;          // sticky: HLT already counted as done

    // IF/ID (17 bits)
    reg         ifid_valid;
    reg  [15:0] ifid_instr;

    // ID/EX (48 bits)
    reg         idex_valid;
    reg  [2:0]  idex_alu_op;
    reg         idex_alu_src_imm;
    reg         idex_uses_a, idex_uses_b;
    reg         idex_reg_we, idex_mem_to_reg, idex_mem_we, idex_flag_we;
    reg         idex_jump, idex_br_z, idex_br_nz, idex_halt;
    reg  [2:0]  idex_rd, idex_ra, idex_rb;
    reg  [7:0]  idex_a_val, idex_b_val, idex_imm;

    // EX/MEM (32 bits)
    reg         exmem_valid;
    reg         exmem_reg_we, exmem_mem_to_reg, exmem_mem_we, exmem_halt;
    reg  [2:0]  exmem_rd;
    reg  [7:0]  exmem_alu_result, exmem_addr, exmem_st_data;

    // MEM/WB (14 bits)
    reg         memwb_valid;
    reg         memwb_reg_we, memwb_halt;
    reg  [2:0]  memwb_rd;
    reg  [7:0]  memwb_result;

    // =========================================================================
    // Stage 1 : IF
    // =========================================================================
    wire [15:0] if_instr;

    imem u_imem (
        .addr  (pc),
        .instr (if_instr)
    );

    // =========================================================================
    // Stage 2 : ID
    // =========================================================================
    wire [3:0] id_opcode = ifid_instr[15:12];
    wire [2:0] id_rd     = ifid_instr[11:9];
    wire [2:0] id_rs1    = ifid_instr[8:6];
    wire [2:0] id_rs2    = ifid_instr[5:3];
    wire [7:0] id_imm    = ifid_instr[7:0];

    wire [2:0] c_alu_op;
    wire       c_alu_src_imm, c_ra_is_rd, c_rb_is_rd, c_uses_a, c_uses_b;
    wire       c_reg_we, c_mem_to_reg, c_mem_we, c_flag_we;
    wire       c_jump, c_br_z, c_br_nz, c_halt;

    control_unit u_ctrl (
        .opcode      (id_opcode),
        .alu_op      (c_alu_op),
        .alu_src_imm (c_alu_src_imm),
        .ra_is_rd    (c_ra_is_rd),
        .rb_is_rd    (c_rb_is_rd),
        .uses_a      (c_uses_a),
        .uses_b      (c_uses_b),
        .reg_we      (c_reg_we),
        .mem_to_reg  (c_mem_to_reg),
        .mem_we      (c_mem_we),
        .flag_we     (c_flag_we),
        .jump        (c_jump),
        .br_z        (c_br_z),
        .br_nz       (c_br_nz),
        .halt        (c_halt)
    );

    // which register each read port reads
    wire [2:0] id_ra = c_ra_is_rd ? id_rd : id_rs1;   // ADDI reads rd on A
    wire [2:0] id_rb = c_rb_is_rd ? id_rd : id_rs2;   // ST   reads rd on B

    // write-back signals (driven in stage 5)
    wire       wb_we   = memwb_valid & memwb_reg_we & ~halted;
    wire [2:0] wb_addr = memwb_rd;
    wire [7:0] wb_data = memwb_result;

    wire [7:0] id_a_val, id_b_val;

    regfile u_rf (
        .clk     (clk),
        .rst     (rst),
        .we      (wb_we),
        .waddr   (wb_addr),
        .wdata   (wb_data),
        .ra_addr (id_ra),
        .ra_data (id_a_val),
        .rb_addr (id_rb),
        .rb_data (id_b_val)
    );

    // =========================================================================
    // Hazard unit
    // =========================================================================
    wire [1:0] fwd_a_sel, fwd_b_sel;
    wire       stall;

    hazard_unit u_hazard (
        .ifid_valid       (ifid_valid),
        .id_ra            (id_ra),
        .id_rb            (id_rb),
        .id_uses_a        (c_uses_a),
        .id_uses_b        (c_uses_b),
        .idex_valid       (idex_valid),
        .idex_ra          (idex_ra),
        .idex_rb          (idex_rb),
        .idex_uses_a      (idex_uses_a),
        .idex_uses_b      (idex_uses_b),
        .idex_rd          (idex_rd),
        .idex_reg_we      (idex_reg_we),
        .idex_mem_to_reg  (idex_mem_to_reg),
        .exmem_valid      (exmem_valid),
        .exmem_rd         (exmem_rd),
        .exmem_reg_we     (exmem_reg_we),
        .exmem_mem_to_reg (exmem_mem_to_reg),
        .memwb_valid      (memwb_valid),
        .memwb_rd         (memwb_rd),
        .memwb_reg_we     (memwb_reg_we),
        .fwd_a_sel        (fwd_a_sel),
        .fwd_b_sel        (fwd_b_sel),
        .stall            (stall)
    );

    // =========================================================================
    // Stage 3 : EX
    // =========================================================================
    // forwarding multiplexers
    reg [7:0] ex_op_a, ex_op_b;

    always @(*) begin
        case (fwd_a_sel)
            2'd1:    ex_op_a = exmem_alu_result;
            2'd2:    ex_op_a = memwb_result;
            default: ex_op_a = idex_a_val;
        endcase
        case (fwd_b_sel)
            2'd1:    ex_op_b = exmem_alu_result;
            2'd2:    ex_op_b = memwb_result;
            default: ex_op_b = idex_b_val;
        endcase
    end

    // immediate multiplexer
    wire [7:0] alu_b = idex_alu_src_imm ? idex_imm : ex_op_b;

    wire [7:0] alu_y;
    wire       alu_z, alu_c;

    alu u_alu (
        .a    (ex_op_a),
        .b    (alu_b),
        .op   (idex_alu_op),
        .c_in (c_flag),
        .y    (alu_y),
        .z    (alu_z),
        .c    (alu_c)
    );

    // branch logic (flags are always up to date in EX)
    wire take_branch = idex_valid &
                       ( idex_jump |
                        (idex_br_z  &  z_flag) |
                        (idex_br_nz & ~z_flag) );
    wire flush       = take_branch;
    wire [7:0] branch_target = idex_imm;

    // HLT anywhere from EX onward: stop fetching, squash younger instructions
    wire halt_in_pipe = (idex_valid  & idex_halt)  |
                        (exmem_valid & exmem_halt) |
                        (memwb_valid & memwb_halt);

    // =========================================================================
    // Stage 4 : MEM
    // =========================================================================
    wire [7:0] dmem_rdata;

    dmem u_dmem (
        .clk   (clk),
        .we    (exmem_valid & exmem_mem_we & ~halted),
        .addr  (exmem_addr),
        .wdata (exmem_st_data),
        .rdata (dmem_rdata)
    );

    wire [7:0] mem_result = exmem_mem_to_reg ? dmem_rdata : exmem_alu_result;

    // =========================================================================
    // Stage 5 : WB  (register write is done through u_rf above)
    // =========================================================================
    assign halted     = memwb_valid & memwb_halt;
    assign instr_done = memwb_valid & ~halt_done;
    assign pc_out     = pc;
    assign flags_out  = {z_flag, c_flag};

    // ID/EX receives a real instruction only in the normal case
    wire id_advance = ifid_valid & ~flush & ~halt_in_pipe & ~stall;

    // =========================================================================
    // The single clocked block: every pipeline register and the PC
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            pc               <= 8'h00;
            z_flag           <= 1'b0;
            c_flag           <= 1'b0;
            halt_done        <= 1'b0;

            ifid_valid       <= 1'b0;
            ifid_instr       <= 16'h0000;

            idex_valid       <= 1'b0;
            idex_alu_op      <= 3'd0;
            idex_alu_src_imm <= 1'b0;
            idex_uses_a      <= 1'b0;
            idex_uses_b      <= 1'b0;
            idex_reg_we      <= 1'b0;
            idex_mem_to_reg  <= 1'b0;
            idex_mem_we      <= 1'b0;
            idex_flag_we     <= 1'b0;
            idex_jump        <= 1'b0;
            idex_br_z        <= 1'b0;
            idex_br_nz       <= 1'b0;
            idex_halt        <= 1'b0;
            idex_rd          <= 3'd0;
            idex_ra          <= 3'd0;
            idex_rb          <= 3'd0;
            idex_a_val       <= 8'h00;
            idex_b_val       <= 8'h00;
            idex_imm         <= 8'h00;

            exmem_valid      <= 1'b0;
            exmem_reg_we     <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
            exmem_mem_we     <= 1'b0;
            exmem_halt       <= 1'b0;
            exmem_rd         <= 3'd0;
            exmem_alu_result <= 8'h00;
            exmem_addr       <= 8'h00;
            exmem_st_data    <= 8'h00;

            memwb_valid      <= 1'b0;
            memwb_reg_we     <= 1'b0;
            memwb_halt       <= 1'b0;
            memwb_rd         <= 3'd0;
            memwb_result     <= 8'h00;
        end
        else if (halted) begin
            // ---------------- freeze: HLT is in WB ----------------
            halt_done <= 1'b1;
        end
        else begin
            // ---------------- flags (EX) ----------------
            if (idex_valid & idex_flag_we) begin
                z_flag <= alu_z;
                c_flag <= alu_c;
            end

            // ---------------- MEM/WB <- MEM ----------------
            memwb_valid  <= exmem_valid;
            memwb_reg_we <= exmem_valid & exmem_reg_we;
            memwb_halt   <= exmem_valid & exmem_halt;
            memwb_rd     <= exmem_rd;
            memwb_result <= mem_result;

            // ---------------- EX/MEM <- EX ----------------
            exmem_valid      <= idex_valid;
            exmem_reg_we     <= idex_valid & idex_reg_we;
            exmem_mem_to_reg <= idex_valid & idex_mem_to_reg;
            exmem_mem_we     <= idex_valid & idex_mem_we;
            exmem_halt       <= idex_valid & idex_halt;
            exmem_rd         <= idex_rd;
            exmem_alu_result <= alu_y;
            exmem_addr       <= ex_op_a;      // LD/ST address = rs1
            exmem_st_data    <= ex_op_b;      // ST data       = rd (port B)

            // ---------------- ID/EX <- ID ----------------
            // a bubble (id_advance = 0) has every enable forced to 0
            idex_valid       <= id_advance;
            idex_alu_op      <= c_alu_op;
            idex_alu_src_imm <= c_alu_src_imm;
            idex_uses_a      <= id_advance & c_uses_a;
            idex_uses_b      <= id_advance & c_uses_b;
            idex_reg_we      <= id_advance & c_reg_we;
            idex_mem_to_reg  <= id_advance & c_mem_to_reg;
            idex_mem_we      <= id_advance & c_mem_we;
            idex_flag_we     <= id_advance & c_flag_we;
            idex_jump        <= id_advance & c_jump;
            idex_br_z        <= id_advance & c_br_z;
            idex_br_nz       <= id_advance & c_br_nz;
            idex_halt        <= id_advance & c_halt;
            idex_rd          <= id_rd;
            idex_ra          <= id_ra;
            idex_rb          <= id_rb;
            idex_a_val       <= id_a_val;
            idex_b_val       <= id_b_val;
            idex_imm         <= id_imm;

            // ---------------- PC and IF/ID ----------------
            if (flush) begin
                pc         <= branch_target;   // go to the target
                ifid_valid <= 1'b0;            // cancel wrong-path fetch
            end
            else if (halt_in_pipe) begin
                pc         <= pc;              // fetch nothing more
                ifid_valid <= 1'b0;
            end
            else if (stall) begin
                pc         <= pc;              // same instruction waits
                ifid_valid <= ifid_valid;
                ifid_instr <= ifid_instr;
            end
            else begin
                pc         <= pc + 8'd1;
                ifid_valid <= 1'b1;
                ifid_instr <= if_instr;
            end
        end
    end

endmodule