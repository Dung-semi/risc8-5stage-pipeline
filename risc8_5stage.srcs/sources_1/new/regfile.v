// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// regfile.v  -  8 x 8-bit register file  (read in ID, written in WB)
// ----------------------------------------------------------------------------
// * Two asynchronous read ports (A and B), one synchronous write port.
// * Write-through bypass: if WB writes the register that ID is reading in the
//   same cycle, the new value is returned immediately. This removes the
//   distance-3 data hazard without any stall.
// * R0 is an ordinary register (it is NOT hard-wired to zero).
// ============================================================================
`timescale 1ns / 1ps

module regfile (
    input  wire       clk,
    input  wire       rst,
    // write port (from WB)
    input  wire       we,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata,
    // read port A
    input  wire [2:0] ra_addr,
    output wire [7:0] ra_data,
    // read port B
    input  wire [2:0] rb_addr,
    output wire [7:0] rb_data
);

    reg [7:0] regs [0:7];
    integer i;

    // synchronous write, synchronous reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 8'h00;
        end else if (we) begin
            regs[waddr] <= wdata;
        end
    end

    // asynchronous read with write-through bypass
    assign ra_data = (we && (waddr == ra_addr)) ? wdata : regs[ra_addr];
    assign rb_data = (we && (waddr == rb_addr)) ? wdata : regs[rb_addr];

endmodule