`ifndef IIC_V
`define IIC_V

`include "EdgeDetection.v"

/**
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_enable 设备使能，每次指令执行完成，都需要将设备disable再enable
 * @param in_byte_to_send 需要向外发送的字节，假如是首个带读写操作的指令，也需要填写对应的bit
 * @param in_instruction 当前要执行的I2C操作：开始传输/发送字节/结束传输
 * @return out_sda_out 外部sda总线的输出
 * @return out_scl 外部scl总线的输出
 * @return out_is_sending 当前设备是否正在发送(需要占用sda总线)
 * @return out_is_completed 当前指令是否执行完成
 * @note:
 * 使用方式：
 * 外部使能，然后设置指令；不断等待当前设备的completed标记置1
 * 要发起下一个指令，需要先将in_enable拉低再拉高
 * e.g.
 * 发送字节：
 * x时刻的时钟上升沿，拉高in_enable，同时设置in_byte_to_send
 * x+1时刻时钟上升沿，拉低in_enable，in_byte_to_send可以被释放，因为模块已经记录了当前要发送的信号了
 * 等待out_is_completed信号变高即发送完成
 *
 * 目前由于FSM的关系，外部使能后，到真正执行行为会有两个时钟周期的延迟(外部使能->state更新->执行新state逻辑)
 * 因此可以观察到scl总线的时钟，它的高电平，低电平，可能执行时钟周期数量会不一致
 */

`define IIC_INST_START_TX 0
`define IIC_INST_STOP_TX 1
`define IIC_INST_WRITE_BYTE 2
`define IIC_STATE_IDLE 4
`define IIC_STATE_SEND_ACK 6
`define IIC_STATE_RCV_ACK 7

module IIC(
    input wire in_clk,
    input wire in_rst,
    input wire in_enable,
    input wire [7:0] in_byte_to_send,
    input wire [1:0] in_instruction,
    input wire in_sda_in,
    output wire out_sda_out,
    output wire out_scl,
    output wire out_is_sending,
    output wire out_is_completed,
    output wire out_err_state
);

    /**
     * 这个寄存器应该是用来对时钟进行分频的!相当于I2C器件中，自己带一个时钟分频器
     * 进而控制I2C总线上的时钟信号
     */
    reg [6:0] _r_clock_Divider = 0;

    reg [2:0] _r_state = `IIC_STATE_IDLE;
    reg [2:0] _r_next_state;
    reg [3:0] _r_bit_index_to_send = 3'd7; // 当前要发送的bit的索引，注意，I2C是从高位开始发送的!
    
    reg _r_sda_out = 0; // 当前sda总线上要发送的bit
    assign out_sda_out = _r_sda_out;

    reg _r_is_sending = 0;
    assign out_is_sending = _r_is_sending;

    reg _r_scl;
    assign out_scl = _r_scl;

    reg _r_is_completed;
    assign out_is_completed = _r_is_completed;

    reg _r_recevied_ack; // 是否真的收到了ACK信号
    reg [3:0] _r_received_ack_counter; // 用来判断ACK信号的稳定性
    reg _r_err_state;
    assign out_err_state = _r_err_state;
    
    /**
     * 尝试在in_enable被拉高的时候，将待发送的数据进行缓存。目的是让外部逻辑不需要再维持发送期间对发送数据的稳定性
     * 这里假设in_enable以及in_byte_to_send都是外部的寄存器发送的数据。
     * 因此在in_enable在x的上升沿拉高为1，同时in_byte_to_send设置了值；在x+1时刻，_r_byte_to_send就会被设置为in_byte_to_send的值
     * 即发送的数据将是in_enable拉高为1时候，in_byte_to_send的值
     */
    reg [7:0] _r_byte_to_send;
    wire _w_enable_posedge_detected;
    EdgeDetection _inst_ed_in_enable(.in_clk(in_clk), .in_rst(in_rst), .in_sig(in_enable), .out_detected(_w_enable_posedge_detected));
    always @(posedge in_clk) begin
        if (in_rst)
            _r_byte_to_send <= 8'd0;
        else if (_w_enable_posedge_detected)
            _r_byte_to_send <= in_byte_to_send;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state <= `IIC_STATE_IDLE;
        end
        else begin
            _r_state <= _r_next_state;
        end
    end

    /// 组合逻辑以确定下一个状态是什么
    always @(*) begin
        case (_r_state)
        `IIC_STATE_IDLE: begin
            if (in_enable)
                _r_next_state = {1'b0, in_instruction};
            else
                _r_next_state = `IIC_STATE_IDLE;
        end
        `IIC_INST_START_TX: begin
            if (_r_clock_Divider[6:5] == 2'b11) ///< 其实相当于只有时钟在b11之前的3个阶段才有效
                _r_next_state = `IIC_STATE_IDLE;
            else
                _r_next_state = `IIC_INST_START_TX;
        end
        `IIC_INST_STOP_TX: begin
            if (_r_clock_Divider[6:5] == 2'b11)
                _r_next_state = `IIC_STATE_IDLE;
            else
                _r_next_state = `IIC_INST_STOP_TX;
        end
        `IIC_INST_WRITE_BYTE: begin
            if (_r_clock_Divider == 7'b111_1111 && _r_bit_index_to_send == 3'd0) ///< 当计时结束，同时当前发送的bit下标也是0时，说明这个bit已经发送完成
                _r_next_state = `IIC_STATE_RCV_ACK;
            else
                _r_next_state = `IIC_INST_WRITE_BYTE;
        end
        `IIC_STATE_RCV_ACK: begin
            if (_r_clock_Divider == 7'b111_1111)
                _r_next_state = `IIC_STATE_IDLE;
            else
                _r_next_state = `IIC_STATE_RCV_ACK;
        end
        default:
            _r_next_state = `IIC_STATE_IDLE;
        endcase
    end

    /// 将状态输出情况进一步提前，提前一个时钟周期
    always @(posedge in_clk) begin
        if (_r_state != `IIC_STATE_IDLE && _r_next_state == `IIC_STATE_IDLE) begin
            _r_is_completed <= 1'b1;
        end
        else begin
            _r_is_completed <= 1'b0;
        end
    end

    /// 决定输出内容，注意：I2C总线若是处于空闲状态，则scl和sda都会处在高电平状态
    always @(posedge in_clk) begin
        case (_r_state)
        `IIC_STATE_IDLE: begin
            if (in_rst) begin
                _r_scl <= 1;
                _r_sda_out <= 1;
                _r_err_state <= 0;
            end
            _r_is_sending <= 0;
            _r_clock_Divider <= 0;
            _r_bit_index_to_send <= 3'd7;
        end
        `IIC_INST_START_TX: begin
            _r_is_sending <= 1;
            _r_clock_Divider <= _r_clock_Divider + 7'd1;
            if (_r_clock_Divider[6:5] == 2'b00) begin /// 最初阶段，将scl和sda总线都拉高，其实是在还原初始状态
                _r_scl <= 1;
                _r_sda_out <= 1;
            end
            else if (_r_clock_Divider[6:5] == 2'b01) begin /// 第二阶段，将sda总线拉低
                _r_sda_out <= 0;
            end
            else if (_r_clock_Divider[6:5] == 2'b10) begin /// 第三阶段，将scl总线拉低
                _r_scl <= 0;
            end
        end
        `IIC_INST_STOP_TX: begin
            _r_is_sending <= 1;
            _r_clock_Divider <= _r_clock_Divider + 7'd1;
            if (_r_clock_Divider[6 : 5] == 2'b00) begin /// 最初阶段，将scl和sda总线拉低
                _r_scl <= 0;
                _r_sda_out <= 0;
            end
            else if (_r_clock_Divider[6 : 5] == 2'b01) begin /// 第二阶段，将scl总线拉高
                _r_scl <= 1;
            end
            else if (_r_clock_Divider[6 : 5] == 2'b10) begin /// 第三阶段，将sda总线也拉高
                _r_sda_out <= 1;
            end
        end
        `IIC_INST_WRITE_BYTE: begin
            _r_is_sending <= 1;
            // 这个地方要循环8次，它是通过让_r_clock_Divider溢出以实现重新计时的功能
            _r_clock_Divider <= _r_clock_Divider + 7'd1;
            _r_sda_out <= _r_byte_to_send[_r_bit_index_to_send] ? 1'b1 : 1'b0;

            /// 在整个发送过程中，其实sda的数据已经“建立”好了，所以下面各阶段并没有操作sda
            if (_r_clock_Divider[6 : 5] == 2'b00) begin /// 一阶段先拉低时钟
                _r_scl <= 0;
            end
            else if (_r_clock_Divider[6 : 5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin /// 二三阶段维持时钟为高电平
                _r_scl <= 1;
            end
            else if (_r_clock_Divider == 7'b111_1111) begin /// 这个bit的时钟计时完毕，下标减一，开始发送下一个bit
                _r_bit_index_to_send <= _r_bit_index_to_send - 3'd1;
            end
            else if (_r_clock_Divider[6 : 5] == 2'b11) begin /// 最后拉低时钟，说明这个bit发送完成
                _r_scl <= 0;
            end

        end
        `IIC_STATE_RCV_ACK: begin
            _r_is_sending <= 0;
            /// TODO: 解析是否真的收到了ACK信号!
            _r_clock_Divider <= _r_clock_Divider + 7'd1;

            // 在scl拉高电平之后，需要在in_sda处于高电平并维持一段时间之后，才会认为是收到了Ack
            // 测试中，Ack信号可能并不会在scl上升沿到来，也可能是下降沿到来。所以在首次上升沿之后就开始检查Ack信号知道结束
            if (_r_clock_Divider[6:5] != 2'b00) begin
                if (in_sda_in) begin
                    _r_received_ack_counter <= _r_received_ack_counter + 1;
                    if (&_r_received_ack_counter) begin
                        _r_recevied_ack <= 1'b1;
                    end
                end
                else begin
                    _r_received_ack_counter <= 4'd0;
                end
            end
            // 在Rcv_ack阶段结束的最后一刻，检查ack信号接收情况
            if (&_r_clock_Divider) begin
                _r_err_state <= ~_r_recevied_ack;
            end

            if (_r_clock_Divider[6:5] == 2'b00) begin
                // 提前开始准备初始化ack的状态，因为下一个状态一定会使检查Ack
                _r_received_ack_counter <= 4'd0;
                _r_recevied_ack <= 1'b0;
                _r_scl <= 0;
            end
            else if (_r_clock_Divider[6:5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin
                _r_scl <= 1;
            end
            else if (_r_clock_Divider[6 : 5] == 2'b11) begin
                _r_scl <= 0;
            end
        end
        endcase
    end


endmodule

`ifdef DEBUG_TEST_BENCH
// 测试IIC的功能，仿真时序
module IIC_SEND_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_enable;
    wire [7:0] _w_byte_to_send;
    reg [1:0] _r_instruction;
    wire _w_sda_out;
    wire _w_scl;
    wire _w_is_sending;
    wire _w_is_completed;

    IIC _inst_iic(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_enable)
        , .in_byte_to_send(_w_byte_to_send)
        , .in_instruction(_r_instruction)
        , .out_sda_out(_w_sda_out)
        , .out_scl(_w_scl)
        , .out_is_completed(_w_is_completed)
        , .out_is_sending(_w_is_sending)
    );

    wire _w_sda_out_actual = _w_is_sending ? _w_sda_out : 1'bz;

    localparam TB_STATE_IDLE = 0;
    localparam TB_STATE_SEND_START_TX = 1;
    localparam TB_STATE_SEND_BYTES = 2;
    localparam TB_STATE_SEND_STOP_TX = 3;
    // 需要一个“前置状态”，用来拉高以及“固定信号”，这些过渡的状态只会维持一个时钟周期
    localparam TB_STATE_PRE_SEND_START_TX = 4;
    localparam TB_STATE_PRE_SEND_BYTES = 5;
    localparam TB_STATE_PRE_SEND_STOP_TX = 6;

    reg [31:0] _r_counter;
    assign _w_byte_to_send = _r_counter[7:0];
    reg [2:0] _r_state;
    reg [2:0] _r_next_state;
    reg [2:0] _r_sent_byte_count;
    initial begin
        _r_enable = 0;
        _r_instruction = 0;
        _r_counter = 0;
        _r_state = TB_STATE_IDLE;
        _r_next_state = TB_STATE_IDLE;
        _r_sent_byte_count = 0;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= 0;
            _r_state <= TB_STATE_IDLE;
        end
        else begin
            _r_counter <= _r_counter + 1;
            _r_state <= _r_next_state;
        end
    end

    always @(*) begin
        case (_r_state)
        TB_STATE_IDLE: begin
            if (_r_counter[2] && _r_counter[1:0] == 2'b00 && _r_sent_byte_count < 3) begin
                _r_next_state = TB_STATE_PRE_SEND_START_TX;
            end
            else begin
                _r_next_state = TB_STATE_IDLE;
            end
        end
        TB_STATE_PRE_SEND_START_TX: begin
            _r_next_state = TB_STATE_SEND_START_TX;
        end
        TB_STATE_SEND_START_TX: begin
            if (~_w_is_completed) begin
                _r_next_state = TB_STATE_SEND_START_TX;
            end
            else begin
                _r_next_state = TB_STATE_PRE_SEND_BYTES;
            end
        end
        TB_STATE_PRE_SEND_BYTES: begin
            _r_next_state = TB_STATE_SEND_BYTES;
        end
        TB_STATE_SEND_BYTES: begin
            if (~_w_is_completed) begin
                _r_next_state = TB_STATE_SEND_BYTES;
            end
            else begin
                if (_r_sent_byte_count < 3) begin
                    _r_next_state = TB_STATE_PRE_SEND_BYTES;
                end
                else begin
                    _r_next_state = TB_STATE_PRE_SEND_STOP_TX;
                end
            end
        end
        TB_STATE_PRE_SEND_STOP_TX: begin
            _r_next_state = TB_STATE_SEND_STOP_TX;
        end
        TB_STATE_SEND_STOP_TX: begin
            if (~_w_is_completed) begin
                _r_next_state = TB_STATE_SEND_STOP_TX;
            end
            else begin
                _r_next_state = TB_STATE_IDLE;
            end
        end
        endcase
    end

    always @(posedge in_clk) begin
        case (_r_state)
        TB_STATE_IDLE: begin
            _r_enable <= 1'b0;
            _r_instruction <= `IIC_INST_START_TX; /// in fact, nothing...
        end
        TB_STATE_PRE_SEND_START_TX: begin
            _r_enable <= 1'b1;
            _r_instruction <= `IIC_INST_START_TX;
        end
        TB_STATE_SEND_START_TX: begin
            _r_enable <= 1'b0; ///< 把它拉低，因为enable信号只用在发起命令的时候拉高一次就够了。这样在动作执行完成之后可以立马让IIC模块回到Idle状态
        end
        TB_STATE_PRE_SEND_BYTES: begin
            _r_sent_byte_count <= _r_sent_byte_count + 1;
           _r_enable <= 1'b1;
           _r_instruction <= `IIC_INST_WRITE_BYTE;
        end
        TB_STATE_SEND_BYTES: begin
            _r_enable <= 1'b0;
        end
        TB_STATE_PRE_SEND_STOP_TX: begin
            _r_enable <= 1'b1;
            _r_instruction <= `IIC_INST_STOP_TX;
        end
        TB_STATE_SEND_STOP_TX: begin
            _r_enable <= 1'b0;
        end
        endcase
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< IIC_V