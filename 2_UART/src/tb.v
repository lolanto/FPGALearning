`define DEBUG_TEST_BENCH
`include "UART_TX.v"
`include "UART_RX.v"
`include "top.v"

module TB();
    reg clk;
    reg rst;

    UART_TX_TB _inst_UART_TX_TB(.in_clk(clk), .in_rst(rst));
    UART_RX_TB _inst_UART_RX_TB(.in_clk(clk), .in_rst(rst));
    Top_TB _inst_TOP_TB(.in_clk(clk), .in_rst(rst));

    always #1 clk<=~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, TB);
        clk = 0;
        rst = 1;
        forever begin
            #1; // 必须添加，否则这个forever块会在每次仿真中都执行，导致vvp无法结束
            if ($time >= 98000) begin
            $finish;
            end
            if ($time >= 2)
                rst = 0;
        end
    end
endmodule
