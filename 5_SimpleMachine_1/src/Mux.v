`ifndef MUX_V
`define MUX_V

// 提供多路选择器的实现

module Mux2To1 #(parameter WIDE=1)(
    input wire [WIDE - 1 : 0] in_a,
    input wire [WIDE - 1 : 0] in_b,
    input wire in_select,
    output wire [WIDE - 1 : 0] out
);

    assign out = in_select ? in_a : in_b;

endmodule

`endif // MUX_V
