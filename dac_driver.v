// 14位无符号DAC驱动模块
// 功能：12位有符号 → 偏移二进制 → 左移2位放大 → 14位无符号满量程输出
// 时钟同步 | 低电平复位 | 满量程无失真转换
module dac_driver(
    input                    clk,            // 系统时钟
    input                    rst_n,          // 低电平复位
    input  signed  [11:0]    dac_data_in,    // 输入：12位有符号补码
    output reg        [13:0] dac_data_out    // 输出：14位无符号（满量程）
);

// 同步寄存器
reg signed [11:0] data_reg;

// 时序逻辑
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_reg    <= 12'sd0;
        dac_data_out <= 14'd0;
    end else begin
        // 第一级打拍
        data_reg <= dac_data_in;
        
        // 核心修正：偏移 + 左移2位（满量程14位输出）
        // 12位有符号 → 加偏移 → 12位无符号 → 左移2位 → 14位满量程
        dac_data_out <= (data_reg + 12'd2048) << 2; 
    end
end

endmodule
