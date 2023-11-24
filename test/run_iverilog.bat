md simulation
del sim.out wave.vcd
iverilog -o sim.out test.sv
vvp -n sim.out