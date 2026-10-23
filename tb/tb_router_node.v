
`timescale 1ns/1ps

module tb_router_node;

reg clk, reset;
wire polarity;

localparam [1:0] DUT_X = 2'd1;
localparam [1:0] DUT_Y = 2'd1;

// Port IDs used by testbench
localparam PE    = 0;
localparam UP    = 1;
localparam DOWN  = 2;
localparam RIGHT = 3;
localparam LEFT  = 4;

// PE interface
reg pesi, pero;
reg [63:0] pedi;
wire peri, peso;
wire [63:0] pedo;

// North interface
reg up_si, up_ro;
reg [63:0] up_di;
wire up_ri, up_so;
wire [63:0] up_do;

// South interface
reg down_si, down_ro;
reg [63:0] down_di;
wire down_ri, down_so;
wire [63:0] down_do;

// East interface
reg right_si, right_ro;
reg [63:0] right_di;
wire right_ri, right_so;
wire [63:0] right_do;

// West interface
reg left_si, left_ro;
reg [63:0] left_di;
wire left_ri, left_so;
wire [63:0] left_do;

// Visible in SimVision
integer test_id;
integer total_tests;
integer pass_tests;
integer fail_tests;
integer log_file;

reg [63:0] packet_a, packet_b;
integer received_a, received_b;
integer first_winner;
integer second_winner;

// DUT
router_node #(
    .MY_X(DUT_X),
    .MY_Y(DUT_Y)
) dut (
    .clk(clk),
    .reset(reset),
    .polarity(polarity),

    .pesi(pesi), .peri(peri),
    .pedi(pedi), .peso(peso),
    .pero(pero), .pedo(pedo),

    .up_si(up_si), .up_ri(up_ri),
    .up_di(up_di), .up_so(up_so),
    .up_ro(up_ro), .up_do(up_do),

    .down_si(down_si), .down_ri(down_ri),
    .down_di(down_di), .down_so(down_so),
    .down_ro(down_ro), .down_do(down_do),

    .right_si(right_si), .right_ri(right_ri),
    .right_di(right_di), .right_so(right_so),
    .right_ro(right_ro), .right_do(right_do),

    .left_si(left_si), .left_ri(left_ri),
    .left_di(left_di), .left_so(left_so),
    .left_ro(left_ro), .left_do(left_do)
);

// 250 MHz clock
always #2 clk = ~clk;

// SimVision database
initial begin
    $shm_open("waveforms/simvision_router");
    $shm_probe("AS");
end

// Mesh packet format
function [63:0] make_packet;
    input vc;
    input [1:0] dest_x, dest_y;
    input [15:0] source;
    input [31:0] payload;
    begin
        make_packet = {
            vc, 1'b0,
            dest_x, dest_y,
            2'b00, 8'h00,
            source, payload
        };
    end
endfunction

// Read a port's ready signal
function input_ready;
    input integer port;
    begin
        case (port)
            PE:    input_ready = peri;
            UP:    input_ready = up_ri;
            DOWN:  input_ready = down_ri;
            RIGHT: input_ready = right_ri;
            LEFT:  input_ready = left_ri;
            default: input_ready = 0;
        endcase
    end
endfunction

// Read output handshake and data
function output_valid;
    input integer port;
    begin
        case (port)
            PE:    output_valid = peso && pero;
            UP:    output_valid = up_so && up_ro;
            DOWN:  output_valid = down_so && down_ro;
            RIGHT: output_valid = right_so && right_ro;
            LEFT:  output_valid = left_so && left_ro;
            default: output_valid = 0;
        endcase
    end
endfunction

function [63:0] output_data;
    input integer port;
    begin
        case (port)
            PE:    output_data = pedo;
            UP:    output_data = up_do;
            DOWN:  output_data = down_do;
            RIGHT: output_data = right_do;
            LEFT:  output_data = left_do;
            default: output_data = 64'h0;
        endcase
    end
endfunction

// Drive input signals
task drive_input;
    input integer port;
    input reg valid;
    input [63:0] data;
    begin
        case (port)
            PE: begin
                pesi = valid; pedi = data;
            end
            UP: begin
                up_si = valid; up_di = data;
            end
            DOWN: begin
                down_si = valid; down_di = data;
            end
            RIGHT: begin
                right_si = valid; right_di = data;
            end
            LEFT: begin
                left_si = valid; left_di = data;
            end
        endcase
    end
endtask

// Inject packet on correct external VC phase
task inject;
    input integer port;
    input [63:0] packet;
    integer timeout;
    reg accepted;
    begin
        accepted = 0;
        timeout = 0;

        @(negedge clk);

        while (!accepted && timeout < 40) begin
            if (input_ready(port) === 1'b1 &&
                polarity !== packet[63]) begin

                drive_input(port, 1'b1, packet);

                @(posedge clk);
                accepted = 1;

                @(negedge clk);
                drive_input(port, 1'b0, 64'h0);
            end
            else begin
                @(negedge clk);
                timeout = timeout + 1;
            end
        end

        if (!accepted) begin
            $display("[ERROR] Injection timeout: port=%0d",
                     port);
            $fdisplay(log_file,
                "[ERROR] Injection timeout: port=%0d", port);
        end
    end
endtask

// Record one test result
task record_result;
    input reg success;
    input [255:0] description;
    begin
        total_tests = total_tests + 1;

        if (success) begin
            pass_tests = pass_tests + 1;
            $display("[PASS] %0s", description);
            $fdisplay(log_file, "[PASS] %0s", description);
        end
        else begin
            fail_tests = fail_tests + 1;
            $display("[FAIL] %0s", description);
            $fdisplay(log_file, "[FAIL] %0s", description);
        end
    end
endtask

// Monitor expected output while injection occurs.
// Monitoring starts before packet injection to avoid
// missing the first output handshake.
task routing_test;
    input integer id;
    input integer src_port;
    input integer dst_port;
    input [63:0] packet;
    input [255:0] description;

    integer cycles;
    integer matches;
    integer wrong;
    reg done;
    begin
        test_id = id;
        matches = 0;
        wrong = 0;
        done = 0;

        $display("\nTEST %0d: %0s", id, description);
        $fdisplay(log_file,
            "\nTEST %0d: %0s", id, description);

        fork
            inject(src_port, packet);

            begin
                for (cycles = 0; cycles < 30; cycles = cycles + 1) begin
                    @(posedge clk);
                    #0.001;

                    if (output_valid(dst_port)) begin
                        if (output_data(dst_port) === packet)
                            matches = matches + 1;
                        else
                            wrong = wrong + 1;
                    end
                end
                done = 1;
            end
        join

        record_result(matches == 1 && wrong == 0,
                      description);

        repeat (4) @(negedge clk);
    end
endtask

// Reset DUT between test groups
task reset_router;
    begin
        @(negedge clk);
        reset = 1;

        pesi = 0; pedi = 0;
        up_si = 0; up_di = 0;
        down_si = 0; down_di = 0;
        right_si = 0; right_di = 0;
        left_si = 0; left_di = 0;

        pero = 1;
        up_ro = 1;
        down_ro = 1;
        right_ro = 1;
        left_ro = 1;

        repeat (4) @(posedge clk);

        @(negedge clk);
        reset = 0;
    end
endtask

// Two simultaneous inputs compete for DOWN.
// Check that both packets arrive exactly once,
// and record which input wins first.
task contention_round;
    input [63:0] pe_packet;
    input [63:0] left_packet;
    output integer winner;

    integer cycles;
    integer count_pe;
    integer count_left;
    integer total_seen;
    integer invalid_count;
    reg [63:0] observed;

    begin
        count_pe = 0;
        count_left = 0;
        total_seen = 0;
        invalid_count = 0;
        winner = -1;

        fork
            begin
                @(negedge clk);
                while (!(peri === 1'b1 &&
                         left_ri === 1'b1 &&
                         polarity === 1'b1))
                    @(negedge clk);

                // VC0 external injection
                pesi = 1;
                pedi = pe_packet;
                left_si = 1;
                left_di = left_packet;

                @(posedge clk);
                @(negedge clk);

                pesi = 0;
                pedi = 0;
                left_si = 0;
                left_di = 0;
            end

            begin
                for (cycles = 0; cycles < 30;
                     cycles = cycles + 1) begin
                    @(posedge clk);
                    #0.001;

                    if (down_so && down_ro) begin
                        observed = down_do;
                        total_seen = total_seen + 1;

                        if (observed === pe_packet) begin
                            count_pe = count_pe + 1;
                            if (winner == -1)
                                winner = PE;
                        end
                        else if (observed === left_packet) begin
                            count_left = count_left + 1;
                            if (winner == -1)
                                winner = LEFT;
                        end
                        else
                            invalid_count = invalid_count + 1;
                    end
                end
            end
        join

        record_result(
            count_pe == 1 &&
            count_left == 1 &&
            total_seen == 2 &&
            invalid_count == 0,
            "Contention: both packets received exactly once"
        );
    end
endtask

// Main test sequence
initial begin
    clk = 0;
    reset = 1;
    test_id = 0;

    total_tests = 0;
    pass_tests = 0;
    fail_tests = 0;

    pesi = 0; pedi = 0; pero = 1;
    up_si = 0; up_di = 0; up_ro = 1;
    down_si = 0; down_di = 0; down_ro = 1;
    right_si = 0; right_di = 0; right_ro = 1;
    left_si = 0; left_di = 0; left_ro = 1;

    log_file = $fopen("out/tb_router_node.out", "w");
    if (log_file == 0)
        log_file = $fopen("tb_router_node.out", "w");

    $display("Starting Phase 1 Router Verification");

    // =====================================================
    // TEST 0: RESET
    // =====================================================
    test_id = 0;
    repeat (5) @(posedge clk);

    #0.001;
    record_result(
        left_ri === 1'b1 &&
        right_ri === 1'b1 &&
        up_ri === 1'b1 &&
        down_ri === 1'b1 &&
        peri === 1'b1 &&
        left_so === 1'b0 &&
        right_so === 1'b0 &&
        up_so === 1'b0 &&
        down_so === 1'b0 &&
        peso === 1'b0,
        "Reset initialization"
    );

    @(negedge clk);
    reset = 0;
    repeat (4) @(negedge clk);

    // =====================================================
    // TESTS 1-6: ROUTING AND SWITCHING
    // Router coordinate: (1,1)
    // =====================================================

    // Test 1: Left -> Right
    routing_test(
        1, LEFT, RIGHT,
        make_packet(0, 2, 1, 16'h0001, 32'hAAAA0001),
        "Left to Right"
    );

    // Test 2: Left -> Down
    routing_test(
        2, LEFT, DOWN,
        make_packet(1, 1, 2, 16'h0002, 32'hBBBB0002),
        "Left to Down"
    );

    // Test 3: Up -> PE
    routing_test(
        3, UP, PE,
        make_packet(0, 1, 1, 16'h0003, 32'hCCCC0003),
        "Up to Local PE"
    );

    // Test 4: PE -> Right
    routing_test(
        4, PE, RIGHT,
        make_packet(1, 3, 1, 16'h0004, 32'hDDDD0004),
        "PE to Right"
    );

    // Test 5: Down -> Up
    routing_test(
        5, DOWN, UP,
        make_packet(0, 1, 0, 16'h0005, 32'hEEEE0005),
        "Down to Up"
    );

    // Test 6: Right -> Left
    routing_test(
        6, RIGHT, LEFT,
        make_packet(1, 0, 1, 16'h0006, 32'hFFFF0006),
        "Right to Left"
    );

    // =====================================================
    // TEST 7: HANDSHAKE WITHOUT BLOCKING
    // =====================================================
    reset_router;

    routing_test(
        7, PE, RIGHT,
        make_packet(0, 2, 1, 16'h0007, 32'h12340007),
        "Handshake without blocking"
    );

    // =====================================================
    // TEST 8: HANDSHAKE WITH BLOCKING
    // =====================================================
    reset_router;
    test_id = 8;

    packet_a = make_packet(
        1, 2, 1, 16'h0008, 32'h12340008
    );

    @(negedge clk);
    right_ro = 0;

    inject(PE, packet_a);

    // Allow packet to reach output buffer.
    repeat (6) @(posedge clk);
    #0.001;

    record_result(
        right_so === 1'b0 &&
        dut.u_out_right.buf_odd_full === 1'b1 &&
        dut.u_out_right.buf_odd === packet_a,
        "Blocking: packet retained in output buffer"
    );

    @(negedge clk);
    right_ro = 1;

    begin : blocking_recovery
        integer cycles;
        integer matches;
        matches = 0;

        for (cycles = 0; cycles < 12;
             cycles = cycles + 1) begin
            @(posedge clk);
            #0.001;

            if (right_so && right_ro &&
                right_do === packet_a)
                matches = matches + 1;
        end

        record_result(
            matches == 1,
            "Blocking recovery: packet sent once"
        );
    end

    // =====================================================
    // TEST 9: ARBITRATION - FIRST CONTENTION
    // =====================================================
    reset_router;
    test_id = 9;

    packet_a = make_packet(
        0, 1, 2, 16'h0009, 32'h1111AAAA
    );
    packet_b = make_packet(
        0, 1, 2, 16'h000A, 32'h2222BBBB
    );

    contention_round(
        packet_a, packet_b, first_winner
    );

    // =====================================================
    // TEST 10: ARBITRATION - SECOND CONTENTION
    // No reset: priority state must be preserved.
    // =====================================================
    test_id = 10;

    repeat (4) @(negedge clk);

    packet_a = make_packet(
        0, 1, 2, 16'h000B, 32'h3333CCCC
    );
    packet_b = make_packet(
        0, 1, 2, 16'h000C, 32'h4444DDDD
    );

    contention_round(
        packet_a, packet_b, second_winner
    );

    record_result(
        first_winner != -1 &&
        second_winner != -1 &&
        first_winner != second_winner,
        "Arbitration: priority rotated"
    );

    // =====================================================
    // FINAL SUMMARY
    // =====================================================
    test_id = 11;

    $display("\n================================");
    $display("ROUTER VERIFICATION SUMMARY");
    $display("Total:  %0d", total_tests);
    $display("Passed: %0d", pass_tests);
    $display("Failed: %0d", fail_tests);
    $display("================================");

    $fdisplay(log_file,
        "Total=%0d Passed=%0d Failed=%0d",
        total_tests, pass_tests, fail_tests);

    $fclose(log_file);
    $finish;
end

// Global timeout protection
initial begin
    #3000;
    $display("[FATAL] Simulation timeout");
    $finish;
end

endmodule
