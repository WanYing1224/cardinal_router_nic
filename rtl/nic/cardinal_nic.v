/*============================================================================================
	Cardinal Network Interface Controller (NIC) Module
	- Strictly compliant with Rules_for_student.txt and Cardinal NIC Spec
    - Two 64-bit channel buffers (Input / Output) with 1-bit status tracking
    - Memory-mapped interface to processor (addr, d_in, d_out, nicEn, nicEnWr)
    - Virtual channel phase-matched handshaking with router PE port
==============================================================================================
Signal meaning:
u/d/r/l/pe – Up, Down, Right, Left
cw – clockwise direction
ccw – counter-clockwise direction
i/o – input/output
pe – processing element
s/r/d – send, ready, data
polarity – even/odd clk cycle

==============================================================================================*/

module cardinal_nic (clk, reset, addr, d_in, d_out, nicEn, nicEnWr, net_si, net_ri, net_di, net_so, net_ro, net_do, net_polarity);

input wire clk, reset;

// Processor Memory Interface
input wire [1:0] addr;
input wire [63:0] d_in;
output reg [63:0] d_out;
input wire nicEn, nicEnWr;

// Network Router Interface (Input Channel -> NIC)
input wire net_si;
output wire net_ri;
input wire [63:0] net_di;

// Network Router Interface (Output Channel <- NIC)
output wire net_so;
input wire net_ro;
output wire [63:0] net_do;
input wire net_polarity;

// ====================================================
// Internal Storage Registers and Status Flags
// ====================================================
reg [63:0] in_buf, out_buf;
reg in_buf_full, out_buf_full;

// ====================================================
// Network Interface Handshake Logic
// ====================================================
// Ready-in asserts when the internal input buffer has space
assign net_ri = ~in_buf_full;

// Output data bus is driven continuously from out_buf
assign net_do = out_buf; 

// Virtual Channel phase check:
// VC0 (bit 63 == 0) transfers when net_polarity == 1
// VC1 (bit 63 == 1) transfers when net_polarity == 0
wire vc_phase_match = (out_buf[63] == ~net_polarity);

// Mealy send-out signal: 
// asserts combinationally when buffer is occupied, downstream router is ready, and VC polarity phase matches
assign net_so = out_buf_full & net_ro & vc_phase_match;

// ====================================================
// Processor Read Logic (Synchronous d_out)
// ====================================================
always @(posedge clk) begin
	if (reset) begin
		d_out <= 64'h0;
	end
	else if (nicEn && !nicEnWr) begin
		case (addr)
			2'b00: d_out <= in_buf;
			2'b01: d_out <= {63'h0, in_buf_full};
			2'b10: d_out <= 64'h0;
			2'b11: d_out <= {63'h0, out_buf_full};
			default: d_out <= 64'h0;
		endcase
	end
	else begin
		d_out <= 64'h0;
	end
end

// ====================================================
// Sequential Control Logic: Input Buffer & Output Buffer State
// ====================================================
always @(posedge clk) begin
	if (reset) begin
		in_buf <= 64'h0;
		in_buf_full <= 1'b0;
		out_buf <= 64'h0;
		out_buf_full <= 1'b0;
	end
	else begin
		if (net_si && !in_buf_full) begin
			in_buf <= net_di;
			in_buf_full <= 1'b1;
		end
		else if (nicEn && !nicEnWr && (addr == 2'b00)) begin
			in_buf_full <= 1'b0;
		end

		// Output Buffer Management (Processor Store & Network Transmission)
		if (nicEn && nicEnWr && (addr == 2'b10)) begin
			if (!out_buf_full) begin
				out_buf <= d_in;
				out_buf_full <= 1'b1;
			end
		end
		else if (net_so) begin
			out_buf_full <= 1'b0;
		end
	end
end

endmodule
