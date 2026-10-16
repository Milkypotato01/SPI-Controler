// SPI slave (oversampled, single clk domain). clk must be >= ~4x SCLK.
// tx_data is latched when CS asserts; rx_data valid when rx_valid pulses (CS release).
module spi_slave #(
    parameter DATA_WIDTH  = 8,
    parameter CPOL        = 1,
    parameter MSB_FIRST   = 1,
    parameter SYNC_STAGES = 2
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  sclk,
    input  logic                  mosi,
    input  logic                  cs_n,
    output logic                  miso,
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  rx_valid
);
    localparam logic CPOL_B = (CPOL != 0);

    logic sclk_s, cs_n_s, mosi_s, sclk_prev, mosi_q;
    logic falling, rising, lead_edge, trail_edge;
    logic load, sample_en, shift_en;

    sync_ff #(.WIDTH(1), .STAGES(SYNC_STAGES), .RESET_VAL(CPOL_B)) u_sclk_sync (
        .clk(clk), .rst_n(rst_n), .d(sclk), .q(sclk_s));
    sync_ff #(.WIDTH(1), .STAGES(SYNC_STAGES), .RESET_VAL(1'b1)) u_cs_sync (
        .clk(clk), .rst_n(rst_n), .d(cs_n), .q(cs_n_s));
    sync_ff #(.WIDTH(1), .STAGES(SYNC_STAGES), .RESET_VAL(1'b0)) u_mosi_sync (
        .clk(clk), .rst_n(rst_n), .d(mosi), .q(mosi_s));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) sclk_prev <= CPOL_B;
        else        sclk_prev <= sclk_s;
    end

    assign falling    = sclk_prev & ~sclk_s;
    assign rising     = ~sclk_prev & sclk_s;
    assign lead_edge  = CPOL_B ? falling : rising;
    assign trail_edge = CPOL_B ? rising  : falling;

    spi_slave_fsm #(.DATA_WIDTH(DATA_WIDTH)) u_fsm (
        .clk(clk), .rst_n(rst_n), .cs_n_s(cs_n_s),
        .lead_edge(lead_edge), .trail_edge(trail_edge),
        .load(load), .sample_en(sample_en), .shift_en(shift_en), .rx_valid(rx_valid));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)         mosi_q <= 1'b0;
        else if (sample_en) mosi_q <= mosi_s;
    end

    shift_register #(.DATA_WIDTH(DATA_WIDTH), .MSB_FIRST(MSB_FIRST)) u_sr (
        .clk(clk), .rst_n(rst_n), .load(load), .load_data(tx_data),
        .shift_en(shift_en), .serial_in(mosi_q),
        .serial_out(miso), .data_out(rx_data));
endmodule
