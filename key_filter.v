`timescale  1ns/1ns
module  key_filter
#(
    parameter CNT_MAX    = 20'd800_000,  // 核心修改：40MHz时钟 20ms消抖计数 40e6*0.02=800000
    parameter KEY_ACTIVE = 1'b0          // 按键有效电平配置：0=低电平有效，1=高电平有效
)
(
    input   wire    sys_clk     ,   // 系统时钟：40MHz  （注释同步修改）
    input   wire    sys_rst_n   ,   // 全局复位：低电平有效
    input   wire    key_in      ,   // 按键输入信号（异步）
    output  reg     key_flag    ,   // 按键状态变化单脉冲标志（仅1个时钟周期有效）
    output  reg     key_state       // 按键稳定状态：1=按下，0=释放（持续有效）
);

// ---------------------- 内部信号定义 ----------------------
reg     [19:0]  cnt_20ms    ;   // 20ms消抖计数器（20位宽，最大值1,048,575，覆盖800000）
reg             key_in_dly   ;   // 按键输入打拍寄存器（同步+消除亚稳态）

// ---------------------- 步骤1：按键输入同步打拍（消除亚稳态） ----------------------
// 核心作用：异步按键信号跨时钟域时，通过打拍稳定信号，避免亚稳态导致误采样
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        // 复位后默认未按下（与有效电平相反，避免初始误判）
        key_in_dly <= ~KEY_ACTIVE;
    else
        // 同步采样按键输入，消除亚稳态
        key_in_dly <= key_in;
end

// ---------------------- 步骤2：20ms消抖计数器（核心消抖逻辑） ----------------------
// 计数逻辑：仅在按键状态未稳定时计数，稳定后保持计数值，状态变化时清零
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cnt_20ms <= 20'b0;
    // 场景1：按键未按下（输入≠有效电平）且当前状态为释放→计数器清零
    else if(key_in_dly != KEY_ACTIVE && key_state == 1'b0)
        cnt_20ms <= 20'b0;
    // 场景2：按键按下（输入=有效电平）且计数未到20ms→计数器自增（按下消抖）
    else if(key_in_dly == KEY_ACTIVE && cnt_20ms < CNT_MAX)
        cnt_20ms <= cnt_20ms + 1'b1;
    // 场景3：按键释放（输入≠有效电平）且当前状态为按下、计数未到20ms→计数器自增（释放消抖）
    else if(key_in_dly != KEY_ACTIVE && key_state == 1'b1 && cnt_20ms < CNT_MAX)
        cnt_20ms <= cnt_20ms + 1'b1;
    // 场景4：计数满20ms→保持计数值（等待状态切换）
    else
        cnt_20ms <= cnt_20ms;
end

// ---------------------- 步骤3：按键状态更新 + 单脉冲标志生成 ----------------------
// key_flag：按下/释放瞬间1拍有效（用于触发单次动作）
// key_state：持续的稳定状态（用于指示按键当前状态）
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        key_flag  <= 1'b0;  // 复位后无动作标志
        key_state <= 1'b0;  // 复位后默认释放状态
    end else begin
        // 条件1：计数满20ms + 输入为有效电平 + 当前释放→按键按下
        if(cnt_20ms == CNT_MAX && key_in_dly == KEY_ACTIVE && key_state == 1'b0) begin
            key_flag  <= 1'b1;       // 置位按下单脉冲
            key_state <= 1'b1;       // 更新为按下状态
        end
        // 条件2：计数满20ms + 输入非有效电平 + 当前按下→按键释放
        else if(cnt_20ms == CNT_MAX && key_in_dly != KEY_ACTIVE && key_state == 1'b1) begin
            key_flag  <= 1'b1;       // 置位释放单脉冲
            key_state <= 1'b0;       // 更新为释放状态
        end
        // 条件3：非20ms满值时刻→单脉冲清零，状态保持
        else begin
            key_flag  <= 1'b0;
            key_state <= key_state;
        end
    end
end

endmodule
