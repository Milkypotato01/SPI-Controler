`timescale 1ns/1ps
module tb_baud_generator;
    localparam CLK_DIV_WIDTH = 8;
    logic clk = 0, rst_n = 0, en = 0, tick;
    logic [CLK_DIV_WIDTH-1:0] div;
    int errors = 0;

    baud_generator #(.CLK_DIV_WIDTH(CLK_DIV_WIDTH)) dut (.*);
    always #5 clk = ~clk;
    initial begin $dumpfile("sim/dump_baud.vcd"); $dumpvars(0, tb_baud_generator); end

    task automatic run(input [CLK_DIV_WIDTH-1:0] d);
        int last = -1, n = 0, now = 0, exp_d = (d == 0) ? 1 : d;
        @(negedge clk); div = d; en = 1;
        repeat (exp_d * 6 + 2) begin
            @(posedge clk); now++;
            if (tick) begin
                if (last >= 0 && (now - last) != exp_d) begin
                    errors++; $display("ERROR div=%0d spacing=%0d", d, now - last);
                end
                last = now; n++;
            end
        end
        if (n < 5) begin errors++; $display("ERROR div=%0d too few ticks (%0d)", d, n); end
        en = 0; @(posedge clk);
        if (tick) begin errors++; $display("ERROR tick while disabled"); end
    endtask

    initial begin
        repeat (3) @(posedge clk); rst_n = 1;
        run(0); run(1); run(2); run(7); run(255);
        if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
        $finish;
    end
endmodule
