`ifndef EDGE_DETECTION_V
`define EDGE_DETECTION_V

/**
 * @breif 边沿检测模块
 * @param Direction 边沿检测方向：0：上升沿；1：下降沿：2：双边沿
 *
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_sig 检测的输入信号
 * @return out_detected 是否检测到边沿变化
 * @note:
 * 该模块假设in_sig的信号是由外部的一个寄存器提供的输入(时序逻辑)
 * 比方说，外部寄存器A，它最初是0，在x时刻上升沿被赋予1，
 * 此时对于in_sig而言，在x上升沿过后它就是1。但是对于_r_last_state而言，由于x上升沿时A的输出依旧是0，因此_r_last_state还是0
 * 此时组合逻辑_r_out_detected就能够检测到上升沿变化！
 * 并且在外部逻辑的(x+1)时钟上升沿，从out_detected依旧能够读取到1(发生了上升沿变化)
 * 
 * 假如in_sig的信号是一个组合逻辑提供。假设最初是0，它在x的上升沿赋予1
 * 那么x上升沿过后，_r_last_state以及in_sig都将同时为1，_r_out_dtected将无法检查到上升沿变化！
 *
 * 建议的命名方式：EdgeDetection _inst_ed_xxx; xxx是待监听的信号
 */
module EdgeDetection #(
    parameter Direction = 0
)(
    input wire in_clk,
    input wire in_rst,
    input wire in_sig,
    output wire out_detected
);

    reg _r_last_state;
    reg _r_out_detected;

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_last_state <= 1'b0;
        end
        else begin
            _r_last_state <= in_sig;
        end
    end

    always @(*) begin
        case (Direction)
        0: _r_out_detected <= ~_r_last_state && in_sig;
        1: _r_out_detected <= _r_last_state && ~in_sig;
        2: _r_out_detected <= (~_r_last_state && in_sig) || (_r_last_state && ~in_sig);
        endcase
    end

    assign out_detected = _r_out_detected;

endmodule

`ifdef DEBUG_TEST_BENCH
module EdgeDetection_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_sig;
    EdgeDetection _inst_ed_1(.in_clk(in_clk), .in_rst(in_rst), .in_sig(_r_sig));

    reg [3:0] _r_counter;

    initial begin
        _r_sig = 0;
        _r_counter = 0;
    end

    always @(posedge in_clk) begin
        _r_counter <= _r_counter + 1;
        if (_r_counter == 2) begin
            _r_counter <= 4'd0;
            _r_sig <= ~_r_sig;
        end
        else begin
            _r_sig <= _r_sig;
        end
    end

endmodule
`endif ///< DEBUG_TEST_BENCH

`endif ///< EDGE_DETECTION_V