`ifndef SYNC_FIFO_V
`define SYNC_FIFO_V
`include "EdgeDetection.v"
/**
 * @brief 同步的FIFO模块(只考虑一个时钟域)
 * @param BIT_WIDTH 一次读写的数据位宽
 * @param DEPTH FIFO组件能够容纳的数据深度，即多少个BIT_WIDTH数据
 *
 * @param in_clk 时钟信号
 * @param in_rst 复位信号(高电平有效)
 * @param in_write_data 要写入的数据
 * @param in_write_enable 是否要写入
 * @param in_read_enable 是否要读取下一个数据
 * @return out_read_data 非空情况下，当前FIFO队尾数据
 * @return out_is_full 当前队列是否已满
 * @return out_is_empty 当前队列是否为空
 * @return out_about_to_be_empty 当前队列即将为空(再出队列就没有数据了)
 * @note
 * 使用说明：
 * 写入：
 * in_write_data准备好要写入的数据，将in_write_enable拉高，下一个时钟上升沿到来时in_write_data将被写入队列中。所以要写入的数据至少需要维持一个时钟周期
 * 在拉高in_write_enable之前，可以检查out_is_full，避免FIFO满队列时写入!
 * 在写入下一个数据之前，必须先将in_write_enable拉低！模块通过in_write_enable从低到高的电平变化来发起写入！
 * e.g. 
 * ...prepare data...
 * in_write_data <= data_to_be_written;
 * if (~out_is_full)
 *    in_write_enable <= 1;
 *
 * 读取：
 * out_read_data一直返回的都是当前队尾的数据
 * 在x时刻上升沿之后，in_read_enable被拉高，此时out_read_data将会是下一个数据。因此in_read_enable即将被拉高的那一个上升沿就是最后一刻可以读取当前队尾数据的机会！
 * 在拉高out_read_enable之前，可以检查out_about_to_be_empty，避免让最后一个元素出队列之后，队列为空，导致out_read_data数据无意义
 * 在发起下一个出队列行为之前，必须将in_read_enable拉低！模块通过in_read_enable从低到高的电平变化发起出队列！
 * e.g.
 * if (~out_is_empty)
 *     read_data <= out_read_data;
 * else
 *     read_data <= read_data;
 * if (~out_about_to_be_empty)
 *     in_read_enable <= 1;
 */
module SyncFIFO #(
    parameter BIT_WIDTH = 8,
    parameter DEPTH = 8
)(
    input wire in_clk,
    input wire in_rst,
    input wire [BIT_WIDTH - 1 : 0] in_write_data,
    input wire in_write_enable,
    output wire [BIT_WIDTH - 1 : 0] out_read_data,
    input wire in_read_enable,
    output wire out_is_full,
    output wire out_is_empty,
    output wire out_about_to_be_empty
);

    localparam BIT_DEPTH_USE = $clog2(DEPTH);
    // 最高位(BIT_DEPTH_USE)作为溢出位，低位(BIT_DEPTH_USE - 1 : 0)作为索引位
    reg [BIT_DEPTH_USE : 0] _r_write_pos;
    reg [BIT_DEPTH_USE : 0] _r_read_pos;

    reg [BIT_DEPTH_USE : 0] _r_read_pos_plus_one;
    always @(*) begin
        _r_read_pos_plus_one = _r_read_pos + 1'b1;
    end
    assign out_about_to_be_empty = (_r_write_pos == _r_read_pos_plus_one);
    // 当前要写入的和现在要读取的是同一个位置，说明当前队列为空
    assign out_is_empty = (_r_write_pos == _r_read_pos);
    // "溢出位"不同，但是"索引位"相同，说明读写位置之间已经偏差了DEPTH个数据了！也就是已经满了！
    assign out_is_full = 
        (_r_write_pos[BIT_DEPTH_USE - 1 : 0] == _r_read_pos[BIT_DEPTH_USE - 1 : 0])
        && (_r_write_pos[BIT_DEPTH_USE] != _r_read_pos[BIT_DEPTH_USE]);

    wire _w_trigger_write_sig;
    EdgeDetection _inst_ed_in_write_enable(.in_clk(in_clk), .in_rst(in_rst), .in_sig(in_write_enable), .out_detected(_w_trigger_write_sig));

    wire _w_trigger_read_sig;
    EdgeDetection _inst_ed_in_read_enable(.in_clk(in_clk), .in_rst(in_rst), .in_sig(in_read_enable), .out_detected(_w_trigger_read_sig));
    

    wire _w_write_enable_actual = ~out_is_full && _w_trigger_write_sig; // 当前未满，而且确实要写入
    wire _w_read_enable_actual = ~out_is_empty && _w_trigger_read_sig; // 当前非空，而且确实希望读取

    wire [BIT_WIDTH - 1 : 0] _w_read_data;
    assign out_read_data = _w_read_data;

    SyncFIFO_Memory #(.BIT_WIDTH(BIT_WIDTH), .DEPTH(DEPTH), .BIT_DEPTH_USE(BIT_DEPTH_USE)) _memory(
        .in_clk(in_clk)
        , .in_write_data(in_write_data)
        , .in_write_enable(_w_write_enable_actual)
        , .in_write_pos(_r_write_pos[BIT_DEPTH_USE - 1 : 0])
        , .out_read_data(_w_read_data[BIT_WIDTH - 1 : 0])
        , .in_read_pos(_r_read_pos[BIT_DEPTH_USE - 1 : 0])
        , .in_read_enable(_w_read_enable_actual)
    );

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_write_pos <= (0);
            _r_read_pos <= (0);
        end
        else begin
            if (_w_write_enable_actual) begin
                _r_write_pos <= _r_write_pos + 1'b1;
            end
            else begin
                _r_write_pos <= _r_write_pos;
            end

            if (_w_read_enable_actual) begin
                _r_read_pos <= _r_read_pos + 1'b1;
            end
            else begin
                _r_read_pos <= _r_read_pos;
            end
        end
    end

endmodule

/**
 * @brief FIFO配套的内存模块，用来暂存所有需要被读写的数据
 * @param BIT_WDITH 一次写入或读取的数据位宽
 * @param DEPTH 模块能够存储的深度(总容量就是BIT_WIDTH * DEPTH)
 *
 * @param in_clk 模块时钟信号
 * @param in_write_data 要写入的数据，不一定就会使用。由in_write_enable决定
 * @param in_write_enable 是否要将in_write_data进行写入
 * @param in_write_pos 要写入的位置
 * @param in_read_pos 要读取的位置
 * @param in_read_enable 是否要读取
 * @return out_read_data 输出要读取的数据，永远返回当前选择的数据的值，但不保证在读取时候的有效性!(e.g. 队列为空时)
 * @note 
 * 内存块本身没有“重置”操作，都是通过上层模块控制读写位置的方式来保证数据的有效性
 * 写入操作只有在时钟上升沿才会生效，假如当前write enable没有激活，那么就一直写入自己的结果 (TODO: 是否会引入latch?)
 * @remark
 * 读取下标，写入下标的有效性不做校验，上层组件在执行时自行进行校验!!
 */
module SyncFIFO_Memory #(
    parameter BIT_WIDTH = 8,
    parameter DEPTH = 8,
    parameter BIT_DEPTH_USE = 3
)(
    input wire in_clk,
    input wire [BIT_WIDTH - 1 : 0] in_write_data,
    input wire in_write_enable,
    input wire [BIT_DEPTH_USE - 1 : 0] in_write_pos,
    output wire [BIT_WIDTH - 1 : 0] out_read_data,
    input wire in_read_enable,
    input wire [BIT_DEPTH_USE - 1 : 0] in_read_pos
);

    reg [BIT_WIDTH - 1 : 0] _r_memories[DEPTH - 1 : 0];

    // 组合逻辑，永远都能够直接返回要读取的内容
    // 之所以在in_read_enable的时候将读取位置+1，是为了让上层能够更加快速地获取下一个数据
    // 上层在in_read_enable的时候，要等下一个时钟上升沿才会更新in_read_pos；此处通过组合逻辑提前了这一操作
    // 注意：这个提前的行为是假设in_read_enable只会在真正期望读取的时钟周期被拉高，其余时间都是低电平!
    reg [BIT_WIDTH - 1 : 0] _r_read_data;
    reg [BIT_DEPTH_USE - 1 : 0] _r_read_pos_actual;
    always @(*) begin
        if (in_read_enable)
            _r_read_pos_actual = in_read_pos + 1'b1;
        else
            _r_read_pos_actual = in_read_pos;

        _r_read_data = _r_memories[_r_read_pos_actual];
    end
    assign out_read_data = _r_read_data;

    // 只有在时钟的上升沿才会让写入的数据生效
    always @(posedge in_clk) begin
        if (in_write_enable)
            _r_memories[in_write_pos] <= in_write_data;
        else
            _r_memories[in_write_pos] <= _r_memories[in_write_pos];
    end

endmodule

`ifdef DEBUG_TEST_BENCH
/** 
 * SyncFIFO的仿真测试代码
 * 1. 写速度大于读取速度，测试写满的情况
 * 2. 写速度小于读取速度，测试读空的情况
 * 3. 写速度等于读取速度，测试普通情况
 */
module SyncFIFO_TB(
    input wire in_clk,
    input wire in_rst
);
    reg [7:0] _r_write_data;
    reg _r_write_enable;
    wire [7:0] _w_read_data;
    reg _r_read_enable;
    wire _w_is_full;
    wire _w_is_empty;
    wire _w_about_to_be_empty;

    SyncFIFO _inst_SyncFIFO(.in_clk(in_clk), .in_rst(in_rst)
        , .in_write_data(_r_write_data[7:0])
        , .in_write_enable(_r_write_enable)
        , .out_read_data(_w_read_data[7:0])
        , .in_read_enable(_r_read_enable)
        , .out_is_full(_w_is_full)
        , .out_is_empty(_w_is_empty)
        , .out_about_to_be_empty(_w_about_to_be_empty));

    reg [7:0] _r_read_data;
    reg [31:0] _r_counter;

    initial begin
        _r_counter = 32'd0;
        _r_write_data = 8'd0;
        _r_write_enable = 1'b0;
        _r_read_enable = 1'b0;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= 32'd0;
            _r_write_data <= 8'd0;
            _r_write_enable <= 1'b0;
            _r_read_enable <= 1'b0;
        end
        else begin
            if (~_w_is_empty)
                _r_read_data <= _w_read_data;
            else
                _r_read_data <= 8'dx;
            _r_counter <= _r_counter + 1;
            _r_write_data <= _r_write_data + 1;
            if (_r_counter <= 32'd32) begin
                if (_w_is_full) begin
                    _r_write_enable <= 0;
                end
                else begin
                    _r_write_enable <= ~_r_write_enable;
                end

                if (_r_counter[2] && _r_counter[1:0] == 2'd0) begin
                    _r_read_enable <= 1;
                end
                else
                    _r_read_enable <= 0;
            end
            else if (_r_counter <= 32'd64) begin
                if (_w_about_to_be_empty) begin
                    _r_read_enable <= 0;
                end
                else begin
                    _r_read_enable <= ~_r_read_enable;
                end

                if (_r_counter[2] && _r_counter[1:0] == 2'd0) begin
                    _r_write_enable <= 1;
                end
                else
                    _r_write_enable <= 0;
            end
            else begin
                if (_w_about_to_be_empty)
                    _r_read_enable <= 0;
                else
                    _r_read_enable <= ~_r_read_enable;
                
                if (_w_is_full)
                    _r_read_enable <= 0;
                else
                    _r_write_enable <= ~_r_write_enable;
            end
        end
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< SYNC_FIFO_V
