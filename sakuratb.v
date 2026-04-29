`timescale 1ps / 1fs

module tb_omdc_top();

    // -------------------------------------------------------------------------
    // 1. 物理层参数 (HKEX 真实物理特性还原)
    // -------------------------------------------------------------------------
    localparam real IDEAL_PERIOD_PS = 3100.198; // 322.56 MHz
    localparam real HKEX_PPM        = 25.0;      
    localparam real GTH_RJ_RMS      = 6.0;       
    
    reg clk_local = 0;
    reg rx_rec_clk = 0;

    // 本地时钟生成
    always #(IDEAL_PERIOD_PS / 2.0) clk_local = ~clk_local;

    // 远端恢复时钟：带频偏和随机抖动
    integer seed = 666;
    initial begin
        #( $urandom_range(0, 3100) ); 
        forever begin
            #( (IDEAL_PERIOD_PS * (1.0 - HKEX_PPM/1e6) / 2.0) + $dist_normal(seed, 0, GTH_RJ_RMS) ) rx_rec_clk = ~rx_rec_clk;
        end
    end

    // -------------------------------------------------------------------------
    // 2. 信号定义
    // -------------------------------------------------------------------------
    reg [63:0] rx_data_mem [0:399999]; 
    reg [63:0] inject_rx_data;
    reg        rst_done;
    
    wire [31:0] tx_data;
    wire [3:0]  tx_ctrl;

    integer total_injected = 0;
    integer total_caught   = 0;

    // -------------------------------------------------------------------------
    // 3. DUT 例化 (直接例化你的核心 Top 层)
    // -------------------------------------------------------------------------
    omdc_system_top dut (
        .clk           (clk_local),
        .rx_data_in    (inject_rx_data),
        .rx_reset_done (rst_done),
        .tx_data_out   (tx_data_out), // 对应你代码里的 tx_data_out
        .tx_ctrl_out   (tx_ctrl_out)  // 对应你代码里的 tx_ctrl_out
    );

    // --- 关键修正：对齐你的内部层级路径 ---
    // 根据你的源码：dut (omdc_system_top) -> u_rx_parser (omdc_rx_parser_top)
    wire internal_valid = dut.u_rx_parser.parsed_msg_valid;
    wire [15:0] internal_type = dut.u_rx_parser.parsed_msg_type;

    // -------------------------------------------------------------------------
    // 4. 仿真控制逻辑
    // -------------------------------------------------------------------------
    initial begin
        inject_rx_data = 64'h0707070707070707;
        rst_done = 0;
        
        $display("\n[SYS] Loading Data: F:/raw_data.hex");
        $readmemh("F:/raw_data.hex", rx_data_mem); 
        
        repeat(500) @(posedge clk_local);
        rst_done = 1;

        $display("[SYS] Link Up. Injecting with Jitter/PPM...");

        for (int i = 0; i < 400000; i++) begin
            if (rx_data_mem[i] === 64'hxxxxxxxxxxxxxxxx) break;
            
            @(posedge rx_rec_clk);
            // 物理层延迟：模拟从 GTH PMA 到 FPGA 逻辑的布线延迟
            #2100 inject_rx_data <= rx_data_mem[i]; 
        end

        // 等待 36ns 架构跑完最后几个包
        repeat(100) @(posedge clk_local);
        
        $display("\n====================================================");
        $display("  [HKEX OMD-C PHYSICAL LAYER SIM REPORT]");
        $display("  TX Injected (Remote Domain): %0d", total_injected);
        $display("  RX Caught   (Local Domain) : %0d", total_caught);
        
        if (total_injected == total_caught && total_injected > 0) begin
            $display("  RESULT: [PASSED] - CDC and Parser are Stable.");
        end else begin
            $display("  RESULT: [FAILED] - Packet Mismatch!");
            $display("  Diff: %0d", (total_injected - total_caught));
        end
        $display("====================================================\n");
        $finish;
    end

    // -------------------------------------------------------------------------
    // 5. 统计监控 (Monitors)
    // -------------------------------------------------------------------------
    
    // 发送计数 (远端时域)
    always @(posedge rx_rec_clk) begin
        if (rst_done && inject_rx_data != 64'h0707070707070707) begin
            // 探测 OMD-C 的 SOP (0xFB)
            if (inject_rx_data[7:0] == 8'hFB || inject_rx_data[15:8] == 8'hFB ||
                inject_rx_data[23:16] == 8'hFB || inject_rx_data[31:24] == 8'hFB ||
                inject_rx_data[39:32] == 8'hFB || inject_rx_data[47:40] == 8'hFB ||
                inject_rx_data[55:48] == 8'hFB || inject_rx_data[63:56] == 8'hFB) begin
                total_injected <= total_injected + 1;
            end
        end
    end

    // 接收计数 (本地时域)
    always @(posedge clk_local) begin
        // 使用修正后的内部路径信号
        if (rst_done && internal_valid) begin
            total_caught <= total_caught + 1;
        end
    end

endmodule