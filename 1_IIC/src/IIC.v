`ifndef IIC_V
`define IIC_V


`include "IICMeta.v"

/**
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_enable 设备使能，每次指令执行完成，都需要将设备disable再enable
 * @param in_byte_to_send 需要向外发送的字节，假如是首个带读写操作的指令，也需要填写对应的bit
 * @return out_byte_read 读取到的字节
 * @return out_ack_read 作为发送方时读取到的ack信号值
 * @param in_instruction 当前要执行的I2C操作：开始传输/发送字节/结束传输
 * @param in_sda_in 外部sda总线的输入
 * @return out_sda_out 外部sda总线的输出
 * @return out_scl 外部scl总线的输出
 * @return out_sda_is_using sda总线是否正在被该器件使用
 * @return out_scl_is_using scl总线是否正在被该器件使用
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

`define IIC_INST_UNKNOWN 0
`define IIC_INST_START_TX `IIC_INST_UNKNOWN + 1 //< 发送开始信号
`define IIC_INST_STOP_TX `IIC_INST_START_TX + 1 //< 发送结束信号
`define IIC_INST_RECV_BYTE `IIC_INST_STOP_TX + 1 //< 接收一个字节信息，并返回ACK信号
`define IIC_INST_RECV_BYTE_WITHOUT_ACK `IIC_INST_RECV_BYTE + 1 //< 接收一个字节信息，但不返回ACK信号
`define IIC_INST_SEND_BYTE `IIC_INST_RECV_BYTE_WITHOUT_ACK + 1 //< 发送一个字节信息，并等待ACK信号
`define IIC_INST_SEND_BYTE_IGNORE_ACK `IIC_INST_SEND_BYTE + 1 //< 发送一个字节信息，并忽略ACK信号

`define IIC_STATE_RECV_ACK `IIC_INST_SEND_BYTE_IGNORE_ACK + 1
`define IIC_STATE_SEND_ACK `IIC_STATE_RECV_ACK + 1
`define IIC_STATE_IGNORE_ACK `IIC_STATE_SEND_ACK + 1
`define IIC_STATE_WAIT_COMPLETE `IIC_STATE_IGNORE_ACK + 1
`define IIC_STATE_WAIT_COMPLETE_FOR_BYTES `IIC_STATE_WAIT_COMPLETE + 1

`define IIC_WRITE_OPERATION_BIT 8'd0
`define IIC_READ_OPERATION_BIT 8'd1

module IIC(
    input wire in_clk,
    input wire in_rst,
    input wire in_enable,

    input wire [7:0] in_byte_to_send,
    output wire [7:0] out_byte_read,
    output wire out_ack_read, 
    input wire [2:0] in_instruction,

    input wire in_sda_in,
    output wire out_sda_out,
    output wire out_scl,

    output wire out_sda_is_using,
    output wire out_scl_is_using,

    output wire out_is_completed
);
    reg [2:0] _r_instruction;
    reg [3:0] _r_state = `IIC_INST_UNKNOWN;
    reg [3:0] _r_next_state;
    reg [3:0] _r_bit_index_to_process = 3'd7; // 当前要发送的bit的索引，注意，I2C是从高位开始发送的!
    reg [7:0] _r_byte_to_process;

    assign out_byte_read = _r_byte_to_process;

    reg _r_is_completed;
    assign out_is_completed = _r_is_completed;

    reg _r_ack_read;
    assign out_ack_read = _r_ack_read;
    
    wire _w_iic_meta_is_completed;
    reg [2:0] _r_iic_meta_instruction;
    reg _r_bit_to_send;
    wire _w_bit_read;

    IICMeta _inst_iic_meta(
        .in_clk(in_clk), .in_rst(in_rst)
        , .in_instruction(_r_iic_meta_instruction)
        , .in_bit_to_send(_r_bit_to_send)
        , .out_bit_read(_w_bit_read)
        , .in_sda_in(in_sda_in)
        , .out_sda_out(out_sda_out)
        , .out_scl(out_scl)
        , .out_sda_is_using(out_sda_is_using)
        , .out_scl_is_using(out_scl_is_using)
        , .out_is_completed(_w_iic_meta_is_completed));

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state <= `IIC_INST_UNKNOWN;
        end
        else begin
            _r_state <= _r_next_state;
        end
    end

    // _r_instruction将会在IIC_STATE_WAIT_COMPLETE_FOR_BYTES状态中提供其正确的“上一次状态”的信息
    always @(posedge in_clk) begin
        if (_r_state == `IIC_INST_UNKNOWN)
            if (_r_next_state != `IIC_INST_UNKNOWN)
                _r_instruction <= in_instruction;
            else
                _r_instruction <= `IIC_INST_UNKNOWN;
    end

    /// 组合逻辑以确定下一个状态是什么
    always @(*) begin
        case (_r_state)
        `IIC_INST_UNKNOWN: begin
            if (in_enable) begin
                _r_next_state = in_instruction;
            end
            else begin
                _r_next_state = `IIC_INST_UNKNOWN;
            end
        end
        `IIC_INST_START_TX,
        `IIC_INST_STOP_TX,
        `IIC_STATE_RECV_ACK,
        `IIC_STATE_SEND_ACK,
        `IIC_STATE_IGNORE_ACK: begin
            _r_next_state = `IIC_STATE_WAIT_COMPLETE;
        end
        `IIC_STATE_WAIT_COMPLETE : begin
            if (_w_iic_meta_is_completed) begin
                _r_next_state = `IIC_INST_UNKNOWN;
            end
            else
                _r_next_state = `IIC_STATE_WAIT_COMPLETE;
        end

        `IIC_INST_SEND_BYTE, `IIC_INST_SEND_BYTE_IGNORE_ACK,
        `IIC_INST_RECV_BYTE, `IIC_INST_RECV_BYTE_WITHOUT_ACK: begin
            _r_next_state = `IIC_STATE_WAIT_COMPLETE_FOR_BYTES;
        end

        `IIC_STATE_WAIT_COMPLETE_FOR_BYTES: begin
            if (_w_iic_meta_is_completed) begin
                case (_r_instruction)
                `IIC_INST_SEND_BYTE: begin
                    if (_r_bit_index_to_process == 3'd0)
                        _r_next_state = `IIC_STATE_RECV_ACK;
                    else
                        _r_next_state = `IIC_INST_SEND_BYTE;
                end
                `IIC_INST_SEND_BYTE_IGNORE_ACK: begin
                    if (_r_bit_index_to_process == 3'd0)
                        _r_next_state = `IIC_STATE_IGNORE_ACK;
                    else
                        _r_next_state = `IIC_INST_SEND_BYTE_IGNORE_ACK;
                end
                `IIC_INST_RECV_BYTE: begin
                    if (_r_bit_index_to_process == 3'd0)
                        _r_next_state = `IIC_STATE_SEND_ACK;
                    else
                        _r_next_state = `IIC_INST_RECV_BYTE;
                end
                `IIC_INST_RECV_BYTE_WITHOUT_ACK: begin
                    if (_r_bit_index_to_process == 3'd0)
                        _r_next_state = `IIC_STATE_IGNORE_ACK;
                    else
                        _r_next_state = `IIC_INST_RECV_BYTE_WITHOUT_ACK;
                end
                default:
                    _r_next_state = `IIC_INST_UNKNOWN;
                endcase
            end
            else
                _r_next_state = `IIC_STATE_WAIT_COMPLETE_FOR_BYTES;
        end
        default:
            _r_next_state = `IIC_INST_UNKNOWN;
        endcase
    end


    always @(posedge in_clk) begin
        _r_iic_meta_instruction <= `IIC_META_INST_UNKNOWN;
        case (_r_state)
        `IIC_INST_UNKNOWN: begin
            _r_bit_index_to_process <= 3'd7;
            _r_ack_read <= 1'b0;
            _r_is_completed <= 1'b0;
            if (in_enable)
                _r_byte_to_process <= in_byte_to_send;
        end
        `IIC_INST_START_TX: begin
            _r_iic_meta_instruction <= `IIC_META_INST_START_TX;
        end
        `IIC_INST_STOP_TX: begin
            _r_iic_meta_instruction <= `IIC_META_INST_STOP_TX;
        end
        `IIC_STATE_RECV_ACK: begin
            _r_iic_meta_instruction <= `IIC_META_INST_RECV_BIT;
        end
        `IIC_STATE_SEND_ACK: begin
            _r_iic_meta_instruction <= `IIC_META_INST_SEND_BIT;
            _r_bit_to_send <= 1'b0; // TODO: 没有校验需要支持？接满8个bit就一定ACK？
        end
        `IIC_STATE_IGNORE_ACK: begin
            _r_iic_meta_instruction <= `IIC_META_INST_SEND_BIT;
            _r_bit_to_send <= 1'b1;
        end
        `IIC_STATE_WAIT_COMPLETE: begin
            if (_w_iic_meta_is_completed) begin
                _r_ack_read <= _w_bit_read;
                _r_is_completed <= 1'b1;
            end
        end

        `IIC_INST_SEND_BYTE, `IIC_INST_SEND_BYTE_IGNORE_ACK: begin
            _r_iic_meta_instruction <= `IIC_META_INST_SEND_BIT;
            _r_bit_to_send <=  _r_byte_to_process[_r_bit_index_to_process];
        end
        `IIC_INST_RECV_BYTE, `IIC_INST_RECV_BYTE_WITHOUT_ACK: begin
            _r_iic_meta_instruction <= `IIC_META_INST_RECV_BIT;
        end
        `IIC_STATE_WAIT_COMPLETE_FOR_BYTES: begin
            if (_w_iic_meta_is_completed) begin
                _r_bit_index_to_process <= _r_bit_index_to_process - 1;
                if (_r_instruction == `IIC_INST_RECV_BYTE
                    || _r_instruction == `IIC_INST_RECV_BYTE_WITHOUT_ACK) begin
                    _r_byte_to_process[_r_bit_index_to_process] <= _w_bit_read;
                end
            end
        end
        endcase
    end


endmodule

`ifdef DEBUG_TEST_BENCH
// 测试IIC的读取功能，仿真时序
module IIC_SEND_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_enable;
    reg [7:0] _r_byte_to_send;
    reg [2:0] _r_instruction;
    wire _w_sda_out;
    wire _w_scl;
    wire _w_is_completed;

    IIC _inst_iic(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_enable)
        , .in_byte_to_send(_r_byte_to_send)
        , .in_instruction(_r_instruction)
        , .out_sda_out(_w_sda_out)
        , .out_scl(_w_scl)
        , .out_is_completed(_w_is_completed)
    );

    localparam TB_STATE_IDLE = 0;
    localparam TB_STATE_SEND_START_TX = 1;
    localparam TB_STATE_SEND_BYTES = 2;
    localparam TB_STATE_SEND_STOP_TX = 3;
    // 需要一个“前置状态”，用来拉高以及“固定信号”，这些过渡的状态只会维持一个时钟周期
    localparam TB_STATE_PRE_SEND_START_TX = 4;
    localparam TB_STATE_PRE_SEND_BYTES = 5;
    localparam TB_STATE_PRE_SEND_STOP_TX = 6;

    reg [31:0] _r_counter;
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
            if (_r_counter[2] && _r_counter[1:0] == 2'b00 && _r_sent_byte_count < 5) begin
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
                // 连续发送了3个字节之后，尝试执行2次repeat start发送
                else if (_r_sent_byte_count < 5) begin
                    _r_next_state = TB_STATE_PRE_SEND_START_TX;
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
            _r_instruction <= `IIC_INST_UNKNOWN; /// in fact, nothing...
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
            _r_instruction <= `IIC_INST_SEND_BYTE;
            _r_byte_to_send <= _r_counter[7:0];
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

// 测试IIC的读取功能，仿真时序
module IIC_READ_TB(
    input wire in_clk,
    input wire in_rst
);
    reg _r_enable;
    wire [7:0] _w_byte_read;
    reg [7:0] _r_byte_read;
    reg [2:0] _r_instruction;
    reg _r_sda_in;
    reg [7:0] _r_byte_to_send;
    wire _w_scl;
    wire _w_sda_out;
    wire _w_is_completed;

    IIC _inst_iic(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_enable)
        , .in_byte_to_send(_r_byte_to_send)
        , .in_instruction(_r_instruction)
        , .in_sda_in(_r_sda_in)
        , .out_byte_read(_w_byte_read)
        , .out_sda_out(_w_sda_out)
        , .out_scl(_w_scl)
        , .out_is_completed(_w_is_completed)
    );

    localparam TB_STATE_IDLE = 0;
    localparam TB_STATE_SEND_START_TX = 1;
    localparam TB_STATE_SEND_BYTES = 2;
    localparam TB_STATE_READ_BYTES = 3;
    localparam TB_STATE_SEND_STOP_TX = 4;
    // 需要一个“前置状态”，用来拉高以及“固定信号”，这些过渡的状态只会维持一个时钟周期
    localparam TB_STATE_PRE_SEND_START_TX = 5;
    localparam TB_STATE_PRE_SEND_BYTES = 6;
    localparam TB_STATE_PRE_SEND_STOP_TX = 7;
    localparam TB_STATE_PRE_READ_BYTES = 8;

    
    reg [31:0] _r_counter;
    reg [3:0] _r_state;
    reg [3:0] _r_next_state;
    reg [2:0] _r_read_byte_count;
    initial begin
        _r_enable = 0;
        _r_instruction = 0;
        _r_counter = 0;
        _r_state = TB_STATE_IDLE;
        _r_next_state = TB_STATE_IDLE;
        _r_read_byte_count = 0;
        _r_sda_in <= 1'b1;
    end

    
    reg [2:0] _r_bit_index_to_send;
    reg [6:0] _r_send_bit_clock;
    always @(posedge in_clk) begin
        case (_r_state)
        TB_STATE_PRE_READ_BYTES: begin
            _r_byte_to_send <= _r_counter[7:0];
            _r_sda_in <= _r_counter[7];
            _r_bit_index_to_send <= 3'd7;
            _r_send_bit_clock <= 7'd1;
        end
        TB_STATE_READ_BYTES: begin
            _r_sda_in <= _r_byte_to_send[_r_bit_index_to_send];
            _r_send_bit_clock <= _r_send_bit_clock + 1;
            if (_r_send_bit_clock == 7'b111_1111) begin
                _r_bit_index_to_send <= _r_bit_index_to_send - 1;
            end
        end
        endcase
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
            if (_r_counter[2] && _r_counter[1:0] == 2'b00 && _r_read_byte_count < 3) begin
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
                if (_r_read_byte_count < 3) begin
                    _r_next_state = TB_STATE_PRE_READ_BYTES;
                end
            end
        end
        TB_STATE_PRE_READ_BYTES: begin
            _r_next_state = TB_STATE_READ_BYTES;
        end
        TB_STATE_READ_BYTES: begin
            if (~_w_is_completed) begin
                _r_next_state = TB_STATE_READ_BYTES;
            end
            else begin
                _r_byte_read = _w_byte_read;
                if (_r_read_byte_count < 3) begin
                    _r_next_state = TB_STATE_PRE_READ_BYTES;
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
            _r_instruction <= `IIC_INST_UNKNOWN; /// in fact, nothing...
        end
        TB_STATE_PRE_SEND_START_TX: begin
            _r_enable <= 1'b1;
            _r_instruction <= `IIC_INST_START_TX;
        end
        TB_STATE_SEND_START_TX: begin
            _r_enable <= 1'b0; ///< 把它拉低，因为enable信号只用在发起命令的时候拉高一次就够了。这样在动作执行完成之后可以立马让IIC模块回到Idle状态
        end
        TB_STATE_PRE_SEND_BYTES: begin
            _r_enable <= 1'b1;
            _r_instruction <= `IIC_INST_SEND_BYTE;
            _r_byte_to_send <= _r_counter[7:0];
        end
        TB_STATE_SEND_BYTES: begin
            _r_enable <= 1'b0;
        end
        TB_STATE_PRE_READ_BYTES: begin
            _r_read_byte_count <= _r_read_byte_count + 1;
            _r_enable <= 1'b1;
            _r_instruction <= `IIC_INST_RECV_BYTE;
        end
        TB_STATE_READ_BYTES: begin
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