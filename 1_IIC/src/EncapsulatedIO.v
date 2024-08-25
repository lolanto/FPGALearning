`ifndef ENCAPSULATED_IO_V
`define ENCAPSULATED_IO_V
`include "IIC.v"
`include "SyncFIFO.v"
`include "EdgeDetection.v"

/**
 * @brief 封装之后的IIC组件，在配置了目标地址之后，就只需要按需往组件里面塞数据就可以了
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_send_enable 拉高表示进入发送模式。时钟上升沿拉高的同时，还需要配置目标地址
 * @param in_data_sig 数据发送信号。时钟上升沿拉高，同时配置要发送的数据，下一个时钟周期再拉低
 * @param in_device_address IIC组件要通讯的目标地址。在in_send_enable被拉高的同一个时钟上升沿内就要配置好地址
 * @param in_write_data 要发送的数据。in_data_sig被拉高的同一个时钟上升沿内就要配置好要发送的数据
 * @return out_read_data
 * @return out_write_buffer_full 当前数据发送缓冲是否已经满了
 * @return out_write_buffer_empty 当前数据发送缓冲是否为空
 * @return out_is_busy 当前模块是否已经被占用(正在发送/接收)
 * @return out_iic_scl iic模块的时钟信号
 * @return out_iic_sda iic模块的数据信号
 * @return out_iic_is_sending iic模块是否正在发送数据
 */
module EncapsulatedIIC(
    input wire in_clk,
    input wire in_rst,
    input wire in_send_enable,
    // input wire in_read_enable,
    input wire in_data_sig,
    input wire [6:0] in_device_address,
    input wire [7:0] in_write_data,
    output wire [7:0] out_read_data,
    output wire out_write_buffer_full,
    output wire out_write_buffer_empty,
    output wire out_is_busy,
    output wire out_err_state,
    /// IIC总线
    input wire in_iic_sda,
    output wire out_iic_scl,
    output wire out_iic_sda,
    output wire out_iic_is_sending
);

    // 保证在in_send_enable/read_enable被拉起的时候，能够将目标地址缓存下来！
    reg [6:0] _r_device_address; ///< 缓存执行操作的地址!
    wire _w_trigger_to_send;
    EdgeDetection _inst_ed_in_send_enable(.in_clk(in_clk), .in_rst(in_rst), .in_sig(in_send_enable), .out_detected(_w_trigger_to_send));
    always @(posedge in_clk) begin
        if (_w_trigger_to_send)
            _r_device_address <= in_device_address;
        else
            _r_device_address <= _r_device_address;
    end
    reg _r_is_busy;
    reg _r_fifo_read_enable_when_sending; ///< 在模块处在发送模式时，模块内控制向FIFO读取的信号

    reg _r_iic_enable;
    reg [7:0] _r_iic_byte_to_send;
    reg [2:0] _r_iic_instruction;
    wire _w_iic_is_completed;

    IIC _inst_iic(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_iic_enable)
        , .in_byte_to_send(_r_iic_byte_to_send)
        , .in_instruction(_r_iic_instruction)
        , .in_sda_in(in_iic_sda)
        , .out_sda_out(out_iic_sda)
        , .out_scl(out_iic_scl)
        , .out_is_completed(_w_iic_is_completed)
        , .out_sda_is_using(out_iic_is_sending)
    );

    reg [7:0] _r_fifo_write_data;
    wire _w_fifo_write_enable;
    wire [7:0] _w_fifo_read_data;
    wire _w_fifo_read_enable;
    wire _w_fifo_is_full;
    wire _w_fifo_is_empty;
    wire _w_fifo_about_to_be_empty;

    assign out_write_buffer_empty = _w_fifo_is_empty;
    assign out_write_buffer_full = _w_fifo_is_full;

    always @(*) begin
        _r_fifo_write_data = in_write_data;
    end

    assign _w_fifo_read_enable = (_r_fifo_read_enable_when_sending); // | (in_read_enable & in_data_sig);
    assign _w_fifo_write_enable = (in_send_enable & in_data_sig); // | _r_fifo_write_enable_when_reading;

    SyncFIFO _inst_SyncFIFO(.in_clk(in_clk), .in_rst(in_rst)
        , .in_write_data(_r_fifo_write_data[7:0])
        , .in_write_enable(_w_fifo_write_enable)
        , .out_read_data(_w_fifo_read_data[7:0])
        , .in_read_enable(_w_fifo_read_enable)
        , .out_is_full(_w_fifo_is_full)
        , .out_is_empty(_w_fifo_is_empty)
        , .out_about_to_be_empty(_w_fifo_about_to_be_empty));

    /// FSM，在进行发送的时候，不断向指定地址发送FIFO中缓存的所有字节

    localparam STATE_IDLE = 0;
    localparam STATE_BEG_SENDING = 1;
    localparam STATE_PRE_SEND_START_TX = 2;
    localparam STATE_SEND_START_TX = 3;
    localparam STATE_PRE_SEND_ADDR = 4;
    localparam STATE_SEND_ADDR = 5;
    localparam STATE_SEND_PENDING = 6;
    localparam STATE_PRE_SEND_BYTE = 7;
    localparam STATE_SEND_BYTE = 8;
    localparam STATE_PRE_SEND_STOP_TX = 9;
    localparam STATE_SEND_STOP_TX = 10;
    localparam STATE_END_SENDING = 11;

    reg [4:0] _r_current_state;
    reg [4:0] _r_next_state;

    always @(posedge in_clk) begin
        if (in_rst)
            _r_current_state <= STATE_IDLE;
        else
            _r_current_state <= _r_next_state;
    end

    always @(*) begin
        if (_r_current_state != STATE_IDLE)
            _r_is_busy = 1'b1;
        else
            _r_is_busy = 1'b0;
    end
    assign out_is_busy = _r_is_busy;

    /// 有限状态机状态转移规则
    always @(*) begin
        _r_next_state = STATE_IDLE;
        case(_r_current_state)
        STATE_IDLE: begin
            if (in_send_enable)
                _r_next_state = STATE_BEG_SENDING;
            // else if (in_read_enable)
            //     _r_next_state = STATE_IDLE;
            else
                _r_next_state = STATE_IDLE;
        end
        STATE_BEG_SENDING: begin
            _r_next_state = STATE_PRE_SEND_START_TX;
        end
        STATE_PRE_SEND_START_TX: begin
            _r_next_state = STATE_SEND_START_TX;
        end
        STATE_SEND_START_TX: begin
            if (~_w_iic_is_completed)
                _r_next_state = STATE_SEND_START_TX;
            else
                _r_next_state = STATE_PRE_SEND_ADDR;
        end
        STATE_PRE_SEND_ADDR: begin
            _r_next_state = STATE_SEND_ADDR;
        end
        STATE_SEND_ADDR: begin
            if (~_w_iic_is_completed)
                _r_next_state = STATE_SEND_ADDR;
            else
                _r_next_state = STATE_SEND_PENDING;
        end
        STATE_SEND_PENDING: begin
            if (_w_fifo_is_empty && ~in_send_enable)
                _r_next_state = STATE_PRE_SEND_STOP_TX;
            else if (~_w_fifo_is_empty)
                _r_next_state = STATE_PRE_SEND_BYTE;
            else
                _r_next_state = STATE_SEND_PENDING;
        end
        STATE_PRE_SEND_BYTE: begin
            _r_next_state = STATE_SEND_BYTE;
        end
        STATE_SEND_BYTE: begin
            if (~_w_iic_is_completed)
                _r_next_state = STATE_SEND_BYTE;
            else
                _r_next_state = STATE_SEND_PENDING;
        end
        STATE_PRE_SEND_STOP_TX: begin
            _r_next_state = STATE_SEND_STOP_TX;
        end
        STATE_SEND_STOP_TX: begin
            if (~_w_iic_is_completed)
                _r_next_state = STATE_SEND_STOP_TX;
            else
                _r_next_state = STATE_END_SENDING;
        end
        STATE_END_SENDING: begin
            _r_next_state = STATE_IDLE;
        end
        endcase
    end
    
    always @(posedge in_clk) begin
        case (_r_current_state)
        STATE_IDLE: begin
            _r_fifo_read_enable_when_sending <= 1'b0;
            _r_iic_enable <= 1'b0;
        end
        STATE_BEG_SENDING: begin
            /// TODO? anything?
        end
        STATE_PRE_SEND_START_TX: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_START_TX;
        end
        STATE_SEND_START_TX: begin
            _r_iic_enable <= 1'b0;
        end
        STATE_PRE_SEND_ADDR: begin
            _r_iic_enable <= 1'b1;
            _r_iic_byte_to_send <= {_r_device_address, 1'b0};
            _r_iic_instruction <= `IIC_INST_SEND_BYTE;
        end
        STATE_SEND_ADDR: begin
            _r_iic_enable <= 1'b0;
        end
        STATE_SEND_PENDING: begin
        end
        STATE_PRE_SEND_BYTE: begin
            _r_fifo_read_enable_when_sending <= 1'b1;
            _r_iic_byte_to_send <= _w_fifo_read_data;
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_SEND_BYTE;
        end
        STATE_SEND_BYTE: begin
            _r_fifo_read_enable_when_sending <= 1'b0;
            _r_iic_enable <= 1'b0;
        end
        STATE_PRE_SEND_STOP_TX: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_STOP_TX;
        end
        STATE_SEND_STOP_TX: begin
            _r_iic_enable <= 1'b0;
        end
        STATE_END_SENDING: begin
        end
        endcase
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module EncapsulatedIIC_SEND_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_send_enable;
    reg _r_data_sig;
    reg [6:0] _r_device_address;
    wire [7:0] _w_byte_to_send;

    reg [7:0] _r_byte_to_send;
    assign _w_byte_to_send = _r_byte_to_send;

    EncapsulatedIIC _inst_EIIC(.in_clk(in_clk), .in_rst(in_rst)
        , .in_send_enable(_r_send_enable)
        , .in_data_sig(_r_data_sig)
        , .in_device_address(_r_device_address)
        , .in_write_data(_w_byte_to_send));

    reg [31:0] _r_counter;
    reg [2:0] _r_sent_byte_count;

    initial begin
        _r_counter = 32'd0;
        _r_sent_byte_count = 3'd0;
    end

    localparam TB_STATE_IDLE = 0;
    localparam TB_STATE_BEG_SEND = 1;
    localparam TB_STATE_SENDING = 2;
    localparam TB_STATE_END_SEND = 3;

    reg [1:0] _r_current_state;
    reg [1:0] _r_next_state;

    always @(posedge in_clk) begin
        if (in_rst)
            _r_current_state <= TB_STATE_IDLE;
        else
            _r_current_state <= _r_next_state;
    end

    always @(*) begin
        case (_r_current_state)
        TB_STATE_IDLE: begin
            if (_r_sent_byte_count == 0)
                _r_next_state = TB_STATE_BEG_SEND;
            else
                _r_next_state = TB_STATE_IDLE;
        end
        TB_STATE_BEG_SEND: begin
            _r_next_state = TB_STATE_SENDING;
        end
        TB_STATE_SENDING: begin
            if (_r_sent_byte_count < 2)
                _r_next_state = TB_STATE_SENDING;
            else
                _r_next_state = TB_STATE_END_SEND;
        end
        TB_STATE_END_SEND: begin
            _r_next_state = TB_STATE_IDLE;
        end
        endcase
    end

    always @(posedge in_clk) begin
        _r_counter <= _r_counter + 1;
        case (_r_current_state)
        TB_STATE_IDLE: begin
            _r_send_enable <= 1'b0;
            _r_data_sig <= 1'b0;
        end
        TB_STATE_BEG_SEND: begin
            _r_send_enable <= 1'b1;
            _r_device_address <= _r_counter[6:0];
        end
        TB_STATE_SENDING: begin
            if (~_r_data_sig) begin
                _r_data_sig <= 1'b1;
                _r_byte_to_send <= _r_counter[7:0];
            end
            else begin
                _r_data_sig <= 1'b0;
                _r_sent_byte_count <= _r_sent_byte_count + 1;
            end
        end
        TB_STATE_END_SEND: begin
            _r_send_enable <= 1'b0;
        end
        endcase
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< ENCAPSULATED_IO_V