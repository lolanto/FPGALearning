`ifndef TOP_V
`define TOP_V
`include "EdgeDetection.v"
`include "Debouncer.v"
`include "IIC_Master.v"


`define TOP_STATE_IDLE 0
`define TOP_STATE_WAITTING_COMPLETE `TOP_STATE_IDLE + 1
`define TOP_STATE_TO_NEXT_JOB `TOP_STATE_WAITTING_COMPLETE + 1
`define TOP_STATE_SEND_START `TOP_STATE_TO_NEXT_JOB + 1
`define TOP_STATE_SNED_ADDR `TOP_STATE_SEND_START + 1
`define TOP_STATE_SEND_BYTE `TOP_STATE_SNED_ADDR + 1
`define TOP_STATE_SEND_STOP `TOP_STATE_SEND_BYTE + 1

`define BYTE_OF_ADDRESS 8'b1010_1100
`define BYTE_TO_SEND 8'b1101_0101

`define PHY_DEBUG 1 // 上机实际测试时输出更多调试信息
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
`ifdef DEBUG_TEST_BENCH
    input wire in_rst,
    input wire in_trigger,
`else
    input wire in_btn_s1, // reset
    input wire in_btn_s2, // trigger at posedge
`endif
    inout wire in_out_iic_scl,
    inout wire in_out_iic_sda
`ifdef PHY_DEBUG
    , output wire [5:0] out_debug_led // 对应片上的6个LED输出接口
`endif
);
`ifndef DEBUG_TEST_BENCH
    wire in_rst = in_btn_s1;
`endif

    reg _r_iic_enable;
    reg [2:0] _r_iic_instruction;
    reg [7:0] _r_iic_byte_to_send;

    wire _w_out_iic_sda;
    wire _w_iic_sda_is_using;
    assign in_out_iic_sda = ~_w_iic_sda_is_using ? 1'bz : _w_out_iic_sda;
    wire _w_in_iic_sda = in_out_iic_sda;

    wire _w_out_iic_scl;
    wire _w_iic_scl_is_using;
    assign in_out_iic_scl = ~_w_iic_scl_is_using ? 1'bz : _w_out_iic_scl;
    wire _w_in_iic_scl = in_out_iic_scl;

    wire [5:0] _w_debug_led;
    assign out_debug_led = _w_debug_led;


    wire _w_iic_is_completed;

    wire _w_trigger;
`ifdef DEBUG_TEST_BENCH
    assign _w_trigger = in_trigger;
`else
    Debouncer _inst_debouncer(.in_clk(in_clk), .in_sig(in_btn_s2), .out_sig_up(_w_trigger));
`endif

    wire _w_is_clock_is_stretching;
    wire _w_is_working;

    IIC_Master _inst_iic_master(
        .in_clk(in_clk),
        .in_rst(in_rst),
        .in_enable(_r_iic_enable),

        .in_byte_to_send(_r_iic_byte_to_send),
        // .out_byte_read(),
        // .out_ack_read()
        .in_instruction(_r_iic_instruction),

        .in_sda_in(_w_in_iic_sda),
        .out_sda_out(_w_out_iic_sda),

        .in_scl_in(_w_in_iic_scl),
        .out_scl_out(_w_out_iic_scl),

        .out_sda_is_using(_w_iic_sda_is_using),
        .out_scl_is_using(_w_iic_scl_is_using),

        .out_is_completed(_w_iic_is_completed)
        , .out_is_working(_w_is_working)
        , .out_is_clock_stretching(_w_is_clock_is_stretching)
    );

    // FSM控制器件业务逻辑: 按下按钮后，向指定地址发送字节
    reg [2:0] _r_state;
    reg [2:0] _r_next_state;
    reg [2:0] _r_next_job;
    reg [1:0] _r_iic_complete_countdown; // iic的完成信号是提前3个tick发起的，要准备一个countdown

`ifdef PHY_DEBUG
    assign _w_debug_led[0] = in_clk;
    assign _w_debug_led[1] = _w_iic_scl_is_using;
    assign _w_debug_led[2] = _w_iic_sda_is_using;
    assign _w_debug_led[3] = _w_is_clock_is_stretching;
    assign _w_debug_led[4] = _w_is_working;
    assign _w_debug_led[5] = _w_iic_is_completed;
`endif

/**********************状态转移********************************************************/
    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_state <= `TOP_STATE_IDLE;
        end
        else begin
            _r_state <= _r_next_state; // 更新状态
        end
    end
/**************************************************************************************/

/**********************状态转移判断逻辑*************************************************/
    always @(*) begin
        case (_r_state)
        `TOP_STATE_IDLE: begin
            if (_w_trigger) begin
                _r_next_state = `TOP_STATE_SEND_START;
            end
            else begin
                _r_next_state = `TOP_STATE_IDLE;
            end
        end
        `TOP_STATE_SEND_START: begin
            _r_next_state = `TOP_STATE_WAITTING_COMPLETE;
        end
        `TOP_STATE_SNED_ADDR: begin
            _r_next_state = `TOP_STATE_WAITTING_COMPLETE;
        end
        `TOP_STATE_SEND_BYTE: begin
            _r_next_state = `TOP_STATE_WAITTING_COMPLETE;
        end
        `TOP_STATE_SEND_STOP: begin
            _r_next_state = `TOP_STATE_WAITTING_COMPLETE;
        end
        `TOP_STATE_WAITTING_COMPLETE: begin
            if (_w_iic_is_completed) begin
                _r_next_state = `TOP_STATE_TO_NEXT_JOB;
            end
            else begin
                _r_next_state = `TOP_STATE_WAITTING_COMPLETE;
            end
        end
        `TOP_STATE_TO_NEXT_JOB: begin
            if (_r_iic_complete_countdown == 2) begin
                _r_next_state = _r_next_job;
            end
            else begin
                _r_next_state = `TOP_STATE_TO_NEXT_JOB;
            end
        end
        default:
            _r_next_state = `TOP_STATE_IDLE;
        endcase
    end
/**************************************************************************************/

/**********************执行各指令循环***************************************************/
    always @(posedge in_clk) begin
        case (_r_next_state)
        `TOP_STATE_IDLE: begin
            _r_iic_enable <= 1'b0;
            _r_iic_instruction <= `IIC_INST_UNKNOWN;
            _r_iic_complete_countdown <= `IIC_PRE_COMPLETE_SIGNAL;
        end
        `TOP_STATE_WAITTING_COMPLETE: begin
            _r_iic_enable <= 1'b0;
            _r_iic_instruction <= `IIC_INST_UNKNOWN;
        end
        `TOP_STATE_TO_NEXT_JOB: begin
            _r_iic_enable <= 1'b0;
            _r_iic_instruction <= `IIC_INST_UNKNOWN;
            _r_iic_complete_countdown <= _r_iic_complete_countdown - 2'd1;
        end
        `TOP_STATE_SEND_START: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_START_TX;
            _r_iic_complete_countdown <= `IIC_PRE_COMPLETE_SIGNAL;
            _r_next_job <= `TOP_STATE_SNED_ADDR;
        end
        `TOP_STATE_SNED_ADDR: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_SEND_BYTE;
            _r_iic_byte_to_send <= `BYTE_OF_ADDRESS;
            _r_iic_complete_countdown <= `IIC_PRE_COMPLETE_SIGNAL;
            _r_next_job <= `TOP_STATE_SEND_BYTE;
        end
        `TOP_STATE_SEND_BYTE: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_SEND_BYTE;
            _r_iic_byte_to_send <= `BYTE_TO_SEND;
            _r_iic_complete_countdown <= `IIC_PRE_COMPLETE_SIGNAL;
            _r_next_job <= `TOP_STATE_SEND_STOP;
        end
        `TOP_STATE_SEND_STOP: begin
            _r_iic_enable <= 1'b1;
            _r_iic_instruction <= `IIC_INST_STOP_TX;
            _r_iic_complete_countdown <= `IIC_PRE_COMPLETE_SIGNAL;
            _r_next_job <= `TOP_STATE_IDLE;
        end
        default: begin
            _r_iic_enable <= 1'b0;
            _r_iic_instruction <= `IIC_INST_UNKNOWN;
        end
        endcase
    end

endmodule

/**************************************************************************************/

`endif