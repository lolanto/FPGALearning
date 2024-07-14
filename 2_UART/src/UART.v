`define BUARD_RATE 115200 /// 目标波特率

module UART_TX(
    input wire in_clk,
    input wire in_rst,
    output wire out_tx,
    // send
    input wire in_send_enable,
    input wire in_send_byte[7:0],
    output wire out_send_finished
)
    localparam COUNT = BOARD_FREQ / BUARD_RATE; ///< 分频计数值
    reg [9:0] _r_send_byte; ///< 10个bit是因为UART一帧就带有10个bit，带上开始的0和结束的1，能够让整个发送逻辑更加统一，不用区分发送内容和标记位
    reg [7:0] _r_counter;
    reg [3:0] _r_send_byte_index;
    reg _r_is_sending;
    reg _r_out_send_finished; ///< 只有在发送完成的时候，才会拉高作为一个信号，在下一个时钟上升沿到来时会被重新拉低

    assign out_tx = _r_is_sending ? _r_send_byte[_r_send_byte_index] : 1'd1;
    assign out_send_finished = _r_out_send_finished;

// 确认状态
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_is_sending <= 1'd0;
            _r_send_byte <= 10'd0;
            _r_out_send_finished <= 1'd0;
        end
        else begin
            _r_out_send_finished <= 1'd0;
            if (in_send_enable == 1'b1) begin
                _r_is_sending <= 1'b1;
                _r_send_byte <= {1'b0, in_send_byte, 1'b1};
            end
            else if (_r_send_byte_index == 4'd10 && _r_counter == COUNT) begin
                _r_is_sending <= 1'b0;
                _r_out_send_finished <= 1'd1;
            end
        end
    end

// 分频
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= 8'd0;
        end
        else begin
            if (_r_is_sending) begin
                _r_counter <= _r_counter + 1;
                if (_r_counter == COUNT) begin
                    _r_counter <= 8'd0;
                end
            end
            else begin
                _r_counter <= 8'd0;
            end
        end
    end

// 更新发送索引
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_send_byte_index <= 4'd0;
        end
        else begin
            if (_r_is_sending && _r_counter == COUNT) begin
                _r_send_byte_index <= _r_send_byte_index + 4'd1;
            end
            else begin
                _r_send_byte_index <= _r_send_byte_index;
            end
        end
    end

endmodule

/**
 * @brief UART外设，波特率是固定的115200，全双工，同时支持读取和写入
 * @param in_clk 时钟信号
 * @param in_rst 复位信号，高电平有效
 * @param out_tx 输出信号线
 * @param in_rx 输入信号线
 * @param in_send_enable 拉高表明要请求发送
 * @param in_send_byte 要发送的字节
 * @param out_sent_finished 模块字节发送完毕
 * @param in_receive_enable 拉高表明要接收数据
 * @param out_received_byte 接收到的字节
 * @param out_received_finished 模块接收字节完毕
 * @note
 * 时序说明：
 * 1. 第一次检查到in_send_enable高电平的时钟上升沿会从in_send_byte中读取要发送的数据。之后外部可以修改in_send_byte的数据，
 * 外部应该在下一个时钟上升沿拉低in_send_enable，避免重复发送
 * 2. 第一次检查到in_receive_enable高电平的时钟上升沿，开始接收串口的输入信号，
 * 外部应该主动在下一个时钟上升沿拉低in_receive_enable，避免重复接收
 * 3. out_send_finished被置为高电平的同时保证UART的一帧发送完毕，并在下一个时钟上升沿自动变回低电平
 * 4. out_received_finished 从 0->1 表示接收完成，上层应该在下一个时钟上升沿将received_byte的数据存储下来
 */
module UART(
    input wire in_clk,
    input wire in_rst,
    output wire out_tx,
    input wire in_rx,
    // send
    input wire in_send_enable,
    input wire in_send_byte[7:0],
    output wire out_send_finished,
    // received
    input wire in_receive_enable,
    output wire out_received_byte[7:0],
    output wire out_receive_finished
)

/// 时序！时序！时序！



endmodule
