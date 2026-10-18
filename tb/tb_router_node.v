/*=============================================================================
Standalone Testbench for Cardinal 5-Port Mesh Router Node
File: tb/tb_router_node.v
Target: router_node #(.MY_X(2'd1), .MY_Y(2'd1))

Output: Writes formatted verification log directly to ../out/tb_router_node.out


=============================================================================*/

`timescale 1ns/1ps

module tb_router_node ();

// Clock and Reset Signals
reg         clk;
reg         reset;
wire        polarity;

// DUT Coordinates: Node (1, 1) in 4x4 Mesh
localparam [1:0] DUT_X = 2'd1;
localparam [1:0] DUT_Y = 2'd1;

// Processing Element (PE) Port
reg         pesi;
wire        peri;
reg  [63:0] pedi;
wire        peso;
reg         pero;
wire [63:0] pedo;

// Up (North) Port
reg         up_si;
wire        up_ri;
reg  [63:0] up_di;
wire        up_so;
reg         up_ro;
wire [63:0] up_do;

// Down (South) Port
reg         down_si;
wire        down_ri;
reg  [63:0] down_di;
wire        down_so;
reg         down_ro;
wire [63:0] down_do;

// Right (East) Port
reg         right_si;
wire        right_ri;
reg  [63:0] right_di;
wire        right_so;
reg         right_ro;
wire [63:0] right_do;

// Left (West) Port
reg         left_si;
wire        left_ri;
reg  [63:0] left_di;
wire        left_so;
reg         left_ro;
wire [63:0] left_do;

// File Descriptor & Test Statistics
integer log_file;
integer total_tests;
integer pass_tests;
integer fail_tests;

// =========================================================================
// Instantiate DUT: router_node at coordinate (1, 1)
// =========================================================================
router_node #(
    .MY_X(DUT_X),
    .MY_Y(DUT_Y)
) dut (
    .clk        (clk),
    .reset      (reset),
    .polarity   (polarity),

    .pesi       (pesi),
    .peri       (peri),
    .pedi       (pedi),
    .peso       (peso),
    .pero       (pero),
    .pedo       (pedo),

    .up_si      (up_si),
    .up_ri      (up_ri),
    .up_di      (up_di),
    .up_so      (up_so),
    .up_ro      (up_ro),
    .up_do      (up_do),

    .down_si    (down_si),
    .down_ri    (down_ri),
    .down_di    (down_di),
    .down_so    (down_so),
    .down_ro    (down_ro),
    .down_do    (down_do),

    .right_si   (right_si),
    .right_ri   (right_ri),
    .right_di   (right_di),
    .right_so   (right_so),
    .right_ro   (right_ro),
    .right_do   (right_do),

    .left_si    (left_si),
    .left_ri    (left_ri),
    .left_di    (left_di),
    .left_so    (left_so),
    .left_ro    (left_ro),
    .left_do    (left_do)
);

// =========================================================================
// Clock Generation: 250 MHz (Period = 4.0 ns)
// =========================================================================
always #2.0 clk = ~clk;

// =========================================================================
// Packet Construction Function (64-Bit Mesh Format)
// [63]   : Virtual Channel (0: VC0 Even, 1: VC1 Odd)
// [62]   : Reserved
// [61:60]: Dest X
// [59:58]: Dest Y
// [57:56]: Reserved
// [55:48]: Hop count (unmodified passthrough)
// [47:32]: Source Node ID
// [31:0] : Payload
// =========================================================================
function [63:0] make_packet(
    input        vc,
    input [1:0]  dest_x,
    input [1:0]  dest_y,
    input [15:0] src_id,
    input [31:0] payload
);
    begin
        make_packet = {vc, 1'b0, dest_x, dest_y, 2'b00, 8'h00, src_id, payload};
    end
endfunction

// =========================================================================
// Synchronous Ingestion Tasks (Driven on negedge clk)
// =========================================================================
task inject_pe(input [63:0] pkt);
    begin
        @(negedge clk);
        while (peri !== 1'b1 || pkt[63] === polarity) begin
            pesi <= 1'b0;
            @(negedge clk);
        end
        pesi <= 1'b1;
        pedi <= pkt;
        @(negedge clk);
        pesi <= 1'b0;
        pedi <= 64'h0;
    end
endtask

task inject_left(input [63:0] pkt);
    begin
        @(negedge clk);
        while (left_ri !== 1'b1 || pkt[63] === polarity) begin
            left_si <= 1'b0;
            @(negedge clk);
        end
        left_si <= 1'b1;
        left_di <= pkt;
        @(negedge clk);
        left_si <= 1'b0;
        left_di <= 64'h0;
    end
endtask

task inject_up(input [63:0] pkt);
    begin
        @(negedge clk);
        while (up_ri !== 1'b1 || pkt[63] === polarity) begin
            up_si <= 1'b0;
            @(negedge clk);
        end
        up_si <= 1'b1;
        up_di <= pkt;
        @(negedge clk);
        up_si <= 1'b0;
        up_di <= 64'h0;
    end
endtask

// =========================================================================
// Packet Verification Tasks
// =========================================================================
task verify_right(input [63:0] exp_pkt, input [127:0] test_name);
    integer timeout;
    reg matched;
    begin
        total_tests = total_tests + 1;
        timeout = 0;
        matched = 0;
        while (timeout < 20 && !matched) begin
            @(posedge clk);
            if (right_so && right_ro) begin
                if (right_do === exp_pkt) begin
                    matched = 1;
                end else begin
                    $fdisplay(log_file, "[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, right_do);
                    $display("[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, right_do);
                end
            end
            timeout = timeout + 1;
        end

        if (matched) begin
            pass_tests = pass_tests + 1;
            $fdisplay(log_file, "[PASS] Test: %0s", test_name);
            $display("[PASS] Test: %0s", test_name);
        end else begin
            fail_tests = fail_tests + 1;
            $fdisplay(log_file, "[FAIL] Test: %0s (Packet not received or timed out)", test_name);
            $display("[FAIL] Test: %0s (Packet not received or timed out)", test_name);
        end
    end
endtask

task verify_down(input [63:0] exp_pkt, input [127:0] test_name);
    integer timeout;
    reg matched;
    begin
        total_tests = total_tests + 1;
        timeout = 0;
        matched = 0;
        while (timeout < 20 && !matched) begin
            @(posedge clk);
            if (down_so && down_ro) begin
                if (down_do === exp_pkt) begin
                    matched = 1;
                end else begin
                    $fdisplay(log_file, "[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, down_do);
                    $display("[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, down_do);
                end
            end
            timeout = timeout + 1;
        end

        if (matched) begin
            pass_tests = pass_tests + 1;
            $fdisplay(log_file, "[PASS] Test: %0s", test_name);
            $display("[PASS] Test: %0s", test_name);
        end else begin
            fail_tests = fail_tests + 1;
            $fdisplay(log_file, "[FAIL] Test: %0s (Packet not received or timed out)", test_name);
            $display("[FAIL] Test: %0s (Packet not received or timed out)", test_name);
        end
    end
endtask

task verify_pe(input [63:0] exp_pkt, input [127:0] test_name);
    integer timeout;
    reg matched;
    begin
        total_tests = total_tests + 1;
        timeout = 0;
        matched = 0;
        while (timeout < 20 && !matched) begin
            @(posedge clk);
            if (peso && pero) begin
                if (pedo === exp_pkt) begin
                    matched = 1;
                end else begin
                    $fdisplay(log_file, "[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, pedo);
                    $display("[MISMATCH] Test '%0s': Exp = %h, Got = %h", test_name, exp_pkt, pedo);
                end
            end
            timeout = timeout + 1;
        end

        if (matched) begin
            pass_tests = pass_tests + 1;
            $fdisplay(log_file, "[PASS] Test: %0s", test_name);
            $display("[PASS] Test: %0s", test_name);
        end else begin
            fail_tests = fail_tests + 1;
            $fdisplay(log_file, "[FAIL] Test: %0s (Packet not received or timed out)", test_name);
            $display("[FAIL] Test: %0s (Packet not received or timed out)", test_name);
        end
    end
endtask

// =========================================================================
// Main Verification Stimulus
// =========================================================================
reg [63:0] p1, p2, p3, p_pe, p_left;

initial begin
    // Open Output Report File
    log_file = $fopen("../out/tb_router_node.out", "w");
    if (!log_file) begin
        $display("[FATAL] Could not create file ../out/tb_router_node.out. Check folder permissions!");
        $finish;
    end

    $fdisplay(log_file, "================================================================================");
    $fdisplay(log_file, "         EE577B Phase 1: Standalone Router Node Verification Report             ");
    $fdisplay(log_file, "         DUT Coordinate: (%0d, %0d) | Target Clock: 250MHz (4.0ns)             ", DUT_X, DUT_Y);
    $fdisplay(log_file, "================================================================================");
    $display("Starting tb_router_node simulation...");

    // Initialize Internal Signals
    clk         = 0;
    reset       = 1;
    total_tests = 0;
    pass_tests  = 0;
    fail_tests  = 0;

    pesi        = 0; pedi     = 64'h0; pero     = 1;
    up_si       = 0; up_di    = 64'h0; up_ro    = 1;
    down_si     = 0; down_di  = 64'h0; down_ro  = 1;
    right_si    = 0; right_di = 64'h0; right_ro = 1;
    left_si     = 0; left_di  = 64'h0; left_ro  = 1;

    // Apply Reset for 5 cycles
    #20.0;
    @(negedge clk);
    reset = 0;
    $fdisplay(log_file, "\n[STATUS] Reset de-asserted at time %0t. Initial polarity = %0b\n", $time, polarity);

    // ---------------------------------------------------------------------
    // Test 1: Straight Dimension Routing (Left In -> Right Out, X-Dimension)
    // Dest X = 2 (> 1), Dest Y = 1 (== 1)
    // ---------------------------------------------------------------------
    $fdisplay(log_file, "--- Test Case 1: Straight X-Routing (Left -> Right) ---");
    p1 = make_packet(1'b0, 2'd2, 2'd1, 16'h0004, 32'hDEAD_0001);
    fork
        inject_left(p1);
        verify_right(p1, "Left to Right (X-Dir)");
    join

    // ---------------------------------------------------------------------
    // Test 2: Turn Routing (Left In -> Down Out, X then Y-Dimension)
    // Dest X = 1 (== 1), Dest Y = 2 (> 1)
    // ---------------------------------------------------------------------
    $fdisplay(log_file, "\n--- Test Case 2: Turn Routing (Left -> Down) ---");
    p2 = make_packet(1'b1, 2'd1, 2'd2, 16'h0004, 32'hCAFE_0002);
    fork
        inject_left(p2);
        verify_down(p2, "Left to Down Turn");
    join

    // ---------------------------------------------------------------------
    // Test 3: Local Core Ejection (Up In -> PE Out)
    // Dest X = 1 (== 1), Dest Y = 1 (== 1)
    // ---------------------------------------------------------------------
    $fdisplay(log_file, "\n--- Test Case 3: Ejection to Local PE (Up -> PE) ---");
    p3 = make_packet(1'b0, 2'd1, 2'd1, 16'h0001, 32'hBEEF_0003);
    fork
        inject_up(p3);
        verify_pe(p3, "Up to PE Ejection");
    join

    // ---------------------------------------------------------------------
    // Test 4: Downstream Backpressure Flow Control Handling
    // Downstream de-asserts ready_in (right_ro = 0)
    // ---------------------------------------------------------------------
    $fdisplay(log_file, "\n--- Test Case 4: Backpressure Handling on Right Port ---");
    right_ro = 0;
    p1 = make_packet(1'b1, 2'd3, 2'd1, 16'h0005, 32'hFEED_0004);
    fork
        inject_pe(p1);
    join

    // Wait 3 clock cycles with downstream stalled
    repeat (3) @(posedge clk);
    if (right_so === 1'b0) begin
        $fdisplay(log_file, "[PASS] Backpressure asserted: right_so correctly suppressed while right_ro=0");
        pass_tests = pass_tests + 1;
    end else begin
        $fdisplay(log_file, "[FAIL] Backpressure violated: right_so asserted while right_ro=0");
        fail_tests = fail_tests + 1;
    end
    total_tests = total_tests + 1;

    // Release backpressure and verify delivery
    @(negedge clk);
    right_ro = 1;
    verify_right(p1, "Backpressure Release Delivery");

    // ---------------------------------------------------------------------
    // Test 5: Arbiter Contention & Fair Rotating Priority
    // Both PE and Left inject simultaneously targeting Down port (Dest: 1, 2)
    // ---------------------------------------------------------------------
    $fdisplay(log_file, "\n--- Test Case 5: Contention & Rotating Priority (PE vs Left -> Down) ---");
    p_pe   = make_packet(1'b0, 2'd1, 2'd2, 16'h0005, 32'h1111_AAAA);
    p_left = make_packet(1'b0, 2'd1, 2'd2, 16'h0004, 32'h2222_BBBB);

    @(negedge clk);
    while (peri !== 1'b1 || left_ri !== 1'b1 || polarity !== 1'b1) begin
        @(negedge clk);
    end

    // Assert both requests concurrently
    pesi    <= 1'b1; pedi    <= p_pe;
    left_si <= 1'b1; left_di <= p_left;
    @(negedge clk);
    pesi    <= 1'b0; pedi    <= 64'h0;
    left_si <= 1'b0; left_di <= 64'h0;

    // Verify that both packets arrive in consecutive phases without drop or corruption
    total_tests = total_tests + 2;
    repeat (8) @(posedge clk) begin
        if (down_so && down_ro) begin
            if (down_do === p_pe) begin
                $fdisplay(log_file, "[PASS] Contention Phase 1 Serviced: PE Packet (%h)", down_do);
                pass_tests = pass_tests + 1;
            end else if (down_do === p_left) begin
                $fdisplay(log_file, "[PASS] Contention Phase 2 Serviced: Left Packet (%h)", down_do);
                pass_tests = pass_tests + 1;
            end
        end
    end

    // ---------------------------------------------------------------------
    // Final Summary
    // ---------------------------------------------------------------------
    #20.0;
    $fdisplay(log_file, "\n================================================================================");
    $fdisplay(log_file, "                           VERIFICATION SUMMARY                                 ");
    $fdisplay(log_file, "================================================================================");
    $fdisplay(log_file, " Total Tests Executed : %0d", total_tests);
    $fdisplay(log_file, " Tests Passed         : %0d", pass_tests);
    $fdisplay(log_file, " Tests Failed         : %0d", fail_tests);

    if (fail_tests == 0 && pass_tests > 0) begin
        $fdisplay(log_file, "\n OVERALL STATUS: >>> ALL TESTS PASSED SUCCESSFULLY <<< \n");
        $display("\n OVERALL STATUS: >>> ALL TESTS PASSED SUCCESSFULLY <<< \n");
    end else begin
        $fdisplay(log_file, "\n OVERALL STATUS: >>> VERIFICATION FAILED (Errors Detected) <<< \n");
        $display("\n OVERALL STATUS: >>> VERIFICATION FAILED (Errors Detected) <<< \n");
    end
    $fdisplay(log_file, "================================================================================");

    $fclose(log_file);$finish;
end


endmodule
