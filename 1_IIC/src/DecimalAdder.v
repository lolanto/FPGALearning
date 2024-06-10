`ifndef DECIMAL_ADDER_V
`define DECIMAL_ADDER_V
/**
 * @brief 两个一位十进制数的加法器，用组合逻辑实现
 * @param in_carry 输入的进位，0或者1
 * @param in_v1 加法器操作数1
 * @param in_v2 加法器操作数2
 * @param out_result 加法器的计算结果，[0, 9]
 * @param out_carray 加法器计算结果是否需要进位
 * @note
 * 这个加法器是为了方便之后译码做的，事实上效率并不高，比方说用了4bit来表达10个数字..
 * 但是这点浪费可以减少之后大量的操作(简化二进制到十进制之间逐位的转换)
 */
module DecimalAdder(
    input wire in_carry,
    input wire [3:0] in_v1,
    input wire [3:0] in_v2,
    output wire [3:0] out_result,
    output wire out_carry
);
    reg [4:0] _r_added;
    reg [3:0] _r_result;
    reg _r_carry;

    always @(*) begin
        _r_added = {1'b0, in_v1} + {1'b0, in_v2} + {4'b0000, in_carry};
        case (_r_added)
        5'd0: begin
            _r_result = 4'd0;
            _r_carry = 1'b0;
        end
        5'd1: begin
            _r_result = 4'd1;
            _r_carry = 1'b0;
        end
        5'd2: begin
            _r_result = 4'd2;
            _r_carry = 1'b0;
        end
        5'd3: begin
            _r_result = 4'd3;
            _r_carry = 1'b0;
        end
        5'd4: begin
            _r_result = 4'd4;
            _r_carry = 1'b0;
        end
        5'd5: begin
            _r_result = 4'd5;
            _r_carry = 1'b0;
        end
        5'd6: begin
            _r_result = 4'd6;
            _r_carry = 1'b0;
        end
        5'd7: begin
            _r_result = 4'd7;
            _r_carry = 1'b0;
        end
        5'd8: begin
            _r_result = 4'd8;
            _r_carry = 1'b0;
        end
        5'd9: begin
            _r_result = 4'd9;
            _r_carry = 1'b0;
        end
        5'd10: begin
            _r_result = 4'd0;
            _r_carry = 1'b1;
        end
        5'd11: begin
            _r_result = 4'd1;
            _r_carry = 1'b1;
        end
        5'd12: begin
            _r_result = 4'd2;
            _r_carry = 1'b1;
        end
        5'd13: begin
            _r_result = 4'd3;
            _r_carry = 1'b1;
        end
        5'd14: begin
            _r_result = 4'd4;
            _r_carry = 1'b1;
        end
        5'd15: begin
            _r_result = 4'd5;
            _r_carry = 1'b1;
        end
        5'd16: begin
            _r_result = 4'd6;
            _r_carry = 1'b1;
        end
        5'd17: begin
            _r_result = 4'd7;
            _r_carry = 1'b1;
        end
        5'd18: begin
            _r_result = 4'd8;
            _r_carry = 1'b1;
        end
        5'd19: begin
            _r_result = 4'd9;
            _r_carry = 1'b1;
        end
        default: begin
            _r_result = 4'd0;
            _r_carry = 1'b0;
        end
        endcase
    end

    assign out_result = _r_result;
    assign out_carry = _r_carry;

endmodule

`endif ///< DECIMAL_ADDER_V