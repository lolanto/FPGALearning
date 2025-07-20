# -*- coding: UTF-8 -*-

import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.runner import get_runner
from IICChecker import *


ENABLE_DEBUG = True
def try_debug():
    if ENABLE_DEBUG is False:
        return
    import debugpy
    # 启动调试器，监听指定端口
    debugpy.listen(5678, in_process_debug_adapter=True)
    print("Waiting for debugger to attach...")

    # 等待调试器附加
    debugpy.wait_for_client()
    print("Debugger attached, resuming execution...")


IIC_META_INST_START_TX = 0
IIC_META_INST_STOP_TX = 1
IIC_META_INST_SEND_BIT = 2
IIC_META_INST_RECV_BIT = 3
IIC_META_INST_UNKNOWN = 4

g_test_case_enable_settings = {
    'idle': False,
    'start': False,
    'stop': False,
    'send_1_bit': False,
    'send_0_bit': False,
    'send_byte': False,
    'send_common': False,
    'recv_1_bit': False,
    'clock_stretching': True
}

# 通用的复位行为
async def reset_signal(dut):
    print("Start Rest")
    await RisingEdge(dut.in_clk)
    dut.in_rst.value = 1
    await RisingEdge(dut.in_clk)
    dut.in_rst.value = 0
    print("Finish Reset")

def check_scl_is_using_as(dut, expect_value):
    assert dut.out_scl_out.value == expect_value
    assert dut.out_scl_is_using.value == 1

def check_sda_is_using_as(dut, expect_value):
    assert dut.out_sda_out.value == expect_value
    assert dut.out_sda_is_using.value == 1

def check_sda_is_in_high_resitance_state(dut):
    assert dut.out_sda_out.value == 'z'
    assert dut.out_sda_is_using == 0

# 所有用例结束时候，期望的结束状态的信号
def check_end_of_sigs(dut):
    assert dut.out_sda_out.value == 'z'
    assert dut.out_sda_is_using == 0
    assert dut.out_scl_out.value == 'z'
    assert dut.out_scl_is_using == 0

def check_scl_and_sda_is_using_and_not_in_high_resitance_state(dut):
    assert dut.out_sda_out.value != 'z'
    assert dut.out_scl_out.value != 'z'
    assert dut.out_sda_is_using.value == 1
    assert dut.out_scl_is_using.value == 1

async def receive_signals(dut, scl_out_sigs, sda_out_sigs):
    iter_count = 0
    while True:
        await RisingEdge(dut.in_clk)
        check_scl_and_sda_is_using_and_not_in_high_resitance_state(dut)
        sda_out_sigs.append(int(dut.out_sda_out.value))
        scl_out_sigs.append(int(dut.out_scl_out.value))
        if dut.out_is_completed.value == 1:
            break
        iter_count += 1
        if iter_count > 5000:
            break
    assert iter_count < 5000

'''
测试用例：用来测试静止状态下的设备输出情况

期望是所有输出都是处于悬空状态
'''
@cocotb.test(skip=not g_test_case_enable_settings['idle'])
async def idle_signal(dut):
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start())
    await reset_signal(dut)
    print("Start Simulate")
    def assert_im_idle(dut):
        assert dut.out_sda_out.value == 'z'
        assert dut.out_sda_is_using == 0
        assert dut.out_scl_out.value == 'z'
        assert dut.out_scl_is_using == 0
    assert_im_idle(dut)
    for _ in range(128):
        await RisingEdge(dut.in_clk)
        assert_im_idle(dut)

'''
测试用例：发送开始信号(标准模式)
开始信号特征——SDA在SCL的高电平状态下由高电平转换成低电平：
1. SCL处于高电平，拉高SDA
2. SDA处于高电平，并维持>4.7us
3. SDA进入低电平，并维持>4.7us
4. SCL处于低电平

检查条件：
信号开始：scl，sda处在高电平
信号中间：这个信号比较特别，它其实只跑3/4个SCL时钟周期，先是一个完整的高电平SCL，然后是半个低电平的SCL
    原因是给之后的动作腾出一个预先的低电平SCL，方便SDA信号进行切换,
    因此SDA的高电平只占SCL的1/3
信号结束：scl, sda处在低电平
动作结束：scl, sda重新处在高阻抗状态

TODO: 还需要考虑信号的时间情况，一个SCL时钟周期在10us左右
'''
@cocotb.test(skip=not g_test_case_enable_settings['start'])
async def start_signal(dut):
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_instruction.value = IIC_META_INST_START_TX
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 1)
    check_sda_is_using_as(dut, 1)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [1]
    scl_out_sigs = [1]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs)
    
    try_to_match_iic_sigs([ IIC_Checker.Start_Checker() ], scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)
    
'''
测试用例：发送结束信号(标准模式)
结束信号特征——SDA在SCL高电平状态下由低电平转为高电平：
1. SCL处于低电平，SDA处于低电平，维持半个SCL时钟周期
3. SCL进入高电平，并维持>4.7us，0.25个SCL时钟周期
4. SDA进入高电平，并维持>4.7us，0.25个SCL时钟周期

检查条件：
信号开始：scl，sda处在低电平
信号中间：这个信号比较特别，它其实只跑3/4个SCL时钟周期，先是半个的低电平SCL，然后是整个高电平的SCL
    原因是之前的SCL因为已经执行过别的动作，因此之前的SCL必然处在低电平的状态
    因此只有结束状态的SDA连续高电平占SCL的1/3
信号结束：scl, sda处在高电平
动作结束：scl, sda重新处在高阻抗状态
'''
@cocotb.test(skip=not g_test_case_enable_settings['stop'])
async def stop_signal(dut):
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_instruction.value = IIC_META_INST_STOP_TX
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 0)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [0]
    scl_out_sigs = [0]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs)
    
    try_to_match_iic_sigs([ IIC_Checker.Stop_Checker() ], scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


'''
测试用例：一个1bit(标准模式)
信号特征：SCL在高电平时，SDA也处于高电平
SDA一直处于高电平状态，而SCL则先处于低电平状态(1/4 周期)，然后进入高电平状态(1/2 周期)，最后再回到低电平状态

检查条件：
信号开始：scl处于低电平状态，sda处在高电平状态
信号结束：分析SCL处于高电平阶段，SDA处于高电平的时间，是否超过SCL高电平时间的98%
动作结束：scl, sda重新处在高阻抗状态
'''
@cocotb.test(skip=not g_test_case_enable_settings['send_1_bit'])
async def send_1_bit_signal(dut):
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_instruction.value = IIC_META_INST_SEND_BIT
    dut.in_bit_to_send.value = 1
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    dut.in_bit_to_send.value = 0
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [1]
    scl_out_sigs = [0]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs)
    
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(1) ], scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


'''
测试用例：一个1bit(标准模式)
信号特征：SCL在高电平时，SDA处于低电平(0bit)
'''
@cocotb.test(skip=not g_test_case_enable_settings['send_0_bit'])
async def send_0_bit_signal(dut):
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_instruction.value = IIC_META_INST_SEND_BIT
    dut.in_bit_to_send.value = 0
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    dut.in_bit_to_send.value = 0
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 0)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [0]
    scl_out_sigs = [0]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs)
    
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(0) ], scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


'''
测试用例：发送一个字节(标准模式)
用来模拟字节信号的发送是否符合预期
预期字节：(MSB) 01011010 (LSB)
'''
@cocotb.test(skip=not g_test_case_enable_settings['send_byte'])
async def send_byte(dut):
    # try_debug()
    TARGET_BYTE_BITS = [0, 1, 0, 1, 1, 0, 1, 0]
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    sda_out_sigs = []
    scl_out_sigs = []
    for bit in TARGET_BYTE_BITS:
        dut.in_instruction.value = IIC_META_INST_SEND_BIT
        dut.in_bit_to_send.value = bit
        await RisingEdge(dut.in_clk)
        # 一个上升沿后恢复命令
        dut.in_instruction.value = IIC_META_INST_UNKNOWN
        dut.in_bit_to_send.value = 0
        # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
        check_scl_is_using_as(dut, 0)
        check_sda_is_using_as(dut, bit)
        assert dut.out_is_completed.value == 0

        sda_out_sigs.append(int(dut.out_sda_out.value))
        scl_out_sigs.append(int(dut.out_scl_out.value))

        await receive_signals(dut, scl_out_sigs, sda_out_sigs)

    try_to_match_iic_sigs([ 
        IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1),
        IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0)],
        scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


'''
测试用例：发送一个字节，同时带上开始和结束信号，但是没有带ACK信号(标准模式)
用来模拟字节信号的发送是否符合预期
预期字节：(MSB) 01011010 (LSB)
'''
@cocotb.test(skip=not g_test_case_enable_settings['send_common'])
async def send_common(dut):
    try_debug()
    TARGET_BYTE_BITS = [0, 1, 0, 1, 1, 0, 1, 0]
    TARGET_INSTRUCTIONS = [IIC_META_INST_START_TX, 
                           IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT,
                           IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT, IIC_META_INST_SEND_BIT,
                           IIC_META_INST_STOP_TX]
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    sda_out_sigs = []
    scl_out_sigs = []
    send_bit_idx = 0
    for instruction in TARGET_INSTRUCTIONS:
        dut.in_instruction.value = instruction
        bit = 0 if instruction == IIC_META_INST_STOP_TX else 1 if instruction == IIC_META_INST_START_TX else TARGET_BYTE_BITS[send_bit_idx]
        if instruction == IIC_META_INST_SEND_BIT:
            send_bit_idx += 1
        dut.in_bit_to_send.value = bit
        await RisingEdge(dut.in_clk)
        # 一个上升沿后恢复命令
        dut.in_instruction.value = IIC_META_INST_UNKNOWN
        dut.in_bit_to_send.value = 0
        # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
        check_scl_is_using_as(dut, 0 if instruction != IIC_META_INST_START_TX else 1)
        check_sda_is_using_as(dut, bit)
        assert dut.out_is_completed.value == 0

        sda_out_sigs.append(int(dut.out_sda_out.value))
        scl_out_sigs.append(int(dut.out_scl_out.value))

        await receive_signals(dut, scl_out_sigs, sda_out_sigs)

    try_to_match_iic_sigs([
        IIC_Checker.Start_Checker(),
        IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1),
        IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0), IIC_Checker.Bit_Checker(1), IIC_Checker.Bit_Checker(0),
        IIC_Checker.Stop_Checker()],
        scl_out_sigs, sda_out_sigs)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


'''
测试用例：接收一个bit信号(标准模式)
'''
@cocotb.test(skip=not g_test_case_enable_settings['recv_1_bit'])
async def recv_1_bit_sig(dut):
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    sda_in_sigs = []
    scl_out_sigs = []
    dut.in_instruction.value = IIC_META_INST_RECV_BIT
    dut.in_sda_in.value = 1
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    assert dut.out_is_completed.value == 0

    scl_out_sigs.append(int(dut.out_scl_out.value))
    sda_in_sigs.append(int(dut.in_sda_in.value))

    iter_count = 0
    while True:
        await RisingEdge(dut.in_clk)
        scl_out_sigs.append(int(dut.out_scl_out.value))
        sda_in_sigs.append(int(dut.in_sda_in.value))
        check_sda_is_in_high_resitance_state(dut)
        if dut.out_is_completed.value == 1:
            break
        iter_count += 1
        if iter_count > 5000:
            break
    assert iter_count < 5000

    assert dut.out_bit_read.value == 1
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(1) ], scl_out_sigs, sda_in_sigs)


'''
测试用例：发送时候突然遇到了时钟延展的情况
预期行为：在发送bit的时候，clk总线被钳低，那么将会重新发送这个bit。
'''
@cocotb.test(skip=not g_test_case_enable_settings['clock_stretching'])
async def sending_while_clock_stretching(dut):
    try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_instruction.value = IIC_META_INST_SEND_BIT
    dut.in_bit_to_send.value = 1
    await RisingEdge(dut.in_clk)
    dut.in_instruction.value = IIC_META_INST_UNKNOWN
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)

    assert dut.out_is_completed.value == 0
    # IICMeta模块执行一个指令的需要的时钟周期总共是2^7个
    # 发送bit的时钟周期被拆分成4段：
    # 开始阶段，SCL处于低电平，时钟周期为2^5
    # 发送阶段，SCL处于高电平，时钟周期为2^6
    # 结束阶段，SCL处于低电平，时钟周期为2^5
    clk_count_for_start = 2**5
    clk_count_for_send = 2**6
    clk_count_for_end = 2**5
    clk_count_initial = 2 # IICMeta模块的时钟周期初始值为2
    for _ in range(clk_count_for_start - clk_count_initial - 2): # '-1'是为了增加一点容错，我怕算错周期，延后了钳制时机
        await RisingEdge(dut.in_clk)
    for _ in range(50):
        dut.in_scl_in.value = 0 # 模拟钳制SCL总线
        await RisingEdge(dut.in_clk)
    dut.in_scl_in.value = 1 # 恢复SCL总线
    await RisingEdge(dut.in_clk) # 执行一个tick，给IICMeta模块一个时钟周期的时间来从钳制转成“重启”
    # 这里会存在一个问题是，一旦从机解除钳制，scl主线会被主机直接拉高。因为主机在时钟延展期间一直在尝试拉高总线
    # 主机只有等钳制解除的下一个时钟上升沿，才能识别到总线被成功拉高，继而重新执行命令(将scl再拉低)
    # 放开，让bit发送指令执行
    sda_out_sigs = []
    scl_out_sigs = []
    while True:
        await RisingEdge(dut.in_clk)
        sda_out_sigs.append(int(dut.out_sda_out.value))
        scl_out_sigs.append(int(dut.out_scl_out.value))
        check_scl_and_sda_is_using_and_not_in_high_resitance_state(dut)
        if dut.out_is_completed.value == 1:
            break
    # 校验sda和scl的输出信号
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(1) ], scl_out_sigs, sda_out_sigs)
    

def main():
    proj_path = os.path.dirname(os.path.abspath(__file__))

    always_run_build_step = True
    generate_wave = True

    source_dirs = [ os.path.join(proj_path, "../../IICMeta.v") ]
    include_dirs = [ os.path.join(proj_path, "../../") ]
    build_dir = os.path.join(proj_path, 'tb_build')
    pre_defines = {'DEBUG_TEST_BENCH': '1'}
    top_level_module = 'IICMeta'

    runner = get_runner('icarus')
    runner.build(
        verilog_sources=source_dirs,
        hdl_toplevel=top_level_module,
        always=always_run_build_step,
        waves=generate_wave,
        build_dir=build_dir,
        includes=include_dirs,
        defines=pre_defines,
        timescale=('1us', '1ns')
    )

    runner.test(hdl_toplevel=top_level_module, test_module='tb_IICMeta,', waves=generate_wave)


if __name__ == '__main__':
    main()

