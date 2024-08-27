`ifndef TOP_V
`define TOP_V
`include "EdgeDetection.v"
`include "Debouncer.v"
`include "ByteToDecimal.v"
`include "IIC.v"

/**
 * @brief 组合逻辑，用来针对TM1650芯片的下标索引和地址之间进行译码
 * @param in_index 下标所用[0, 3]
 * @param out_address 译码后的地址字节码
 */
module I2C_TM1650_BIT_ADDRESS(
    input wire [1:0] in_index,
    output wire [7:0] out_address
);
    localparam I2C_BIT_ADDRESS_3 = 8'h34;
    localparam I2C_BIT_ADDRESS_2 = 8'h35;
    localparam I2C_BIT_ADDRESS_1 = 8'h36;
    localparam I2C_BIT_ADDRESS_0 = 8'h37;

    reg [7:0] _r_address;
    always @(*) begin
        case (in_index)
        2'd0: _r_address = I2C_BIT_ADDRESS_0;
        2'd1: _r_address = I2C_BIT_ADDRESS_1;
        2'd2: _r_address = I2C_BIT_ADDRESS_2;
        2'd3: _r_address = I2C_BIT_ADDRESS_3;
        default: _r_address = 8'h00;
        endcase
    end

    assign out_address = _r_address;
endmodule

/**
 * @brief 组合逻辑，用来针对TM1650芯片的数字和字节码之间进行译码(不带小数点)
 * @param in_decimal 输入的二进制数，仅表示一个十进制位(BCD)[0, 9]
 * @param out_byte 译码之后的数字字节码
 */
module I2C_TM1650_DECIMAL_TO_BYTE_COMMAND(
    input wire [3:0] in_decimal,
    output wire [7:0] out_byte
);
    localparam I2C_NUMBER_BYTE_CODE_0 = 8'h3f;
    localparam I2C_NUMBER_BYTE_CODE_1 = 8'h06;
    localparam I2C_NUMBER_BYTE_CODE_2 = 8'h5b;
    localparam I2C_NUMBER_BYTE_CODE_3 = 8'h4f;
    localparam I2C_NUMBER_BYTE_CODE_4 = 8'h66;
    localparam I2C_NUMBER_BYTE_CODE_5 = 8'h6d;
    localparam I2C_NUMBER_BYTE_CODE_6 = 8'h7d;
    localparam I2C_NUMBER_BYTE_CODE_7 = 8'h07;
    localparam I2C_NUMBER_BYTE_CODE_8 = 8'h7f;
    localparam I2C_NUMBER_BYTE_CODE_9 = 8'h6f;

    reg [7:0] _r_byte;

    always @(*) begin
        case (in_decimal)
        4'd0: _r_byte = I2C_NUMBER_BYTE_CODE_0;
        4'd1: _r_byte = I2C_NUMBER_BYTE_CODE_1;
        4'd2: _r_byte = I2C_NUMBER_BYTE_CODE_2;
        4'd3: _r_byte = I2C_NUMBER_BYTE_CODE_3;
        4'd4: _r_byte = I2C_NUMBER_BYTE_CODE_4;
        4'd5: _r_byte = I2C_NUMBER_BYTE_CODE_5;
        4'd6: _r_byte = I2C_NUMBER_BYTE_CODE_6;
        4'd7: _r_byte = I2C_NUMBER_BYTE_CODE_7;
        4'd8: _r_byte = I2C_NUMBER_BYTE_CODE_8;
        4'd9: _r_byte = I2C_NUMBER_BYTE_CODE_9;
        default: _r_byte = 8'h00;
        endcase
    end

    assign out_byte = _r_byte;
endmodule

module FetchByteFromEEPROM (
    input wire in_clk,
    input wire in_rst,
    input wire in_enable,

    output wire out_iic_enable,
    output wire [2:0] out_iic_inst,
    output wire [7:0] out_iic_byte_to_send,
    input wire [7:0] in_iic_byte_read,
    input wire in_iic_is_complete,

    output wire [7:0] out_fetched_byte,
    output wire out_is_completed,

    output wire out_debug
);

    reg _r_out_iic_enable;
    reg [2:0] _r_out_iic_inst;
    reg [7:0] _r_out_iic_byte_to_send;
    reg [7:0] _r_fetched_byte;
    reg _r_out_is_completed;
    
    assign out_iic_enable = _r_out_iic_enable;
    assign out_iic_inst = _r_out_iic_inst;
    assign out_iic_byte_to_send = _r_out_iic_byte_to_send;
    assign out_fetched_byte = _r_fetched_byte;
    assign out_is_completed = _r_out_is_completed;

    localparam EEPROM_DEVICE_ADDRESS = 8'hA0;
    reg [7:0] _r_byte_address;

    localparam STATE_IDLE = 0;
    localparam STATE_START_FETCH = 1;
    localparam STATE_SEND_DEVICE_ADDRESS_WRITE = 2;
    localparam STATE_SEND_BYTE_ADDRESS = 3;
    localparam STATE_SEND_REPEAT_START = 4;
    localparam STATE_SEND_DEVICE_ADDRESS_READ = 5;
    localparam STATE_READ_BYTE = 6;
    localparam STATE_STOP_FETCH = 7;

    reg [2:0] _r_state;
    reg [2:0] _r_next_state;
    reg _r_waitting_command;

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state <= STATE_IDLE;
        end
        else begin
            _r_state <= _r_next_state;
        end
    end

    always @(*) begin
        _r_next_state = STATE_IDLE;
        case (_r_state)
        STATE_IDLE: begin
            if (in_enable)
                _r_next_state = STATE_START_FETCH;
            else
                _r_next_state = STATE_IDLE;
        end
        STATE_START_FETCH: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_START_FETCH;
            else
                _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE;
        end
        STATE_SEND_DEVICE_ADDRESS_WRITE: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE;
            else
                _r_next_state = STATE_SEND_BYTE_ADDRESS;
        end
        STATE_SEND_BYTE_ADDRESS: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_SEND_BYTE_ADDRESS;
            else
                _r_next_state = STATE_SEND_REPEAT_START;
        end
        STATE_SEND_REPEAT_START: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_SEND_REPEAT_START;
            else
                _r_next_state = STATE_READ_BYTE;
        end
        STATE_READ_BYTE: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_READ_BYTE;
            else
                _r_next_state = STATE_STOP_FETCH;
        end
        STATE_STOP_FETCH: begin
            if (~in_iic_is_complete)
                _r_next_state = STATE_STOP_FETCH;
            else
                _r_next_state = STATE_IDLE;
        end
        endcase
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_waitting_command <= 1'b0;
        end
        else begin
            if (_r_state != _r_next_state)
                _r_waitting_command <= 1'b0;
            else
                _r_waitting_command <= 1'b1;
        end
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_byte_address <= 8'd0;
            _r_out_iic_enable <= 1'b0;
            _r_out_iic_inst <= `IIC_INST_UNKNOWN;
            _r_out_is_completed <= 1'b0;
            _r_out_iic_byte_to_send <= 4'd0;
        end
        else begin
            case (_r_state)
            STATE_IDLE: begin
                // _r_out_is_completed <= 1'b0;
                _r_byte_address <= 8'd0;
                _r_out_iic_enable <= 1'b0;
                _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                _r_out_iic_byte_to_send <= 4'd0;
            end
            STATE_START_FETCH: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_START_TX;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_DEVICE_ADDRESS_WRITE: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    _r_out_iic_byte_to_send <= EEPROM_DEVICE_ADDRESS | `IIC_WRITE_OPERATION_BIT;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_BYTE_ADDRESS: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    _r_out_iic_byte_to_send <= _r_byte_address;
                    _r_byte_address <= _r_byte_address + 1;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_REPEAT_START: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_START_TX;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_DEVICE_ADDRESS_READ: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    _r_out_iic_byte_to_send <= EEPROM_DEVICE_ADDRESS | `IIC_READ_OPERATION_BIT;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_READ_BYTE: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_RECV_BYTE;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                    if (in_iic_is_complete)
                        _r_fetched_byte <= in_iic_byte_read;
                end
            end
            STATE_STOP_FETCH: begin
                if (in_iic_is_complete)
                    _r_out_is_completed <= 1'b1;
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_STOP_TX;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            endcase
        end
    end

endmodule

module ShowByteToTM1650 (
    input wire in_clk,
    input wire in_rst,
    input wire in_enable,
    input wire [7:0] in_byte_to_show,

    output wire out_iic_enable,
    output wire [2:0] out_iic_inst,
    output wire [7:0] out_iic_byte_to_send,
    input wire in_iic_is_complete,

    output wire out_is_completed
);

    reg _r_out_iic_enable;
    reg [2:0] _r_out_iic_inst;
    reg [7:0] _r_out_iic_byte_to_send;
    reg _r_out_is_completed;

    assign out_iic_enable = _r_out_iic_enable;
    assign out_iic_inst = _r_out_iic_inst;
    assign out_iic_byte_to_send = _r_out_iic_byte_to_send;
    assign out_is_completed = _r_out_is_completed;

    localparam TM1650_CONTROL_ADDRESS = 8'h24;
    localparam TM1650_LIGHTING_CMD_BYTE = 8'h15;

    localparam STATE_IDLE = 0;
    localparam STATE_START_SHOW = 1;
    localparam STATE_SEND_DEVICE_ADDRESS_WRITE = 2;
    localparam STATE_SEND_DEVICE_ADDRESS_WRITE_DECIMAL = 3;
    localparam STATE_STOP_SHOW = 4;
    localparam STATE_SEND_BYTE = 5;
    localparam STATE_FINISH_SEND_BYTE = 6;

    reg _r_setup_tm1650;
    reg [2:0] _r_digit_count;

    wire [7:0] _w_TM1650_digit_byte;
    wire [7:0] _w_TM1650_digit_addr;

    wire [3:0] _w_decimal [3:0];
    I2C_TM1650_BIT_ADDRESS _inst_tm1650_bit_address(.in_index(_r_digit_count[1:0]), .out_address(_w_TM1650_digit_addr));
    I2C_TM1650_DECIMAL_TO_BYTE_COMMAND _inst_tm1650_bit_byte(.in_decimal(_w_decimal[_r_digit_count[1:0]]), .out_byte(_w_TM1650_digit_byte));
    ByteToDecimal _inst_byte_to_decimal(.in_byte(in_byte_to_show)
        , .out_decimal_0(_w_decimal[2'd0])
        , .out_decimal_1(_w_decimal[2'd1])
        , .out_decimal_2(_w_decimal[2'd2])
        , .out_decimal_3(_w_decimal[2'd3]));

    reg [3:0] _r_state;
    reg [3:0] _r_next_state;

    always @(posedge in_clk) begin
        if(in_rst)
            _r_state <= STATE_IDLE;
        else
            _r_state <= _r_next_state;
    end

    always @(*) begin
        _r_next_state = STATE_IDLE;
        case (_r_state)
        STATE_IDLE: begin
            if (in_enable) begin
                _r_next_state = STATE_START_SHOW;
            end
            else begin
                _r_next_state = STATE_IDLE;
            end
        end
        STATE_START_SHOW: begin
            if (~in_iic_is_complete) begin
                _r_next_state = STATE_START_SHOW;
            end
            else begin
                if (~_r_setup_tm1650) begin
                    _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE;
                end
                else begin
                    _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE_DECIMAL;
                end
            end
        end
        STATE_SEND_DEVICE_ADDRESS_WRITE: begin
            if (~in_iic_is_complete) begin
                _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE;
            end
            else
                _r_next_state = STATE_SEND_BYTE;
        end
        STATE_SEND_DEVICE_ADDRESS_WRITE_DECIMAL: begin
            if (~in_iic_is_complete) begin
                _r_next_state = STATE_SEND_DEVICE_ADDRESS_WRITE_DECIMAL;
            end
            else
                _r_next_state = STATE_SEND_BYTE;
        end
        STATE_SEND_BYTE: begin
            if (~in_iic_is_complete) begin
                _r_next_state = STATE_SEND_BYTE;
            end
            else begin
                _r_next_state = STATE_FINISH_SEND_BYTE;
            end
        end
        STATE_FINISH_SEND_BYTE: begin
            if (~in_iic_is_complete) begin
                _r_next_state = STATE_FINISH_SEND_BYTE;
            end
            else begin
                if (_r_digit_count[2])
                    _r_next_state = STATE_STOP_SHOW;
                else
                    _r_next_state = STATE_START_SHOW;
            end
        end
        STATE_STOP_SHOW: begin
            _r_next_state = STATE_IDLE;
        end
        endcase
    end

    reg _r_waitting_command;
    always @(posedge in_clk) begin
        if (in_rst)
            _r_waitting_command <= 1'b0;
        else if (_r_state != _r_next_state)
            _r_waitting_command <= 1'b0;
        else
            _r_waitting_command <= 1'b1;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_out_iic_byte_to_send <= 4'd0;
            _r_out_iic_enable <= 1'b0;
            _r_out_iic_inst <= `IIC_INST_UNKNOWN;
            _r_digit_count <= 3'd0;
            _r_setup_tm1650 <= 1'b0;
            _r_out_is_completed <= 1'b0;
        end
        else begin
            case (_r_state)
            STATE_IDLE: begin
                _r_out_iic_byte_to_send <= 4'd0;
                _r_out_iic_enable <= 1'b0;
                _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                _r_digit_count <= 3'd0;
                _r_out_is_completed <= 1'b0;
            end
            STATE_START_SHOW: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_START_TX;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_DEVICE_ADDRESS_WRITE: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    _r_out_iic_byte_to_send <= TM1650_CONTROL_ADDRESS;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_DEVICE_ADDRESS_WRITE_DECIMAL: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    _r_out_iic_byte_to_send <= _w_TM1650_digit_addr;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_SEND_BYTE: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_SEND_BYTE;
                    if (~_r_setup_tm1650) begin
                        _r_setup_tm1650 <= 1'b1;
                        _r_out_iic_byte_to_send <= TM1650_LIGHTING_CMD_BYTE;
                    end
                    else begin
                        _r_digit_count <= _r_digit_count + 1;
                        _r_out_iic_byte_to_send <= _w_TM1650_digit_byte;
                    end
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_FINISH_SEND_BYTE: begin
                if (~_r_waitting_command) begin
                    _r_out_iic_enable <= 1'b1;
                    _r_out_iic_inst <= `IIC_INST_STOP_TX;
                end
                else begin
                    _r_out_iic_enable <= 1'b0;
                    _r_out_iic_inst <= `IIC_INST_UNKNOWN;
                end
            end
            STATE_STOP_SHOW: begin
                _r_out_is_completed <= 1'b1;
            end
            endcase
        end
    end

endmodule

module LDE_Debug(
    input wire [5:0] in_value,
    output wire [5:0] out_led
);

    assign out_led = ~in_value;

endmodule

/**
 * @param in_btn_s1 复位信号按钮，高电平有效
 * @param in_btn_s2 加法触发按钮，高电平有效
 */
module Top(
    input wire in_clk,
    input wire in_btn_s1,
    input wire in_btn_s2,
    output wire out_iic_scl,
    inout wire in_out_iic_sda,

    output wire [5:0] out_debug
);
    wire in_rst = in_btn_s1;

    reg _r_iic_enable;
    reg [2:0] _r_iic_instruction;
    reg [7:0] _r_iic_byte_to_send;
    wire [7:0] _w_iic_byte_read;

`ifdef DEBUG_TEST_BENCH
    wire _w_in_iic_sda = 1'b1;
`else
    wire _w_in_iic_sda = in_out_iic_sda;
`endif

    wire _w_out_iic_sda;
    wire _w_iic_is_sending;
    assign in_out_iic_sda = ~_w_iic_is_sending ? 1'bz : _w_out_iic_sda;
    wire _w_iic_is_completed;

    IIC _inst_iic(
        .in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_iic_enable)
        , .in_byte_to_send(_r_iic_byte_to_send)
        , .out_byte_read(_w_iic_byte_read)
        , .in_instruction(_r_iic_instruction)
        , .in_sda_in(_w_in_iic_sda)
        , .out_sda_out(_w_out_iic_sda)
        , .out_scl(out_iic_scl)
        , .out_sda_is_using(_w_iic_is_sending)
        , .out_is_completed(_w_iic_is_completed)
    );


    wire _w_trigger;

`ifdef DEBUG_TEST_BENCH
    assign _w_trigger = in_btn_s2;
`else
    Debouncer _inst_debouncer(.in_clk(in_clk), .in_sig(in_btn_s2), .out_sig_up(_w_trigger));
`endif
    
    reg _r_trigger_byte_fetch;
    wire _w_fetcher_iic_enable;
    wire [2:0] _w_fetcher_iic_inst;
    wire [7:0] _w_fetcher_iic_byte_to_send;
    wire [7:0] _w_fetcher_fetched_byte;
    wire _w_fetcher_is_completed;

    FetchByteFromEEPROM _inst_fetch_byte_from_eeprom(
        .in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_trigger_byte_fetch)
        , .out_iic_enable(_w_fetcher_iic_enable)
        , .out_iic_byte_to_send(_w_fetcher_iic_byte_to_send)
        , .out_iic_inst(_w_fetcher_iic_inst)
        , .in_iic_byte_read(_w_iic_byte_read)
        , .in_iic_is_complete(_w_iic_is_completed)
        , .out_fetched_byte(_w_fetcher_fetched_byte)
        , .out_is_completed(_w_fetcher_is_completed));

    reg _r_trigger_show_tm1650;
    wire _w_show_iic_enable;
    wire [2:0] _w_show_iic_inst;
    wire [7:0] _w_show_iic_byte_to_send;
    wire _w_show_is_completed;

    ShowByteToTM1650 _inst_show_byte_to_tm1650(
        .in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_trigger_show_tm1650)
        , .in_byte_to_show(_w_fetcher_fetched_byte)
        , .out_iic_enable(_w_show_iic_enable)
        , .out_iic_inst(_w_show_iic_inst)
        , .out_iic_byte_to_send(_w_show_iic_byte_to_send)
        , .in_iic_is_complete(_w_iic_is_completed)
        , .out_is_completed(_w_show_is_completed));

    localparam STATE_IDLE = 0;
    localparam STATE_FETCH_BYTE = 1;
    localparam STATE_SHOW_BYTE = 2;

    reg [2:0] _r_state;
    reg [2:0] _r_next_state;

    LDE_Debug _inst_led_debug(.in_value({_w_fetcher_is_completed, out_iic_scl, _w_out_iic_sda, _w_iic_is_sending, _r_state[1:0]}), .out_led(out_debug));

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state = STATE_IDLE;
        end
        else
            _r_state = _r_next_state;
    end

    always @(*) begin
        _r_next_state = STATE_IDLE;
        case(_r_state)
        STATE_IDLE: begin
            if (_w_trigger)
                _r_next_state = STATE_FETCH_BYTE;
            else
                _r_next_state = STATE_IDLE;
        end
        STATE_FETCH_BYTE: begin
            if (~_w_fetcher_is_completed)
                _r_next_state = STATE_FETCH_BYTE;
            else
                _r_next_state = STATE_SHOW_BYTE;
        end
        STATE_SHOW_BYTE: begin
            if (~_w_show_is_completed)
                _r_next_state = STATE_SHOW_BYTE;
            else
                _r_next_state = STATE_IDLE;
        end
        endcase
    end

    always @(*) begin
        case(_r_state)
        STATE_IDLE: begin
            _r_iic_enable = 1'b0;
            _r_iic_instruction = `IIC_INST_UNKNOWN;
            _r_iic_byte_to_send = 4'd0;
        end
        STATE_FETCH_BYTE: begin
            _r_iic_enable = _w_fetcher_iic_enable;
            _r_iic_instruction = _w_fetcher_iic_inst;
            _r_iic_byte_to_send = _w_fetcher_iic_byte_to_send;
        end
        STATE_SHOW_BYTE: begin
            _r_iic_enable = _w_show_iic_enable;
            _r_iic_instruction = _w_show_iic_inst;
            _r_iic_byte_to_send = _w_show_iic_byte_to_send;
        end
        default: begin
            _r_iic_enable = 1'b0;
            _r_iic_instruction = `IIC_INST_UNKNOWN;
            _r_iic_byte_to_send = 4'd0;
        end
        endcase
    end

    reg _r_waitting_command;
    // always @(posedge in_clk) begin
    //     if (in_rst) begin
    //         _r_waitting_command <= 1'b0;
    //     end
    //     else if (_r_state != _r_next_state)
    //         _r_waitting_command <= 1'b0;
    //     else
    //         _r_waitting_command <= 1'b1;
    // end
    always @(*) begin
        _r_waitting_command = _r_state == _r_next_state ? 1'b1 : 1'b0;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_trigger_byte_fetch <= 1'b0;
            _r_trigger_show_tm1650 <= 1'b0;
        end
        else begin
            case(_r_state)
            STATE_IDLE: begin
                _r_trigger_byte_fetch <= 1'b0;
                _r_trigger_show_tm1650 <= 1'b0;
            end
            STATE_FETCH_BYTE: begin
                if (~_r_waitting_command) begin
                    _r_trigger_byte_fetch <= 1'b1;
                end
                else begin
                    _r_trigger_byte_fetch <= 1'b0;
                end
            end
            STATE_SHOW_BYTE: begin
                if (~_r_waitting_command) begin
                    _r_trigger_show_tm1650 <= 1'b1;
                end
                else begin
                    _r_trigger_show_tm1650 <= 1'b0;
                end
            end
            endcase
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH
module TOP_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_btn_s2;
    wire _w_iic_sda;
    wire _w_iic_scl;

    Top _inst_top(.in_clk(in_clk), .in_btn_s1(in_rst), .in_btn_s2(_r_btn_s2), .out_iic_scl(_w_iic_scl), .in_out_iic_sda(_w_iic_sda));

    initial begin
        _r_btn_s2 <= 1'b0;
    end

    reg [31:0] _r_counter;

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_btn_s2 <= 1'b1;
            _r_counter <= 32'd0;
        end
        else begin
            _r_counter <= _r_counter + 1;
            if (_r_counter[30] && |_r_counter[29:0] == 0)
                _r_btn_s2 <= 1;
            else
                _r_btn_s2 <= 0;
        end
    end

endmodule
`endif ///< DEBUG_TEST_BENCH

`endif