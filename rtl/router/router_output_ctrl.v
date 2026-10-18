/*===================================
    Router Output Control Module
=====================================
Signal meaning:
cw – clockwise direction
ccw – counter-clockwise direction
i/o – input/output
pe – processing element
s/r/d – send, ready, data
polarity – even/odd clk cycle
=====================================*/


module router_output_ctrl (
    input wire clk,
    input wire reset,
    input wire polarity,

    // Internal crossbar data from candidate input controllers
    input wire [63:0] data_in_pe,
    input wire [63:0] data_in_up,
    input wire [63:0] data_in_down,
    input wire [63:0] data_in_right,
    input wire [63:0] data_in_left,

    // Requests from candidate input controllers
    input wire req_in_up,
    input wire req_in_down,
    input wire req_in_right,
    input wire req_in_left,
    input wire req_in_pe,

    // Grants back to candidate input controllers
    output reg grant_out_up,
    output reg grant_out_down,
    output reg grant_out_right,
    output reg grant_out_left,
    output reg grant_out_pe,

    // External link interface
    output wire [63:0] data_out,
    output wire send_out,
    input wire ready_in  // Downstream ready (ro)
);

// Priority State Encoding
localparam [2:0] PRIO_PE = 3'd0;
localparam [2:0] PRIO_UP = 3'd1;
localparam [2:0] PRIO_DOWN = 3'd2;
localparam [2:0] PRIO_RIGHT = 3'd3;
localparam [2:0] PRIO_LEFT = 3'd4;

// Rotating Arbiter & Grant Generation
reg [63:0] buf_even, buf_odd;
reg buf_even_full, buf_odd_full;
reg [2:0] priority_even, priority_odd;

wire target_buf_empty = (polarity == 1'b0) ? !buf_even_full : !buf_odd_full;          // Check whether the destination buffer for this cycle can accept a packet
wire [2:0] current_priority = (polarity == 1'b0) ? priority_even : priority_odd;      // Select current VC priority (0 = A has priority, 1 = B has priority)

always @(*) begin
    grant_out_pe    = 1'b0;
    grant_out_up = 1'b0;
    grant_out_down = 1'b0;
    grant_out_right  = 1'b0;
    grant_out_left  = 1'b0;

    // Only grant when destination buffer has space
    if (target_buf_empty) begin
        case (current_priority)
            PRIO_PE: begin
                if (req_in_pe) grant_out_pe = 1'b1;
                else if (req_in_up) grant_out_up = 1'b1;
                else if (req_in_down) grant_out_down = 1'b1;
                else if (req_in_right) grant_out_right = 1'b1;
                else if (req_in_left) grant_out_left = 1'b1;
            end

            PRIO_UP: begin
                if (req_in_up) grant_out_up = 1'b1;
                else if (req_in_down) grant_out_down = 1'b1;
                else if (req_in_right) grant_out_right = 1'b1;
                else if (req_in_left) grant_out_left = 1'b1;
                else if (req_in_pe) grant_out_pe = 1'b1;
            end

            PRIO_DOWN: begin
                if (req_in_down) grant_out_down = 1'b1;
                else if (req_in_right) grant_out_right = 1'b1;
                else if (req_in_left) grant_out_left = 1'b1;
                else if (req_in_pe) grant_out_pe = 1'b1;
                else if (req_in_up) grant_out_up = 1'b1;
            end

            PRIO_RIGHT: begin
                if (req_in_right) grant_out_right = 1'b1;
                else if (req_in_left) grant_out_left = 1'b1;
                else if (req_in_pe) grant_out_pe = 1'b1;
                else if (req_in_up) grant_out_up = 1'b1;
                else if (req_in_down) grant_out_down = 1'b1;
            end

            PRIO_LEFT: begin
                if (req_in_left) grant_out_left = 1'b1;
                else if (req_in_pe) grant_out_pe = 1'b1;
                else if (req_in_up) grant_out_up = 1'b1;
                else if (req_in_down) grant_out_down = 1'b1;
                else if (req_in_right) grant_out_right = 1'b1;
            end

            default: begin
                if (req_in_pe) grant_out_pe = 1'b1;
                else if (req_in_up) grant_out_up = 1'b1;
                else if (req_in_down) grant_out_down = 1'b1;
                else if (req_in_right) grant_out_right = 1'b1;
                else if (req_in_left) grant_out_left = 1'b1;
            end
        endcase
    end
end

// Rotating Priority State Tracking
wire [2:0] total_requests = {2'b00, req_in_pe} + {2'b00, req_in_up} + {2'b00, req_in_down} + {2'b00, req_in_right} + {2'b00, req_in_left};
wire contention = (total_requests > 3'd1);

reg [2:0] next_prio_on_conflict;
always @(*) begin
    if (grant_out_pe) next_prio_on_conflict = PRIO_UP;
    else if (grant_out_up) next_prio_on_conflict = PRIO_DOWN;
    else if (grant_out_down) next_prio_on_conflict = PRIO_RIGHT;
    else if (grant_out_right) next_prio_on_conflict = PRIO_LEFT;
    else next_prio_on_conflict = PRIO_PE;
end

wire grant_active = grant_out_pe | grant_out_up | grant_out_down | grant_out_right | grant_out_left;

always @(posedge clk) begin
    if (reset) begin
        priority_even <= PRIO_PE;
        priority_odd  <= PRIO_PE;
    end 
    else begin
        // Rotate priority strictly when contention occurs and a grant is issued
        if (polarity == 1'b0) begin
            if (contention && target_buf_empty && grant_active) begin
                priority_even <= next_prio_on_conflict;
            end
        end 
        else begin
            if (contention && target_buf_empty && grant_active) begin
                priority_odd <= next_prio_on_conflict;
            end
        end
    end
end

// Packet Multiplexer: payload and header pass through unmodified
wire [63:0] packet_to_write = grant_out_pe ? data_in_pe : 
                              grant_out_up ? data_in_up :
                              grant_out_down ? data_in_down :
                              grant_out_right ? data_in_right :
                              grant_out_left ? data_in_left : 64'h0;

// Buffer Write Logic
// Even Output Buffer (VC0)
always @(posedge clk) begin
    if (reset) begin
        buf_even <= 64'h0;
        buf_even_full <= 1'b0;
    end 
    else begin
        // Internal write on Even cycle (polarity == 0)
        if (polarity == 1'b0 && grant_active) begin
            buf_even <= packet_to_write;
            buf_even_full <= 1'b1;
        end
        // External clear on Odd cycle (polarity == 1)
        else if (polarity == 1'b1 && ready_in && buf_even_full) begin
            buf_even_full <= 1'b0;
        end
    end
end

// Odd Output Buffer (VC1)
always @(posedge clk) begin
    if (reset) begin
        buf_odd <= 64'h0;
        buf_odd_full <= 1'b0;
    end 
    else begin
        // Internal write on Odd cycle (polarity == 1)
        if (polarity == 1'b1 && grant_active) begin
            buf_odd <= packet_to_write;
            buf_odd_full <= 1'b1;
        end
        // External clear on Even cycle (polarity == 0)
        else if (polarity == 1'b0 && ready_in && buf_odd_full) begin
            buf_odd_full <= 1'b0;
        end
    end
end

// Output MUX & Mealy Send Handshake
// Polarity 0: transmits Odd buffer (VC1)
// Polarity 1: transmits Even buffer (VC0)
assign data_out = (polarity == 1'b0) ? buf_odd : buf_even;

wire active_out_full = (polarity == 1'b0) ? buf_odd_full : buf_even_full;
assign send_out = !reset && active_out_full && ready_in;

endmodule
