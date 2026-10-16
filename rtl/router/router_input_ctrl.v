/*===================================
    Router Input Control Module
=====================================
Signal meaning:
cw – clockwise direction
ccw – counter-clockwise direction
i/o – input/output
pe – processing element
s/r/d – send, ready, data
polarity – even/odd clk cycle
=====================================*/

module router_input_ctrl #(
    parameter [1:0] PORT_TYPE = 2'd0
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
    output  reg request_cw,     // req_cw
    output reg request_ccw,     // req_ccw
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

// Route / Address Decoder
always @(*) begin
    request_cw  = 1'b0;
    request_ccw = 1'b0;
    request_pe  = 1'b0;

    if(active_buf_full) begin
        case (PORT_TYPE)
            2'd0: begin
                if (selected_data_out[62] == 1'b0) begin
                    request_cw = 1'b1;
                end
                else begin
                    request_ccw = 1'b1;
                end
            end
            2'd1: begin
                if (selected_data_out[55:48] == 8'h00) begin
                    request_pe = 1'b1;
                end
                else begin
                    request_cw = 1'b1;
                end
            end
            2'd2: begin
                if (selected_data_out[55:48] == 8'h00) begin
                    request_pe = 1'b1;
                end
                else begin
                    request_ccw = 1'b1;
                end
            end
            default: begin
                request_cw  = 1'b0;
                request_ccw = 1'b0;
                request_pe  = 1'b0;
            end
        endcase
    end
end

endmodule
