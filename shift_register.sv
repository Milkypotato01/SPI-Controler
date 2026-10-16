// Generic load/shift register (DATA_WIDTH >= 2). load has priority over shift.
module shift_register #(
    parameter DATA_WIDTH = 8,
    parameter MSB_FIRST  = 1
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  load,
    input  logic [DATA_WIDTH-1:0] load_data,
    input  logic                  shift_en,
    input  logic                  serial_in,
    output logic                  serial_out,
    output logic [DATA_WIDTH-1:0] data_out
);
    logic [DATA_WIDTH-1:0] sr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        sr <= '0;
        else if (load)     sr <= load_data;
        else if (shift_en) begin
            if (MSB_FIRST != 0) sr <= {sr[DATA_WIDTH-2:0], serial_in};
            else                sr <= {serial_in, sr[DATA_WIDTH-1:1]};
        end
    end

    assign serial_out = (MSB_FIRST != 0) ? sr[DATA_WIDTH-1] : sr[0];
    assign data_out   = sr;
endmodule
