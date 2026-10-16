// N-stage synchronizer (STAGES >= 2). Newest sample in LSBs, output = oldest stage.
module sync_ff #(
    parameter WIDTH            = 1,
    parameter STAGES           = 2,
    parameter [WIDTH-1:0] RESET_VAL = '0
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    localparam TOTAL = STAGES * WIDTH;
    logic [TOTAL-1:0] pipe;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pipe <= {STAGES{RESET_VAL}};
        else        pipe <= (pipe << WIDTH) | {{(TOTAL-WIDTH){1'b0}}, d};
    end

    assign q = pipe[TOTAL-1 -: WIDTH];
endmodule
