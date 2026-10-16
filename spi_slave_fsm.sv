// Slave control FSM (3-always-block), driven by synchronized edge strobes.
module spi_slave_fsm #(
    parameter DATA_WIDTH = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic cs_n_s,
    input  logic lead_edge,
    input  logic trail_edge,
    output logic load,
    output logic sample_en,
    output logic shift_en,
    output logic rx_valid
);
    localparam CNT_W = $clog2(DATA_WIDTH) + 1;
    localparam [CNT_W-1:0] LAST_CNT = DATA_WIDTH - 1;

    typedef enum logic [1:0] {S_IDLE, S_WAIT_LEAD, S_WAIT_TRAIL, S_DONE} state_t;
    state_t state, next_state;
    logic [CNT_W-1:0] bit_cnt;
    logic             last;

    assign last = (bit_cnt == LAST_CNT);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:       if (!cs_n_s)       next_state = S_WAIT_LEAD;
            S_WAIT_LEAD:  if (cs_n_s)        next_state = S_IDLE;
                          else if (lead_edge)  next_state = S_WAIT_TRAIL;
            S_WAIT_TRAIL: if (cs_n_s)        next_state = S_IDLE;
                          else if (trail_edge) begin
                              if (last) next_state = S_DONE;
                              else      next_state = S_WAIT_LEAD;
                          end
            S_DONE:       if (cs_n_s)        next_state = S_IDLE;
            default:                         next_state = S_IDLE;
        endcase
    end

    always_comb begin
        load      = (state == S_IDLE)       && !cs_n_s;
        sample_en = (state == S_WAIT_LEAD)  && !cs_n_s && lead_edge;
        shift_en  = (state == S_WAIT_TRAIL) && !cs_n_s && trail_edge;
        rx_valid  = (state == S_DONE)       && cs_n_s;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        bit_cnt <= '0;
        else if (load)     bit_cnt <= '0;
        else if (shift_en) bit_cnt <= bit_cnt + 1'b1;
    end
endmodule
