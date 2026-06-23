`timescale  1ns/1ns

module top (
    input                   clk_50m,      
    input                   rst_n,      
    input                   key_in,     
    input                   mode,       // 该引脚已闲置，仅保留接口兼容
    input  signed [11:0]    adc_data,     
    output                  adc_clk_out,  
    output        [7:0]     dac_data_out,
    output                  dac_clk_out
);

// ====================== 核心参数配置 ======================
// 系统时钟40MHz，周期25ns
// 延迟时间 = delay_cnt × 25ns
localparam DATA_WIDTH = 12;       // ADC数据位宽
localparam DEPTH      = 8192;     // RAM深度，最大延迟8191拍（204.775us）
localparam ADDR_WIDTH = 13;       // 地址位宽 2^13=8192
localparam STEP       = 10;       // 【快速步进核心】每次按键增加的延迟拍数（可自由修改：10/20/50）

// ====================== 时钟与复位 ======================
wire         clk_40m;
wire         pll_areset;
assign pll_areset = ~rst_n;

// 时钟输出分配（与原代码一致）
assign adc_clk_out = clk_40m;
assign dac_clk_out = clk_40m;

// ====================== 按键消抖 ======================
wire         key_trigger;
key_filter u_key_filter (
    .sys_clk    (clk_40m),
    .sys_rst_n  (rst_n),
    .key_in     (key_in),
    .key_flag   (key_trigger),
    .key_state  ()
);

// ====================== 信号两级同步（防亚稳态） ======================
reg          mode_sync1, mode_sync2;
reg signed [DATA_WIDTH-1:0] adc_sync1, adc_sync2;

// ====================== 双端口RAM（环形延迟缓冲区） ======================
reg  [DATA_WIDTH-1:0] ram [0:DEPTH-1];   // 双端口RAM，Quartus自动推断为BRAM
reg  [ADDR_WIDTH-1:0] wr_addr;           // 写地址指针
reg  [ADDR_WIDTH-1:0] rd_addr;           // 读地址指针
reg  [ADDR_WIDTH-1:0] delay_cnt;         // 可控延迟值
reg signed [DATA_WIDTH-1:0] delay_data;  // 延迟输出数据

// ====================== PLL实例 ======================
pll pll_inst (
	.areset ( pll_areset ),
	.inclk0 ( clk_50m ),
	.c0     ( clk_40m )
);

// ====================== 同步逻辑 ======================
always @(posedge clk_40m or negedge rst_n) begin
    if(!rst_n) begin
        mode_sync1 <= 1'b0;
        mode_sync2 <= 1'b0;
        adc_sync1  <= 'd0;
        adc_sync2  <= 'd0;
    end else begin
        mode_sync1 <= mode;
        mode_sync2 <= mode_sync1;
        adc_sync1  <= adc_data;
        adc_sync2  <= adc_sync1;
    end
end

// ====================== RAM写指针 + 数据写入 ======================
// 写指针持续自增，循环写入最新ADC数据
always @(posedge clk_40m or negedge rst_n) begin
    if(!rst_n) begin
        wr_addr <= 'd0;
    end else begin
        wr_addr <= wr_addr + 1'b1;
        ram[wr_addr] <= adc_sync2;  // 同步后的数据写入RAM
    end
end

// ====================== 仅延迟增加 + 快速步进 ======================
// 废弃mode引脚，无论mode是什么，按键仅触发：延迟快速增加
always @(posedge clk_40m or negedge rst_n) begin
    if(!rst_n) begin
        delay_cnt <= 'd0;  // 默认0延迟
    end else if(key_trigger) begin
        // 核心：每次按键增加 STEP 拍延迟，达到最大值后保持不变
        if(delay_cnt < DEPTH - STEP) begin
            delay_cnt <= delay_cnt + STEP;
        end else begin
            delay_cnt <= DEPTH - 1;  // 锁死在最大延迟
        end
    end
end

// ====================== RAM读指针（核心延迟逻辑） ======================
// 读地址 = 写地址 - 延迟值 → 实现精准可控延迟
always @(*) begin
    rd_addr = wr_addr - delay_cnt;
end

// 读取延迟后的数据
always @(posedge clk_40m) begin
    delay_data <= ram[rd_addr];
end

// ====================== 12位有符号 → 8位无符号 DAC数据转换 ======================
reg [7:0] dac_data_out_reg;
always @(posedge clk_40m or negedge rst_n) begin
    if(!rst_n) begin
        dac_data_out_reg <= 8'd0;
    end else begin
        dac_data_out_reg <= delay_data  >> 4;
    end
end

// ====================== 输出 ======================
assign dac_data_out = dac_data_out_reg;

endmodule
