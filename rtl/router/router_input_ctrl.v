/*================================================================================
    Router_Input_Control Module
    Description: 2D Mesh Input Controller with Dual Virtual Channel Buffers,
                 Polarity-Based Time Multiplexing, and X-Y Coordinate Routing.
==================================================================================
Signal meaning:
cw – clockwise direction
ccw – counter-clockwise direction
i/o – input/output
pe – processing element
s/r/d – send, ready, data
polarity – even/odd clk cycle
=====================================*/

module router_input_ctrl #(
    parameter [1:0] PORT_TYPE = 2'd0,
    parameter [1:0] MY_X      = 2'd0,
    parameter [1:0] MY_Y      = 2'd0
)(
    input wire clk,
    input wire reset,
    input wire polarity,

    // External channel interface
    input wire [63:0] data_in,  // di
    input wire send_in,         // si
    output wire ready_in,       // ri

    // Internal channel interface
    input wire grant_in,
    output wire [63:0] selected_data_out,
    output reg request_north,   // req_north
    output reg request_south,   // req_south
    output reg request_east,    // req_east
    output reg request_west,    // req_west
    output reg request_pe       // req_pe
);

reg [63:0] buf_even;
reg buf_even_full;

reg [63:0] buf_odd;
reg buf_odd_full;

// Flow Control Signals (Moore State Machine)
// Polarity 0 (Even cycle): External transfers target Odd buffer (VC1)
// Polarity 1 (Odd cycle) : External transfers target Even buffer (VC0)
assign ready_in = reset ? 1'b1 : ((polarity == 1'b0) ? ~buf_odd_full : ~buf_even_full);

// Even Buffer (VC0)
always @(posedge clk) begin
    if (reset) begin
        buf_even <= 64'h0;
        buf_even_full <= 1'b0;
    end
    else begin
        // External write
        if (polarity == 1'b1 && send_in && !buf_even_full) begin
            buf_even <= data_in;
            buf_even_full <= 1'b1;
        end
        // Internal forwarding
        else if (polarity == 1'b0 && grant_in && buf_even_full) begin
            buf_even_full <= 1'b0;
        end
    end
end

// Odd Buffer (VC1)
always @(posedge clk) begin
    if (reset) begin
        buf_odd <= 64'h0;
        buf_odd_full <= 1'b0;
    end
    else begin
        // External write
        if (polarity == 1'b0 && send_in && !buf_odd_full) begin
            buf_odd <= data_in;
            buf_odd_full <= 1'b1;
        end
        // Internal forwarding
        else if (polarity == 1'b1 && grant_in && buf_odd_full) begin
            buf_odd_full <= 1'b0;
        end
    end
end

// Internal VC MUX
assign selected_data_out = (polarity == 1'b0) ? buf_even : buf_odd;
wire active_buf_full = (polarity == 1'b0) ? buf_even_full : buf_odd_full;

// Route / Address Decoder (Dimension-Order X-Y Routing)
wire [1:0] dest_x = selected_data_out[61:60];
wire [1:0] dest_y = selected_data_out[59:58];

always @(*) begin
    request_north = 1'b0;
    request_south = 1'b0;
    request_east = 1'b0;
    request_west = 1'b0;
    request_pe = 1'b0;

    if (active_buf_full) begin
        // Route in X dimension first
        if (dest_x > MY_X) begin
            request_east = 1'b1;
        end
        else if (dest_x < MY_X) begin
            request_west = 1'b1;
        end
        // When X matches, route in Y dimension
        else if (dest_y > MY_Y) begin
            request_south = 1'b1;
        end
        else if (dest_y < MY_Y) begin
            request_north = 1'b1;
        end
        // Destination node reached
        else begin
            request_pe = 1'b1;
        end
    end
end

endmodule
