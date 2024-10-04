`ifndef IIC_PROXY_V
`define IIC_PROXY_V

`include "IIC.v"
`include "Mux.v"

/**
 * @brief IIC Proxy模块是一个结合了RAM和IIC功能的代理模块，它能够让用户RAM中设置IIC总线上执行命令所需的一切数据
 * 然后该Proxy负责完成对应的工作。从RAM读取数据发送到指定地址，或者从指定地址读取数据并写到RAM上
 * 该器件本身并不包含RAM，而是通过线路本身向外界的RAM发起数据读写操作
 *
 * @param in_clk 时钟信号
 * @param in_rst 复位信号
 * @param in_enable 使能信号
 * @return out_is_completed 指令是否已经执行完成 
 * @param in_mem_data 字节信号，连接外部的RAM模块
 * @return out_mem_data 输出字节信号，连接外部的RAM模块
 * @return out_mem_addr 输出字节地址信号，连接外部的RAM模块，外部RAM模块的宽度至少>=8
 * @return out_mem_write 输出RAM操作信号
 * @return out_mem_enable 输出RAM使能信号
 *
 * @note:
 *
 * Proxy协议：
 * 使能信号被拉高之后：
 * 0x0100: 读取指令
 * 0x0200: 指令参数1
 * 0x0300 ~ 0xFF00: 返回数据(读/写结果)
 *
 * 指令：
 * 1. 向A地址发送B个字节，带结束符
 *      0xA | 0x0, 0xB, data
 * 2. 向A地址发送B个字节，不带结束符
 *      0xA | 0x0, 0xB | 0x80, data
 * 3. 向A地址读取B个字节，带结束符
 *      0xA | 0x1, 0xB
 * 4. 向A地址读取B个字节，带结束符
 *      0xA | 0x1, 0xB | 0x80
 *
 * 简单概括就是参数是2个字节，其中
 * 第一个参数: 地址加读写操作符，按照IIC的地址规则即可
 *  [7:1] iic deivce address
 *  [0]: read(0) / write(1)
 * 第二个参数: 
 *  [7]: 是否要发送结束符
 *  [6:0]: 要发送的字节数
 *
 * 外部RAM的要求：
 *
 * 器件使用的RAM会假设它在一个时钟周期之后完成数据操作(无论读写)
 * out_mem_addr是8bit，即外部RAM至少需要8bit的宽度。
 * 返回的内存操作地址是一个**偏移**，外部器件根据需要对地址进行必要的**偏移计算**(必须通过组合逻辑完成以避免时序问题)以确定最终的地址
 * e.g. IIC的内存区域起始地址是0xA0，IICProxy返回的内存地址是0x01，那么需要访问的RAM地址是0xA0 + 0x01 = 0xA1
 */

module IICProxy (
    input wire in_clk,
    input wire in_rst,

    input wire in_enable,
    output wire out_is_completed,

    // 存储器输入输出
    input wire [7:0] in_mem_data,
    output wire [7:0] out_mem_data,
    output wire [7:0] out_mem_addr,
    output wire out_mem_write,
    output wire out_mem_enable,

    // IIC总线输入输出
    input wire in_sda_in,
    output wire out_sda_out,
    input wire in_scl_in,
    output wire out_scl,
    output wire out_sda_is_using,
    output wire out_scl_is_using

    , output wire out_debug_1
    , output wire out_debug_2
`ifdef DEBUG_TEST_BENCH
    , output wire d_out_iic_completed
`endif
);

    localparam IICPROXY_STATE_IDLE = 0;
    localparam IICPROXY_STATE_READ_PARAM1 = 1;
    localparam IICPROXY_STATE_READ_PARAM2 = 2;
    localparam IICPROXY_STATE_NOTIFY_IIC_BEG = 3;
    localparam IICPROXY_STATE_JUDGING = 4;
    localparam IICPROXY_STATE_WAITTING_IIC = 5;
    localparam IICPROXY_STATE_NOTIFY_IIC_END = 6;
    localparam IICPROXY_STATE_FINISH = 7;
    localparam IICPROXY_STATE_BUS_IS_BUSY = 8;

    localparam IICPROXY_STATE_BIT_WIDTH = 4;
    localparam IICPROXY_BIT_FOR_OP_BYTE_COUNT = 7;
    localparam IICPROXY_MAX_OP_BYTE_COUNT = 2 ** IICPROXY_BIT_FOR_OP_BYTE_COUNT;

    reg [IICPROXY_STATE_BIT_WIDTH - 1:0] _r_current_state;
    reg [IICPROXY_STATE_BIT_WIDTH - 1:0] _r_next_state;
    reg _r_out_is_completed;
    assign out_is_completed = _r_out_is_completed;
    reg _r_is_working;
    // >>> BEG: registers for IIC
    // vvv IIC控制信号相关数据
    reg [7:0] _r_iic_target_addr_and_read_write;
    wire _w_iic_is_read_request = _r_iic_target_addr_and_read_write[0];
    reg [IICPROXY_BIT_FOR_OP_BYTE_COUNT - 1:0] _r_iic_rest_op_bytes_count;
    reg [IICPROXY_BIT_FOR_OP_BYTE_COUNT - 1:0] _r_iic_opd_bytes_count; // operated bytes count
    
    reg _r_iic_should_ignore_end; // << 是否需要忽略停止信号
    reg _r_iic_have_sent_addr; // << 是否已经发送了地址
    reg _r_iic_have_sent_stop; // << 是否应该发送了停止信号

    wire _w_iic_bus_is_busy = ~in_scl_in && ~_w_iic_scl_is_using;

    reg _r_iic_enable;
    reg [7:0] _r_iic_byte_to_send;
    wire [7:0] _w_iic_byte_read;
    reg [7:0] _r_iic_byte_read;
    wire _w_iic_receive_ack;
    reg [2:0] _r_iic_instruction;
    wire _w_iic_is_completed;
    wire _w_iic_is_working;
    wire _w_iic_scl_is_using;
    wire _w_iic_sda_is_using;
    assign out_scl_is_using = _w_iic_scl_is_using | _r_is_working;
    assign out_sda_is_using = _w_iic_sda_is_using;
`ifdef DEBUG_TEST_BENCH
    assign d_out_iic_completed = _w_iic_is_completed;
`endif
    assign out_debug_1 = _w_iic_scl_is_using | _r_is_working;
    assign out_debug_2 = _w_iic_bus_is_busy;

    IIC _inst_iic(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_iic_enable)
        , .in_byte_to_send(_r_iic_byte_to_send)
        , .out_byte_read(_w_iic_byte_read)
        , .out_ack_read(_w_iic_receive_ack)
        , .in_instruction(_r_iic_instruction)
        , .out_is_completed(_w_iic_is_completed)
        , .out_is_working(_w_iic_is_working)
        , .in_sda_in(in_sda_in)
        , .out_sda_out(out_sda_out)
        , .out_scl(out_scl)
        , .out_sda_is_using(_w_iic_sda_is_using)
        , .out_scl_is_using(_w_iic_scl_is_using));

    // <<< END: registers for IIC

    // >>> BEG: registers for outside memory controller
    reg _r_out_mem_write;
    assign out_mem_write = _r_out_mem_write & _r_out_mem_enable; // << 以防万一，毕竟假如不需要使用mem，那么也不可能写

    reg _r_out_mem_enable;
    assign out_mem_enable = _r_out_mem_enable;

    reg [7:0] _r_out_mem_data;
    assign out_mem_data = _r_out_mem_data;

    reg [7:0] _r_out_mem_addr;
    assign out_mem_addr = _r_out_mem_addr;

    reg [7:0] _r_mem_read_data;
    // <<< END: registers for outside memory controller

    always @(*) begin
        _r_next_state = IICPROXY_STATE_IDLE;
        case(_r_current_state) 
        IICPROXY_STATE_IDLE: begin
            if (in_enable)
                _r_next_state = IICPROXY_STATE_READ_PARAM1;
            else
                _r_next_state = IICPROXY_STATE_IDLE;
        end
        IICPROXY_STATE_READ_PARAM1: begin
            _r_next_state = IICPROXY_STATE_READ_PARAM2;
        end
        IICPROXY_STATE_READ_PARAM2: begin
            _r_next_state = IICPROXY_STATE_NOTIFY_IIC_BEG;
        end
        IICPROXY_STATE_NOTIFY_IIC_BEG: begin
            _r_next_state = IICPROXY_STATE_WAITTING_IIC;
        end
        IICPROXY_STATE_WAITTING_IIC: begin
            if (_w_iic_is_completed)
                _r_next_state = IICPROXY_STATE_JUDGING;
            else
                _r_next_state = IICPROXY_STATE_WAITTING_IIC;
        end
        IICPROXY_STATE_JUDGING: begin
            if (_w_iic_bus_is_busy) begin
                _r_next_state = IICPROXY_STATE_BUS_IS_BUSY;
            end
            else if (!_r_iic_have_sent_addr) begin
                _r_next_state = IICPROXY_STATE_WAITTING_IIC;
            end
            else if (_r_iic_have_sent_stop) begin
                _r_next_state = IICPROXY_STATE_FINISH;
            end
            else if ((|_r_iic_rest_op_bytes_count)) begin
                _r_next_state = IICPROXY_STATE_WAITTING_IIC;
            end
            else if ((|_r_iic_rest_op_bytes_count) == 1'b0) begin
                _r_next_state = IICPROXY_STATE_NOTIFY_IIC_END;
            end
        end
        IICPROXY_STATE_NOTIFY_IIC_END: begin
            if (!_r_iic_should_ignore_end)
                _r_next_state = IICPROXY_STATE_WAITTING_IIC;
            else
                _r_next_state = IICPROXY_STATE_FINISH;
        end
        IICPROXY_STATE_FINISH: begin
            _r_next_state = IICPROXY_STATE_IDLE;
        end
        IICPROXY_STATE_BUS_IS_BUSY: begin
            if (_w_iic_bus_is_busy)
                _r_next_state = IICPROXY_STATE_BUS_IS_BUSY;
            else
                _r_next_state = IICPROXY_STATE_JUDGING;
        end
        endcase
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_current_state <= IICPROXY_STATE_IDLE;
        end
        else begin
            _r_current_state <= _r_next_state;
        end
    end

    task T_RESET_OUT_MEM_OP;
        begin
            _r_out_mem_write <= 1'b0;
            _r_out_mem_enable <= 1'b0;
        end
    endtask

    task T_Init_For_StateMachine;
        begin
            T_RESET_OUT_MEM_OP();
            _r_out_is_completed <= 1'b0;
            _r_iic_have_sent_addr <= 1'b0;
            _r_iic_have_sent_stop <= 1'b0;
            _r_iic_rest_op_bytes_count <= 0;
            _r_iic_opd_bytes_count <= 0;
        end
    endtask

    task T_READ_FOR_NEXT_BYTE;
        begin
            // 尝试读取下一个字节数据，用来准备下一次要开始发送的字节数据
            _r_out_mem_enable <= 1'b1;
            _r_out_mem_write <= 1'b0;
            _r_out_mem_addr <= _r_iic_opd_bytes_count + 2 + _r_iic_have_sent_addr;
        end
    endtask

    task T_WRITE_BYTE;
        begin
            _r_out_mem_enable <= 1'b1;
            _r_out_mem_write <= 1'b1;
            _r_out_mem_addr <= _r_iic_opd_bytes_count + 1;
        end
    endtask



    always @(posedge in_clk) begin
        if (in_rst) begin
            T_Init_For_StateMachine();
            _r_is_working <= 1'b0;
        end
        else begin
            if (_r_current_state != IICPROXY_STATE_IDLE
                && _r_current_state != IICPROXY_STATE_BUS_IS_BUSY)
                _r_is_working <= 1'b1;
            else
                _r_is_working <= 1'b0;

            case(_r_current_state)
            IICPROXY_STATE_IDLE: begin
                T_Init_For_StateMachine();    
            end
            IICPROXY_STATE_READ_PARAM1: begin
                _r_out_mem_write <= 1'b0; // Stand for read
                _r_out_mem_enable <= 1'b1;
                _r_out_mem_addr <= 8'd0; // try to read param 1
            end
            IICPROXY_STATE_READ_PARAM2: begin
                _r_iic_target_addr_and_read_write <= in_mem_data;
                _r_out_mem_write <= 1'b0;
                _r_out_mem_enable <= 1'b1;
                _r_out_mem_addr <= 8'd1; // try to read param 2
            end
            IICPROXY_STATE_NOTIFY_IIC_BEG: begin
                T_RESET_OUT_MEM_OP();
                _r_iic_rest_op_bytes_count <= in_mem_data[6:0];
                _r_iic_opd_bytes_count <= 0;
                _r_iic_should_ignore_end <= in_mem_data[7];
                _r_iic_instruction <= `IIC_INST_START_TX;
                _r_iic_enable <= 1'b1;
                _r_iic_have_sent_addr <= 1'b0;
            end
            IICPROXY_STATE_WAITTING_IIC: begin
                _r_iic_enable <= 1'b0;
                _r_iic_instruction <= `IIC_INST_UNKNOWN;
                // 假如当前正在尝试发送数据，那么在之前的状态(JUDGING)中已经发起过一次内存的读取操作
                // 这里将读取的结果缓存起来，用作下一次发送使用
                if (_r_out_mem_enable && !_w_iic_is_read_request) begin
                    _r_mem_read_data <= in_mem_data;
                end
                T_RESET_OUT_MEM_OP();
            end
            IICPROXY_STATE_JUDGING: begin
                if (_r_iic_have_sent_stop 
                    || (|_r_iic_rest_op_bytes_count == 1'b0)
                    || _w_iic_bus_is_busy) begin
                    // 只是在发送完结束信号后，暂时回到了这个状态
                    // 但我们已经完成了所有工作，因此不执行任何操作
                    // 又或者当前总线正忙，我们只是在等待
                end
                else begin
                    _r_iic_enable <= 1'b1;
                    if (!_r_iic_have_sent_addr) begin
                        _r_iic_have_sent_addr <= 1'b1;
                        _r_iic_instruction <= `IIC_INST_SEND_BYTE;
                        _r_iic_byte_to_send <= _r_iic_target_addr_and_read_write;
                        T_READ_FOR_NEXT_BYTE();
                    end
                    else begin
                        _r_iic_rest_op_bytes_count <= _r_iic_rest_op_bytes_count - 1;
                        _r_iic_opd_bytes_count <= _r_iic_opd_bytes_count + 1;
                        if (!_w_iic_is_read_request) begin // Write to IIC bus
                            _r_iic_instruction <= `IIC_INST_SEND_BYTE;
                            _r_iic_byte_to_send <= _r_mem_read_data;
                            T_READ_FOR_NEXT_BYTE();
                        end
                        else begin // Read from IIC bus
                            _r_iic_instruction <= `IIC_INST_RECV_BYTE;
                            if (|_r_iic_opd_bytes_count) begin
                                _r_out_mem_data <= _w_iic_byte_read;
                                T_WRITE_BYTE();
                            end
                        end
                    end
                end
                
            end
            IICPROXY_STATE_NOTIFY_IIC_END: begin
                // 保证最后一个IIC总线读取请求能够被正确写入到RAM中
                if (_w_iic_is_read_request) begin
                    _r_out_mem_data <= _w_iic_byte_read;
                    T_WRITE_BYTE();
                end
                if (!_r_iic_should_ignore_end) begin
                    _r_iic_enable <= 1'b1;
                    _r_iic_instruction <= `IIC_INST_STOP_TX;
                end
                _r_iic_have_sent_stop <= 1'b1;
            end
            IICPROXY_STATE_FINISH: begin
                T_RESET_OUT_MEM_OP();
                _r_out_is_completed <= 1'b1;
            end
            endcase
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH
// 一个简单的RAM，用来模拟IICProxy所使用的外部RAM
module FAKE_RAM_TB #(parameter DEPTH=8)(
    input wire in_clk,
    input wire in_rst,
    input wire in_write_enable,
    input wire [7:0] in_addr,
    input wire [7:0] in_data,
    output wire [7:0] out_data
);

    integer  i = 0;
    reg [7:0] _r_data [2 ** DEPTH - 1 : 0];

    assign out_data = _r_data[in_addr];

    always @(posedge in_clk) begin
        if (in_rst) begin
            for (i = 0; i < 2 ** DEPTH; i=i+1) begin
                _r_data[i] <= 8'd0;
            end
        end
        else begin
            if (in_write_enable) begin
                _r_data[in_addr] <= in_data;
            end
        end
    end

endmodule

// 测试IIC的读取功能，仿真时序
module IICPROXY_READ_WRITE_TB(
    input wire in_clk,
    input wire in_rst
);
    localparam TB_STATE_IDLE = 0;
    localparam TB_STATE_SETUP = 1;
    localparam TB_STATE_INVOKE = 2;
    localparam TB_STATE_WAITTING = 3;
    localparam TB_STATE_FINISH = 4;

    // >>> BEG: registers for Test Bench controll
    reg [2:0] _r_current_state;
    reg [2:0] _r_next_state;
    reg [2:0] _r_counter;
    reg [9:0] _r_counter_for_bus_busy;
    wire [7:0] _w_value = 8'b0101_1010;
    reg _r_try_to_read;
    reg _r_try_to_write;
    reg _r_wrote_addr;
    reg _r_wrote_byte_count;

    reg _r_write_ram_from_iicproxy; // << 用来控制当前到RAM的控制权应该属于当前模块(0)还是来自IICProxy(1)
    reg [7:0] _r_write_ram_addr;
    reg [7:0] _r_write_ram_data;
    reg _r_write_ram_write;
    reg _r_write_ram_enable;

    // <<< END: registers for Test Bench controll

    // >>> BEG: registers for IICProxy
    reg _r_iicproxy_enable;
    reg _r_iicproxy_sda_data;
    reg _r_iicproxy_scl_data;
    wire _w_iicproxy_is_completed;
    wire _w_iicproxy_mem_write;
    wire _w_iicproxy_mem_enable;
    wire [7:0] _w_iicproxy_mem_data;
    wire [7:0] _w_iicproxy_mem_addr;
    wire _w_iic_is_completed;
    // <<< END: registers for IICProxy

    // >>> BEG: variables for RAM
    wire _w_ram_write_enable;
    wire [7:0] _w_ram_addr;
    wire [7:0] _w_ram_input_data;
    wire [7:0] _w_ram_output_data;

    // 通过多路选择器的方式，将RAM的控制权分成来自本模块以及IICProxy模块
    Mux2To1 #(.WIDE(8)) _inst_mux2to1_ram_addr(.in_a(_w_iicproxy_mem_addr)
        , .in_b(_r_write_ram_addr)
        , .in_select(_r_write_ram_from_iicproxy)
        , .out(_w_ram_addr));
    Mux2To1 #(.WIDE(8)) _inst_mux2to1_ram_input_data(.in_a(_w_iicproxy_mem_data)
        , .in_b(_r_write_ram_data)
        , .in_select(_r_write_ram_from_iicproxy)
        , .out(_w_ram_input_data));
    Mux2To1 _inst_mux2to1_ram_write_enable(.in_a(_w_iicproxy_mem_write)
        , .in_b(_r_write_ram_write)
        , .in_select(_r_write_ram_from_iicproxy)
        , .out(_w_ram_write_enable));
    // <<< END: variables for RAM

    FAKE_RAM_TB _inst_fake_ram(.in_clk(in_clk), .in_rst(in_rst)
        , .in_write_enable(_w_ram_write_enable)
        , .in_addr(_w_ram_addr)
        , .in_data(_w_ram_input_data)
        , .out_data(_w_ram_output_data));

    IICProxy _inst_iic_proxy(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_iicproxy_enable)
        , .in_mem_data(_w_ram_output_data)
        , .in_sda_in(_r_iicproxy_sda_data)
        , .in_scl_in(_r_iicproxy_scl_data)
        , .out_is_completed(_w_iicproxy_is_completed)
        , .out_mem_data(_w_iicproxy_mem_data)
        , .out_mem_addr(_w_iicproxy_mem_addr)
        , .out_mem_write(_w_iicproxy_mem_write)
        , .out_mem_enable(_w_iicproxy_mem_enable)
        , .d_out_iic_completed(_w_iic_is_completed));

    initial begin
        _r_current_state <= TB_STATE_IDLE;
        _r_next_state <= TB_STATE_IDLE;
        _r_try_to_read <= 1'b1;
        _r_try_to_write <= 1'b0;
        _r_wrote_addr <= 1'b0;
        _r_wrote_byte_count <= 1'b0;
    end

    // 伪造sda数据
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_iicproxy_sda_data <= 1'b0;
            _r_iicproxy_scl_data <= 1'b0;
            _r_counter <= 3'd0;
            _r_counter_for_bus_busy <= 10'd0;
        end
        else if (_w_iic_is_completed) begin
            _r_iicproxy_sda_data <= _w_value[_r_counter];
            if (_r_counter == 3'd7) begin
                _r_iicproxy_scl_data <= 1'b0;
                _r_counter_for_bus_busy <= _r_counter_for_bus_busy + 1;
            end
            else
                _r_iicproxy_scl_data <= 1'b1;
            _r_counter <= _r_counter + 1;
        end
        else if (|_r_counter_for_bus_busy) begin
            _r_counter_for_bus_busy <= _r_counter_for_bus_busy + 1;
            if ((&_r_counter_for_bus_busy))
                _r_iicproxy_scl_data <= 1'b1;
        end
    end

    always @(posedge in_clk) begin
        if (in_rst)
            _r_current_state <= TB_STATE_IDLE;
        else
            _r_current_state <= _r_next_state;
    end

    always @(*) begin
        case (_r_current_state)
        TB_STATE_IDLE: begin
            if (_r_try_to_read || _r_try_to_write)
                _r_next_state = TB_STATE_SETUP;
            else
                _r_next_state = TB_STATE_IDLE;
        end
        TB_STATE_SETUP: begin
            // 准备写入请求相关的内容
            if (!_r_wrote_addr
                || !_r_wrote_byte_count)
                _r_next_state = TB_STATE_SETUP;
            else
                _r_next_state = TB_STATE_INVOKE;
        end
        TB_STATE_INVOKE: begin
            _r_next_state = TB_STATE_WAITTING;
        end
        TB_STATE_WAITTING: begin
            if (_w_iicproxy_is_completed)
                _r_next_state = TB_STATE_FINISH;
            else
                _r_next_state = TB_STATE_WAITTING;
        end
        TB_STATE_FINISH: begin
            _r_next_state = TB_STATE_IDLE;
        end
        endcase
    end

    task T_Init_For_StateMachine;
        begin
            _r_wrote_addr <= 1'b0;
            _r_wrote_byte_count <= 1'b0;
            _r_write_ram_from_iicproxy <= 1'b0;
            _r_write_ram_write <= 1'b0;
        end
    endtask

    always @(posedge in_clk) begin
        if (in_rst) begin
            T_Init_For_StateMachine();
        end
        else begin
            case (_r_current_state)
            TB_STATE_IDLE: begin
                T_Init_For_StateMachine();
            end
            TB_STATE_SETUP: begin
                if (!_r_wrote_addr) begin
                    _r_write_ram_write <= 1'b1;
                    _r_write_ram_addr <= 8'h00;
                    if (_r_try_to_read)
                        _r_write_ram_data <= 8'hA1;
                    else if (_r_try_to_write)
                        _r_write_ram_data <= 8'hB0;
                    _r_wrote_addr <= 1'b1;
                end
                else if (!_r_wrote_byte_count) begin
                    _r_write_ram_write <= 1'b1;
                    _r_write_ram_addr <= 8'h01;
                    _r_write_ram_data <= 8'h1F;
                    _r_wrote_byte_count <= 1'b1;
                end
            end
            TB_STATE_INVOKE: begin
                _r_write_ram_write <= 1'b0;
                _r_write_ram_from_iicproxy <= 1'b1; // << 切换权限，之后的RAM操作就由IICProxy来控制
                _r_iicproxy_enable <= 1'b1;
            end
            TB_STATE_WAITTING: begin
                _r_iicproxy_enable <= 1'b0;
            end
            TB_STATE_FINISH: begin
                if (_r_try_to_read) begin
                    _r_try_to_read <= 1'b0;
                    _r_try_to_write <= 1'b1;
                end
                if (_r_try_to_write)
                    _r_try_to_write <= 1'b0;
            end
            endcase
        end
    end

endmodule

`endif // DEBUG_TEST_BENCH

`endif // IIC_PROXY_V