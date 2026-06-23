`timescale  1ns/1ns

module topde (
    input                   clk_50m,
    input                   rst_n,
    input                   key_in,
    input                   mode,       // ???????????????
    input  signed [11:0]    adc_data,
    output                  adc_clk_out,
    output        [7:0]     dac_data_out,
    output                  dac_clk_out
);

localparam DATA_WIDTH = 12;       // ADC ????

// ?????
wire         clk_40m;
wire         pll_areset = ~rst_n;
assign adc_clk_out = clk_40m;
assign dac_clk_out = clk_40m;

// ADC ??? DAC ????
wire signed [DATA_WIDTH-1:0] adc_sampled;
wire [13:0] dac_data_14bit;

pll pll_inst (
    .areset ( pll_areset ),
    .inclk0 ( clk_50m ),
    .c0     ( clk_40m )
);

adc_driver #(
    .ADC_WIDTH(DATA_WIDTH)
) u_adc_driver (
    .clk_sample(clk_40m),
    .rst_n(rst_n),
    .adc_data(adc_data),
    .adc_out(adc_sampled)
);

dac_driver u_dac_driver (
    .clk(clk_40m),
    .rst_n(rst_n),
    .dac_data_in(adc_sampled),
    .dac_data_out(dac_data_14bit)
);

assign dac_data_out = dac_data_14bit[13:6];  // 14??????8?????

endmodule
