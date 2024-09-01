`ifndef SINGLE_PORT_RAM_V
`define SINGLE_PORT_RAM_V

/**
 * @brief 单输入口的Distribute RAM模块，用来作为简单的，临时存储FPGA数据的模块
 *
 * @param in_clk 时钟信号
 * @param in_rst 复位信号
 * @param in_addr 访问地址，地址宽度与RAM模块的深度有关
 * @param in_write_enable 写入使能，高电平时，会向in_addr指定的地址写入in_write_data的数据
 * @param in_write_data 需要写入的数据，in_write_enable高电平时有效
 * @return out_data 输出in_addr对应的数据
 *
 * @note:
 * 写入数据：时钟上升沿，若in_write_enable处于高电平，则会将in_write_data的数据写入到in_addr指定的地址位置
 * 写入的数据在下一个时钟上升沿时可读取。因此建议in_write_enable，in_write_data和in_addr在同一个时钟上升沿一起设置
 * in_write_enable信号不能一直维持高电平!写完后应立即置回低电平状态
 *
 * 读取数据：时钟上升沿，out_data将是in_addr地址所代表的数据。外部于时钟上升沿设置的in_addr，将会在下一个时钟上升沿读取到对应的数据
 */
module SinglePortRAM #(parameter DEPTH=8) (
    input wire in_clk,
    input wire in_rst,
    input wire [DEPTH - 1:0] in_addr,
    input wire in_write_enable,
    input wire [7:0] in_write_data,
    output wire [7:0] out_data
);
    integer  i = 0;
    reg [7:0] _r_data [2 ** DEPTH - 1 : 0];
    reg [7:0] _r_out_data;

    assign out_data = _r_data[in_addr];

    always @(posedge in_clk) begin
        if (in_rst) begin
            for (i = 0; i < 2 ** DEPTH; i=i+1) begin
                _r_data[i] <= 8'd0;
            end
        end
        else begin
            if (in_write_enable) begin
                _r_data[in_addr] <= in_write_data;
            end
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module TB_SinglePortRAM(
    input wire in_clk,
    input wire in_rst
);
    // 往前10个地址连续写入数据，之后再重新读取出来
    `define RAM_DEPTH 8

    reg [`RAM_DEPTH - 1:0] _r_addr;
    reg [7:0] _r_write_data;
    reg _r_write_enable;

    wire [7:0] _w_read_data;

    reg [4:0] _r_process_count;

    initial begin
        _r_addr <= `RAM_DEPTH'd0;
        _r_write_data <= 8'd0;
        _r_write_enable <= 1'b0;
        _r_process_count <= 5'd0;
    end

    SinglePortRAM #(.DEPTH(`RAM_DEPTH)) _inst_SPRAM(.in_clk(in_clk), .in_rst(in_rst)
        , .in_write_enable(_r_write_enable)
        , .in_addr(_r_addr)
        , .in_write_data(_r_write_data)
        , .out_data(_w_read_data));
    
    always @(posedge in_clk) begin
        // 让地址能够循环起来
        if (_r_process_count[4] && ~(|_r_process_count[3:0])) begin
            _r_addr <= 0;
        end
        else begin
            _r_addr <= _r_addr + 1;
        end
        _r_process_count <= _r_process_count + 1;
        if (~_r_process_count[4]) begin
            _r_write_enable <= 1'b1;
            _r_write_data <= _r_write_data + 1;
        end
        else begin
           _r_write_enable <= 1'b0; 
        end
    end

endmodule

`endif // DEBUG_TEST_BENCH

`endif // SINGLE_PORT_RAM_V