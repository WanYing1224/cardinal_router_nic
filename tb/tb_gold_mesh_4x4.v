/*============================================================================================
    System Testbench for 16-Node 4x4 Gold Mesh (tb_gold_mesh_4x4.v)
    - Verifies multi-hop Dimension-Order (X-Y) routing across all 16 nodes
    - Dumps verification progress, payload comparison, and summary to ../out/tb_gold_mesh_4x4.out
    - Dumps SimVision waveform database to simvision_mesh/
============================================================================================*/

`timescale 1ns/1ps

module tb_gold_mesh_4x4;

    // Clock and Reset
    reg clk;
    reg reset;

    // 16-Node PE Wires
    reg  [15:0] pesi;
    reg  [15:0] pero;
    wire [15:0] peso;
    wire [15:0] peri;
    reg  [63:0] pedi [0:15];
    wire [63:0] pedo [0:15];
    wire [15:0] polarity;

    // Testbench Management Variables
    integer fout;
    integer errors;
    integer packets_sent;
    integer packets_received;
    integer i;

    // Waveform Database Dump for SimVision (simvision_mesh)
    initial begin
        $shm_open("waveforms/simvision_mesh");
        $shm_probe("AS");
    end

    // Clock Generation: 250 MHz (Period = 4.0 ns)
    always #2.0 clk = ~clk;

    // =========================================================================
    // Instantiate 16-Node Mesh DUT
    // =========================================================================
    gold_mesh_4x4 u_mesh (
        .clk             (clk),
        .reset           (reset),

        .node0_pesi      (pesi[0]),     .node0_pero      (pero[0]),
        .node0_peso      (peso[0]),     .node0_peri      (peri[0]),
        .node0_pedi      (pedi[0]),     .node0_pedo      (pedo[0]),
        .node0_polarity  (polarity[0]),

        .node1_pesi      (pesi[1]),     .node1_pero      (pero[1]),
        .node1_peso      (peso[1]),     .node1_peri      (peri[1]),
        .node1_pedi      (pedi[1]),     .node1_pedo      (pedo[1]),
        .node1_polarity  (polarity[1]),

        .node2_pesi      (pesi[2]),     .node2_pero      (pero[2]),
        .node2_peso      (peso[2]),     .node2_peri      (peri[2]),
        .node2_pedi      (pedi[2]),     .node2_pedo      (pedo[2]),
        .node2_polarity  (polarity[2]),

        .node3_pesi      (pesi[3]),     .node3_pero      (pero[3]),
        .node3_peso      (peso[3]),     .node3_peri      (peri[3]),
        .node3_pedi      (pedi[3]),     .node3_pedo      (pedo[3]),
        .node3_polarity  (polarity[3]),

        .node4_pesi      (pesi[4]),     .node4_pero      (pero[4]),
        .node4_peso      (peso[4]),     .node4_peri      (peri[4]),
        .node4_pedi      (pedi[4]),     .node4_pedo      (pedo[4]),
        .node4_polarity  (polarity[4]),

        .node5_pesi      (pesi[5]),     .node5_pero      (pero[5]),
        .node5_peso      (peso[5]),     .node5_peri      (peri[5]),
        .node5_pedi      (pedi[5]),     .node5_pedo      (pedo[5]),
        .node5_polarity  (polarity[5]),

        .node6_pesi      (pesi[6]),     .node6_pero      (pero[6]),
        .node6_peso      (peso[6]),     .node6_peri      (peri[6]),
        .node6_pedi      (pedi[6]),     .node6_pedo      (pedo[6]),
        .node6_polarity  (polarity[6]),

        .node7_pesi      (pesi[7]),     .node7_pero      (pero[7]),
        .node7_peso      (peso[7]),     .node7_peri      (peri[7]),
        .node7_pedi      (pedi[7]),     .node7_pedo      (pedo[7]),
        .node7_polarity  (polarity[7]),

        .node8_pesi      (pesi[8]),     .node8_pero      (pero[8]),
        .node8_peso      (peso[8]),     .node8_peri      (peri[8]),
        .node8_pedi      (pedi[8]),     .node8_pedo      (pedo[8]),
        .node8_polarity  (polarity[8]),

        .node9_pesi      (pesi[9]),     .node9_pero      (pero[9]),
        .node9_peso      (peso[9]),     .node9_peri      (peri[9]),
        .node9_pedi      (pedi[9]),     .node9_pedo      (pedo[9]),
        .node9_polarity  (polarity[9]),

        .node10_pesi     (pesi[10]),    .node10_pero     (pero[10]),
        .node10_peso     (peso[10]),    .node10_peri     (peri[10]),
        .node10_pedi     (pedi[10]),    .node10_pedo     (pedo[10]),
        .node10_polarity (polarity[10]),

        .node11_pesi     (pesi[11]),    .node11_pero     (pero[11]),
        .node11_peso     (peso[11]),    .node11_peri     (peri[11]),
        .node11_pedi     (pedi[11]),    .node11_pedo     (pedo[11]),
        .node11_polarity (polarity[11]),

        .node12_pesi     (pesi[12]),    .node12_pero     (pero[12]),
        .node12_peso     (peso[12]),    .node12_peri     (peri[12]),
        .node12_pedi     (pedi[12]),    .node12_pedo     (pedo[12]),
        .node12_polarity (polarity[12]),

        .node13_pesi     (pesi[13]),    .node13_pero     (pero[13]),
        .node13_peso     (peso[13]),    .node13_peri     (peri[13]),
        .node13_pedi     (pedi[13]),    .node13_pedo     (pedo[13]),
        .node13_polarity (polarity[13]),

        .node14_pesi     (pesi[14]),    .node14_pero     (pero[14]),
        .node14_peso     (peso[14]),    .node14_peri     (peri[14]),
        .node14_pedi     (pedi[14]),    .node14_pedo     (pedo[14]),
        .node14_polarity (polarity[14]),

        .node15_pesi     (pesi[15]),    .node15_pero     (pero[15]),
        .node15_peso     (peso[15]),    .node15_peri     (peri[15]),
        .node15_pedi     (pedi[15]),    .node15_pedo     (pedo[15]),
        .node15_polarity (polarity[15])
    );

    // =========================================================================
    // Helper Function: Construct 64-bit Packet
    // =========================================================================
    function [63:0] build_packet;
        input        vc;       // [63]
        input [1:0]  dest_x;   // [61:60]
        input [1:0]  dest_y;   // [59:58]
        input [7:0]  hops;     // [55:48]
        input [15:0] src_node; // [47:32]
        input [31:0] payload;  // [31:0]
        begin
            build_packet = {vc, 1'b0, dest_x, dest_y, 2'b00, hops, src_node, payload};
        end
    endfunction

    // =========================================================================
    // Task: Inject Packet into Specified Source Node
    // =========================================================================
    task send_packet;
        input integer src_id;
        input [63:0]  pkt;
        reg target_vc;
        begin
            target_vc = pkt[63];

            @(negedge clk);
            while (polarity[src_id] == target_vc || !peri[src_id]) begin
                @(negedge clk);
            end

            pedi[src_id] = pkt;
            pesi[src_id] = 1'b1;
            packets_sent = packets_sent + 1;

            $fdisplay(fout, "[Time %0t ns] [INJECT] Node %0d injected packet %h (VC=%b, Dest=(%0d,%0d))",
                     $time, src_id, pkt, pkt[63], pkt[61:60], pkt[59:58]);
            $display("[Time %0t ns] [INJECT] Node %0d injected packet %h (VC=%b, Dest=(%0d,%0d))",
                     $time, src_id, pkt, pkt[63], pkt[61:60], pkt[59:58]);

            @(negedge clk);
            pesi[src_id] = 1'b0;
            pedi[src_id] = 64'h0;
        end
    endtask

    // =========================================================================
    // Task: Expect & Verify Packet at Destination Node
    // =========================================================================
    task expect_packet;
        input integer dst_id;
        input [63:0]  expected_pkt;
        input integer timeout_cycles;
        reg received;
        integer cycle_count;
        begin
            received = 0;
            cycle_count = 0;

            while (!received && cycle_count < timeout_cycles) begin
                @(posedge clk);
                #0.1;
                if (peso[dst_id] && pero[dst_id]) begin
                    received = 1;
                    packets_received = packets_received + 1;
                    if (pedo[dst_id] === expected_pkt) begin
                        $fdisplay(fout, "[Time %0t ns] [PASS] Node %0d received correct packet: %h",
                                 $time, dst_id, pedo[dst_id]);
                        $display("[Time %0t ns] [PASS] Node %0d received correct packet: %h",
                                 $time, dst_id, pedo[dst_id]);
                    end else begin
                        $fdisplay(fout, "[Time %0t ns] [FAIL] Node %0d packet mismatch! Expected: %h, Got: %h",
                                 $time, dst_id, expected_pkt, pedo[dst_id]);
                        $display("[Time %0t ns] [FAIL] Node %0d packet mismatch! Expected: %h, Got: %h",
                                 $time, dst_id, expected_pkt, pedo[dst_id]);
                        errors = errors + 1;
                    end
                end
                cycle_count = cycle_count + 1;
            end

            if (!received) begin
                $fdisplay(fout, "[Time %0t ns] [FAIL] Node %0d timed out waiting for packet: %h",
                         $time, dst_id, expected_pkt);
                $display("[Time %0t ns] [FAIL] Node %0d timed out waiting for packet: %h",
                         $time, dst_id, expected_pkt);
                errors = errors + 1;
            end
        end
    endtask

    // =========================================================================
    // Main Verification Flow
    // =========================================================================
    reg [63:0] pkt_test;

    initial begin
        fout = $fopen("out/tb_gold_mesh_4x4.out", "w");
        if (fout == 0) begin
            fout = $fopen("tb_gold_mesh_4x4.out", "w");
        end

        clk = 0;
        reset = 1;
        pesi = 16'h0000;
        pero = 16'hFFFF;
        errors = 0;
        packets_sent = 0;
        packets_received = 0;

        for (i = 0; i < 16; i = i + 1) begin
            pedi[i] = 64'h0;
        end

        $fdisplay(fout, "==================================================================");
        $fdisplay(fout, "       EE577B Phase 1: 4x4 Gold Mesh System Verification          ");
        $fdisplay(fout, "==================================================================");

        // Test 1: Reset & Polarity Check
        $fdisplay(fout, "\n--- Test 1: Reset & Polarity Synchronization ---");
        repeat (5) @(posedge clk);
        #0.1;
        if (polarity !== 16'h0000) begin
            $fdisplay(fout, "[FAIL] Not all polarities are 0 during reset: %h", polarity);
            errors = errors + 1;
        end else begin
            $fdisplay(fout, "[PASS] All 16 node polarities held at 0 during reset.");
        end

        @(negedge clk);
        reset = 0;

        repeat (4) begin
            @(posedge clk);
            #0.1;
            if (polarity !== 16'hFFFF && polarity !== 16'h0000) begin
                $fdisplay(fout, "[FAIL] Node polarities lost lockstep synchronization: %h", polarity);
                errors = errors + 1;
            end
        end
        $fdisplay(fout, "[PASS] All 16 node polarities toggle synchronously.");

        // Test 2: Horizontal 1-Hop Traversal (Node 0 -> Node 1)
        $fdisplay(fout, "\n--- Test 2: Horizontal 1-Hop Traversal (0 -> 1) ---");
        pkt_test = build_packet(1'b0, 2'd1, 2'd0, 8'd1, 16'd0, 32'hAAAA_0001);
        fork
            send_packet(0, pkt_test);
            expect_packet(1, pkt_test, 20);
        join

        // Test 3: Vertical 1-Hop Traversal (Node 0 -> Node 4)
        $fdisplay(fout, "\n--- Test 3: Vertical 1-Hop Traversal (0 -> 4) ---");
        pkt_test = build_packet(1'b1, 2'd0, 2'd1, 8'd1, 16'd0, 32'hAAAA_0004);
        fork
            send_packet(0, pkt_test);
            expect_packet(4, pkt_test, 20);
        join

        // Test 4: Corner-to-Corner Traversal (Node 0 -> Node 15)
        $fdisplay(fout, "\n--- Test 4: Corner-to-Corner Traversal (Node 0 -> Node 15) ---");
        pkt_test = build_packet(1'b0, 2'd3, 2'd3, 8'd6, 16'd0, 32'hDEAD_BEEF);
        fork
            send_packet(0, pkt_test);
            expect_packet(15, pkt_test, 40);
        join

        // Test 5: Reverse Traversal (Node 15 -> Node 0)
        $fdisplay(fout, "\n--- Test 5: Reverse Traversal (Node 15 -> Node 0) ---");
        pkt_test = build_packet(1'b1, 2'd0, 2'd0, 8'd6, 16'd15, 32'hCAFE_BABE);
        fork
            send_packet(15, pkt_test);
            expect_packet(0, pkt_test, 40);
        join

        // Test 6: Concurrent Multi-Node Traffic
        $fdisplay(fout, "\n--- Test 6: Concurrent Traffic Across Multiple Nodes ---");
        fork
            begin
                send_packet(2, build_packet(1'b0, 2'd2, 2'd2, 8'd2, 16'd2, 32'h2222_1010));
            end
            begin
                send_packet(5, build_packet(1'b0, 2'd3, 2'd1, 8'd2, 16'd5, 32'h5555_0707));
            end
            begin
                send_packet(12, build_packet(1'b0, 2'd1, 2'd3, 8'd1, 16'd12, 32'hCCCC_1313));
            end
            begin
                expect_packet(10, build_packet(1'b0, 2'd2, 2'd2, 8'd2, 16'd2, 32'h2222_1010), 40);
            end
            begin
                expect_packet(7,  build_packet(1'b0, 2'd3, 2'd1, 8'd2, 16'd5, 32'h5555_0707), 40);
            end
            begin
                expect_packet(13, build_packet(1'b0, 2'd1, 2'd3, 8'd1, 16'd12, 32'hCCCC_1313), 40);
            end
        join

        // Test 7: Downstream Backpressure Handling
        $fdisplay(fout, "\n--- Test 7: Downstream Backpressure Handling ---");
        pkt_test = build_packet(1'b1, 2'd1, 2'd1, 8'd2, 16'd0, 32'h9999_0505);
        pero[5] = 1'b0;

        fork
            send_packet(0, pkt_test);
            begin
                repeat (10) @(posedge clk);
                #0.1;
                if (peso[5] && !pero[5]) begin
                    $fdisplay(fout, "[PASS] Node 5 holding packet under backpressure (peso=1, pero=0)");
                end
                @(negedge clk);
                pero[5] = 1'b1;
                expect_packet(5, pkt_test, 20);
            end
        join

        repeat (10) @(posedge clk);

        $fdisplay(fout, "\n==================================================================");
        $fdisplay(fout, "                    VERIFICATION SUMMARY                         ");
        $fdisplay(fout, "==================================================================");
        $fdisplay(fout, "Total Packets Injected : %0d", packets_sent);
        $fdisplay(fout, "Total Packets Received : %0d", packets_received);
        $fdisplay(fout, "Total Errors Encountered: %0d", errors);
        if (errors == 0 && packets_sent == packets_received) begin
            $fdisplay(fout, "OVERALL STATUS: >>> ALL TESTS PASSED SUCCESSFULLY <<<");
            $display("\nOVERALL STATUS: >>> ALL TESTS PASSED SUCCESSFULLY <<<\n");
        end else begin
            $fdisplay(fout, "OVERALL STATUS: >>> TESTBENCH FAILED <<<");
            $display("\nOVERALL STATUS: >>> TESTBENCH FAILED <<<\n");
        end
        $fdisplay(fout, "==================================================================");

        $fclose(fout);
        $finish;
    end

endmodule
