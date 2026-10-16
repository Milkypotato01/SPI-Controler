// Master control FSM (3-always-block). Pure control: no bus data handled here.
// CPHA=0: first bit valid before leading edge; sample on leading, shift on trailing.
module spi_master_fsm #(
    parameter DATA_WIDTH = 8,
    parameter CPOL       = 1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic tick,       // half-period tick
    output logic load,
    output logic sample_en,  // leading edge
    output logic shift_en,   // trailing edge
    output logic done,
    output logic busy,
    output logic baud_en,
    output logic sclk,
    output logic cs_n
);
    localparam logic CPOL_B = (CPOL != 0);
    localparam CNT_W = $clog2(DATA_WIDTH) + 1;
    localparam [CNT_W-1:0] LAST_CNT = DATA_WIDTH - 1;

    typedef enum logic [1:0] {S_IDLE, S_LEAD_WAIT, S_ACTIVE, S_HOLD} state_t;
    state_t state, next_state;
    logic [CNT_W-1:0] bit_cnt;
    logic             last;

    assign last = (bit_cnt == LAST_CNT);

    // 1) state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // 2) next-state logic
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:      if (start) next_state = S_LEAD_WAIT;
            S_LEAD_WAIT: if (tick)  next_state = S_ACTIVE;
            S_ACTIVE:    if (tick) begin
                             if (last) next_state = S_HOLD;
                             else      next_state = S_LEAD_WAIT;
                         end
            S_HOLD:      if (tick)  next_state = S_IDLE;
            default:                next_state = S_IDLE;
        endcase
    end

    // 3) output decode
    always_comb begin
        load      = (state == S_IDLE)      && start;
        sample_en = (state == S_LEAD_WAIT) && tick;
        shift_en  = (state == S_ACTIVE)    && tick;
        done      = (state == S_HOLD)      && tick;
        busy      = (state != S_IDLE);
        baud_en   = busy;
    end

    // glitch-free registered pad outputs, time-aligned with `state`
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk <= CPOL_B;
            cs_n <= 1'b1;
        end else begin
            sclk <= (next_state == S_ACTIVE) ? ~CPOL_B : CPOL_B;
            cs_n <= (next_state == S_IDLE);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        bit_cnt <= '0;
        else if (load)     bit_cnt <= '0;
        else if (shift_en) bit_cnt <= bit_cnt + 1'b1;
    end
endmodule
