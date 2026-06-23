// 12位有符号并行ADC采集驱动
// 功能：异步ADC数据同步锁存，消除亚稳态，输出稳定的采样数据
module adc_driver#(
    parameter ADC_WIDTH = 12  // 参数化ADC位宽，方便复用修改
)(
    input                    clk_sample,      // ADC采样时钟（驱动时钟）
    input                    rst_n,           // 低电平有效复位
    input  signed [ADC_WIDTH-1:0] adc_data,   // 12位有符号ADC并行输入
    output reg signed [ADC_WIDTH-1:0] adc_out // 同步后稳定输出
);

// 内部同步寄存器（两级同步，消除亚稳态，FPGA标准处理方式）
reg signed [ADC_WIDTH-1:0] adc_data_sync;

// -------------------------- 两级同步采样逻辑 --------------------------
// 第一级：异步数据打拍，第二级：输出稳定数据
always@(posedge clk_sample or negedge rst_n) begin
    if(!rst_n) begin
        adc_data_sync <= 12'sd0;  // 同步寄存器复位
        adc_out       <= 12'sd0;  // 输出复位
    end else begin
        adc_data_sync <= adc_data;    // 第一级锁存：接收原始ADC数据
        adc_out       <= adc_data_sync;// 第二级锁存：输出稳定数据（无亚稳态）
    end
end

endmodule
