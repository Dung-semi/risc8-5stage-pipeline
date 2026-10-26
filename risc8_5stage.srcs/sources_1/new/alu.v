// ============================================================================
// Lê Kỳ Dũng - mã số sinh viên SE190745
// ----------------------------------------------------------------------------
// alu.v  -  8-bit Arithmetic Logic Unit  (Stage 3, EX)
// ----------------------------------------------------------------------------
// Purely combinational. Computes the result and the Z / C flags.
//
//   op  operation          C output
//   0   ADD  y = a + b     carry out of bit 7
//   1   SUB  y = a - b     borrow (1 when a < b)
//   2   AND  y = a & b     unchanged (c_in)
//   3   OR   y = a | b     unchanged (c_in)
//   4   XOR  y = a ^ b     unchanged (c_in)
//   5   SHL  y = a << 1    old bit 7
//   6   SHR  y = a >> 1    old bit 0
//   7   PASS y = b         unchanged (c_in)   (used by LDI)
//
// Z is 1 whenever the result is zero.
// ============================================================================
`timescale 1ns / 1ps

module alu (
    input  wire [7:0] a,        // operand A
    input  wire [7:0] b,        // operand B (register or immediate)
    input  wire [2:0] op,       // operation select
    input  wire       c_in,     // current carry flag (kept by logic ops)
    output reg  [7:0] y,        // result
    output wire       z,        // zero flag
    output reg        c         // carry / borrow flag
);

    // 9-bit sum and difference so that the carry / borrow appears in bit 8
    wire [8:0] sum  = {1'b0, a} + {1'b0, b};
    wire [8:0] diff = {1'b0, a} - {1'b0, b};

    always @(*) begin
        // defaults: avoid latches
        y = 8'h00;
        c = c_in;
        case (op)
            3'd0: begin y = sum[7:0];          c = sum[8];  end  // ADD
            3'd1: begin y = diff[7:0];         c = diff[8]; end  // SUB (borrow)
            3'd2: begin y = a & b;                          end  // AND
            3'd3: begin y = a | b;                          end  // OR
            3'd4: begin y = a ^ b;                          end  // XOR
            3'd5: begin y = {a[6:0], 1'b0};    c = a[7];    end  // SHL
            3'd6: begin y = {1'b0, a[7:1]};    c = a[0];    end  // SHR
            default: begin y = b;                           end  // PASS B
        endcase
    end

    assign z = (y == 8'h00);

endmodule