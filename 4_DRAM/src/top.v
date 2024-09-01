`ifndef TOP_V
`define TOP_V
`include "SinglePortRam.v"
`include "Debouncer.v"

// 1. 尝试外接更多的按钮
// 2. 通过这些按钮的状态来指定写入的地址以及写入的数据，位数可以少一点

module top(
    input wire in_clk,
    input wire btn_s1, // 复位键
    input wire btn_s2, // 地址更新键
    input wire btn_s3, // 额外按键，写入确认键
    input wire [3:0] in_addr,
    input wire [3:0] in_data,
    output wire [3:0] out_led
);
    wire _w_rst;
    wire _w_addr_update;
    wire _w_write_enable;
    wire [7:0] _w_out_data;
    assign out_led = ~_w_out_data[3:0]; // 设备的LED比较特殊，低电平才会亮

    reg [7:0] _r_addr;
    reg [7:0] _r_write_data;
    reg _r_write_enable;

`ifdef DEBUG_TEST_BENCH
    assign _w_rst = btn_s1;
    assign _w_addr_update = btn_s2;
    assign _w_write_enable = btn_s3;
`else
    Debouncer _inst_debouncer_1(.in_clk(in_clk), .in_sig(btn_s1), .out_sig_up(_w_rst));
    Debouncer _inst_debouncer_2(.in_clk(in_clk), .in_sig(btn_s2), .out_sig_up(_w_addr_update));
    Debouncer _inst_debouncer_3(.in_clk(in_clk), .in_sig(btn_s3), .out_sig_up(_w_write_enable));
`endif

    SinglePortRAM _inst_SPRAM(.in_clk(in_clk), .in_rst(_w_rst)
        , .in_addr(_r_addr)
        , .in_write_enable(_r_write_enable)
        , .in_write_data(_r_write_data)
        , .out_data(_w_out_data));

    always @(posedge in_clk) begin
        _r_write_enable <= 1'b0;
        if (_w_rst) begin
            _r_addr <= 8'd0;
            _r_write_data <= 8'd0;
        end
        else begin
            if (_w_addr_update) begin
                _r_addr <= { 4'd0, in_addr };
            end
            if (_w_write_enable) begin
                _r_write_data <= {4'd0, in_data};
                _r_write_enable <= 1'b1;
            end
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module TB_TOP(
    input wire in_clk,
    input wire in_rst
);

    reg _r_btn_s2;
    reg _r_btn_s3;

    reg [3:0] _r_addr;
    reg [3:0] _r_data;

    reg [31:0] _r_counter;

    top _inst_top(.in_clk(in_clk), .btn_s1(in_rst), .btn_s2(_r_btn_s2), .btn_s3(_r_btn_s3)
        , .in_addr(_r_addr), .in_data(_r_data));

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= 32'd0;
            _r_data <= 4'd0;
            _r_addr <= 4'd0;
            _r_btn_s2 <= 1'b0;
            _r_btn_s3 <= 1'b0;
        end
        else begin
            _r_btn_s2 <= 1'b0;
            _r_btn_s3 <= 1'b0;
            _r_counter <= _r_counter + 1;
            if (&_r_counter[3:0]) begin
                _r_addr <= _r_addr + 1;
                _r_btn_s2 <= 1'b1;
            end
            else if (_r_counter[4] && ~(|_r_counter[3:0])) begin
                _r_data <= _r_data + 1;
                _r_btn_s3 <= 1'b1;
            end
        end
    end

endmodule

`endif // DEBUG_TEST_BENCH

`endif // TOP_V
