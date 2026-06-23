// 12位有符号数180°移相模块（延迟半个周期实现）
// 系统时钟：40MHz | 目标信号：2MHz | 精准180°移相（无相位误差）
module phase_shift_180 (
    input                   clk,        // 40MHz 系统时钟
    input                   rst_n,      // 低电平复位
    input  signed [11:0]    din,        // 12位有符号输入（ADC采集数据）
    output signed [11:0]    dout        // 12位有符号移相输出
);

// 核心参数：40MHz时钟 + 2MHz信号 → 半周期 = 10个时钟周期
localparam HALF_PERIOD_CLK = 10;

// 深度为10的寄存器缓冲区（12位有符号类型）
reg signed [11:0] delay_buf [0:HALF_PERIOD_CLK-1];

// 时序逻辑：移位寄存器更新
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        // for循环批量复位，代码更简洁通用
        integer i;
        for(i=0; i<HALF_PERIOD_CLK; i=i+1) begin
            delay_buf[i] <= 12'sd0;
        end
    end else begin
        // 逐级移位延迟（10级移位寄存器）
        delay_buf[0] <= din;          
        delay_buf[1] <= delay_buf[0]; 
        delay_buf[2] <= delay_buf[1]; 
        delay_buf[3] <= delay_buf[2]; 
        delay_buf[4] <= delay_buf[3]; 
        delay_buf[5] <= delay_buf[4];
        delay_buf[6] <= delay_buf[5];
        delay_buf[7] <= delay_buf[6];
        delay_buf[8] <= delay_buf[7];
        delay_buf[9] <= delay_buf[8];
    end
end

// 输出延迟10个时钟的数据 → 精准180°移相
assign dout = delay_buf[HALF_PERIOD_CLK-1]; 

endmodule
