`define DEBUG_TEST_BENCH
`include "Counter.v"
`include "top.v"

module TB();
    reg clk;
    reg rst;

    Counter #(16, 2) _inst_counter (.in_clk(clk), .in_rst(rst));
    Top _inst_top (.in_clk(clk), .in_btn(rst));

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
