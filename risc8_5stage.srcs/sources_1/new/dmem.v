// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// dmem.v  -  256 x 8-bit data memory  (Stage 4, MEM)
// ----------------------------------------------------------------------------
// * Asynchronous read  (LD gets its byte in the same cycle as the address).
// * Synchronous write  (ST writes on the rising clock edge).
// Vivado maps this to distributed LUT-RAM.
// ============================================================================
`timescale 1ns / 1ps

module dmem (
    input  wire       clk,
    input  wire       we,       // write enable (ST in MEM)
    input  wire [7:0] addr,     // byte address
    input  wire [7:0] wdata,    // store data
    output wire [7:0] rdata     // load data
);

    reg [7:0] mem [0:255];
    integer i;

    // all locations start at zero (valid for simulation and FPGA init)
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'h00;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
    end

    assign rdata = mem[addr];

endmodule