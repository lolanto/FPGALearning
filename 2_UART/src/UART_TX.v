`ifndef UART_TX_V
`define UART_TX_V

`include "UART_Common.v"
`include "Device_Common.v"

/**
 * @brief 负责发送的UART器件
 * @param in_clk 时钟信号
 * @param in_rst 复位信号，高电平有效
 * @param out_tx UART输出总线
 * @param in_send_enable 使能发送
 * @param in_send_byte 要发送的字节
 * @param out_send_finished 字节发送完成信号
 * @note 
 * 时钟上升沿检查in_send_enable，高电平时同时读取in_send_byte信号，并开始发送该字节
 * out_send_finished在发送完成后的时钟上升沿置为高电平，并在下一个时钟上升沿置为低电平
 * in_send_enable信号不应该一直处于高电平，否则会导致重复发送
 *
 * 时序：
 *
 * 目前是在时钟上升沿检查到in_send_enable为高电平时，该时钟上升沿会初始化UART_TX状态(准备进入sending状态，缓存待发送数据)
 * 同时，UART发送器件会立即进入发送状态，开始发送第一个bit(拉低总线)
 * 时钟每经过COUNT个周期，会改变一次发送的bit状态，到最后一个bit经过了COUNT个周期后，out_send_byte信号会被拉高，并在下一个上升沿来到时被拉低
 * 外部器件通过监听这个信号以判断发送是否完成
 */

module UART_TX(
    input wire in_clk,
    input wire in_rst,
    output wire out_tx,
    // send
    input wire in_send_enable,
    input wire [7:0] in_send_byte,
    output wire out_send_finished,
    output wire out_is_sending
);
    localparam COUNT = `BOARD_FREQ / `BUARD_RATE - 1; ///< 分频计数值
    reg [9:0] _r_send_byte; ///< 10个bit是因为UART一帧就带有10个bit，带上开始的0和结束的1，能够让整个发送逻辑更加统一，不用区分发送内容和标记位
    reg [7:0] _r_counter; ///< 分频计数器
    reg [3:0] _r_send_byte_index; ///< 当前正在发送的字节位下标，将开始和结束的标记位也算上
    reg _r_is_sending; ///< 当前是否处在发送状态当中
    reg _r_out_send_finished; ///< 只有在发送完成的时候，才会拉高作为一个信号，在下一个时钟上升沿到来时会被重新拉低

    assign out_tx = _r_is_sending ? _r_send_byte[_r_send_byte_index] : 1'b1;
    assign out_send_finished = _r_out_send_finished;
    assign out_is_sending = _r_is_sending;

// 确认状态
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_is_sending <= 1'b0;
            _r_send_byte <= 10'd0;
            _r_out_send_finished <= 1'b0;
        end
        else begin
            _r_out_send_finished <= 1'b0;
            if (in_send_enable == 1'b1) begin
                _r_is_sending <= 1'b1;
                _r_send_byte <= {1'b1, in_send_byte, 1'b0};
            end
            // 最后一个bit发送的时候，会提前3个tick完成。
            // 之所以提前完成，是为了实现上层器件对连续发送的支持
            // 之所以是提前3个tick，是可以让上层器件能够提前开始准备下一次要发送的数据。3是经验估算的值
            else if (_r_send_byte_index == 4'd9 && _r_counter == COUNT - 3) begin
                _r_is_sending <= 1'b0;
                _r_out_send_finished <= 1'b1;
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
                _r_counter <= _r_counter + 8'd1;
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
            if (_r_is_sending) begin
                if (_r_counter == COUNT) begin
                    if (_r_send_byte_index == 4'd9) begin
                        _r_send_byte_index <= 4'd0;
                    end
                    else begin
                        _r_send_byte_index <= _r_send_byte_index + 4'd1;
                    end
                end
                else begin
                    _r_send_byte_index <= _r_send_byte_index;
                end
            end
            else begin
                _r_send_byte_index <= 4'd0;
            end
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module UART_TX_TB(
    input wire in_clk,
    input wire in_rst
);
    
    reg [7:0] _r_send_byte;
    reg _r_send_enable;
    wire _w_send_finished;

    initial begin
        _r_send_enable = 1'b0;
        _r_send_byte = 8'h00;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_send_byte <= 8'b1010_0101;
            _r_send_enable <= 1'b1;
        end
        else begin
            if (_w_send_finished) begin
                _r_send_byte <= _r_send_byte + 8'd1;
                _r_send_enable <= 1'b1;
            end
            else begin
                _r_send_enable <= 1'b0;
            end
        end
    end

    UART_TX _inst(.in_clk(in_clk), .in_rst(in_rst), 
        .in_send_byte(_r_send_byte),
        .in_send_enable(_r_send_enable),
        .out_send_finished(_w_send_finished));

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< UART_TX_V
