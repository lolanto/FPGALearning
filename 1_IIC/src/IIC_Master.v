`ifndef IIC_MASTER_V
`define IIC_MASTER_V

/**
 * @brief IIC总线 主机端控制器
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_enable 设备使能。只有当使能被拉高的时候，in_instruction才会被处理
 * @param in_byte_to_send 需要向外发送的字节，假如是首个带读写操作的指令，也需要填写对应的bit
 * @return out_byte_read 读取到的字节
 * @return out_ack_read 作为发送方时读取到的ack信号值
 * @param in_instruction 当前要执行的I2C操作：开始传输/发送字节/接收字节/结束传输
 * @param in_sda_in 外部sda总线的输入
 * @return out_sda_out 外部sda总线的输出
 * @param in_scl_in 外部scl总线的输入
 * @return out_scl_out 外部scl总线的输出
 * @return out_sda_is_using sda总线是否正在被该器件使用
 * @return out_scl_is_using scl总线是否正在被该器件使用
 * @return out_is_completed 当前指令是否执行完成
 * @return out_is_working 当前器件是否正在工作
 * @return out_is_clock_stretching 当前是否处在时钟拉伸状态
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
`define IIC_INST_REPEAT_START_TX `IIC_INST_START_TX + 1 //< 发送重复开始信号
`define IIC_INST_STOP_TX `IIC_INST_REPEAT_START_TX + 1 //< 发送结束信号
`define IIC_INST_RECV_BYTE `IIC_INST_STOP_TX + 1 //< 接收一个字节信息，并返回ACK信号
`define IIC_INST_SEND_BYTE `IIC_INST_RECV_BYTE + 1 //< 发送一个字节信息，并等待ACK信号

// Note: 各种"准备"状态存在的意义是对接下来的指令执行进行初始化，其存在的目的
// 是为了在进行连续指令执行时，可以绕过Complete -> Idle -> command的延迟
// 所有的"准备"状态，都只会存在一个Tick
`define IIC_STATE_IDLE 0

`define IIC_STATE_PRE_SEND_START `IIC_STATE_IDLE + 1 //< 准备发送开始信号
`define IIC_STATE_SENDING_START `IIC_STATE_PRE_SEND_START + 1 //< 正在发送开始信号

`define IIC_STATE_PRE_SEND_REPEAT_START `IIC_STATE_SENDING_START + 1 //< 准备发送重复开始信号
`define IIC_STATE_SENDING_REPEAT_START `IIC_STATE_PRE_SEND_REPEAT_START + 1 //< 正在发送重复开始信号

`define IIC_STATE_PRE_SEND_STOP `IIC_STATE_SENDING_REPEAT_START + 1 //< 准备发送结束信号
`define IIC_STATE_SENDING_STOP `IIC_STATE_PRE_SEND_STOP + 1 //< 正在发送结束信号

`define IIC_STATE_PRE_SEND_BYTE `IIC_STATE_SENDING_STOP + 1 //< 准备发送字节信息
`define IIC_STATE_SENDING_BYTE `IIC_STATE_PRE_SEND_BYTE + 1 //< 正在发送字节信息

`define IIC_STATE_PRE_RECV_BYTE `IIC_STATE_SENDING_BYTE + 1 //< 准备接收字节信息
`define IIC_STATE_RECVING_BYTE `IIC_STATE_PRE_RECV_BYTE + 1 //< 正在接收字节信息

`define IIC_STATE_SENDING_ACK `IIC_STATE_RECVING_BYTE + 1 //< 正在发送ACK信号
`define IIC_STATE_RECVING_ACK `IIC_STATE_SENDING_ACK + 1 //< 正在接收ACK信号
`define IIC_STATE_COMPLETE `IIC_STATE_RECVING_ACK + 1 //< 当前指令已经完成

`define IIC_PRE_COMPLETE_SIGNAL 7'd3

module IIC_Master(
    input wire in_clk,
    input wire in_rst,
    input wire in_enable,

    input wire [7:0] in_byte_to_send,
    output wire [7:0] out_byte_read,
    output wire out_ack_read, 
    input wire [2:0] in_instruction,

    input wire in_sda_in,
    output wire out_sda_out,

    input wire in_scl_in,
    output wire out_scl_out,

    output wire out_sda_is_using,
    output wire out_scl_is_using,

    output wire out_is_completed,
    output wire out_is_working,
    output wire out_is_clock_stretching
);
    reg [2:0] _r_instruction; // 模块被使能后接收到的指令
    reg [3:0] _r_state = `IIC_STATE_IDLE; // 当前状态
    reg [3:0] _r_next_state; // 下一个状态
    reg [3:0] _r_bit_index_to_process = 4'b0_111; // 当前要发送的bit的索引，注意，I2C是从高位开始发送的!
    reg [7:0] _r_byte_to_process; // 当前要发送的字节
    reg [6:0] _r_clock_Divider = 7'd0; // 时钟分频器，计数到0时，表示可以发送下一个bit

    assign out_byte_read = _r_byte_to_process;

    reg _r_is_completed;
    assign out_is_completed = _r_is_completed;
    reg _r_is_working;
    assign out_is_working = _r_is_working;

    reg _r_ack_read;
    assign out_ack_read = _r_ack_read;
    
    wire _w_bit_read;

    reg _r_sda_is_using;
    assign out_sda_is_using = _r_sda_is_using;

    reg _r_sda_out;
    assign out_sda_out = _r_sda_is_using ? _r_sda_out : 1'bz; // 如果sda总线正在被使用，则输出sda_out，否则输出高阻态

    reg _r_scl_is_using;
    assign out_scl_is_using = _r_scl_is_using;

    reg _r_scl_out;
    assign out_scl_out = _r_scl_is_using ? _r_scl_out : 1'bz; // 如果scl总线正在被使用，则输出scl_out，否则输出高阻态


    reg [5:0] _r_received_sig_counter; // 负责接受bit数据，通过统计sda总线上有多少个1来判断当前接收到的bit是0还是1


    reg _r_is_clock_stretching; // 是否正在进行时钟拉伸
    always @(*) begin
        _r_is_clock_stretching = out_scl_is_using && (out_scl_out == 1) && (in_scl_in == 0);
    end
    assign out_is_clock_stretching = _r_is_clock_stretching; // 输出时钟拉伸状态


    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_instruction <= `IIC_INST_UNKNOWN;
        end
        else if (in_enable) begin
            _r_instruction <= in_instruction;
        end
    end

/**********************状态转移********************************************************/
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state <= `IIC_STATE_IDLE;
        end
        else begin
            _r_state <= _r_next_state; // 更新状态
        end
    end
/**************************************************************************************/
/**********************状态转移判断逻辑*************************************************/
    function [3:0] f_get_next_state_according_to_instruction;
        input _f_in_enable;
        input [2:0] _f_in_instruction;
    begin
        if (_f_in_enable && _f_in_instruction != `IIC_INST_UNKNOWN) begin
            case (_f_in_instruction)
                `IIC_INST_START_TX: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_PRE_SEND_START;
                end
                `IIC_INST_REPEAT_START_TX: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_PRE_SEND_REPEAT_START;
                end
                `IIC_INST_STOP_TX: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_PRE_SEND_STOP;
                end
                `IIC_INST_RECV_BYTE: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_PRE_RECV_BYTE;
                end
                `IIC_INST_SEND_BYTE: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_PRE_SEND_BYTE;
                end
                default: begin
                    f_get_next_state_according_to_instruction = `IIC_STATE_IDLE; // 未知指令，回到空闲状态
                end
            endcase
        end
        else begin
            f_get_next_state_according_to_instruction = `IIC_STATE_IDLE;
        end
    end
    endfunction

    always @(*) begin
        case (_r_state)
        `IIC_STATE_IDLE: begin
            _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
        end
        // Start
        `IIC_STATE_PRE_SEND_START: begin
            _r_next_state = `IIC_STATE_SENDING_START;
        end
        `IIC_STATE_SENDING_START: begin
            if (_r_clock_Divider == 7'b11_00000) begin
                if (in_enable && in_instruction) begin
                    _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
                end
                else begin
                    _r_next_state = `IIC_STATE_COMPLETE; // 发送完成，进入完成状态
                end
            end
            else begin
                _r_next_state = `IIC_STATE_SENDING_START; // 保持当前状态，直到发送完成
            end
        end
        // Repeat Start
        `IIC_STATE_PRE_SEND_REPEAT_START: begin
            _r_next_state = `IIC_STATE_SENDING_REPEAT_START;
        end
        `IIC_STATE_SENDING_REPEAT_START: begin
            if (_r_clock_Divider == 7'b00_00000) begin
                if (in_enable && in_instruction) begin
                    _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
                end
                else begin
                    _r_next_state = `IIC_STATE_COMPLETE; // 发送完成，进入完成状态
                end
            end
            else begin
                _r_next_state = `IIC_STATE_SENDING_REPEAT_START; // 保持当前状态，直到发送完成
            end
        end
        // Stop
        `IIC_STATE_PRE_SEND_STOP: begin
            _r_next_state = `IIC_STATE_SENDING_STOP;
        end
        `IIC_STATE_SENDING_STOP: begin
            if (_r_clock_Divider == 7'b11_00000) begin
                if (in_enable && in_instruction) begin
                    _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
                end
                else begin
                    _r_next_state = `IIC_STATE_COMPLETE; // 发送完成，进入完成状态
                end
            end
            else begin
                _r_next_state = `IIC_STATE_SENDING_STOP; // 保持当前状态，直到发送完成
            end
        end
        // Send Byte
        `IIC_STATE_PRE_SEND_BYTE: begin
            _r_next_state = `IIC_STATE_SENDING_BYTE;
        end
        `IIC_STATE_SENDING_BYTE: begin
            if (_r_clock_Divider == 7'b00_00000 && _r_bit_index_to_process == 4'b1_111) begin
                _r_next_state = `IIC_STATE_RECVING_ACK; // 发送完一个字节，进入接收ACK状态
            end
            else begin
                _r_next_state = `IIC_STATE_SENDING_BYTE; // 保持当前状态，直到发送完成
            end
        end
        // Recv Byte
        `IIC_STATE_PRE_RECV_BYTE: begin
            _r_next_state = `IIC_STATE_RECVING_BYTE;
        end
        `IIC_STATE_RECVING_BYTE: begin
            if (_r_clock_Divider == 7'b00_00000 && _r_bit_index_to_process == 4'b1_111) begin
                _r_next_state = `IIC_STATE_SENDING_ACK; // 接收完一个字节，进入发送ACK状态
            end
            else begin
                _r_next_state = `IIC_STATE_RECVING_BYTE; // 保持当前状态，直到接收完成
            end
        end
        // Recv Ack
        `IIC_STATE_RECVING_ACK: begin
            if (_r_clock_Divider == 7'b00_00000) begin
                if (in_enable && in_instruction) begin
                    _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
                end
                else begin
                    _r_next_state = `IIC_STATE_COMPLETE; // 接收ACK完成，进入完成状态
                end
            end
            else begin
                _r_next_state = `IIC_STATE_RECVING_ACK; // 保持当前状态，直到接收完成
            end
        end
        // Send Ack
        `IIC_STATE_SENDING_ACK: begin
            if (_r_clock_Divider == 7'b00_00000) begin
                if (in_enable && in_instruction) begin
                    _r_next_state = f_get_next_state_according_to_instruction(in_enable, in_instruction);
                end
                else begin
                    _r_next_state = `IIC_STATE_COMPLETE; // 发送ACK完成，进入完成状态
                end
            end
            else begin
                _r_next_state = `IIC_STATE_SENDING_ACK; // 保持当前状态，直到发送完成
            end
        end
        `IIC_STATE_COMPLETE: begin
            _r_next_state = `IIC_STATE_IDLE; // 完成状态后，回到空闲状态
        end
        default: begin
            _r_next_state = _r_state; // 保持当前状态
        end
        endcase
    end
/***************************************************************************************/

/**********************执行各指令循环***************************************************
    * @brief 执行各指令循环
    * @note 该部分代码会在每个时钟周期执行，根据当前状态以及时钟计数控制sda和scl总线的输出
**************************************************************************************/
    task t_init_working_vars;
    begin
        _r_sda_out <= 1'bz; // 初始化sda总线为高阻态
        _r_scl_out <= 1'bz; // 初始化scl总线为高阻态
        _r_scl_is_using <= 1'b0; // 初始化scl总线未被使用
        _r_sda_is_using <= 1'b0; // 初始化sda总线未被使用
        _r_is_working <= 1'b0;
        _r_is_completed <= 1'b0;
        _r_clock_Divider <= 7'd0;
        _r_bit_index_to_process <= 4'b0_111; // 重置bit索引
        _r_byte_to_process <= 8'd0; // 重置要发送的字
        _r_ack_read <= 1'b0; // 清除ACK读取状态
        _r_received_sig_counter <= 6'd0; // 清除接收计数器
    end
    
    endtask
    always @(posedge in_clk) begin
        if (in_rst) begin
            t_init_working_vars();
        end
        else begin
            case (_r_next_state) // TODO：或许可以将这部分带逻辑更新的行为放到state更新的循环里？这样这里也可以改成组合逻辑
/*------------------------------------------------------------------------------------
            * @brief 空闲状态，等待外部使能和指令
            * @note 在此状态下，模块会等待外部的使能信号和指令输入
            *       一旦接收到有效的指令，将根据指令类型进入相应的状态
            *       _r_is_working会被置为1，表示模块正在工作
------------------------------------------------------------------------------------*/
            `IIC_STATE_IDLE: begin
                t_init_working_vars();
                _r_is_working <= 1'b0;
            end
/*------------------------------------------------------------------------------------
            * @brief 发送开始信号状态
            * @note 在此状态下，模块会发送I2C总线的开始信号
            *       通过控制scl和sda总线的输出，完成开始信号的发送
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是96！
            *       0~31: scl/sda总线都处于高电平状态。即模拟一段时间的总线空闲状态
            *       32~63: 将sda总线拉低，表示开始传输
            *       64~95: 将scl总线拉低，表示开始传输
            *       一旦发送完成，将进入完成状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_PRE_SEND_START: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_is_completed <= 1'b0;
                _r_clock_Divider <= 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                /// 最初阶段，将scl和sda总线都拉高，其实是在还原初始状态
                _r_scl_out <= 1;
                _r_sda_out <= 1;
            end
            `IIC_STATE_SENDING_START: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
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
                // 提前拉起completed信号，这样上层有机会响应
                if (_r_clock_Divider[6:0] >= 7'b11_00000 - `IIC_PRE_COMPLETE_SIGNAL) begin
                    _r_is_completed <= 1'b1;
                end
                else begin
                    _r_is_completed <= 1'b0;
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 发送重复开始信号状态
            * @note 在此状态下，模块会发送I2C总线的重复开始信号
            *       通过控制scl和sda总线的输出，完成重复开始信号的发送
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是128！
            *       0~31: scl处于低电平，因为之前的命令结束后必然是低电平，这样可以衔接。sda处于高电平
            *       32~63: scl拉高，表示开始下一轮的时钟，也是准备再模拟一边开始信号
            *       64~95: 将sda总线拉低
            *       96~127: 将scl总线拉低，表示开始传输
            *       一旦发送完成，将进入完成状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_PRE_SEND_REPEAT_START: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_is_completed <= 1'b0;
                _r_clock_Divider <= 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                _r_scl_out <= 0;
                _r_sda_out <= 1;
            end
            `IIC_STATE_SENDING_REPEAT_START: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                if (_r_clock_Divider[6:5] == 2'b00) begin
                    _r_scl_out <= 0;
                    _r_sda_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01) begin
                    _r_scl_out <= 1;
                    _r_sda_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b10) begin
                    _r_scl_out <= 1;
                    _r_sda_out <= 0;
                end
                else if (_r_clock_Divider[6:5] == 2'b11) begin
                    _r_scl_out <= 0;
                    _r_sda_out <= 0;
                end

                // 提前拉起completed信号，这样上层有机会响应
                if (_r_clock_Divider[6:0] >= 7'b00_00000 - `IIC_PRE_COMPLETE_SIGNAL) begin
                    _r_is_completed <= 1'b1;
                end
                else begin
                    _r_is_completed <= 1'b0;
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 发送结束信号
            * @note 在此状态下，模块会发送I2C总线的结束信号
            *       通过控制scl和sda总线的输出，完成结束信号的发送
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是96！
            *       0~31: scl/sda总线都处于低电平，这是为了和之前其它状态形成平滑过渡(之前的状态，最后都会让总线处于低电平状态)
            *       32~63: 将scl总线拉高
            *       64~95: 将sda总线拉高
            *       一旦发送完成，将进入完成状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_PRE_SEND_STOP: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_is_completed <= 1'b0;
                _r_clock_Divider <= 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                /// 最初阶段，将scl和sda总线拉低
                _r_scl_out <= 0;
                _r_sda_out <= 0;
            end
            `IIC_STATE_SENDING_STOP: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                if (_r_clock_Divider[6:5] == 2'b00) begin /// 最初阶段，将scl和sda总线拉低
                    _r_scl_out <= 0;
                    _r_sda_out <= 0;
                end
                else if (_r_clock_Divider[6:5] == 2'b01) begin /// 第二阶段，将scl总线拉高
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b10) begin /// 第三阶段，将sda总线也拉高
                    _r_sda_out <= 1;
                end

                // 提前拉起completed信号，这样上层有机会响应
                if (_r_clock_Divider[6:0] >= 7'b11_00000 - `IIC_PRE_COMPLETE_SIGNAL) begin
                    _r_is_completed <= 1'b1;
                end
                else begin
                    _r_is_completed <= 1'b0;
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 发送字节状态
            * @note 在此状态下，模块会向I2C总线发送信息
            *       通过控制scl和sda总线的输出，完成字节的发送
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是128 * 8！
            *       由于发送的内容一早就准备好，因此sda总线状态在128个时钟周期内不变，只有一个bit发送完才会更新
            *       0~31: scl拉低，表示bit在准备阶段
            *       32~95: scl拉高，表示bit在发送阶段
            *       96~127: 将scl总线拉低，表示bit发送完成
            *       一旦接收完成，将进入接受ACK状态
            * @note 一旦遇到Clock Stretching，则计时器会重置，重新开始从MSB开始发送字节
------------------------------------------------------------------------------------*/
            `IIC_STATE_PRE_SEND_BYTE: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_is_completed <= 1'b0;
                _r_clock_Divider <= 7'd1;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用

                _r_byte_to_process <= in_byte_to_send; // 记录要发送的字节
                _r_bit_index_to_process <= 4'b0_111; // 重置bit索引
                _r_sda_out <= in_byte_to_send[7]; // 将要发送的bit输出到sda总线上
                _r_scl_out <= 0;
            end
            `IIC_STATE_SENDING_BYTE: begin
                _r_sda_out <= _r_byte_to_process[_r_bit_index_to_process]; // 将要发送的bit输出到sda总线上
                _r_is_working <= 1'b1; // 模块正在工作
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线正在被使用
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                /// 在整个发送过程中，其实sda的数据已经“建立”好了，所以下面各阶段并没有操作sda
                if (_r_clock_Divider[6 : 5] == 2'b00) begin
                    _r_scl_out <= 0;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6 : 5] == 2'b11) begin
                    _r_scl_out <= 0;
                end
                if (_r_is_clock_stretching) begin
                    _r_clock_Divider <= 7'd1; // 如果正在进行时钟拉伸，则重置时钟分频器
                    _r_scl_out <= 1'b0;
                    _r_bit_index_to_process <= 4'b0_111;
                end
                else if (_r_clock_Divider == 7'b11_11111) begin
                    // 继续发送下一个bit
                    _r_bit_index_to_process <= _r_bit_index_to_process - 1'b1;
                    _r_clock_Divider <= 7'd0; // 重置时钟分频器
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 接收字节状态
            * @note 在此状态下，模块会接收I2C总线上的字节信息
            *       通过控制scl和sda总线的输出，完成字节的接收
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是128 * 8！
            *       0~31: scl拉低，表示bit在准备阶段
            *       32~95: scl拉高，表示bit在接收阶段，这个时候开始统计有多少个1,0信号
            *       96~127: 将scl总线拉低，表示bit发送完成
            *       bit的结果会根据_r_received_sig_counter的最高位来判断。
            *       意思是整个scl高电平期间，至少有一半的信号是高电平，才表示接收了1，否则是0
            *       一旦接收完成，将进入发送ACK状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_PRE_RECV_BYTE: begin
                _r_is_working <= 1'b1; // 模块正在工作
                _r_is_completed <= 1'b0;
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b0; // sda总线释放
                _r_clock_Divider <= 7'd1;

                _r_bit_index_to_process <= 4'b0_111;
                _r_received_sig_counter <= 6'd0;
                _r_scl_out <= 1'b0;
            end
            `IIC_STATE_RECVING_BYTE: begin
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b0; // sda总线释放
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                if (_r_clock_Divider[6:5] == 2'b00) begin
                    _r_received_sig_counter <= 6'd0;
                    _r_scl_out <= 1'b0;
                end
                else if (_r_clock_Divider[6:0] == 7'b01_00000) begin // 避免_r_received_sig_counter溢出，忽略第一个
                    _r_scl_out <= 1'b1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin
                    _r_scl_out <= 1'b1;
                    if (in_sda_in == 1'b1) begin
                        _r_received_sig_counter <= _r_received_sig_counter + 1'b1; // 统计接收到的信号
                    end
                    else begin
                        _r_received_sig_counter <= _r_received_sig_counter; // 如果是0，则不增加计数
                    end
                end
                else if (_r_clock_Divider[6:5] == 2'b11) begin
                    _r_scl_out <= 1'b0;
                end
                if (_r_is_clock_stretching) begin
                    _r_clock_Divider <= 7'd1; // 如果正在进行时钟拉伸，则重置时钟分频器
                    _r_bit_index_to_process <= 4'b0_111;
                    _r_scl_out <= 1'b0;
                end
                else if (_r_clock_Divider == 7'b11_11111) begin
                    _r_byte_to_process[_r_bit_index_to_process] <= _r_received_sig_counter[5];
                    // 继续接收下一个bit
                    _r_bit_index_to_process <= _r_bit_index_to_process - 1'b1;
                    _r_clock_Divider <= 7'd0; // 重置时钟分频器
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 接收ACK状态
            * @note 在此状态下，模块会接收ACK信号
            *       通过控制scl和sda总线的输出，完成ACK信号的接收
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是128！
            *       0~31: scl拉低，表示bit在准备阶段
            *       32~95: scl拉高，表示bit在接收阶段，这个时候开始统计有多少个1,0信号
            *       96~127: 将scl总线拉低，表示bit发送完成
            *       bit的结果会根据_r_received_sig_counter的最高位来判断。
            *       意思是整个scl高电平期间，至少有一半的信号是高电平，才表示接收了1，否则是0
            *       一旦接收完成，将进入完成状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_RECVING_ACK: begin
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b0; // sda总线释放
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                if (_r_clock_Divider[6:5] == 2'b00) begin
                    _r_received_sig_counter <= 6'd0;
                    _r_scl_out <= 0;
                end
                else if (_r_clock_Divider[6:0] == 7'b01_00000) begin // 避免_r_received_sig_counter溢出，忽略第一个
                    _r_scl_out <= 1;
                end
                else if (_r_clock_Divider[6:5] == 2'b01 || _r_clock_Divider[6:5] == 2'b10) begin
                    _r_scl_out <= 1;
                    if (in_sda_in == 1'b1) begin
                        _r_received_sig_counter <= _r_received_sig_counter + 1'b1; // 统计接收到的信号
                    end
                    else begin
                        _r_received_sig_counter <= _r_received_sig_counter; // 如果是0，则不增加计数
                    end
                end
                else if (_r_clock_Divider[6:5] == 2'b11) begin
                    _r_scl_out <= 0;
                end

                // 提前拉起completed信号，这样上层有机会响应
                if (_r_clock_Divider[6:0] >= 7'b00_00000 - `IIC_PRE_COMPLETE_SIGNAL) begin
                    _r_is_completed <= 1'b1;
                    _r_ack_read <= _r_received_sig_counter[5]; // 根据接收到的信号判断ACK状态
                end
                else begin
                    _r_is_completed <= 1'b0;
                end

            end
/*------------------------------------------------------------------------------------
            * @brief 发送ACK状态
            * @note 在此状态下，模块会发送ACK信号
            *       通过控制scl和sda总线的输出，完成ACK信号的发送
            *       总线的状态通过_r_clock_Divider进行分频控制，总的时钟数量是64！
            *       0~31: scl拉低，表示bit在准备阶段
            *       32~95: scl拉高，表示bit在发送阶段，ACK默认都发送到最高
            *       96~127: 将scl总线拉低，表示bit发送完成
            *       一旦发送完成，将进入完成状态
------------------------------------------------------------------------------------*/
            `IIC_STATE_SENDING_ACK: begin
                _r_scl_is_using <= 1'b1; // scl总线正在被使用
                _r_sda_is_using <= 1'b1; // sda总线释放
                _r_is_working <= 1'b1; // 模块正在工作
                _r_clock_Divider <= _r_clock_Divider + 7'd1;
                _r_sda_out <= 1'b0; // ACK信号成功接收，会拉低sda总线!
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

                // 提前拉起completed信号，这样上层有机会响应
                if (_r_clock_Divider[6:0] >= 7'b00_00000 - `IIC_PRE_COMPLETE_SIGNAL) begin
                    _r_is_completed <= 1'b1;
                end
                else begin
                    _r_is_completed <= 1'b0;
                end
            end
/*------------------------------------------------------------------------------------
            * @brief 完成状态
            * @note 该状态的作用是标记当前指令已经完成。用于让外部组件能够
            *       接受到维持一个时钟周期的完成信号。
            *       之后会回到空闲状态，等待新的指令输入
------------------------------------------------------------------------------------*/
            `IIC_STATE_COMPLETE: begin
                _r_is_completed <= 1'b1; // 标记当前指令已完成
                _r_is_working <= 1'b0; // 完成后，工作状态置为0
                _r_scl_is_using <= 1'b0; // scl总线不再被使用
                _r_sda_is_using <= 1'b0; // sda总线不再被使用
                _r_clock_Divider <= 7'd0;
            end
            endcase
        end
    end


endmodule

`endif ///< IIC_MASTER_V