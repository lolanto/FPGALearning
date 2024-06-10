`define DEBUG_TEST_BENCH
`include "SyncFIFO.v"
`include "IIC.v"
`include "EncapsulatedIO.v"
`include "top.v"

module TB();
    reg clk;
    reg rst;

    SyncFIFO_TB _inst_SyncFIFO_TB(.in_clk(clk), .in_rst(rst));
    EdgeDetection_TB _inst_EdgeDetection_TB(.in_clk(clk), .in_rst(rst));
    IIC_SEND_TB _inst_IIC_Send_TB(.in_clk(clk), .in_rst(rst));
    EncapsulatedIIC_SEND_TB _inst_EIIC_SSend_TB(.in_clk(clk), .in_rst(rst));
    TOP_TB _inst_TOP_TB(.in_clk(clk), .in_rst(rst));

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
