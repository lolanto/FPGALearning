`ifndef TOP_FOR_IIC_PROXY_V
`define TOP_FOR_IIC_PROXY_V

`include "IICProxy.v"
`include "SinglePortRam.v"

module TopForIICProxy(
    input wire in_clk,
    input wire in_rst,
    input wire in_start,
    input wire in_sda,
    input wire in_scl,
    output wire out_sda,
    output wire out_sda_is_using,
    output wire out_scl,
    output wire out_scl_is_using
    , output wire out_debug_1
    , output wire out_debug_2
);

    localparam M_STATE_IDLE = 0;
    localparam M_STATE_SETUP = 1;
    localparam M_STATE_INVOKE = 2;
    localparam M_STATE_WAITTING = 3;
    localparam M_STATE_FINISH = 4;
    localparam M_STATE_WAIT_100ms = 5; // 两个请求之间等待100ms

    // >>> BEG: registers for Test Bench controll
    reg [2:0] _r_current_state;
    reg [2:0] _r_next_state;
    reg _r_try_to_read;
    reg _r_try_to_write;
    reg _r_wrote_addr;
    reg _r_wrote_byte_count;

    reg _r_write_ram_from_iicproxy; // << 用来控制当前到RAM的控制权应该属于当前模块(0)还是来自IICProxy(1)
    reg [7:0] _r_write_ram_addr;
    reg [7:0] _r_write_ram_data;
    reg _r_write_ram_write;
    reg _r_write_ram_enable;

    reg [15:0] _r_counter;

    // <<< END: registers for Test Bench controll

    // >>> BEG: registers for IICProxy
    reg _r_iicproxy_enable;
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

    SinglePortRAM _inst_fake_ram(.in_clk(in_clk), .in_rst(in_rst)
        , .in_write_enable(_w_ram_write_enable)
        , .in_addr(_w_ram_addr)
        , .in_write_data(_w_ram_input_data)
        , .out_data(_w_ram_output_data));

    IICProxy _inst_iic_proxy(.in_clk(in_clk), .in_rst(in_rst)
        , .in_enable(_r_iicproxy_enable)
        , .out_is_completed(_w_iicproxy_is_completed)

        , .in_sda_in(in_sda)
        , .in_scl_in(in_scl)
        , .out_sda_out(out_sda)
        , .out_scl(out_scl)
        , .out_sda_is_using(out_sda_is_using)
        , .out_scl_is_using(out_scl_is_using)

        , .in_mem_data(_w_ram_output_data)
        , .out_mem_data(_w_iicproxy_mem_data)
        , .out_mem_addr(_w_iicproxy_mem_addr)
        , .out_mem_write(_w_iicproxy_mem_write)
        , .out_mem_enable(_w_iicproxy_mem_enable)
        
        , .out_debug_1(out_debug_1)
        , .out_debug_2(out_debug_2));

    always @(posedge in_clk) begin
        if (in_rst)
            _r_current_state <= M_STATE_IDLE;
        else
            _r_current_state <= _r_next_state;
    end

    always @(*) begin
        _r_next_state = M_STATE_IDLE;
        case (_r_current_state)
        M_STATE_IDLE: begin
            if (in_start && (_r_try_to_read || _r_try_to_write))
                _r_next_state = M_STATE_SETUP;
            else
                _r_next_state = M_STATE_IDLE;
        end
        M_STATE_SETUP: begin
            // 准备写入请求相关的内容
            if (!_r_wrote_addr
                || !_r_wrote_byte_count)
                _r_next_state = M_STATE_SETUP;
            else
                _r_next_state = M_STATE_INVOKE;
        end
        M_STATE_INVOKE: begin
            _r_next_state = M_STATE_WAITTING;
        end
        M_STATE_WAITTING: begin
            if (_w_iicproxy_is_completed)
                _r_next_state = M_STATE_FINISH;
            else
                _r_next_state = M_STATE_WAITTING;
        end
        M_STATE_FINISH: begin
            _r_next_state = M_STATE_WAIT_100ms;
        end
        M_STATE_WAIT_100ms: begin
`ifdef DEBUG_TEST_BENCH
            if (1'b1)    
`else
            if (_r_counter[14])
`endif ///< DEBUG_TEST_BENCH
                _r_next_state = M_STATE_IDLE;
            else
                _r_next_state = M_STATE_WAIT_100ms;
        end
        endcase
    end

    task T_Init_For_StateMachine;
        begin
            _r_wrote_addr <= 1'b0;
            _r_wrote_byte_count <= 1'b0;
            _r_write_ram_from_iicproxy <= 1'b0;
            _r_write_ram_write <= 1'b0;
            _r_counter <= 16'd0;
        end
    endtask

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_try_to_read <= 1'b1;
            _r_try_to_write <= 1'b0;
            T_Init_For_StateMachine();
        end
        else begin
            case (_r_current_state)
            M_STATE_IDLE: begin
                T_Init_For_StateMachine();
            end
            M_STATE_SETUP: begin
                if (!_r_wrote_addr) begin
                    _r_write_ram_write <= 1'b1;
                    _r_write_ram_addr <= 8'h00;
                    if (_r_try_to_read)
                        _r_write_ram_data <= 8'h09;
                    else if (_r_try_to_write)
                        _r_write_ram_data <= 8'h08;
                    _r_wrote_addr <= 1'b1;
                end
                else if (!_r_wrote_byte_count) begin
                    _r_write_ram_write <= 1'b1;
                    _r_write_ram_addr <= 8'h01;
                    _r_write_ram_data <= 8'h0E;
                    _r_wrote_byte_count <= 1'b1;
                end
            end
            M_STATE_INVOKE: begin
                _r_write_ram_write <= 1'b0;
                _r_write_ram_from_iicproxy <= 1'b1; // << 切换权限，之后的RAM操作就由IICProxy来控制
                _r_iicproxy_enable <= 1'b1;
            end
            M_STATE_WAITTING: begin
                _r_iicproxy_enable <= 1'b0;
            end
            M_STATE_FINISH: begin
                if (_r_try_to_read) begin
                    _r_try_to_read <= 1'b0;
                    _r_try_to_write <= 1'b1;
                end
                if (_r_try_to_write)
                    _r_try_to_write <= 1'b0;
            end
            M_STATE_WAIT_100ms: begin
                _r_counter <= _r_counter + 1;
            end
            endcase
        end
    end

endmodule

`ifdef DEBUG_TEST_BENCH

module TopForIICProxy_TB(
    input wire in_clk,
    input wire in_rst
);

    reg _r_start;
    reg _r_sda;
    reg _r_scl;

    TopForIICProxy _inst_top_for_iic_proxy(.in_clk(in_clk), .in_rst(in_rst)
        , .in_start(_r_start)
        , .in_sda(_r_sda)
        , .in_scl(_r_scl));

    initial begin
        _r_start = 1'b0;
        _r_sda = 1'b1;
        _r_scl = 1'b1;
    end

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_start = 1'b0;
            _r_sda = 1'b1;
            _r_scl = 1'b1;
        end
        else begin
            _r_start = 1'b1;
        end
    end

endmodule

`endif ///< DEBUG_TEST_BENCH

`endif ///< TOP_FOR_IIC_PROXY_V
