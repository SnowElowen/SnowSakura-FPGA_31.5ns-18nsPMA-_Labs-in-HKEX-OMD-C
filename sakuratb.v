`timescale 1ps / 1fs

module tb_omdc_top();

    // -------------------------------------------------------------------------
    // 1. Physical Layer Parameters (HKEX Real-world Environment Emulation)
    // -------------------------------------------------------------------------
    localparam real IDEAL_PERIOD_PS = 3100.198; // Target: 322.56 MHz
    localparam real HKEX_PPM        = 25.0;     // Frequency Offset (Parts Per Million)
    localparam real GTH_RJ_RMS      = 6.0;      // Random Jitter RMS (ps)
    
    reg clk_local = 0;
    reg rx_rec_clk = 0;

    // Local Clock Generation (FPGA System Clock)
    always #(IDEAL_PERIOD_PS / 2.0) clk_local = ~clk_local;

    // Recovered Clock Generation: Includes Frequency Offset and Random Jitter
    integer seed = 666;
    initial begin
        // Initial random phase offset to simulate asynchronous startup
        #( $urandom_range(0, 3100) ); 
        forever begin
            #( (IDEAL_PERIOD_PS * (1.0 - HKEX_PPM/1e6) / 2.0) + $dist_normal(seed, 0, GTH_RJ_RMS) ) rx_rec_clk = ~rx_rec_clk;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Signal Definitions
    // -------------------------------------------------------------------------
    reg [63:0] rx_data_mem [0:399999]; 
    reg [63:0] inject_rx_data;
    reg        rst_done;
    
    wire [31:0] tx_data;
    wire [3:0]  tx_ctrl;

    integer total_injected = 0;
    integer total_caught   = 0;

    // -------------------------------------------------------------------------
    // 3. DUT Instantiation (Core System Top Level)
    // -------------------------------------------------------------------------
    omdc_system_top dut (
        .clk           (clk_local),
        .rx_data_in    (inject_rx_data),
        .rx_reset_done (rst_done),
        .tx_data_out   (tx_data),
        .tx_ctrl_out   (tx_ctrl)
    );

    // --- Hierarchical Probe: Monitoring internal signals for verification ---
    // Path: dut (omdc_system_top) -> u_rx_parser (omdc_rx_parser_top)
    wire internal_valid = dut.u_rx_parser.parsed_msg_valid;
    wire [15:0] internal_type = dut.u_rx_parser.parsed_msg_type;

    // -------------------------------------------------------------------------
    // 4. Simulation Control Logic
    // -------------------------------------------------------------------------
    initial begin
        // Initialize signals
        inject_rx_data = 64'h0707070707070707;
        rst_done = 0;
        
        $display("\n[SYS] Loading Raw Data: F:/raw_data.hex");
        $readmemh("F:/raw_data.hex", rx_data_mem); 
        
        // Stabilization period before releasing reset
        repeat(500) @(posedge clk_local);
        rst_done = 1;

        $display("[SYS] Link Up. Injecting with Jitter/PPM stress...");

        for (int i = 0; i < 400000; i++) begin
            // Break on end of data file
            if (rx_data_mem[i] === 64'hxxxxxxxxxxxxxxxx) break;
            
            @(posedge rx_rec_clk);
            // Physical Layer Latency: Emulates GTH PMA to FPGA Logic routing delay
            #2100 inject_rx_data <= rx_data_mem[i]; 
        end

        // Drain the pipeline (Ensures 36ns path is fully processed)
        repeat(100) @(posedge clk_local);
        
        // Final Reporting
        $display("\n====================================================");
        $display("  [HKEX OMD-C PHYSICAL LAYER SIM REPORT]");
        $display("  TX Injected (Remote Domain): %0d", total_injected);
        $display("  RX Caught   (Local Domain) : %0d", total_caught);
        
        if (total_injected == total_caught && total_injected > 0) begin
            $display("  RESULT: [PASSED] - CDC and Parser are Stable.");
        end else begin
            $display("  RESULT: [FAILED] - Packet Mismatch Detected!");
            $display("  Difference: %0d", (total_injected - total_caught));
        end
        $display("====================================================\n");
        $finish;
    end

    // -------------------------------------------------------------------------
    // 5. Statistics & Performance Monitors
    // -------------------------------------------------------------------------
    
    // Injected Packet Counter (Remote Clock Domain)
    always @(posedge rx_rec_clk) begin
        if (rst_done && inject_rx_data != 64'h0707070707070707) begin
            // Detect OMD-C Start of Packet (SOP: 0xFB)
            if (inject_rx_data[7:0] == 8'hFB || inject_rx_data[15:8] == 8'hFB ||
                inject_rx_data[23:16] == 8'hFB || inject_rx_data[31:24] == 8'hFB ||
                inject_rx_data[39:32] == 8'hFB || inject_rx_data[47:40] == 8'hFB ||
                inject_rx_data[55:48] == 8'hFB || inject_rx_data[63:56] == 8'hFB) begin
                total_injected <= total_injected + 1;
            end
        end
    end

    // Caught Packet Counter (Local Clock Domain)
    always @(posedge clk_local) begin
        // Monitor internal parser valid signal
        if (rst_done && internal_valid) begin
            total_caught <= total_caught + 1;
        end
    end

endmodule
