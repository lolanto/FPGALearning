/**
 * 三态门示例代码
 * @param inout_wire 三态门输入输出端口
 * @param in_btn_1 为0(默认)则表示当前处于输入状态，为1则处于输出状态
 * @param in_btn_2 当三态门处于输出状态时，用来控制输出的值，为0(默认)时输出0，否则输出1
 * @return out_led_1 用来表明当前三态门的输入情况。当处于输入状态时，根据输入结果显示亮灭；当处于输出状态时，灯灭
 */

/**
 * 实验结果：
 * 1. 当请求输出高阻抗时，输入能够读取到线上的实际值
 * 2. 当请求输出低电平时，输入能够读取到的也是低电平
 * 3. 当请求输出高电平时，输入能够读取到的也是高电平
 * 4. 当请求输出高电平，但此时外部已经被拉低时，输入能够读取到的依旧是低电平！
 */

module Top(
    inout wire inout_wire,
    input wire in_btn_1,
    input wire in_btn_2,
    output wire out_led_1
);

    reg _r_value_in;
    reg _r_value_out;
    wire _w_trying_output = in_btn_1;
    assign inout_wire = _w_trying_output ? _r_value_out : 1'bz;

    always @(*) begin
        _r_value_in = inout_wire;
        _r_value_out = in_btn_2;
    end

    wire _w_led_on = _r_value_in;
    assign out_led_1 = ~_w_led_on; // 我用的板子led高电平灭，低电平亮

endmodule
