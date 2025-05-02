`ifndef IIC_META_V
`define IIC_META_V

`define IIC_META_INST_START_TX 0
`define IIC_META_INST_STOP_TX 1
`define IIC_META_INST_SEND_BIT 2
`define IIC_META_INST_RECV_BIT 3
`define IIC_META_INST_UNKNOWN 4
`define IIC_META_INST_REPEAT_START_TX 5 // 只是作为内部FSM的一个状态指令，外部不应该直接使用这个命令
`define BIT_COUNT_OF_IIC_META_INST 3
// TODO: 接收开始和结束信号

`define IIC_SIG_IDLE 1'bz

/**
 * IIC的最基础元件，只负责Bit的传递，开始和结束信号的传递
 * @param in_clk 时钟信号
 * @param in_rst 复位信号
 * @param in_instruction 指令选择
 * @param in_bit_to_send 当指令是IIC_INST_SEND_BIT时，需要发送的bit
 * @return out_bit_read 当指令是IIC_INST_RECV_BIT时，接收到的bit
 * @param in_sda_in 从SDA线缆上接收到的信号
 * @return out_sda_out 向SDA线缆发送的信号
 * @return out_scl 向SCL线缆发送的信号
 * @return out_sda_is_using 表明当前sda线缆是否被占用(输出时占用)
 * @return out_scl_is_using 表明当前SCL线缆是否被占用(由于目前是作为控制器，因此理论上会被一直占用)
 * @return out_is_completed 指令是否执行完成
 
 * 这个器件将作为IIC总线控制器的最基础的原件，IIC总线的行为就是IIC_INST的4种。
 * Byte的发送和接收，ACK信号的发送和接收，以及通讯的开始和结束都可以由上面的几种指令组合而成

 * 使用方式和时序：
 * 1. 时钟上升沿将in_instruction置为需要执行的命令，否则请一直保持IIC_META_INST_UNKNOWN状态
 * 2. 当in_instruction被设置之后，将会进入执行阶段，期间修改in_instruction将无用
 * 3. in_instruction被修改成目标指令的同时，sda/scl将在**相同的时钟上升沿立即**开始产生有效信号
 * 4. 指令执行完成的时钟上升沿out_is_completed置为高电平，并在下一个时钟上升沿恢复低电平。当上层电路接收到out_is_completed置为高电平时
 * 4.1. 当前指令已经彻底执行完成，假如是连续任务，应该在此刻立即设置下一个指令及其所需的其它参数
 * 4.2. 假如指令是IIC_INST_SEND_BIT，那么需要发送的bit也应该在同时一并准备妥当
 * 4.3. 假如指令是IIC_INST_RECV_BIT，那么out_is_completed置为高电平的同时，out_bit_read也将会是读取到的电平
 * 4.4. 假如没有接收到任何指令，器件将回到Idle状态
 */

 /**
  * 1. 所有动作的执行最后，都必须要回到Unknown，去还原必要的状态。比方说SendBit这个动作，可能会连续执行8次，它的分频计数器就需要在每次
  * 执行完成后“归零”
  * 2. 当回到Unknown状态的时候，不要尝试还原sda/scl的状态，即便sda/scl的默认状态都是高电平。因为
    2.1 避免因为连续两个指令中间插入一个默认状态(高电平)而导致电平信号出现瞬间的跳变，特别是bit连续发送的过程中
    2.2 在默认状态只有在总线被释放了之后(Send_stop)才会被设置
  * 3. 外界设备在x个时钟上升沿设置了指令之后，x+1个时钟上升沿_r_instruct被设置为对应的指令，x+2个时钟上升沿，指令涉及的时序逻辑才正式生效
  * 假设接收指令时候的状态必然是Unknown：
  * 3.1 接收到的是StartTX:
  *     x: IS_UNKNOWN == 1; _r_instruction = unknown; _r_next_instruction = StartTX; _w_actual_instruction = StartTX; 按照Unknown来执行
  *     x + 1: IS_UNKNOWN == 1; _r_instruction = unknown; _w_actual_instruction = StartTX; 还是按照Unknown来执行
  *     x + 2: IS_UNKNOWN == 0; _r_instruction = StartTX; _w_actual_instruction = StartTX; 按照StartTX来执行
  * 3.2 接收到的是SendBit:
  *     x: IS_UNKNOWN == 1;
  */

module IICMeta(
    input wire in_clk,
    input wire in_rst,

    input wire [`BIT_COUNT_OF_IIC_META_INST - 1:0] in_instruction,
    input wire in_bit_to_send,
    output wire out_bit_read,

    input wire in_sda_in,
    output wire out_sda_out,
    output wire out_sda_is_using,

    input wire in_scl_in,
    output wire out_scl_out,
    output wire out_scl_is_using,

    output wire out_is_completed
);

    /**
     * 这个寄存器应该是用来对时钟进行分频的!相当于I2C器件中，自己带一个时钟分频器
     * 进而控制I2C总线上的时钟信号
     */
    reg [6:0] _r_clock_Divider = 0;
    
    reg _r_sda_out = 0; // 当前sda总线上要发送的bit
    // 这个是为了加速IICMeta对外界命令的响应而增加的寄存器
    // 它会在外界指令到达的同一时钟沿设置好要发送的值
    reg _r_sda_out_com; 
    assign out_sda_out = _r_sda_out_com;

    reg _r_is_sending = 0;
    reg _r_is_receving = 0;
    assign out_sda_is_using = _r_is_sending;

    reg _r_scl_out;
    // 这个是为了加速IICMeta对外界命令的响应而增加的寄存器
    // 它会在外界指令到达的同一时钟沿设置好要发送的值
    reg _r_scl_out_com;
    assign out_scl_out = _r_scl_out_com;
    wire _w_scl_in = in_scl_in;
    // 当前scl总线想输出高电平，但是输入却是低电平，说明正在被外界强行拉低
    wire _w_is_scl_force_low = _w_scl_in == 1'b0 && _r_scl_out_com == 1'b1;
    assign out_scl_is_using = (_r_is_sending || _r_is_receving);
    // 假如被外界强行拉低，或者没有被使用，缺处在低电平，说明可能发生了clock stretching
    wire _w_is_clock_stretching = _w_is_scl_force_low || (!out_scl_is_using && _w_scl_in == 1'b0);

    reg _r_is_completed;
    assign out_is_completed = _r_is_completed;

    reg [5:0] _r_received_sig_counter; // 用来接收到的信号情况
    
    reg _r_bit_to_send;
    reg _r_bit_read;
    assign out_bit_read = _r_bit_read;

    reg [`BIT_COUNT_OF_IIC_META_INST - 1:0] _r_instruction;
    reg [`BIT_COUNT_OF_IIC_META_INST - 1:0] _r_next_instruction;
    reg [`BIT_COUNT_OF_IIC_META_INST - 1:0] _r_prev_instruction;
`define IS_UNKONWN_INSTRUCTION (_r_instruction == `IIC_META_INST_UNKNOWN)
`define PREV_INST_IS_NEITHER_UNKNOWN_NOR_STOP (_r_prev_instruction != `IIC_META_INST_UNKNOWN && _r_prev_instruction != `IIC_META_INST_STOP_TX)
    // 为了加速指令的判断，因为指令的设置和指令真正被执行之间有一个始终的延迟，用这种方式，可以让外界设置的指令得到立即执行
    wire [`BIT_COUNT_OF_IIC_META_INST - 1:0] _w_actual_instruction = `IS_UNKONWN_INSTRUCTION ? in_instruction : _r_instruction;

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_instruction <= `IIC_META_INST_UNKNOWN;
        end
        else begin
            _r_instruction <= _r_next_instruction;
        end
    end

    // >>> 为了避免_r_bit_to_send被综合成Latch进行的特殊处理
    // 希望_r_bit_to_send可以立即响应用户的指令，即用户在时钟上升沿设置了bit之后，几乎同一时刻_r_bit_to_send立即配置为相同的值
    // 且之后无论用户如何修改in_bit_to_send，_r_bit_to_send都可以缓存最初的值
    reg _r_bit_to_send_clk;
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_bit_to_send_clk <= 1'b1;
        end
        else if (_r_instruction == `IIC_META_INST_UNKNOWN)
            _r_bit_to_send_clk <= in_bit_to_send;
        else
            _r_bit_to_send_clk <= _r_bit_to_send_clk;
    end

    always @(*) begin
        if (_r_instruction == `IIC_META_INST_UNKNOWN)
            _r_bit_to_send = in_bit_to_send;
        else
            _r_bit_to_send = _r_bit_to_send_clk;
    end
    // <<< 为了避免_r_bit_to_send被综合成Latch进行的特殊处理

    // 在状态即将发生切换的时候，记录上一次执行的指令，用来在发起repeat start的时候控制起始scl/sda信号
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_prev_instruction <= `IIC_META_INST_UNKNOWN;
        end
        else if (_r_instruction != `IIC_META_INST_UNKNOWN && _r_next_instruction == `IIC_META_INST_UNKNOWN)
            _r_prev_instruction <= _r_instruction;
    end

    // _r_next_instruction的状态转移逻辑
    always @(*) begin
        if (in_rst) begin
            _r_next_instruction = `IIC_META_INST_UNKNOWN;
        end
        else begin
            case (_r_instruction)
            `IIC_META_INST_UNKNOWN: begin
                // 当前处于空闲状态，可以用外部传入的in_instruction来设置_r_next_instruction
                _r_next_instruction = in_instruction;
                if (in_instruction == `IIC_META_INST_START_TX) begin
                    if (`PREV_INST_IS_NEITHER_UNKNOWN_NOR_STOP) begin
                        // 首次“发送信号”，总线的默认状态为高电平，因此可以直接拉低
                        // 重复“发送信号”，总线的状态为低电平，需要保证scl时钟数和之前的一致，以及正确地拉高电平
                        _r_next_instruction = `IIC_META_INST_REPEAT_START_TX;
                    end
                end
                // Note: 没有在这里设置_r_prev_instruction，因为所有指令最后都会回到这里做下一个指令切换，_r_prev_instruction应该在其它指令里设置
            end
            `IIC_META_INST_START_TX: begin
                if (_r_is_completed) begin
                    _r_next_instruction = `IIC_META_INST_UNKNOWN;
                end
                else
                    _r_next_instruction = `IIC_META_INST_START_TX;
            end
            `IIC_META_INST_STOP_TX: begin
                if (_r_is_completed) begin
                    _r_next_instruction = `IIC_META_INST_UNKNOWN;
                end
                else
                    _r_next_instruction = `IIC_META_INST_STOP_TX;
            end
            `IIC_META_INST_SEND_BIT: begin
                if (_r_is_completed) begin
                    _r_next_instruction = `IIC_META_INST_UNKNOWN;
                end
                else
                    _r_next_instruction = `IIC_META_INST_SEND_BIT;
            end
            `IIC_META_INST_RECV_BIT: begin
                if (_r_is_completed) begin
                    _r_next_instruction = `IIC_META_INST_UNKNOWN;
                end
                else
                    _r_next_instruction = `IIC_META_INST_RECV_BIT;
            end
            `IIC_META_INST_REPEAT_START_TX: begin
                if (_r_is_completed) begin
                    _r_next_instruction = `IIC_META_INST_UNKNOWN;
                end
                else
                    _r_next_instruction = `IIC_META_INST_REPEAT_START_TX;
            end
            default:
                _r_next_instruction = `IIC_META_INST_UNKNOWN;
            endcase
        end
    end

    // 根据当前输入的命令，设置状态寄存器以及sda/scl输出关联的寄存器情况
    always @(*) begin
        _r_is_sending = 1'b0;
        _r_is_receving = 1'b0;
        _r_sda_out_com = 1'bz;
        _r_scl_out_com = 1'bz;
        case (_w_actual_instruction)
        `IIC_META_INST_UNKNOWN: begin
            _r_sda_out_com = _r_sda_out;
            _r_scl_out_com = _r_scl_out;
        end
        `IIC_META_INST_SEND_BIT: begin
            _r_is_sending = 1'b1;
            _r_sda_out_com = _r_bit_to_send;
            _r_scl_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b0 : _r_scl_out;
        end
        `IIC_META_INST_RECV_BIT: begin
            _r_is_receving = 1'b1;
            _r_scl_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b0 : _r_scl_out;
        end
        `IIC_META_INST_START_TX: begin
            // 这里在假设执行StartTX之前，总线都处在高电平状态
            _r_is_sending = 1'b1;
            _r_sda_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b1 : _r_sda_out;
            _r_scl_out_com = `IS_UNKONWN_INSTRUCTION ? (`PREV_INST_IS_NEITHER_UNKNOWN_NOR_STOP ? 1'b0 : 1'b1) : _r_scl_out;
        end
        `IIC_META_INST_STOP_TX: begin
            // 这里在假设执行StopTX之前，总线处在低电平状态
            // 因为之前发送bit的指令，最后都会将scl总线拉到低电平，stop之前肯定是它
            _r_is_sending = 1'b1;
            _r_sda_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b0 : _r_sda_out;
            _r_scl_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b0 : _r_scl_out;
        end
        `IIC_META_INST_REPEAT_START_TX: begin
            // 这里在假设执行Repeat StartTX之前，总线处在低电平状态
            _r_is_sending = 1'b1;
            _r_sda_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b1 : _r_sda_out;
            _r_scl_out_com = `IS_UNKONWN_INSTRUCTION ? 1'b0 : _r_scl_out;
        end
        endcase
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_sda_out <= `IIC_SIG_IDLE;
            _r_scl_out <= `IIC_SIG_IDLE;
            _r_clock_Divider <= 7'd1;
            _r_bit_read <= 1'b0;
        end
        else if (_w_is_clock_stretching) begin
            // 假如当前检查到处在clock stretching状态，则将计数器重置，目的是让bit/开始/结束重新发送
            _r_clock_Divider <= 7'd2;
        end
        else begin
            case (_r_instruction)
            `IIC_META_INST_UNKNOWN: begin
                /**
                 * clock的初始值之所以是2，是因为
                 * 1. 时钟的初始值从1开始计算，0代表128.
                 * 2. [第0个时钟周期] 从上层器件设置instruction开始，sda/scl总线就已经开始工作。而时序电路会慢一个tick，因此从2开始
                 */
                _r_clock_Divider <= 7'd2;
                _r_sda_out <= `IIC_SIG_IDLE;
                _r_scl_out <= `IIC_SIG_IDLE;
                _r_bit_read <= 1'b0;
                // 以下行为是为了保证在_r_instruction即将被修改的时候，能够提前执行scl/sda状态，核心是提高响应速度
                if (_r_next_instruction == `IIC_META_INST_START_TX) begin
                    _r_scl_out <= 1'b1;
                    _r_sda_out <= 1'b1;
                end
                else if (_r_next_instruction == `IIC_META_INST_STOP_TX) begin
                    _r_scl_out <= 1'b0;
                    _r_sda_out <= 1'b0;
                end
                else if (_r_next_instruction == `IIC_META_INST_SEND_BIT) begin
                    _r_scl_out <= 1'b0;
                end
                else if (_r_next_instruction == `IIC_META_INST_RECV_BIT) begin
                    _r_scl_out <= 1'b0;
                end
            end
            `IIC_META_INST_START_TX: begin
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                if (_r_clock_Divider[6:5] == 2'b00) begin /// 最初阶段，将scl和sda总线都拉高，其实是在还原初始状态
                    _r_scl_out <= 1;
                    _r_sda_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01) begin /// 第二阶段，将sda总线拉低
                    _r_sda_out <= 0;
                end
                else if (_r_clock_Divider[6:5] == 2'b10) begin /// 第三阶段，将scl总线拉低
                    _r_scl_out <= 0;
                end
            end
            `IIC_META_INST_REPEAT_START_TX: begin
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                if (_r_clock_Divider[6:5] == 2'b00) begin /// 最初阶段，将scl和sda总线都拉高，其实是在还原初始状态
                    _r_scl_out <= 0;
                    _r_sda_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01) begin /// 第二阶段，将sda总线拉低
                    _r_scl_out <= 1;
                    _r_sda_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b10) begin /// 第三阶段，将scl总线拉低
                    _r_scl_out <= 1;
                    _r_sda_out <= 0;
                end
                else if (_r_clock_Divider[6:5] == 2'b11) begin
                    _r_scl_out <= 0;
                    _r_sda_out <= 0;
                end
            end
            `IIC_META_INST_STOP_TX: begin
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                if (_r_clock_Divider[6 : 5] == 2'b00) begin /// 最初阶段，将scl和sda总线拉低
                    _r_scl_out <= 0;
                    _r_sda_out <= 0;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b01) begin /// 第二阶段，将scl总线拉高
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b10) begin /// 第三阶段，将sda总线也拉高
                    _r_sda_out <= 1;
                end
            end
            `IIC_META_INST_SEND_BIT: begin
                // 这个地方要循环8次，它是通过让_r_clock_Divider溢出以实现重新计时的功能
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                _r_sda_out <= _r_bit_to_send;

                /// 在整个发送过程中，其实sda的数据已经“建立”好了，所以下面各阶段并没有操作sda
                if (_r_clock_Divider[6 : 5] == 2'b00) begin /// 一阶段先拉低时钟
                    _r_scl_out <= 0;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin /// 二三阶段维持时钟为高电平
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b11) begin /// 最后拉低时钟，说明这个bit发送完成
                    _r_scl_out <= 0;
                end
            end
            `IIC_META_INST_RECV_BIT: begin
                // TODO: 目前假设自己就是控制器，因此从总线上读取，也是要发起时钟信号
                _r_clock_Divider <= _r_clock_Divider + 7'd1;

                if (_r_clock_Divider[6:5] == 2'b00) begin
                    _r_received_sig_counter <= 5'd0;
                    _r_scl_out <= 0;
                end
                else if (_r_clock_Divider[6:0] == 7'b010_0000) begin
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin
                    _r_scl_out <= 1;
                    _r_received_sig_counter <= _r_received_sig_counter + in_sda_in;
                end
                else if (_r_clock_Divider[6:5] == 2'b11) begin
                    _r_scl_out <= 0;
                    _r_bit_read <= _r_received_sig_counter[5];
                end
            end
            endcase
        end
    end

    // 提前一个时钟周期发起_r_is_completed信号
    // 这样在指令真正执行完最后一个scl时钟周期后的第一个clk上升沿
    // 外部器件可以立即开始设置instruction以及send_bit的值
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_is_completed <= 1'b0;
        end
        else begin
            _r_is_completed <= 1'b0;
            case (_r_instruction)
            `IIC_META_INST_START_TX, `IIC_META_INST_STOP_TX: begin
                if (_r_clock_Divider == 7'b11_00000 - 1) begin
                    _r_is_completed <= 1'b1;
                end
            end
            `IIC_META_INST_SEND_BIT, `IIC_META_INST_RECV_BIT, `IIC_META_INST_REPEAT_START_TX: begin
                if (_r_clock_Divider == 7'b11_11111) begin // 这里没有'-1'，是因为它们的结束值是00_00000(溢出)
                    _r_is_completed <= 1'b1;
                end
            end
            endcase
        end
    end

`undef IS_UNKONWN_INSTRUCTION
endmodule


`ifdef DEBUG_TEST_BENCH

// 测试IIC的bit以及信号发送接收功能，仿真时序
module IICMeta_TB(
    input wire in_clk,
    input wire in_rst
);

    reg [`BIT_COUNT_OF_IIC_META_INST - 1:0] _r_instruction;
    reg [`BIT_COUNT_OF_IIC_META_INST - 1:0] _r_next_instruction;
    wire _w_is_completed;
    reg _r_bit_to_send = 1'b0;
    reg [2:0] _r_next_bit_index;
    reg [1:0] _r_repeat_start_time;
    reg _r_try_receive;
    wire [7:0] _w_byte_to_send = 8'b1010_0101;
    wire _w_sda_in = 1'b1;

    IICMeta _inst (.in_clk(in_clk), .in_rst(in_rst)
        , .in_bit_to_send(_r_bit_to_send)
        , .in_instruction(_r_instruction)
        , .in_sda_in(_w_sda_in)
        , .out_is_completed(_w_is_completed));

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_instruction <= `IIC_META_INST_START_TX;
            _r_next_bit_index <= 3'd0;
            _r_repeat_start_time <= 2'd0;
            _r_try_receive <= 1'b0;
        end
        else begin
            _r_instruction <= _r_next_instruction;
            if (_r_next_instruction == `IIC_META_INST_SEND_BIT) begin
                _r_bit_to_send <= _w_byte_to_send[_r_next_bit_index];
                if (_w_is_completed)
                    _r_next_bit_index <= _r_next_bit_index + 1;
            end
            else if (_r_next_instruction == `IIC_META_INST_RECV_BIT) begin
                _r_repeat_start_time <= _r_repeat_start_time + 1;
            end
        end
    end

    always @(*) begin
        case (_r_instruction)
        `IIC_META_INST_UNKNOWN: begin
            _r_next_instruction = `IIC_META_INST_UNKNOWN;
        end
        `IIC_META_INST_START_TX: begin
            if (_w_is_completed) begin
                if (_r_try_receive) begin
                    _r_next_instruction = `IIC_META_INST_RECV_BIT;
                end
                else begin
                    _r_next_instruction = `IIC_META_INST_SEND_BIT;
                end
            end
            else begin
                _r_next_instruction = `IIC_META_INST_START_TX;
            end
        end
        `IIC_META_INST_SEND_BIT: begin
            if (_w_is_completed) begin
                if (_r_next_bit_index == 3'd0) begin
                    _r_next_instruction = `IIC_META_INST_RECV_BIT;
                end
                else begin
                    _r_next_instruction = `IIC_META_INST_SEND_BIT;
                end
            end
            else begin
                _r_next_instruction = `IIC_META_INST_SEND_BIT;
            end
        end
        `IIC_META_INST_RECV_BIT: begin
            if (_w_is_completed) begin
                if (_r_repeat_start_time == 2'd1) begin
                    _r_next_instruction = `IIC_META_INST_STOP_TX;
                end
                else begin
                    _r_next_instruction = `IIC_META_INST_START_TX;
                end
            end
            else begin
                _r_next_instruction = `IIC_META_INST_RECV_BIT;
            end
        end
        `IIC_META_INST_STOP_TX: begin
            if (_w_is_completed) begin
                _r_next_instruction = `IIC_META_INST_START_TX;
            end
            else begin
                _r_next_instruction = `IIC_META_INST_STOP_TX;
            end
        end
        endcase
    end

    // IIC_META_INST_START_TX
    

endmodule

`endif // DEBUG_TEST_BENCH

`endif // IIC_META_V