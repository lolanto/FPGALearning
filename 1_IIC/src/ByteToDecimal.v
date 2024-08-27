`ifndef BYTE_TO_DECIMAL_V
`define BYTE_TO_DECIMAL_V

// 打表的方式，将8bit无符号整数，拆分成3个Decimal Value

module ByteToDecimal(
    input wire [7:0] in_byte,
    output wire [3:0] out_decimal_0,
    output wire [3:0] out_decimal_1,
    output wire [3:0] out_decimal_2,
    output wire [3:0] out_decimal_3
);

    reg [3:0] _r_decimal_0;
    reg [3:0] _r_decimal_1;
    reg [3:0] _r_decimal_2;

    assign out_decimal_0 = _r_decimal_0;
    assign out_decimal_1 = _r_decimal_1;
    assign out_decimal_2 = _r_decimal_2;
    assign out_decimal_3 = 4'd0;

    always @(*) begin
        case(in_byte)
        
            8'd0: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd1: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd2: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd3: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd4: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd5: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd6: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd7: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd8: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd9: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd0;
            end

            8'd10: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd11: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd12: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd13: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd14: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd15: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd16: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd17: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd18: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd19: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd0;
            end

            8'd20: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd21: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd22: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd23: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd24: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd25: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd26: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd27: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd28: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd29: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd0;
            end

            8'd30: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd31: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd32: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd33: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd34: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd35: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd36: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd37: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd38: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd39: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd0;
            end

            8'd40: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd41: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd42: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd43: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd44: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd45: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd46: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd47: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd48: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd49: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd0;
            end

            8'd50: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd51: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd52: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd53: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd54: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd55: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd56: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd57: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd58: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd59: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd0;
            end

            8'd60: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd61: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd62: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd63: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd64: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd65: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd66: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd67: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd68: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd69: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd0;
            end

            8'd70: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd71: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd72: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd73: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd74: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd75: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd76: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd77: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd78: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd79: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd0;
            end

            8'd80: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd81: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd82: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd83: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd84: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd85: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd86: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd87: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd88: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd89: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd0;
            end

            8'd90: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd91: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd92: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd93: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd94: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd95: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd96: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd97: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd98: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd99: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd0;
            end

            8'd100: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd101: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd102: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd103: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd104: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd105: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd106: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd107: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd108: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd109: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd1;
            end

            8'd110: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd111: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd112: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd113: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd114: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd115: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd116: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd117: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd118: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd119: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd1;
            end

            8'd120: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd121: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd122: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd123: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd124: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd125: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd126: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd127: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd128: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd129: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd1;
            end

            8'd130: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd131: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd132: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd133: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd134: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd135: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd136: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd137: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd138: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd139: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd1;
            end

            8'd140: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd141: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd142: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd143: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd144: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd145: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd146: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd147: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd148: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd149: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd1;
            end

            8'd150: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd151: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd152: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd153: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd154: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd155: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd156: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd157: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd158: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd159: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd1;
            end

            8'd160: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd161: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd162: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd163: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd164: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd165: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd166: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd167: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd168: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd169: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd6;
                _r_decimal_2 = 4'd1;
            end

            8'd170: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd171: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd172: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd173: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd174: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd175: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd176: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd177: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd178: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd179: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd7;
                _r_decimal_2 = 4'd1;
            end

            8'd180: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd181: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd182: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd183: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd184: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd185: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd186: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd187: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd188: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd189: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd8;
                _r_decimal_2 = 4'd1;
            end

            8'd190: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd191: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd192: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd193: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd194: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd195: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd196: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd197: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd198: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd199: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd9;
                _r_decimal_2 = 4'd1;
            end

            8'd200: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd201: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd202: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd203: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd204: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd205: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd206: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd207: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd208: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd209: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd0;
                _r_decimal_2 = 4'd2;
            end

            8'd210: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd211: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd212: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd213: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd214: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd215: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd216: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd217: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd218: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd219: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd1;
                _r_decimal_2 = 4'd2;
            end

            8'd220: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd221: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd222: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd223: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd224: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd225: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd226: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd227: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd228: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd229: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd2;
                _r_decimal_2 = 4'd2;
            end

            8'd230: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd231: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd232: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd233: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd234: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd235: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd236: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd237: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd238: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd239: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd3;
                _r_decimal_2 = 4'd2;
            end

            8'd240: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd241: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd242: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd243: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd244: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd245: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd246: begin
                _r_decimal_0 = 4'd6;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd247: begin
                _r_decimal_0 = 4'd7;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd248: begin
                _r_decimal_0 = 4'd8;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd249: begin
                _r_decimal_0 = 4'd9;
                _r_decimal_1 = 4'd4;
                _r_decimal_2 = 4'd2;
            end

            8'd250: begin
                _r_decimal_0 = 4'd0;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

            8'd251: begin
                _r_decimal_0 = 4'd1;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

            8'd252: begin
                _r_decimal_0 = 4'd2;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

            8'd253: begin
                _r_decimal_0 = 4'd3;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

            8'd254: begin
                _r_decimal_0 = 4'd4;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

            8'd255: begin
                _r_decimal_0 = 4'd5;
                _r_decimal_1 = 4'd5;
                _r_decimal_2 = 4'd2;
            end

        endcase
    end

endmodule

`endif // BYTE_TO_DECIMAL_V
