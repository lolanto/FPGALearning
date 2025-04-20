`include "GlobalDefine.v"
`include "Counter.v"
`include "utils/Debouncer.v"

module Top(
    input wire in_clk,
    input wire in_btn,
    output wire out_led_1,
    output wire out_debug
);
    wire _w_rst;
    wire _w_out_sig;
    assign out_led_1 = _w_out_sig;
    assign out_debug = _w_out_sig;
`ifdef DEBUG_TEST_BENCH
    assign _w_rst = in_btn;
`else
    Debouncer _inst_deb_for_rst(.in_clk(in_clk), .in_sig(in_btn), .out_sig_up(_w_rst));
`endif // DEBUG_TEST_BENCH

`ifdef DEBUG_TEST_BENCH
    Counter #(16, 1) _inst_counter(.in_clk(in_clk), .in_rst(_w_rst), .out_sig(_w_out_sig));
`else
    Counter #(`ENV_BASIC_FREQ, 1) _inst_counter(.in_clk(in_clk), .in_rst(_w_rst), .out_sig(_w_out_sig));
`endif // DEBUG_TEST_BENCH
    

endmodule
