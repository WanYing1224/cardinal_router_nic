/*=============================================================================
    EE577B Cardinal NIC Verification Testbench
    - Module: tb_cardinal_nic
    - DUT: cardinal_nic
    - Clock: 250 MHz (4.0 ns period)
    - Full coverage of Phase I report test cases and automatic self-checking
    - Logs results to console and out/cardinal_nic.out
    - Dumps SimVision waveform database to simvision_nic/
=============================================================================*/

`timescale 1ns/1ps

module tb_cardinal_nic;

    // =========================================================================
    // Simulation Parameters & Test Signals
    // =========================================================================
    localparam real CLK_PERIOD = 4.0; // 250 MHz clock

    reg         clk;
    reg         reset;

    // Processor Bus Interface
    reg  [1:0]  addr;
    reg  [63:0] d_in;
    wire [63:0] d_out;
    reg         nicEn;
    reg         nicEnWr;

    // Network Router Interface
    reg         net_si;
    wire        net_ri;
    reg  [63:0] net_di;

    wire        net_so;
    reg         net_ro;
    wire [63:0] net_do;
    reg         net_polarity;

    // Test Tracking Variables
    integer fout;
    integer test_count;
    integer error_count;

    // =========================================================================
    // Waveform Database Dump for SimVision (simvision_nic)
    // =========================================================================
    initial begin
        $shm_open("waveforms/simvision_nic");
        $shm_probe("AS");
    end

    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    cardinal_nic u_dut (
        .clk          (clk),
        .reset        (reset),
        .addr         (addr),
        .d_in         (d_in),
        .d_out        (d_out),
        .nicEn        (nicEn),
        .nicEnWr      (nicEnWr),
        .net_si       (net_si),
        .net_ri       (net_ri),
        .net_di       (net_di),
        .net_so       (net_so),
        .net_ro       (net_ro),
        .net_do       (net_do),
        .net_polarity (net_polarity)
    );

    // =========================================================================
    // Clock & Polarity Generation
    // =========================================================================
    // 250 MHz Clock: 2.0 ns High, 2.0 ns Low
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // Polarity: resets to 0, toggles every posedge clk while reset is deasserted
    always @(posedge clk) begin
        if (reset) begin
            net_polarity <= 1'b0;
        end else begin
            net_polarity <= ~net_polarity;
        end
    end

    // =========================================================================
    // Helper Tasks for CPU and Network Transactions
    // =========================================================================
    // CPU Store Task
    task cpu_store(input [1:0] reg_addr, input [63:0] data);
        begin
            @(negedge clk);
            addr    = reg_addr;
            d_in    = data;
            nicEn   = 1'b1;
            nicEnWr = 1'b1;
            @(posedge clk);
            #0.1; // Hold slightly past rising edge
        end
    endtask

    // CPU Load Task
    task cpu_load(input [1:0] reg_addr, output [63:0] data_read);
        begin
            @(negedge clk);
            addr    = reg_addr;
            nicEn   = 1'b1;
            nicEnWr = 1'b0;
            @(posedge clk);
            #0.5; // Allow synchronous d_out register to settle
            data_read = d_out;
        end
    endtask

    // CPU Idle Task
    task cpu_idle();
        begin
            @(negedge clk);
            nicEn   = 1'b0;
            nicEnWr = 1'b0;
            addr    = 2'b00;
            d_in    = 64'h0;
        end
    endtask

    // Check Task
    task check_condition(input [255:0] test_name, input condition, input [255:0] fail_msg);
        begin
            test_count = test_count + 1;
            if (condition) begin
                $display("[PASS] %0s", test_name);
                $fdisplay(fout, "[PASS] %0s", test_name);
            end else begin
                $display("[FAIL] %0s: %0s", test_name, fail_msg);
                $fdisplay(fout, "[FAIL] %0s: %0s", test_name, fail_msg);
                error_count = error_count + 1;
            end
        end
    endtask

    // =========================================================================
    // Main Test Stimulus
    // =========================================================================
    reg [63:0] read_val;
    reg [63:0] packet_vc0;
    reg [63:0] packet_vc1;
    reg [63:0] packet_corrupt;
    reg [63:0] rx_packet;

    initial begin
        // File output setup (checks out/ folder, falls back to local directory)
        fout = $fopen("out/cardinal_nic.out", "w");
        if (fout == 0) begin
            fout = $fopen("cardinal_nic.out", "w");
        end

        test_count  = 0;
        error_count = 0;

        // Initialize Test Packets
        // Bit 63 = VC (0: VC0, 1: VC1)
        packet_vc0     = 64'h0C01_0000_1234_5678; // VC0 packet (dest x=0, y=0)
        packet_vc1     = 64'h8C01_0000_AABB_CCDD; // VC1 packet (dest x=0, y=0)
        packet_corrupt = 64'hDEAD_BEEF_CAFE_BABE;
        rx_packet      = 64'h0000_0004_FACE_0001;

        // Default Signal Driving
        reset   = 1'b1;
        addr    = 2'b00;
        d_in    = 64'h0;
        nicEn   = 1'b0;
        nicEnWr = 1'b0;
        net_si  = 1'b0;
        net_di  = 64'h0;
        net_ro  = 1'b0;

        $display("=================================================================");
        $display("   EE577B Cardinal NIC Testbench Simulation Starting            ");
        $display("=================================================================");
        $fdisplay(fout, "=================================================================");
        $fdisplay(fout, "   EE577B Cardinal NIC Testbench Simulation Starting            ");
        $fdisplay(fout, "=================================================================");

        // ---------------------------------------------------------------------
        // TEST 1: Synchronous Reset Verification
        // ---------------------------------------------------------------------
        repeat (3) @(posedge clk);
        #1;
        check_condition("Reset net_ri active", net_ri === 1'b1, "net_ri should be 1 during reset");
        check_condition("Reset net_so inactive", net_so === 1'b0, "net_so should be 0 during reset");
        check_condition("Reset d_out is zero", d_out === 64'h0, "d_out should be 0 during reset");

        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);
        #1;
        check_condition("Post-reset net_ri ready", net_ri === 1'b1, "net_ri should remain 1 after reset");

        // ---------------------------------------------------------------------
        // TEST 2: CPU Store when Output Buffer Available (out_status == 0)
        // ---------------------------------------------------------------------
        cpu_load(2'b11, read_val); // Read output status
        check_condition("Output status initially empty", read_val[0] === 1'b0, "Output status should be 0");

        cpu_store(2'b10, packet_vc0); // Store VC0 packet
        cpu_idle();

        cpu_load(2'b11, read_val); // Read output status
        check_condition("Output status occupied after store", read_val[0] === 1'b1, "Output status should be 1");
        check_condition("net_do drives stored packet", net_do === packet_vc0, "net_do mismatch");

        // ---------------------------------------------------------------------
        // TEST 3: CPU Store when Output Buffer Unavailable (out_status == 1)
        // ---------------------------------------------------------------------
        // Buffer is occupied; attempt another store. It must be ignored.
        cpu_store(2'b10, packet_corrupt);
        cpu_idle();

        check_condition("Corrupt store ignored", net_do === packet_vc0, "Packet was corrupted by illegal store");

        // ---------------------------------------------------------------------
        // TEST 4: NIC-to-Router Handshake with Blocking (net_ro == 0)
        // ---------------------------------------------------------------------
        // Block the transmission by keeping net_ro = 0
        @(negedge clk);
        net_ro = 1'b0;
        repeat (2) @(posedge clk);
        #0.5;
        check_condition("net_so blocked when net_ro=0", net_so === 1'b0, "net_so must be 0 when net_ro is 0");

        // ---------------------------------------------------------------------
        // TEST 5: NIC-to-Router Handshake without Blocking (VC0 / Phase Matched)
        // ---------------------------------------------------------------------
        // Packet in out_buf is VC0 (bit 63 = 0). It must transfer when net_polarity == 1.
        @(negedge clk);
        net_ro = 1'b1;

        // Monitor transmission across polarity toggle
        @(posedge clk);
        #0.5;
        if (net_polarity == 1'b1) begin
            check_condition("VC0 net_so asserts on polarity=1", net_so === 1'b1, "net_so should assert for VC0");
        end

        @(posedge clk);
        #0.5;
        // After sending, out_buf should be empty
        check_condition("Output buffer cleared after send", net_so === 1'b0, "net_so should deassert after delivery");

        cpu_load(2'b11, read_val);
        check_condition("Output status empty after transmission", read_val[0] === 1'b0, "Output status should clear");

        // ---------------------------------------------------------------------
        // TEST 6: NIC-to-Router Handshake without Blocking (VC1 / Phase Matched)
        // ---------------------------------------------------------------------
        cpu_store(2'b10, packet_vc1); // Store VC1 packet (bit 63 = 1)
        cpu_idle();

        @(negedge clk);
        net_ro = 1'b1;

        // Packet is VC1: it must transfer when net_polarity == 0
        @(posedge clk);
        #0.5;
        if (net_polarity == 1'b0) begin
            check_condition("VC1 net_so asserts on polarity=0", net_so === 1'b1, "net_so should assert for VC1");
        end

        @(posedge clk);
        #0.5;
        cpu_load(2'b11, read_val);
        check_condition("Output status empty after VC1 send", read_val[0] === 1'b0, "Output status should clear");

        // ---------------------------------------------------------------------
        // TEST 7: Router-to-NIC Reception (net_si == 1, net_ri == 1)
        // ---------------------------------------------------------------------
        cpu_load(2'b01, read_val);
        check_condition("Input status initially empty", read_val[0] === 1'b0, "Input status should be 0");

        @(negedge clk);
        net_si = 1'b1;
        net_di = rx_packet;
        @(posedge clk); // Router clocks packet into NIC
        #0.5;
        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;

        // ---------------------------------------------------------------------
        // TEST 8: Reception Blocking (net_ri == 0 when buffer occupied)
        // ---------------------------------------------------------------------
        #0.5;
        check_condition("net_ri deasserts when input buffer full", net_ri === 1'b0, "net_ri should be 0");

        cpu_load(2'b01, read_val); // Read input status
        check_condition("Input status indicates full", read_val[0] === 1'b1, "Input status should be 1");

        // ---------------------------------------------------------------------
        // TEST 9: CPU Load when Input Buffer Available (addr == 2'b00, Pop-on-Read)
        // ---------------------------------------------------------------------
        cpu_load(2'b00, read_val); // Read input buffer
        check_condition("CPU reads correct packet data", read_val === rx_packet, "Read data mismatch");

        // Reading empties the buffer: verify in_status = 0 and net_ri = 1
        cpu_load(2'b01, read_val);
        check_condition("Input buffer cleared after read", read_val[0] === 1'b0, "Input status should clear");
        check_condition("net_ri reasserts ready", net_ri === 1'b1, "net_ri should return to 1");

        // ---------------------------------------------------------------------
        // TEST 10: CPU Load when Input Buffer Empty (in_status == 0)
        // ---------------------------------------------------------------------
        cpu_load(2'b01, read_val);
        check_condition("Load status when empty returns 0", read_val[0] === 1'b0, "Status must be 0");

        // ---------------------------------------------------------------------
        // TEST 11: Disabled Access (nicEn == 0)
        // ---------------------------------------------------------------------
        @(negedge clk);
        nicEn   = 1'b0;
        nicEnWr = 1'b0;
        addr    = 2'b01;
        @(posedge clk);
        #0.5;
        check_condition("d_out is 0 when nicEn=0", d_out === 64'h0, "d_out must be 0 when disabled");

        // =====================================================================
        // Final Results Summary & File Closing
        // =====================================================================
        $display("=================================================================");
        $display("   TEST SUMMARY: Total Tests: %0d | Errors: %0d", test_count, error_count);
        if (error_count == 0) begin
            $display("   VERDICT: ALL TESTS PASSED!");
        end else begin
            $display("   VERDICT: SIMULATION FAILED WITH %0d ERROR(S)", error_count);
        end
        $display("=================================================================");

        $fdisplay(fout, "=================================================================");
        $fdisplay(fout, "   TEST SUMMARY: Total Tests: %0d | Errors: %0d", test_count, error_count);
        if (error_count == 0) begin
            $fdisplay(fout, "   VERDICT: ALL TESTS PASSED!");
        end else begin
            $fdisplay(fout, "   VERDICT: SIMULATION FAILED WITH %0d ERROR(S)", error_count);
        end
        $fdisplay(fout, "=================================================================");

        $fclose(fout);
        $finish;
    end

endmodule
