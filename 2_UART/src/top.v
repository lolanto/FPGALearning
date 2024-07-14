`include "UART_RX.v"
`include "UART_TX.v"
`include "SyncFIFO.v"

`ifndef TOP_V
`define TOP_V

/**
 * @param in_btn_s1 复位信号按钮，高电平有效
 * @param in_uart_rx UART串口的输入总线
 * @param out_uart_tx UART串口的输出总线
 * @desc
 * uart串口接收到一个字节，就返回接收到的这个字节
 */
module Top(
    input wire in_clk,
    input wire in_btn_s1,
    input wire in_uart_rx,
    output wire out_uart_tx,
    output wire out_debug
);

    wire _w_rst = in_btn_s1;

    wire _w_uart_rx_recevied_finished;
    wire [7:0] _w_uart_rx_received_byte;
    UART_RX _inst_uart_rx(.in_clk(in_clk), .in_rst(_w_rst)
        , .in_rx(in_uart_rx)
        , .out_receive_finish(_w_uart_rx_recevied_finished)
        , .out_received_byte(_w_uart_rx_received_byte)
        , .out_debug(out_debug));

    reg _r_uart_tx_send_enable;
    reg [7:0] _r_uart_tx_send_byte;
    wire _w_uart_tx_send_finished;
    wire _w_uart_tx_is_sending;
    UART_TX _inst_uart_tx(.in_clk(in_clk), .in_rst(_w_rst)
        , .out_tx(out_uart_tx)
        , .in_send_enable(_r_uart_tx_send_enable)
        , .in_send_byte(_r_uart_tx_send_byte)
        , .out_send_finished(_w_uart_tx_send_finished)
        , .out_is_sending(_w_uart_tx_is_sending));
    

    wire [7:0] _w_buffered_send_byte;
    wire _w_fifo_is_empty;
    SyncFIFO _inst_SyncFIFO(.in_clk(in_clk), .in_rst(_w_rst)
        , .in_write_data(_w_uart_rx_received_byte)
        , .in_write_enable(_w_uart_rx_recevied_finished)
        , .out_read_data(_w_buffered_send_byte)
        , .in_read_enable(_r_uart_tx_send_enable)
        , .out_is_empty(_w_fifo_is_empty));

    reg _r_received_byte;
    always @(posedge in_clk) begin
        if (_w_rst) begin
            _r_uart_tx_send_enable <= 1'b0;
            _r_uart_tx_send_byte <= 8'd0;
            _r_received_byte <= 1'b0;
        end
        else begin
            _r_uart_tx_send_enable <= 1'b0;
            _r_received_byte <= 1'b0;
            if (_w_uart_rx_recevied_finished) begin
                _r_received_byte <= 1'b1;
            end
            if ((_r_received_byte && ~_w_uart_tx_is_sending)
                || (_w_uart_tx_send_finished && ~_w_fifo_is_empty)) begin
                _r_uart_tx_send_enable <= 1'b1;
                _r_uart_tx_send_byte <= _w_buffered_send_byte;
            end
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module Top_TB(
    input wire in_clk,
    input wire in_rst
);

    localparam COUNT = `BOARD_FREQ / `BUARD_RATE - 1;
    localparam HALF_COUNT = COUNT / 2; ///< 一旦在一个COUNT的Tick数量内，低电平/高电平超过了HALF_COUNT，那么就认为这个COUNT周期内的信号是对应的电平
    localparam SEND_DATA = 20'b1_0011_0010_0_1_0011_0001_0;
    reg _r_tx;
    wire _w_rx;
    reg [7:0] _r_counter;
    reg [19:0] _r_send_byte;
    reg [4:0] _r_send_byte_index;

    Top _inst_top(.in_clk(in_clk), .in_btn_s1(in_rst), .in_uart_rx(_r_tx), .out_uart_tx(_w_rx));

    initial begin
        _r_counter = 8'd0;
        _r_send_byte = SEND_DATA;
        _r_tx = 1'b1;
        _r_send_byte_index = 5'd0;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_counter <= 8'd0;
            _r_send_byte <= SEND_DATA;
            _r_tx <= 1'b1;
            _r_send_byte_index <= 5'd0;
        end
        else begin
            _r_counter <= _r_counter + 1;
            if (_r_counter == COUNT) begin
                _r_counter <= 8'd0;
                _r_tx <= _r_send_byte[_r_send_byte_index];
                _r_send_byte_index <= _r_send_byte_index + 1;
                if (_r_send_byte_index == 19) begin
                    _r_send_byte_index <= 5'd0;
                    _r_tx <= 1'b1;
                end
            end
        end
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< TOP_V

