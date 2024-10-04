`ifndef TOP_V
`define TOP_V
`include "topForIICProxy.v"
`include "Debouncer.v"

module Top(
    input wire in_clk,
    input wire in_btn_s1,
    input wire in_btn_s2,
    inout wire inout_sda,
    inout wire inout_scl,
    output wire out_debug_1,
    output wire out_debug_2,
    output wire out_debug_3
`ifdef DEBUG_TEST_BENCH
    , input wire d_in_sda
    , input wire d_in_scl
    , input wire d_in_rst
`endif ///< DEBUG_TEST_BENCH
);

    wire _w_start;
`ifdef DEBUG_TEST_BENCH
    assign _w_start = in_btn_s1;
`else
    Debouncer _inst_debouncer_s1(.in_clk(in_clk)
        , .in_sig(in_btn_s1)
        , .out_sig_up(_w_start));
`endif ///< DEBUG_TEST_BENCH

`ifdef DEBUG_TEST_BENCH
    wire _w_rst = d_in_rst;
`else
    wire _w_rst = in_btn_s2;
`endif ///< DEBUG_TEST_BENCH
    
    wire _w_sda_is_using;
    wire _w_out_sda;
    assign inout_sda = _w_sda_is_using ? _w_out_sda : 1'bz;
    wire _w_scl_is_using;
    wire _w_out_scl;
    assign inout_scl = _w_scl_is_using ? _w_out_scl : 1'bz;

    TopForIICProxy _inst_top_for_iic_proxy(.in_clk(in_clk), .in_rst(_w_rst)
        , .in_start(_w_start)
    // >>> BEG: I2C相关参数
`ifdef DEBUG_TEST_BENCH
        , .in_sda(d_in_sda)
`else
        , .in_sda(inout_sda)
`endif ///< DEBUG_TEST_BENCH
        , .out_sda(_w_out_sda)
        , .out_sda_is_using(_w_sda_is_using)

`ifdef DEBUG_TEST_BENCH
        , .in_scl(d_in_scl)
`else
        , .in_scl(inout_scl)
`endif ///< DEBUG_TEST_BENCH
        , .out_scl(_w_out_scl)
        , .out_scl_is_using(_w_scl_is_using)
    // <<< END: I2C相关参数
        , .out_debug_1(out_debug_1)
        , .out_debug_2(out_debug_2));

    assign out_debug_3 = _w_out_sda;

endmodule

`ifdef DEBUG_TEST_BENCH

module Top_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_btn_s1;
    reg _r_btn_s2;
    reg _r_sda;

    Top _inst_top(.in_clk(in_clk)
        , .in_btn_s1(_r_btn_s1)
        , .in_btn_s2(_r_btn_s2)
        , .d_in_sda(_r_sda)
        , .d_in_rst(in_rst));
    
    initial begin
        _r_btn_s1 = 1'b0;
        _r_btn_s2 = 1'b0;
        _r_sda = 1'b0;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_btn_s1 <= 1'b1;
            _r_btn_s2 <= 1'b1;
        end
        else begin
            _r_sda <= 1'b1;
        end
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif
