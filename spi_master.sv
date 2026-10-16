// SPI master top. CPOL param (default 1 = idle-high), CPHA = 0 (sample on leading edge).
// SCLK half period = clk_div clk cycles. With SYNC_STAGES=2 use clk_div >= 6
// so the slave's first MISO bit round-trips before the first leading edge.
module spi_master #(
    parameter DATA_WIDTH    = 8,
    parameter CLK_DIV_WIDTH = 8,
    parameter CPOL          = 1,
    parameter MSB_FIRST     = 1,
    parameter SYNC_STAGES   = 2
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [DATA_WIDTH-1:0]    tx_data,
    input  logic [CLK_DIV_WIDTH-1:0] clk_div,
    output logic                     busy,
    output logic                     done,     // 1-clk pulse, rx_data valid
    output logic [DATA_WIDTH-1:0]    rx_data,
    output logic                     sclk,
    output logic                     mosi,
    input  logic                     miso,
    output logic                     cs_n
);
    logic tick, baud_en, load, sample_en, shift_en;
    logic miso_s, miso_q;

    baud_generator #(.CLK_DIV_WIDTH(CLK_DIV_WIDTH)) u_baud (
        .clk(clk), .rst_n(rst_n), .en(baud_en), .div(clk_div), .tick(tick));

    spi_master_fsm #(.DATA_WIDTH(DATA_WIDTH), .CPOL(CPOL)) u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .tick(tick),
        .load(load), .sample_en(sample_en), .shift_en(shift_en),
        .done(done), .busy(busy), .baud_en(baud_en), .sclk(sclk), .cs_n(cs_n));

    sync_ff #(.WIDTH(1), .STAGES(SYNC_STAGES), .RESET_VAL(1'b0)) u_miso_sync (
        .clk(clk), .rst_n(rst_n), .d(miso), .q(miso_s));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)         miso_q <= 1'b0;
        else if (sample_en) miso_q <= miso_s;
    end

    shift_register #(.DATA_WIDTH(DATA_WIDTH), .MSB_FIRST(MSB_FIRST)) u_sr (
        .clk(clk), .rst_n(rst_n), .load(load), .load_data(tx_data),
        .shift_en(shift_en), .serial_in(miso_q),
        .serial_out(mosi), .data_out(rx_data));
endmodule
