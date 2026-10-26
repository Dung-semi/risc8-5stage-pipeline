// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// tb_risc8_5stage.v  -  self-checking testbench for risc8_5stage_core
// ----------------------------------------------------------------------------
// * 100 MHz clock (10 ns), reset held for 2 cycles
// * prints the pipeline state every cycle
// * waits for 'halted', then checks registers, memory and flags
// * prints statistics (cycles, instructions, CPI, stalls, flushes, forwards)
//   and finally *** ALL TESTS PASSED *** or *** TEST FAILED ***
// ============================================================================
`timescale 1ns / 1ps

module tb_risc8_5stage;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    wire       halted;
    wire [7:0] pc_out;
    wire [1:0] flags_out;
    wire       instr_done;

    risc8_5stage_core dut (
        .clk        (clk),
        .rst        (rst),
        .halted     (halted),
        .pc_out     (pc_out),
        .flags_out  (flags_out),
        .instr_done (instr_done)
    );

    // ---------------- clock: 100 MHz ----------------
    always #5 clk = ~clk;

    // ---------------- statistics ----------------
    integer cycle       = 0;
    integer n_instr     = 0;
    integer n_stall     = 0;
    integer n_flush     = 0;
    integer n_fwd       = 0;
    integer errors      = 0;

    always @(posedge clk) begin
        if (!rst && !halted) begin
            cycle = cycle + 1;
            if (instr_done)              n_instr = n_instr + 1;
            if (dut.stall && !dut.flush) n_stall = n_stall + 1;
            if (dut.flush)               n_flush = n_flush + 1;
            if (dut.fwd_a_sel != 2'd0)   n_fwd   = n_fwd + 1;
            if (dut.fwd_b_sel != 2'd0)   n_fwd   = n_fwd + 1;

            $display("cyc %3d | PC=%h | IF/ID %s %h | ID/EX %b EX/MEM %b MEM/WB %b | stall=%b flush=%b fwdA=%0d fwdB=%0d | Z=%b C=%b",
                     cycle, dut.pc,
                     dut.ifid_valid ? "v" : "-", dut.ifid_instr,
                     dut.idex_valid, dut.exmem_valid, dut.memwb_valid,
                     dut.stall, dut.flush, dut.fwd_a_sel, dut.fwd_b_sel,
                     dut.z_flag, dut.c_flag);
        end
    end

    // ---------------- check helper ----------------
    task check;
        input [8*16-1:0] name;
        input [7:0]      got;
        input [7:0]      exp;
        begin
            if (got === exp)
                $display("  PASS  %0s = 0x%h", name, got);
            else begin
                $display("  FAIL  %0s = 0x%h (expected 0x%h)", name, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    // ---------------- main sequence ----------------
    initial begin
        $display("==== risc8 5-stage pipeline simulation ====");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        #1 rst = 1'b0;

        // wait for HLT to reach WB (with a timeout)
        fork : wait_halt
            begin
                wait (halted === 1'b1);
                disable wait_halt;
            end
            begin
                repeat (2000) @(posedge clk);
                $display("*** TIMEOUT: processor did not halt ***");
                $finish;
            end
        join

        // HLT in WB is the last instruction completing
        cycle   = cycle + 1;
        n_instr = n_instr + 1;
        @(posedge clk); #1;

        $display("");
        $display("==== Results ====");
        check("R1",        dut.u_rf.regs[1],     8'h00);
        check("R2",        dut.u_rf.regs[2],     8'h0F);
        check("R3",        dut.u_rf.regs[3],     8'h01);
        check("R4",        dut.u_rf.regs[4],     8'h20);
        check("R5",        dut.u_rf.regs[5],     8'h00);
        check("R6",        dut.u_rf.regs[6],     8'h66);
        check("R7",        dut.u_rf.regs[7],     8'h00);
        check("MEM[0x20]", dut.u_dmem.mem[8'h20], 8'h0F);
        check("Z,C",       {6'b0, flags_out},    8'h03);

        $display("");
        $display("==== Statistics ====");
        $display("  cycles            : %0d", cycle);
        $display("  instructions      : %0d", n_instr);
        $display("  CPI               : %0d.%02d", cycle / n_instr, (cycle * 100 / n_instr) % 100);
        $display("  load-use stalls   : %0d", n_stall);
        $display("  taken branches    : %0d (2-cycle flush each)", n_flush);
        $display("  forwarded operands: %0d", n_fwd);
        $display("");

        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TEST FAILED: %0d error(s) ***", errors);
        $finish;
    end

endmodule