`ifndef DEBOUNCER_V
`define DEBOUNCER_V

/**
 * @breif 信号(按钮)除抖模块
 * @param in_clk 时钟信号
 * @param in_sig 目标信号
 * @param out_sig_state 当前信号的状态，供内部系统直接使用
 * @param out_sig_down 是否检测到下降沿
 * @param out_sig_up 是否检测到上升沿
 * @note 信号除抖，基本原理就是检查输入信号in_sig是不是在一定时间内保持与当前已经缓存的状态out_sig_state不一致
 * 超过时间就认为信号发生了变化。上升沿和下降沿的检测信号只会维持一个时钟周期。在out_sig_state发生翻转的前一个时钟周期可以
 * 读取到out_sig_down/up被拉高
 */
module Debouncer(
    input wire in_clk,
    input wire in_sig,
    output wire out_sig_state,
    output wire out_sig_down,
    output wire out_sig_up
);

// sig_sync_0/1以及in_sig，共同组成了三个顺序信号！其中in_sig是N时刻的信号，sig_sync_0是N+1时刻的信号，sig_sync_1是N+2时刻的信号
// 信号均是时钟上升沿时采样得到
reg _r_sig_sync_0;  always @(posedge in_clk) _r_sig_sync_0 <= in_sig;
reg _r_sig_sync_1;  always @(posedge in_clk) _r_sig_sync_1 <= _r_sig_sync_0;
reg _r_sig_state;
assign out_sig_state = _r_sig_state;

reg [15:0] _r_sig_counter;

// N+2时刻的信号和目前的状态一致，认为信号没有发生变化
wire _w_sig_idle = (_r_sig_state==_r_sig_sync_1);
wire _w_sig_count_max = &_r_sig_counter;

always @(posedge in_clk) begin
if(_w_sig_idle)
    _r_sig_counter <= 0;
else begin
    /// 假如_r_sig_sync_1信号和当前状态不一致，那么有可能是发生了信号转变，开始计数，只要在2^16次时钟周期之后，这个信号不一致的情况依旧存在
    /// 就认为信号状态发生了变化
    _r_sig_counter <= _r_sig_counter + 16'd1;
    if(_w_sig_count_max) _r_sig_state <= ~_r_sig_state;
end
end

// 当_r_sig_sync_1信号与当前状态不一致，同时已经过了2^16个时钟周期，同时之前的状态是高电平，那么认为检测到了下降沿
assign out_sig_down = ~_w_sig_idle & _w_sig_count_max & _r_sig_state;
// 当_r_sig_sync_1信号与当前状态不一致，同时已经过了2^16个时钟周期，同时之前的状态是低电平，那么认为检测到了上升沿
assign out_sig_up   = ~_w_sig_idle & _w_sig_count_max & ~_r_sig_state;
endmodule

`endif ///< DEBOUNCER_V