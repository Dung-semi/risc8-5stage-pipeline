## ============================================================================
## Lê Kỳ Dũng - mã số sinh viên SE190745
## ----------------------------------------------------------------------------
## risc8.xdc  -  constraints for risc8_5stage_core
## ----------------------------------------------------------------------------
## Tells Vivado the target clock: 100 MHz (10 ns period).
## Used by synthesis, implementation and the timing check (WNS must be >= 0).
## No pin assignments: this project is simulated and timed only, not loaded
## onto a real board.
## ============================================================================

create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]