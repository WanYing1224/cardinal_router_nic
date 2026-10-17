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


module router_output_ctrl #(
    parameter [1:0] PORT_TYPE = 2'd0
)(
    input wire clk,
    input wire reset,
    input wire polarity,

    // Internal crossbar data from candidate input controllers
    input wire [63:0] data_in_a,
    input wire [63:0] data_in_b,

    // Requests from candidate input controllers
    input wire req_in_a,
    input wire req_in_b,

    // Grants back to candidate input controllers
    output reg grant_out_a,
    output reg grant_out_b,

    // External link interface
    output wire [63:0] data_out,
    output wire send_out,
    input wire ready_in  // Downstream ready (ro)
);

// Rotating Arbiter & Grant Generation
reg [63:0] buf_even, buf_odd;
reg buf_even_full, buf_odd_full;
reg priority_even, priority_odd;

wire target_buf_empty = (polarity == 1'b0) ? !buf_even_full : !buf_odd_full;    // Check whether the destination buffer for this cycle can accept a packet
wire current_priority = (polarity == 1'b0) ? priority_even : priority_odd;      // Select current VC priority (0 = A has priority, 1 = B has priority)

always @(*) begin
    grant_out_a = 1'b0;
    grant_out_b = 1'b0;

    // Only grant when destination buffer has space
    if (target_buf_empty) begin
        if (req_in_a && !req_in_b) begin
            grant_out_a = 1'b1;
        end
        else if (!req_in_a && req_in_b) begin
            grant_out_b = 1'b1;
        end
        else if (req_in_a && req_in_b) begin
            if (current_priority == 1'b0) begin
                grant_out_a = 1'b1;
            end
            else begin
                grant_out_b = 1'b1;
            end
        end
    end
end

// Rotating Priority State Tracking
always @(posedge clk) begin
    // Initial Priority at Reset: Input A has priority over Input B
    if (reset) begin
        priority_even <= 1'b0;
        priority_odd <= 1'b0;
    end
    else begin
        // Priority only toggles when both inputs request at the same time and the destination buffer has space to accept a packet
        if (polarity == 1'b0) begin
            if (req_in_a && req_in_b && target_buf_empty) begin
                priority_even <= ~priority_even;
            end
        end
        else begin
            if (req_in_a && req_in_b && target_buf_empty) begin
                priority_odd <= ~priority_odd;
            end
        end
    end
end

// Packet Multiplexer: payload and header pass through unmodified
wire [63:0] selected_packet = grant_out_a ? data_in_a : (grant_out_b ? data_in_b : 64'h0);
wire [63:0] packet_to_write = selected_packet;

// Buffer Write Logic
// Even Output Buffer (VC0)
always @(posedge clk) begin
    if (reset) begin
        buf_even <= 64'h0;
        buf_even_full <= 1'b0;
    end
    else begin
        // Write on Even Cycle (polarity == 0)
        if (polarity == 1'b0 && (grant_out_a || grant_out_b)) begin
            buf_even <= packet_to_write;
            buf_even_full <= 1'b1;
        end
        // Clear Even Buffer on Odd Cycle (polarity == 1)
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
        // Write on Odd Cycle (polarity == 1)
        if (polarity == 1'b1 && (grant_out_a || grant_out_b)) begin
            buf_odd <= packet_to_write;
            buf_odd_full <= 1'b1;
        end
        // Clear Odd Buffer on Even Cycle (polarity == 0)
        else if (polarity == 1'b0 && ready_in && buf_odd_full) begin
            buf_odd_full <= 1'b0;
        end
    end
end

// Output MUX & Mealy Send Handshake
assign data_out = (polarity == 1'b0) ? buf_odd : buf_even;

wire active_out_full = (polarity == 1'b0) ? buf_odd_full : buf_even_full;
assign send_out = !reset && active_out_full && ready_in;

endmodule
