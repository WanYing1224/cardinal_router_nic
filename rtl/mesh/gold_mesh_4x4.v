/*============================================================================================
	4x4 Gold Mesh Module
==============================================================================================
Signal meaning:
u/d/r/l/pe – Up, Down, Right, Left
cw – clockwise direction
ccw – counter-clockwise direction
i/o – input/output
pe – processing element
s/r/d – send, ready, data
polarity – even/odd clk cycle
==============================================================================================
Mesh Topology (4x4):
Row 0:  Node  0 (0,0) <=======> Node  1 (1,0) <=======> Node  2 (2,0) <=======> Node  3 (3,0)
			||                      ||                      ||                      ||
Row 1:  Node  4 (0,1) <=======> Node  5 (1,1) <=======> Node  6 (2,1) <=======> Node  7 (3,1)
			||                      ||                      ||                      ||
Row 2:  Node  8 (0,2) <=======> Node  9 (1,2) <=======> Node 10 (2,2) <=======> Node 11 (3,2)
			||                      ||                      ||                      ||
Row 3:  Node 12 (0,3) <=======> Node 13 (1,3) <=======> Node 14 (2,3) <=======> Node 15 (3,3)
==============================================================================================*/

module gold_mesh_4x4 (
	input clk,
	input reset,

	// Node 0 (0,0) Interface
	input node0_pesi, node0_pero,
	output node0_peso, node0_peri,
	input  [63:0] node0_pedi,
	output [63:0] node0_pedo,
	output node0_polarity,

	// Node 1 (1,0) Interface
	input node1_pesi, node1_pero,
	output node1_peso, node1_peri,
	input  [63:0] node1_pedi,
	output [63:0] node1_pedo,
	output node1_polarity,

	// Node 2 (2,0) Interface
	input node2_pesi, node2_pero,
	output node2_peso, node2_peri,
	input  [63:0] node2_pedi,
	output [63:0] node2_pedo,
	output node2_polarity,

	// Node 3 (3,0) Interface
	input node3_pesi, node3_pero,
	output node3_peso, node3_peri,
	input  [63:0] node3_pedi,
	output [63:0] node3_pedo,
	output node3_polarity,

	// Node 4 (0,1) Interface
	input node4_pesi, node4_pero,
	output node4_peso, node4_peri,
	input  [63:0] node4_pedi,
	output [63:0] node4_pedo,
	output node4_polarity,

	// Node 5 (1,1) Interface
	input node5_pesi, node5_pero,
	output node5_peso, node5_peri,
	input  [63:0] node5_pedi,
	output [63:0] node5_pedo,
	output node5_polarity,

	// Node 6 (2,1) Interface
	input node6_pesi, node6_pero,
	output node6_peso, node6_peri,
	input  [63:0] node6_pedi,
	output [63:0] node6_pedo,
	output node6_polarity,

	// Node 7 (3,1) Interface
	input node7_pesi, node7_pero,
	output node7_peso, node7_peri,
	input  [63:0] node7_pedi,
	output [63:0] node7_pedo,
	output node7_polarity,

	// Node 8 (0,2) Interface
	input node8_pesi, node8_pero,
	output node8_peso, node8_peri,
	input  [63:0] node8_pedi,
	output [63:0] node8_pedo,
	output node8_polarity,

	// Node 9 (1,2) Interface
	input node9_pesi, node9_pero,
	output node9_peso, node9_peri,
	input  [63:0] node9_pedi,
	output [63:0] node9_pedo,
	output node9_polarity,

	// Node 10 (2,2) Interface
	input node10_pesi, node10_pero,
	output node10_peso, node10_peri,
	input  [63:0] node10_pedi,
	output [63:0] node10_pedo,
	output node10_polarity,

	// Node 11 (3,2) Interface
	input node11_pesi, node11_pero,
	output node11_peso, node11_peri,
	input  [63:0] node11_pedi,
	output [63:0] node11_pedo,
	output node11_polarity,

	// Node 12 (0,3) Interface
	input node12_pesi, node12_pero,
	output node12_peso, node12_peri,
	input  [63:0] node12_pedi,
	output [63:0] node12_pedo,
	output node12_polarity,

	// Node 13 (1,3) Interface
	input node13_pesi, node13_pero,
	output node13_peso, node13_peri,
	input  [63:0] node13_pedi,
	output [63:0] node13_pedo,
	output node13_polarity,
	
	// Node 14 (2,3) Interface
	input node14_pesi, node14_pero,
	output node14_peso, node14_peri,
	input  [63:0] node14_pedi,
	output [63:0] node14_pedo,
	output node14_polarity

	// Node 15 (3,3) Interface
	input node15_pesi, node15_pero,
	output node15_peso, node15_peri,
	input  [63:0] node15_pedi,
	output [63:0] node15_pedo,
	output node15_polarity
);
// ====================================================
// PE Interface Bus Packaging for Clean Array Indexing
// ====================================================
wire pe_si_bus [0:15];
wire pe_ri_bus [0:15];
wire [63:0] pe_di_bus  [0:15];
wire pe_so_bus [0:15];
wire pe_ro_bus [0:15];
wire [63:0] pe_do_bus [0:15];
wire pe_polarity_bus [0:15];

assign pe_si_bus[0] = node0_pesi;
assign node0_peri = pe_ri_bus[0];
assign pe_di_bus[0] = node0_pedi;
assign node0_peso = pe_so_bus[0];
assign pe_ro_bus[0] = node0_pero;
assign node0_pedo = pe_do_bus[0];
assign node0_polarity = pe_polarity_bus[0];

assign pe_si_bus[1] = node1_pesi;
assign node1_peri = pe_ri_bus[1];
assign pe_di_bus[1] = node1_pedi;
assign node1_peso = pe_so_bus[1];
assign pe_ro_bus[1] = node1_pero;
assign node1_pedo = pe_do_bus[1];
assign node1_polarity = pe_polarity_bus[1];

assign pe_si_bus[2] = node2_pesi;
assign node2_peri = pe_ri_bus[2];
assign pe_di_bus[2] = node2_pedi;
assign node2_peso = pe_so_bus[2];
assign pe_ro_bus[2] = node2_pero;
assign node2_pedo = pe_do_bus[2];
assign node2_polarity = pe_polarity_bus[2];

assign pe_si_bus[3] = node3_pesi;
assign node3_peri = pe_ri_bus[3];
assign pe_di_bus[3] = node3_pedi;
assign node3_peso = pe_so_bus[3];
assign pe_ro_bus[3] = node3_pero;
assign node3_pedo = pe_do_bus[3];
assign node3_polarity = pe_polarity_bus[3];

assign pe_si_bus[4] = node4_pesi;
assign node4_peri = pe_ri_bus[4];
assign pe_di_bus[4] = node4_pedi;
assign node4_peso = pe_so_bus[4];
assign pe_ro_bus[4] = node4_pero;
assign node4_pedo = pe_do_bus[4];
assign node4_polarity = pe_polarity_bus[4];

assign pe_si_bus[5] = node5_pesi;
assign node5_peri = pe_ri_bus[5];
assign pe_di_bus[5] = node5_pedi;
assign node5_peso = pe_so_bus[5];
assign pe_ro_bus[5] = node5_pero;
assign node5_pedo = pe_do_bus[5];
assign node5_polarity = pe_polarity_bus[5];

assign pe_si_bus[6] = node6_pesi;
assign node6_peri = pe_ri_bus[6];
assign pe_di_bus[6] = node6_pedi;
assign node6_peso = pe_so_bus[6];
assign pe_ro_bus[6] = node6_pero;
assign node6_pedo = pe_do_bus[6];
assign node6_polarity = pe_polarity_bus[6];

assign pe_si_bus[7] = node7_pesi;
assign node7_peri = pe_ri_bus[7];
assign pe_di_bus[7] = node7_pedi;
assign node7_peso = pe_so_bus[7];
assign pe_ro_bus[7] = node7_pero;
assign node7_pedo = pe_do_bus[7];
assign node7_polarity = pe_polarity_bus[7];

assign pe_si_bus[8] = node8_pesi;
assign node8_peri = pe_ri_bus[8];
assign pe_di_bus[8] = node8_pedi;
assign node8_peso = pe_so_bus[8];
assign pe_ro_bus[8] = node8_pero;
assign node8_pedo = pe_do_bus[8];
assign node8_polarity = pe_polarity_bus[8];

assign pe_si_bus[9] = node9_pesi;
assign node9_peri = pe_ri_bus[9];
assign pe_di_bus[9] = node9_pedi;
assign node9_peso = pe_so_bus[9];
assign pe_ro_bus[9] = node9_pero;
assign node9_pedo = pe_do_bus[9];
assign node9_polarity = pe_polarity_bus[9];

assign pe_si_bus[10] = node10_pesi;
assign node10_peri = pe_ri_bus[10];
assign pe_di_bus[10] = node10_pedi;
assign node10_peso = pe_so_bus[10];
assign pe_ro_bus[10] = node10_pero;
assign node10_pedo = pe_do_bus[10];
assign node10_polarity = pe_polarity_bus[10];

assign pe_si_bus[11] = node11_pesi;
assign node11_peri = pe_ri_bus[11];
assign pe_di_bus[11] = node11_pedi;
assign node11_peso = pe_so_bus[11];
assign pe_ro_bus[11] = node11_pero;
assign node11_pedo = pe_do_bus[11];
assign node11_polarity = pe_polarity_bus[11];

assign pe_si_bus[12] = node12_pesi;
assign node12_peri = pe_ri_bus[12];
assign pe_di_bus[12] = node12_pedi;
assign node12_peso = pe_so_bus[12];
assign pe_ro_bus[12] = node12_pero;
assign node12_pedo = pe_do_bus[12];
assign node12_polarity = pe_polarity_bus[12];

assign pe_si_bus[13] = node13_pesi;
assign node13_peri = pe_ri_bus[13];
assign pe_di_bus[13] = node13_pedi;
assign node13_peso = pe_so_bus[13];
assign pe_ro_bus[13] = node13_pero;
assign node13_pedo = pe_do_bus[13];
assign node13_polarity = pe_polarity_bus[13];

assign pe_si_bus[14] = node14_pesi;
assign node14_peri = pe_ri_bus[14];
assign pe_di_bus[14] = node14_pedi;
assign node14_peso = pe_so_bus[14];
assign pe_ro_bus[14] = node14_pero;
assign node14_pedo = pe_do_bus[14];
assign node14_polarity = pe_polarity_bus[14];

assign pe_si_bus[15] = node15_pesi;
assign node15_peri = pe_ri_bus[15];
assign pe_di_bus[15] = node15_pedi;
assign node15_peso = pe_so_bus[15];
assign pe_ro_bus[15] = node15_pero;
assign node15_pedo = pe_do_bus[15];
assign node15_polarity = pe_polarity_bus[15];

// ====================================================
// Grid Internal Network Wiring
// ====================================================
// Horizontal links: right_do/so/ri of (x,y) <-> left_di/si/ro of (x+1,y)
wire [63:0] h_data_right [0:2][0:3];
wire h_send_right [0:2][0:3];
wire h_ready_right [0:2][0:3];

wire [63:0] h_data_left [0:2][0:3];
wire h_send_left [0:2][0:3];
wire h_ready_left [0:2][0:3];

// Vertical links: down_do/so/ri of (x,y) <-> up_di/si/ro of (x,y+1)
wire [63:0] v_data_down [0:3][0:2];
wire v_send_down [0:3][0:2];
wire v_ready_down [0:3][0:2];

wire [63:0] v_data_up [0:3][0:2];
wire v_send_up [0:3][0:2];
wire v_ready_up [0:3][0:2];

// ====================================================
// 4x4 Grid Instantiation via Generate Loops
// ====================================================
genvar x, y;
generate
	for (y=0; y<4; y=y+1) begin: ROW
		for (x=0; x<4; x=x+1) begin: COL
			localparam [3:0] NODE_ID = y * 4 + x;

			// Dedicated port wires for router instance (x, y)
			wire [63:0] node_up_di, node_up_do;
			wire node_up_si, node_up_so;
			wire node_up_ri, node_up_ro;

			wire [63:0] node_down_di, node_down_do;
			wire node_down_si, node_down_so;
			wire node_down_ri, node_down_ro;

			wire [63:0] node_right_di, node_right_do;
			wire node_right_si, node_right_so;
			wire node_right_ri, node_right_ro;

			wire [63:0] node_left_di, node_left_do;
			wire node_left_si, node_left_so;
			wire node_left_ri, node_left_ro;

			// Up Interconnect & Boundary Tie-Off
			if (y == 0) begin: BORDER_UP
				assign node_up_di = 64'h0;
				assign node_up_si = 1'b0;
				assign node_up_ro = 1'b0;
			end 
			else begin: INTERNAL_UP
				assign node_up_di = v_data_down[x][y-1];
				assign node_up_si = v_send_down[x][y-1];
				assign v_ready_down[x][y-1] = node_up_ri;

				assign v_data_up[x][y-1] = node_up_do;
				assign v_send_up[x][y-1] = node_up_so;
				assign node_up_ro = v_ready_up[x][y-1];
			end

			// Down Interconnect & Boundary Tie-Off
			if (y == 3) begin: BORDER_DOWN
				assign node_down_di = 64'h0;
				assign node_down_si = 1'b0;
				assign node_down_ro = 1'b0;
			end 
			else begin: INTERNAL_DOWN
				assign v_data_down[x][y] = node_down_do;
				assign v_send_down[x][y] = node_down_so;
				assign node_down_ro = v_ready_down[x][y];

				assign node_down_di = v_data_up[x][y];
				assign node_down_si = v_send_up[x][y];
				assign v_ready_up[x][y] = node_down_ri;
			end

			// Right Interconnect & Boundary Tie-Off
			if (x == 3) begin: BORDER_RIGHT
				assign node_right_di = 64'h0;
				assign node_right_si = 1'b0;
				assign node_right_ro = 1'b0;
			end 
			else begin: INTERNAL_RIGHT
				assign h_data_right[x][y] = node_right_do;
				assign h_send_right[x][y] = node_right_so;
				assign node_right_ro = h_ready_right[x][y];

				assign node_right_di = h_data_left[x][y];
				assign node_right_si = h_send_left[x][y];
				assign h_ready_left[x][y] = node_right_ri;
			end

			// Left Interconnect & Boundary Tie-Off
			if (x == 0) begin: BORDER_LEFT
				assign node_left_di = 64'h0;
				assign node_left_si = 1'b0;
				assign node_left_ro = 1'b0;
			end 
			else begin: INTERNAL_LEFT
				assign node_left_di = h_data_right[x-1][y];
				assign node_left_si = h_send_right[x-1][y];
				assign h_ready_right[x-1][y] = node_left_ri;

				assign h_data_left[x-1][y] = node_left_do;
				assign h_send_left[x-1][y] = node_left_so;
				assign node_left_ro = h_ready_left[x-1][y];
			end

			router_node #(
				.MY_X(x[1:0]),
				.MY_Y(y[1:0])
			) u_router_node (
				.clk      (clk),
				.reset    (reset),
				.polarity (pe_polarity_bus[NODE_ID]),

				// Local Core PE Interface
				.pesi     (pe_si_bus[NODE_ID]),
				.peri     (pe_ri_bus[NODE_ID]),
				.pedi     (pe_di_bus[NODE_ID]),
				.peso     (pe_so_bus[NODE_ID]),
				.pero     (pe_ro_bus[NODE_ID]),
				.pedo     (pe_do_bus[NODE_ID]),

				// Up Port
				.up_si    (node_up_si),
				.up_ri    (node_up_ri),
				.up_di    (node_up_di),
				.up_so    (node_up_so),
				.up_ro    (node_up_ro),
				.up_do    (node_up_do),

				// Down Port
				.down_si  (node_down_si),
				.down_ri  (node_down_ri),
				.down_di  (node_down_di),
				.down_so  (node_down_so),
				.down_ro  (node_down_ro),
				.down_do  (node_down_do),

				// Right Port
				.right_si (node_right_si),
				.right_ri (node_right_ri),
				.right_di (node_right_di),
				.right_so (node_right_so),
				.right_ro (node_right_ro),
				.right_do (node_right_do),

				// Left Port
				.left_si  (node_left_si),
				.left_ri  (node_left_ri),
				.left_di  (node_left_di),
				.left_so  (node_left_so),
				.left_ro  (node_left_ro),
				.left_do  (node_left_do)
			);
		end
	end
endgenerate

endmodule
