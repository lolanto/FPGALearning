`define DEBUG_TEST_BENCH
`include "SinglePortRam.v"
`include "IICProxy.v"
`include "topForIICProxy.v"
`include "top.v"

module TB();
    reg clk;
    reg rst;

    IICPROXY_READ_WRITE_TB _inst_iicproxy_read_tb(.in_clk(clk), .in_rst(rst));
    TopForIICProxy_TB _inst_top_for_iicproxy_tb(.in_clk(clk), .in_rst(rst));
    Top_TB _inst_top_tb(.in_clk(clk), .in_rst(rst));

    always #1 clk<=~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, TB);
        clk = 0;
        rst = 1;
        forever begin
            #1; // 必须添加，否则这个forever块会在每次仿真中都执行，导致vvp无法结束
            if ($time >= 200000) begin
            $finish;
            end
            if ($time >= 2)
                rst = 0;
        end
    end
endmodule
