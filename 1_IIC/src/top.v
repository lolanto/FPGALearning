`ifndef TOP_V
`define TOP_V
`include "EncapsulatedIO.v"
`include "EdgeDetection.v"
`include "DecimalAdder.v"
`include "Debouncer.v"

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
module I2C_TM1650_DECIMAL_TO_BYTE(
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
    output wire out_err_led,
    output wire [3:0] out_values
);

    localparam TM1650_CONTROL_ADDRESS = 8'h24;
    localparam TM1650_LIGHTING_CMD_BYTE = 8'h15;

    wire _w_rst = in_btn_s1;

    wire _w_add_trigger;

`ifdef DEBUG_TEST_BENCH
    assign _w_add_trigger = in_btn_s2;
`else
    Debouncer _inst_debouncer(.in_clk(in_clk), .in_sig(in_btn_s2), .out_sig_up(_w_add_trigger));
`endif

    reg [3:0] _r_values[3:0];
    assign out_values = _r_values[0];
    wire [3:0] _w_add_results[3:0];
    wire _w_carries[3:0];
    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin : decimal_adder_insts
            if (i == 0) begin
                DecimalAdder _inst_da(.in_carry(1'b1), .in_v1(_r_values[i]), .in_v2(4'b0000)
                    , .out_result(_w_add_results[i]), .out_carry(_w_carries[i]));
            end
            else begin
                DecimalAdder _inst_da(.in_carry(_w_carries[i - 1]), .in_v1(_r_values[i]), .in_v2(4'b0000)
                    , .out_result(_w_add_results[i]), .out_carry(_w_carries[i]));
            end
        end
    endgenerate

    wire _w_err_state;    
    wire _w_in_iic_sda = in_out_iic_sda;
    wire _w_out_iic_sda;
    wire _w_iic_is_sending;
    reg _r_send_enable;
    reg _r_data_sig;
    reg [6:0] _r_device_address;
    reg [7:0] _r_data;
    wire _w_eiic_is_busy;
    EncapsulatedIIC _inst_EIIC(.in_clk(in_clk), .in_rst(_w_rst)
        , .in_send_enable(_r_send_enable)
        , .in_data_sig(_r_data_sig)
        , .in_device_address(_r_device_address)
        , .in_write_data(_r_data)
        , .out_is_busy(_w_eiic_is_busy)
        , .in_iic_sda(_w_in_iic_sda)
        , .out_iic_scl(out_iic_scl)
        , .out_iic_sda(_w_out_iic_sda)
        , .out_iic_is_sending(_w_iic_is_sending)
        , .out_err_state(_w_err_state)
    );
    assign in_out_iic_sda = ~_w_iic_is_sending ? 1'bz : _w_out_iic_sda;
    assign out_err_led = ~_w_err_state;

    localparam STATE_IDLE = 0;
    localparam STATE_UPDATE_DECIMAL_VALUE = 6;
    localparam STATE_SEND_SIG = 1; ///< 准备数据
    localparam STATE_SEND_ADDR = 2; ///< 设置发起地址，开始发送信号
    localparam STATE_SEND_DATA = 3; ///< 填充发送数据
    localparam STATE_FINISH_SEND_DATA = 5; ///< 完成当前的数据发送
    localparam STATE_SEND_WAIT = 4; ///< 等待发送完毕

    reg [2:0] _r_current_state;
    reg [2:0] _r_next_state;
    reg _r_setup_tm1650;
    reg [2:0] _r_digit_count;

    reg [7:0] _r_value_to_send;
    reg [7:0] _r_addr_to_send;
    wire [7:0] _w_TM1650_digit_byte;
    wire [7:0] _w_TM1650_digit_addr;
    I2C_TM1650_BIT_ADDRESS _inst_tm1650_bit_address(.in_index(_r_digit_count[1:0]), .out_address(_w_TM1650_digit_addr));
    I2C_TM1650_DECIMAL_TO_BYTE _inst_tm1650_bit_byte(.in_decimal(_r_values[_r_digit_count]), .out_byte(_w_TM1650_digit_byte));

    always @(posedge in_clk) begin
        if(_w_rst)
            _r_current_state <= STATE_IDLE;
        else
            _r_current_state <= _r_next_state;
    end

    always @(*) begin
        _r_next_state = STATE_IDLE;
        case (_r_current_state)
        STATE_IDLE: begin
            if (_w_add_trigger) begin
                _r_next_state = STATE_UPDATE_DECIMAL_VALUE;
            end
            else begin
                _r_next_state = STATE_IDLE;
            end
        end
        STATE_UPDATE_DECIMAL_VALUE : begin
            _r_next_state = STATE_SEND_SIG;
        end
        STATE_SEND_SIG: begin
            _r_next_state = STATE_SEND_ADDR;
        end
        STATE_SEND_ADDR: begin
            _r_next_state = STATE_SEND_DATA;
        end
        STATE_SEND_DATA: begin
            _r_next_state = STATE_FINISH_SEND_DATA;
        end
        STATE_FINISH_SEND_DATA: begin
            _r_next_state = STATE_SEND_WAIT;
        end
        STATE_SEND_WAIT: begin
            if (~_w_eiic_is_busy) begin
                if (_r_digit_count == 3'd4)
                    _r_next_state = STATE_IDLE;
                else
                    _r_next_state = STATE_SEND_SIG;
            end
            else
                _r_next_state = STATE_SEND_WAIT;
        end
        endcase
    end

    always @(posedge in_clk) begin : FSM
        integer i;
        if (_w_rst) begin
            _r_setup_tm1650 <= 1'b0;
            for(i = 0; i < 4; i = i + 1) begin
                _r_values[i] <= 4'd0;
            end
        end
        else begin
            case(_r_current_state)
            STATE_IDLE: begin
                _r_digit_count <= 0;
                _r_data_sig <= 0;
                _r_send_enable <= 0;
            end
            STATE_UPDATE_DECIMAL_VALUE: begin
                for(i = 0; i < 4; i = i + 1) begin
                    _r_values[i] <= _w_add_results[i];
                end
            end
            STATE_SEND_SIG: begin
                if (_r_setup_tm1650 == 0) begin
                    _r_addr_to_send <= TM1650_CONTROL_ADDRESS;
                    _r_value_to_send <= TM1650_LIGHTING_CMD_BYTE;
                end
                else begin
                    _r_addr_to_send <= _w_TM1650_digit_addr;
                    _r_value_to_send <= _w_TM1650_digit_byte;
                end
            end
            STATE_SEND_ADDR: begin
                _r_send_enable <= 1'b1;
                _r_device_address <= _r_addr_to_send[6:0];
            end
            STATE_SEND_DATA: begin
                _r_data_sig <= 1'b1;
                _r_data <= _r_value_to_send;
            end
            STATE_FINISH_SEND_DATA: begin
                _r_data_sig <= 1'b0;
                _r_send_enable <= 1'b0;
                if (_r_setup_tm1650 != 0)
                    _r_digit_count <= _r_digit_count + 1'b1;
                _r_setup_tm1650 <= 1;
            end
            STATE_SEND_WAIT: begin
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
            if (_r_counter[10] && |_r_counter[9:0] == 0)
                _r_btn_s2 <= 1;
            else
                _r_btn_s2 <= 0;
        end
    end

endmodule
`endif ///< DEBUG_TEST_BENCH

`endif