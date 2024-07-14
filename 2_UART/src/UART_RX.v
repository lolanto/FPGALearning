`ifndef UART_RX_V
`define UART_RX_V

`include "UART_Common.v"
`include "Device_Common.v"

/**
 * @brief UART的接收器件，不需要使能这个器件，它会一直进行监听，并在接收到一个byte之后产生一个信号来通知上层
 * @param in_clk 时钟信号
 * @param in_rst 复位信号，高电平有效
 * @param in_rx UART接收端输入总线
 * @param out_receive_finish 发起接收完成的信号
 * @param out_received_byte 读取接收到的字节
 * @note
 * 外设可以在任何时候从out_received_byte读取UART最近一次接收到的字节信号
 * 每次out_receive_finish信号被拉高的同时，out_received_byte一定会被刷新成刚接收到的字节
 *
 * 时序
 * 
 * 在接收一个字节信号还剩下半个接收周期的时候，会将out_receive_finish电平拉高，在下一个时钟上升沿拉低
 * 在检测到out_receive_finish被拉高的时钟上升沿，同时也能够从out_receive_byte中获得最新接收到的字节数据
 *
 * 可以在任意时钟上升沿访问out_received_byte，它必定是已经就绪的字节
 */

module UART_RX(
    input wire in_clk,
    input wire in_rst,
    input wire in_rx,
    // received
    output wire out_receive_finish,
    output wire [7:0] out_received_byte,
    output wire out_debug
);

    localparam COUNT = `BOARD_FREQ / `BUARD_RATE - 1;
    localparam HALF_COUNT = COUNT / 2; ///< 一旦在一个COUNT的Tick数量内，低电平/高电平超过了HALF_COUNT，那么就认为这个COUNT周期内的信号是对应的电平

    reg [3:0] _r_received_byte_index;
    reg [9:0] _r_current_receiving_byte;
    reg [7:0] _r_previous_received_byte;
    reg [7:0] _r_counter;
    reg [7:0] _r_receving_sig; ///< 当前接收到的信号的计数器，假如是高电平则+1，否则为+0

    // 处理采集信号，包括监听开始信号，中间位以及结束位
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_received_byte_index <= 4'd0;
            _r_receving_sig <= 8'd0;
            _r_counter <= 8'd0;
            _r_current_receiving_byte <= 10'd0;
        end
        else begin
            // 正在接收第一个bit(起始位)
            if (_r_received_byte_index == 4'd0) begin
                // 接收到一个低电平信号，开始进行信号采集
                if (_r_counter == 8'd0 && ~in_rx) begin
                    _r_counter <= 8'd1;
                    _r_receving_sig <= in_rx;
                end
                // 信号采集周期结束，分析采集的结果
                else if (_r_counter == COUNT) begin
                    // 还原采集周期状态，为下一个采集周期做准备
                    _r_counter <= 8'd0;
                    _r_receving_sig <= in_rx;
                    _r_current_receiving_byte[_r_received_byte_index] <= _r_receving_sig > HALF_COUNT ? 1'b1 : 1'b0;
                    // 假如当前信号采集周期内，采集到低电平信号，则认为已经开始传输
                    // 将字节位存储索引+1
                    if (_r_receving_sig < HALF_COUNT) begin
                        _r_received_byte_index <= _r_received_byte_index + 4'd1;
                    end
                end
                // 正在采集信号
                else if (_r_counter != 8'd0) begin
                    _r_receving_sig <= _r_receving_sig + in_rx;
                    _r_counter <= _r_counter + 8'd1;
                end
                else begin
                    _r_receving_sig <= in_rx;
                    _r_counter <= _r_counter;
                end
            end
            // 正在接收传输
            else begin
                _r_receving_sig <= _r_receving_sig + in_rx;
                _r_counter <= _r_counter + 8'd1;
                // 采集周期刚开始，进行初始化
                if (_r_counter == 8'd0) begin
                    _r_counter <= 8'd1;
                    _r_receving_sig <= in_rx;
                end
                // 正在采集结束位
                else if (_r_received_byte_index == 4'd9) begin
                    // 提前将结束位的采集计数器在技术周期过半的时候直接拉满，即结束位的采集周期只有正常周期的一半
                    // 提前半个周期结束采集是因为：
                    // 结束位是固定的高电平，且对接收的字节不会有任何贡献
                    // 提前结束可以给上层器件预留充足的时间读取和处理已经读取的数据，方便实现连续读取
                    if (_r_counter == HALF_COUNT) begin
                        _r_counter <= COUNT;
                    end
                    else if (_r_counter == COUNT) begin
                        _r_received_byte_index <= 4'd0;
                    end
                end
                // 非结束位的采集周期结束
                else if (_r_counter == COUNT) begin
                    _r_counter <= 8'd0;
                    _r_receving_sig <= in_rx;
                    _r_received_byte_index <= _r_received_byte_index + 4'd1;
                    _r_current_receiving_byte[_r_received_byte_index] <= _r_receving_sig > HALF_COUNT ? 1'b1 : 1'b0;
                end
            end
        end
    end

    reg _r_out_receive_finish;

    assign out_receive_finish = _r_out_receive_finish;
    assign out_received_byte = _r_previous_received_byte;

    // 发送接收情况，更新接收字节信息
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_out_receive_finish <= 1'b0;
            _r_previous_received_byte <= 8'd0;
        end
        else begin
            _r_out_receive_finish <= 1'b0;
            if (_r_received_byte_index == 9 && _r_counter == COUNT) begin
                _r_out_receive_finish <= 1'b1;
                _r_previous_received_byte <= _r_current_receiving_byte[8:1]; // 开头和结尾的bit都是标志位非字节内容，因此去掉
            end
        end
    end

    assign out_debug = _r_received_byte_index != 4'd0;

endmodule

`ifdef DEBUG_TEST_BENCH

module UART_RX_TB(
    input wire in_clk,
    input wire in_rst
);
    localparam COUNT = `BOARD_FREQ / `BUARD_RATE - 1;
    localparam HALF_COUNT = COUNT / 2; ///< 一旦在一个COUNT的Tick数量内，低电平/高电平超过了HALF_COUNT，那么就认为这个COUNT周期内的信号是对应的电平
    localparam INITIAL_COUNT = COUNT - HALF_COUNT - 10;
    reg [9:0] _r_send_byte;
    reg [7:0] _r_counter;
    reg [3:0] _r_send_byte_index;
    reg _r_rx;
    initial begin
        _r_rx <= 1'b1;
        _r_counter <= 8'd0;
        _r_send_byte <= 10'b10011_00010;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= INITIAL_COUNT;
            _r_send_byte <= 10'b10011_00010;
        end
        else begin
            _r_counter <= _r_counter + 8'd1;
            if (_r_counter == COUNT) begin
                _r_counter <= 8'd0;
            end
        end
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_rx <= 1'b1;
            _r_send_byte_index <= 4'd0;
        end
        else begin
            if (_r_counter == COUNT) begin
                _r_rx <= _r_send_byte[_r_send_byte_index];
                _r_send_byte_index <= _r_send_byte_index + 4'd1;
                if (_r_send_byte_index == 9) begin
                    _r_send_byte_index <= 4'd9;
                end
            end
        end
    end

    UART_RX _inst(.in_clk(in_clk), .in_rst(in_rst), .in_rx(_r_rx));

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< UART_RX_V
