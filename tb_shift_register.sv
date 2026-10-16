`timescale 1ns/1ps
module tb_shift_register;
    localparam DATA_WIDTH = 8;
    logic clk = 0, rst_n = 0, load = 0, shift_en = 0, serial_in = 0;
    logic [DATA_WIDTH-1:0] load_data = '0;
    logic so_m, so_l;
    logic [DATA_WIDTH-1:0] do_m, do_l;
    int errors = 0;

    shift_register #(.DATA_WIDTH(DATA_WIDTH), .MSB_FIRST(1)) dut_msb (
        .clk, .rst_n, .load, .load_data, .shift_en, .serial_in, .serial_out(so_m), .data_out(do_m));
    shift_register #(.DATA_WIDTH(DATA_WIDTH), .MSB_FIRST(0)) dut_lsb (
        .clk, .rst_n, .load, .load_data, .shift_en, .serial_in, .serial_out(so_l), .data_out(do_l));

    always #5 clk = ~clk;
    initial begin $dumpfile("sim/dump_sr.vcd"); $dumpvars(0, tb_shift_register); end

    initial begin
        logic [DATA_WIDTH-1:0] v, in_w;
        v = 8'hB2; in_w = 8'h4D;
        repeat (3) @(posedge clk); rst_n = 1;
        @(negedge clk); load_data = v; load = 1;
        @(negedge clk); load = 0;
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (so_m !== v[DATA_WIDTH-1-i]) begin errors++; $display("ERROR msb out bit %0d", i); end
            if (so_l !== v[i])              begin errors++; $display("ERROR lsb out bit %0d", i); end
            serial_in = in_w[DATA_WIDTH-1-i]; shift_en = 1;   // MSB-first in for msb instance
            @(negedge clk);
        end
        shift_en = 0;
        if (do_m !== in_w) begin errors++; $display("ERROR msb data_out %h", do_m); end
        // load priority over shift
        load_data = 8'h11; load = 1; shift_en = 1; @(negedge clk);
        if (do_m !== 8'h11) begin errors++; $display("ERROR load priority"); end
        if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
        $finish;
    end
endmodule
