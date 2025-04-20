`ifndef COUNTER_V
`define COUNTER_V

module Counter #(
    parameter Basic_Freq = 27_000_000,
    parameter Seg_Count = 2
)(
    input wire in_clk,
    input wire in_rst,
    output wire out_sig
);

    reg [25:0] _r_count;
    reg _r_sig;

    assign out_sig = _r_sig;

    localparam Flip_Count = Basic_Freq / Seg_Count;

    always @(posedge in_clk) begin
        if (in_rst) begin
            _r_count <= 26'd0;
            _r_sig <= 1'b0;
        end
        else begin
            _r_count <= _r_count + 1;
            if (_r_count == Flip_Count) begin
                _r_sig <= ~_r_sig;
                _r_count <= 26'd0;
            end
        end
    end

endmodule


`endif // COUNTER_V
