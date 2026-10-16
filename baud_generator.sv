// Half-period tick generator. tick pulses (1 clk) every `div` clk cycles while en=1.
// div = 0 is treated as 1. SCLK frequency = f_clk / (2 * div).
module baud_generator #(
    parameter CLK_DIV_WIDTH = 8
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     en,
    input  logic [CLK_DIV_WIDTH-1:0] div,
    output logic                     tick
);
    logic [CLK_DIV_WIDTH-1:0] cnt;
    logic [CLK_DIV_WIDTH-1:0] div_eff;

    always_comb div_eff = (div == '0) ? {{(CLK_DIV_WIDTH-1){1'b0}}, 1'b1} : div;

    assign tick = en && (cnt >= (div_eff - 1'b1));  // >= tolerates div changes mid-count

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)           cnt <= '0;
        else if (!en || tick) cnt <= '0;
        else                  cnt <= cnt + 1'b1;
    end
endmodule
