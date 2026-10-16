`timescale 1ns/1ps
// Self-checking integration TB: spi_master <-> spi_slave (CPOL=1, CPHA=0).
// Covers baud_generator, shift_register, sync_ff, both FSMs.
module tb_spi_master;
    localparam DATA_WIDTH    = 8;
    localparam CLK_DIV_WIDTH = 8;
    localparam CPOL          = 1;
    localparam MSB_FIRST     = 1;
    localparam CLK_PERIOD    = 10;

    logic clk = 1'b0, rst_n;
    logic start;
    logic [DATA_WIDTH-1:0]    m_tx, s_tx, m_rx, s_rx;
    logic [CLK_DIV_WIDTH-1:0] clk_div;
    logic busy, done, s_rx_valid;
    logic sclk, mosi, miso, cs_n;

    int errors = 0;
    int checks = 0;

    spi_master #(.DATA_WIDTH(DATA_WIDTH), .CLK_DIV_WIDTH(CLK_DIV_WIDTH),
                 .CPOL(CPOL), .MSB_FIRST(MSB_FIRST)) dut_m (
        .clk(clk), .rst_n(rst_n), .start(start), .tx_data(m_tx), .clk_div(clk_div),
        .busy(busy), .done(done), .rx_data(m_rx),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n));

    spi_slave #(.DATA_WIDTH(DATA_WIDTH), .CPOL(CPOL), .MSB_FIRST(MSB_FIRST)) dut_s (
        .clk(clk), .rst_n(rst_n), .sclk(sclk), .mosi(mosi), .cs_n(cs_n), .miso(miso),
        .tx_data(s_tx), .rx_data(s_rx), .rx_valid(s_rx_valid));

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_spi_master);
    end

    // ---------------- checkers ----------------
    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[%0t] ERROR: %s", $time, msg);
        end
    endtask

    // capture results
    logic [DATA_WIDTH-1:0] m_rx_cap, s_rx_cap;
    logic                  s_seen;
    always @(posedge clk) begin
        if (done)       m_rx_cap <= m_rx;
        if (s_rx_valid) begin s_rx_cap <= s_rx; s_seen <= 1'b1; end
    end

    // SCLK idle level whenever CS is inactive
    always @(posedge clk) if (rst_n && cs_n) check(sclk === CPOL[0], "SCLK not idle while cs_n high");

    // per-bit MOSI / MISO check on leading edge, edge count
    logic [DATA_WIDTH-1:0] exp_m_tx, exp_s_tx;
    int lead_cnt = 0;
    localparam LEAD_EDGE_IS_NEG = (CPOL != 0);
    always @(sclk) if (!cs_n && rst_n) begin
        if ((LEAD_EDGE_IS_NEG && sclk === 1'b0) || (!LEAD_EDGE_IS_NEG && sclk === 1'b1)) begin
            int bi;
            bi = (MSB_FIRST != 0) ? (DATA_WIDTH-1-lead_cnt) : lead_cnt;
            check(mosi === exp_m_tx[bi], $sformatf("MOSI bit %0d mismatch", lead_cnt));
            check(miso === exp_s_tx[bi], $sformatf("MISO bit %0d mismatch", lead_cnt));
            lead_cnt++;
        end
    end

    // ---------------- stimulus ----------------
    task automatic do_reset();
        rst_n = 1'b0; start = 1'b0; m_tx = '0; s_tx = '0; clk_div = 8'd8;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
    endtask

    task automatic xfer(input [DATA_WIDTH-1:0] mt, input [DATA_WIDTH-1:0] st,
                        input [CLK_DIV_WIDTH-1:0] div);
        int timeout;
        m_tx = mt; s_tx = st; clk_div = div;
        exp_m_tx = mt; exp_s_tx = st; lead_cnt = 0; s_seen = 1'b0;
        @(posedge clk); start <= 1'b1;
        @(posedge clk); start <= 1'b0;
        timeout = 0;
        while (!(done) && timeout < 100000) begin @(posedge clk); timeout++; end
        check(timeout < 100000, "timeout waiting for master done");
        timeout = 0;
        while (!s_seen && timeout < 1000) begin @(posedge clk); timeout++; end
        check(s_seen, "slave rx_valid never asserted");
        repeat (3) @(posedge clk);
        check(lead_cnt == DATA_WIDTH, $sformatf("expected %0d leading edges, got %0d", DATA_WIDTH, lead_cnt));
        check(m_rx_cap === st, $sformatf("master rx %h != slave tx %h", m_rx_cap, st));
        check(s_rx_cap === mt, $sformatf("slave rx %h != master tx %h", s_rx_cap, mt));
        check(cs_n === 1'b1 && !busy, "master not idle after transfer");
    endtask

    logic [DATA_WIDTH-1:0] patt [6];
    initial begin patt[0]=8'h00; patt[1]=8'hFF; patt[2]=8'hA5; patt[3]=8'h5A; patt[4]=8'h01; patt[5]=8'h80; end

    initial begin
        do_reset();
        check(sclk === CPOL[0] && cs_n === 1'b1, "bad reset state");

        // directed patterns at several clock ratios
        foreach (patt[i]) xfer(patt[i], ~patt[i], 8'd8);
        xfer(8'hC3, 8'h3C, 8'd6);
        xfer(8'h96, 8'h69, 8'd16);
        xfer(8'hDE, 8'hAD, 8'd255);

        // random, back-to-back
        for (int i = 0; i < 100; i++)
            xfer($urandom_range(0, (1<<DATA_WIDTH)-1), $urandom_range(0, (1<<DATA_WIDTH)-1),
                 $urandom_range(6, 20));

        // mid-reset recovery
        do_reset();
        xfer(8'hF0, 8'h0F, 8'd8);

        $display("checks=%0d errors=%0d", checks, errors);
        if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
        $finish;
    end

    initial begin
        #200_000_000;
        $display("TEST FAILED (global watchdog)");
        $finish;
    end
endmodule
