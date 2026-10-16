RTL = rtl/*.sv
.PHONY: lint sim unit wave synth all clean
all: lint sim unit

lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME $(RTL) --top-module spi_master
	verilator --lint-only -Wall -Wno-DECLFILENAME $(RTL) --top-module spi_slave

sim:
	iverilog -g2012 -o sim/sim.out tb/tb_spi_master.sv $(RTL) && vvp sim/sim.out

unit:
	iverilog -g2012 -o sim/baud.out tb/tb_baud_generator.sv rtl/baud_generator.sv && vvp sim/baud.out
	iverilog -g2012 -o sim/sr.out tb/tb_shift_register.sv rtl/shift_register.sv && vvp sim/sr.out

wave:
	gtkwave sim/dump.vcd

synth:
	yosys -s synth/synth.ys | tee synth/synth_report.txt

clean:
	rm -f sim/*.out sim/*.vcd synth/synth_report.txt
