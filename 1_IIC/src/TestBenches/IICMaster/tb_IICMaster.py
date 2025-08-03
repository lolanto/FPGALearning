import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.runner import get_runner
from IICChecker import *

# 提前x个时钟周期拉起完成信号
ENABLE_SIGNAL_PRE_COMPLETED = 3

ENABLE_DEBUG = False
def try_debug():
    if ENABLE_DEBUG is False:
        return
    import debugpy
    # 启动调试器，监听指定端口
    debugpy.listen(("127.0.0.1", 9855), in_process_debug_adapter=True)
    print("Waiting for debugger to attach...")

    # 等待调试器附加
    debugpy.wait_for_client()
    print("Debugger attached, resuming execution...")


IIC_INST_UNKNOWN = 0
IIC_INST_START_TX = IIC_INST_UNKNOWN + 1
IIC_INST_REPEAT_START_TX = IIC_INST_START_TX + 1
IIC_INST_STOP_TX = IIC_INST_REPEAT_START_TX + 1
IIC_INST_RECV_BYTE = IIC_INST_STOP_TX + 1
IIC_INST_SEND_BYTE = IIC_INST_RECV_BYTE + 1

g_run_all = True

g_test_case_enable_settings = {
    'idle': False,
    'start': False,
    'repeat_start': False,
    'stop': False,
    'send_byte': False,
    'receive_byte': False,
    'clock_stretching_send_byte': False,
    'clock_stretching_receive_byte': False,
    'complete_send_and_receive': False,
    'complete_receive_and_send': False,
    'start_repeat_start_send_and_stop': False, # 开始信号后再发送开始信号
    'start_receive_stop_start_send_stop': False, # 开始接收停止再开始发送最后停止
    'start_send_send_stop': False,
    'start_receive_receive_stop': True
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

async def receive_signals(dut, scl_out_sigs, sda_out_sigs, timeout=5000, complete_callback=None):
    iter_count = 0
    complete_sig_count_down = ENABLE_SIGNAL_PRE_COMPLETED
    while iter_count < timeout:
        await RisingEdge(dut.in_clk)
        if complete_callback is not None and dut.out_is_completed.value == 1:
            complete_callback()
        if dut.out_is_completed.value == 1:
            complete_sig_count_down -= 1
        check_scl_and_sda_is_using_and_not_in_high_resitance_state(dut)
        sda_out_sigs.append(int(dut.out_sda_out.value))
        scl_out_sigs.append(int(dut.out_scl_out.value))
        iter_count += 1
        if dut.out_is_completed.value == 1 and complete_sig_count_down == 0:
            break
    assert iter_count < 5000


@cocotb.test(skip=not g_test_case_enable_settings['idle'] and not g_run_all)
async def idle_signal(dut):
    """
    测试用例：用来测试静止状态下的设备输出情况

    期望是所有输出都是处于悬空状态
    """
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start())
    await reset_signal(dut)
    print("Start Simulate")
    def _assert_im_idle(dut):
        assert dut.out_sda_out.value == 'z'
        assert dut.out_sda_is_using == 0
        assert dut.out_scl_out.value == 'z'
        assert dut.out_scl_is_using == 0
    _assert_im_idle(dut)
    for _ in range(128):
        await RisingEdge(dut.in_clk)
        _assert_im_idle(dut)


async def _impl_start_signal(dut, skip_cmd_setting, in_complete_callback=None):
    if skip_cmd_setting is False:
        dut.in_instruction.value = IIC_INST_START_TX
        dut.in_enable.value = 1
        await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 1)
    check_sda_is_using_as(dut, 1)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [1]
    scl_out_sigs = [1]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, complete_callback=in_complete_callback)
    
    try_to_match_iic_sigs([ IIC_Checker.Start_Checker() ], scl_out_sigs, sda_out_sigs)

@cocotb.test(skip=not g_test_case_enable_settings['start'] and not g_run_all)
async def start_signal(dut):
    """
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
    """
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    
    await _impl_start_signal(dut, skip_cmd_setting=False)
    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_stop_signal(dut, skip_cmd_setting, in_complete_callback=None):
    if skip_cmd_setting is False:
        dut.in_instruction.value = IIC_INST_STOP_TX
        dut.in_enable.value = 1
        await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 0)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [0]
    scl_out_sigs = [0]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, complete_callback=in_complete_callback)
    
    try_to_match_iic_sigs([ IIC_Checker.Stop_Checker() ], scl_out_sigs, sda_out_sigs)

@cocotb.test(skip=not g_test_case_enable_settings['stop'] and not g_run_all)
async def stop_signal(dut):
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
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    await _impl_stop_signal(dut, skip_cmd_setting=False)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_repeat_start(dut, skip_cmd_setting, in_complete_callback=None):
    if skip_cmd_setting is False:
        dut.in_instruction.value = IIC_INST_REPEAT_START_TX
        dut.in_enable.value = 1
        await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)
    assert dut.out_is_completed.value == 0
    
    sda_out_sigs = [1]
    scl_out_sigs = [0]
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, complete_callback=in_complete_callback)
    
    try_to_match_iic_sigs([ IIC_Checker.Repeat_Start_Checker() ], scl_out_sigs, sda_out_sigs)


@cocotb.test(skip=not g_test_case_enable_settings['repeat_start'] and not g_run_all)
async def repeat_start(dut):
    """
    测试用例：发送重复开始信号(标准模式)
    开始信号特征——SDA在SCL的高电平状态下由高电平转换成低电平：
    1. SCL处于高电平，拉高SDA
    2. SDA处于高电平，并维持>4.7us
    3. SDA进入低电平，并维持>4.7us
    4. SCL处于低电平

    检查条件：
    信号开始：scl处于低电平，sda处于高电平，维持1/4个时钟周期
    信号中间1：scl拉高电平, sda保持高电平，维持到2/4个时钟周期
    信号中间2：scl保持高电平，sda拉低电平，维持到3/4个时钟周期
    信号结束：scl, sda处在低电平
    """
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    await _impl_repeat_start(dut, skip_cmd_setting=False)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_send_byte(dut, byte_to_send, skip_cmd_setting, in_complete_callback=None):
    if skip_cmd_setting is False:
        dut.in_instruction.value = IIC_INST_SEND_BYTE
        dut.in_byte_to_send.value = byte_to_send
        dut.in_enable.value = 1
        await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, ((byte_to_send >> 7) & 1))
    assert dut.out_is_completed.value == 0

    sda_out_sigs = [((byte_to_send >> 7) & 1)]
    scl_out_sigs = [0]

    # 发送一个字节需要8个SCL时钟周期，每个周期单独需要tick 128次，第一个周期提前进行了一次tick所以减一
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, timeout=128 * 8 - 1)
    
    bit_checkers_of_byte_to_send = []
    for i in range(7, -1, -1):
        bit_checkers_of_byte_to_send.append(IIC_Checker.Bit_Checker((byte_to_send >> i) & 1))

    try_to_match_iic_sigs(bit_checkers_of_byte_to_send, scl_out_sigs, sda_out_sigs)

    # 开始进入ACK接收状态
    dut.in_sda_in.value = 1  # 模拟ACK信号为1
    for _ in range(32):
        await RisingEdge(dut.in_clk)
        check_scl_is_using_as(dut, 0)
        check_sda_is_in_high_resitance_state(dut)
    for _ in range(64):
        await RisingEdge(dut.in_clk)
        check_scl_is_using_as(dut, 1)
        check_sda_is_in_high_resitance_state(dut)
    for _ in range(32 - ENABLE_SIGNAL_PRE_COMPLETED):
        await RisingEdge(dut.in_clk)
        check_scl_is_using_as(dut, 0)
        check_sda_is_in_high_resitance_state(dut)

    if ENABLE_SIGNAL_PRE_COMPLETED:
        for i in range(ENABLE_SIGNAL_PRE_COMPLETED):
            await RisingEdge(dut.in_clk)
            # 提前拉起了完成信号
            assert dut.out_is_completed.value == 1
            assert dut.out_ack_read.value == 1
            check_scl_is_using_as(dut, 0)
            check_sda_is_in_high_resitance_state(dut)
            if in_complete_callback is not None:
                in_complete_callback()
    else:
        await RisingEdge(dut.in_clk)
        assert dut.out_is_completed.value == 1
        assert dut.out_ack_read.value == 1

@cocotb.test(skip=not g_test_case_enable_settings['send_byte'] and not g_run_all)
async def send_byte(dut):
    '''
    测试用例：发送一个字节(标准模式)
    用来模拟字节信号的发送是否符合预期
    预期字节：(MSB) 11011010 (LSB)
    '''
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    try_debug()
    await _impl_send_byte(dut, 0b11011010, skip_cmd_setting=False)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_clock_stretching_send_byte(dut, byte_to_send, time_of_stretching):
    dut.in_instruction.value = IIC_INST_SEND_BYTE
    dut.in_byte_to_send.value = byte_to_send
    dut.in_enable.value = 1
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)
    assert dut.out_is_completed.value == 0

    # 模拟时钟拉伸，将scl总线钳制到低电平
    for _ in range(time_of_stretching):
        dut.in_scl_in.value = 0
        await RisingEdge(dut.in_clk)
        while dut.out_is_clock_stretching.value != 1:
            await RisingEdge(dut.in_clk)
    
    dut.in_scl_in.value = 1  # 恢复SCL总线
    await RisingEdge(dut.in_clk)
    assert dut.out_is_clock_stretching.value == 0

    sda_out_sigs = [1]
    scl_out_sigs = [0]

    # 发送一个字节需要8个SCL时钟周期，每个周期单独需要tick 128次，第一个周期提前进行了一次tick所以减一
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, timeout=128 * 8 - 1)

    bit_checkers_of_byte_to_send = []
    for i in range(7, -1, -1):
        bit_checkers_of_byte_to_send.append(IIC_Checker.Bit_Checker((byte_to_send >> i) & 1))

    try_to_match_iic_sigs(bit_checkers_of_byte_to_send,
        scl_out_sigs, sda_out_sigs)
    
    # 开始进入ACK接收状态
    await RisingEdge(dut.in_clk)
    dut.in_sda_in.value = 1  # 模拟ACK信号为1
    for _ in range(32):
        check_scl_is_using_as(dut, 0)
        check_sda_is_in_high_resitance_state(dut)
        await RisingEdge(dut.in_clk)
    for _ in range(64):
        check_scl_is_using_as(dut, 1)
        check_sda_is_in_high_resitance_state(dut)
        await RisingEdge(dut.in_clk)
    for _ in range(32):
        check_scl_is_using_as(dut, 0)
        check_sda_is_in_high_resitance_state(dut)
        await RisingEdge(dut.in_clk)
    
    assert dut.out_is_completed.value == 1
    assert dut.out_ack_read.value == 1



@cocotb.test(skip=not g_test_case_enable_settings['clock_stretching_send_byte'] and not g_run_all)
async def clock_stretching_send_byte(dut):
    '''
    测试用例：发送一个字节，但是在发送之前遇到了时钟拉伸(标准模式)
    用来模拟字节信号的发送是否符合预期
    预期：检查到时钟拉伸，则暂停发送，并在拉伸结束后重新发送
    '''
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    
    await _impl_clock_stretching_send_byte(dut, 0b11001010, 4)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting, in_complete_callback=None):
    if skip_cmd_setting is False:
        dut.in_instruction.value = IIC_INST_RECV_BYTE
        dut.in_enable.value = 1
        await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_in_high_resitance_state(dut)
    assert dut.out_is_completed.value == 0

    # 模拟接收数据，需要监听SCL的状态，以判断输入的SDA的值
    for i in range(7, -1, -1):
        time_scl_in_0 = 0
        while dut.out_scl_out.value != 1:
            time_scl_in_0 += 1
            check_scl_is_using_as(dut, 0)
            check_sda_is_in_high_resitance_state(dut)
            await RisingEdge(dut.in_clk)
        assert time_scl_in_0 == 32
        # 在SCL为高电平时，设置SDA的输入值
        time_scl_in_1 = 0
        while dut.out_scl_out.value != 0:
            time_scl_in_1 += 1
            check_scl_is_using_as(dut, 1)
            check_sda_is_in_high_resitance_state(dut)
            dut.in_sda_in.value = (byte_to_receive >> i) & 1
            await RisingEdge(dut.in_clk)
        assert time_scl_in_1 == 64
        for _ in range(32):
            check_scl_is_using_as(dut, 0)
            check_sda_is_in_high_resitance_state(dut)
            await RisingEdge(dut.in_clk)

    # 模拟发送ACK信号
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)
    sda_out_sigs = [1]
    scl_out_sigs = [0]
    
    await receive_signals(dut, scl_out_sigs, sda_out_sigs, complete_callback=in_complete_callback)
    assert dut.out_byte_read.value == byte_to_receive

    # 检查ACK输出信号
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(1) ], scl_out_sigs, sda_out_sigs)


@cocotb.test(skip=not g_test_case_enable_settings['receive_byte'] and not g_run_all)
async def receive_byte(dut):
    '''
    测试用例：模拟接收一个字节(标准模式)
    用来模拟字节信号的接收是否符合预期
    预期字节：(MSB) 10011010 (LSB)
    '''
    byte_to_receive = 0b10011010
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    await _impl_receive_byte(dut, byte_to_receive, False)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


async def _impl_clock_stretching_receive_byte(dut, byte_to_receive, clock_stretching_time):
    dut.in_instruction.value = IIC_INST_RECV_BYTE
    dut.in_enable.value = 1
    await RisingEdge(dut.in_clk)
    # 一个上升沿后恢复命令
    dut.in_instruction.value = IIC_INST_UNKNOWN
    dut.in_enable.value = 0
    await RisingEdge(dut.in_clk)
    # 指令配置之后的第一个时钟上升沿，检查scl和sda的初始状态
    check_scl_is_using_as(dut, 0)
    check_sda_is_in_high_resitance_state(dut)
    assert dut.out_is_completed.value == 0

    # 模拟时钟拉伸，将scl总线钳制到低电平
    for _ in range(clock_stretching_time):
        dut.in_scl_in.value = 0
        await RisingEdge(dut.in_clk)
        while dut.out_is_clock_stretching.value != 1:
            await RisingEdge(dut.in_clk)
    
    dut.in_scl_in.value = 1  # 恢复SCL总线
    await RisingEdge(dut.in_clk)
    assert dut.out_is_clock_stretching.value == 0

    # 模拟接收数据，需要监听SCL的状态，以判断输入的SDA的值
    for i in range(7, -1, -1):
        time_scl_in_0 = 0
        while dut.out_scl_out.value != 1:
            time_scl_in_0 += 1
            check_scl_is_using_as(dut, 0)
            check_sda_is_in_high_resitance_state(dut)
            await RisingEdge(dut.in_clk)
        assert time_scl_in_0 == 32
        # 在SCL为高电平时，设置SDA的输入值
        time_scl_in_1 = 0
        while dut.out_scl_out.value != 0:
            time_scl_in_1 += 1
            check_scl_is_using_as(dut, 1)
            check_sda_is_in_high_resitance_state(dut)
            dut.in_sda_in.value = (byte_to_receive >> i) & 1
            await RisingEdge(dut.in_clk)
        assert time_scl_in_1 == 64
        for _ in range(32):
            check_scl_is_using_as(dut, 0)
            check_sda_is_in_high_resitance_state(dut)
            await RisingEdge(dut.in_clk)

    # 模拟发送ACK信号
    check_scl_is_using_as(dut, 0)
    check_sda_is_using_as(dut, 1)
    sda_out_sigs = [1]
    scl_out_sigs = [0]
    
    await receive_signals(dut, scl_out_sigs, sda_out_sigs)
    assert dut.out_byte_read.value == byte_to_receive

    # 检查ACK输出信号
    try_to_match_iic_sigs([ IIC_Checker.Bit_Checker(1) ], scl_out_sigs, sda_out_sigs)

@cocotb.test(skip=not g_test_case_enable_settings['clock_stretching_receive_byte'] and not g_run_all)
async def clock_stretching_receive_byte(dut):
    '''
    测试用例：模拟接收一个字节，但是在接收之前遇到了时钟拉伸(标准模式)
    用来模拟字节信号的接收是否符合预期
    预期字节：(MSB) 10011010 (LSB)
    '''
    byte_to_receive = 0b10011010
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")
    
    await _impl_clock_stretching_receive_byte(dut, byte_to_receive, 4)

    # 再过一个时钟上升沿，上层器件设置下一步命令
    await RisingEdge(dut.in_clk)
    # 上层器件不设置任何命令
    # 再过一个时钟上升沿，器件应该恢复默认状态
    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


@cocotb.test(skip=not g_test_case_enable_settings['complete_send_and_receive'] and not g_run_all)
async def complete_send_and_receive(dut):
    '''
    测试用例：完整地进行一次发送和接收字节流程，包括发送开始和结束信号
    '''
    byte_to_send = 0b11000101
    byte_to_receive = 0b10011010
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send.value = byte_to_send
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)

    send_byte_complete_callback_state = 0
    def send_byte_complete_callback():
        nonlocal dut
        nonlocal send_byte_complete_callback_state
        if send_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_RECV_BYTE
        send_byte_complete_callback_state += 1

    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback)

    recv_byte_complete_callback_state = 0
    def recv_byte_complete_callback():
        nonlocal dut
        nonlocal recv_byte_complete_callback_state
        if recv_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        recv_byte_complete_callback_state += 1

    await _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting=True, in_complete_callback=recv_byte_complete_callback)

    await _impl_stop_signal(dut, skip_cmd_setting=True)

    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)

@cocotb.test(skip=not g_test_case_enable_settings['complete_receive_and_send'] and not g_run_all)
async def complete_receive_and_send(dut):
    '''
    测试用例：完整地进行一次发送和接收字节流程，包括发送开始和结束信号
    '''
    byte_to_send = 0b11000101
    byte_to_receive = 0b10011010
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_RECV_BYTE
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)


    recv_byte_complete_callback_state = 0
    def recv_byte_complete_callback():
        nonlocal dut
        nonlocal recv_byte_complete_callback_state
        if recv_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send.value = byte_to_send
        recv_byte_complete_callback_state += 1

    await _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting=True, in_complete_callback=recv_byte_complete_callback)

    send_byte_complete_callback_state = 0
    def send_byte_complete_callback():
        nonlocal dut
        nonlocal send_byte_complete_callback_state
        if send_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        send_byte_complete_callback_state += 1
    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback)

    await _impl_stop_signal(dut, skip_cmd_setting=True)

    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)

@cocotb.test(skip=not g_test_case_enable_settings['start_repeat_start_send_and_stop'] and not g_run_all)
async def start_repeat_start_send_and_stop(dut):

    byte_to_send = 0b11000101
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_REPEAT_START_TX
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)
    
    repeat_start_complete_callback_state = 0
    def repeat_start_complete_callback():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal repeat_start_complete_callback_state
        if repeat_start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send.value = byte_to_send
        repeat_start_complete_callback_state += 1

    await _impl_repeat_start(dut, skip_cmd_setting=True, in_complete_callback=repeat_start_complete_callback)

    send_byte_complete_callback_state = 0
    def send_byte_complete_callback():
        nonlocal dut
        nonlocal send_byte_complete_callback_state
        if send_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        send_byte_complete_callback_state += 1

    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback)

    await _impl_stop_signal(dut, skip_cmd_setting=True)

    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


@cocotb.test(skip=not g_test_case_enable_settings['start_receive_stop_start_send_stop'] and not g_run_all)
async def start_receive_stop_start_send_stop(dut):

    byte_to_send = 0b11000101
    byte_to_receive = 0b10011010
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_RECV_BYTE
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)

    recv_byte_complete_callback_state = 0
    def recv_byte_complete_callback():
        nonlocal dut
        nonlocal recv_byte_complete_callback_state
        if recv_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        recv_byte_complete_callback_state += 1

    await _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting=True, in_complete_callback=recv_byte_complete_callback)

    stop_complete_callback_state = 0
    def stop_complete_callback():
        nonlocal dut
        nonlocal stop_complete_callback_state
        if stop_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_START_TX
        stop_complete_callback_state += 1

    await _impl_stop_signal(dut, skip_cmd_setting=True, in_complete_callback=stop_complete_callback)

    start_complete_callback_state_2 = 0
    def start_complete_callback_2():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal start_complete_callback_state_2
        if start_complete_callback_state_2 == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send = byte_to_send
        start_complete_callback_state_2 += 1

    await _impl_start_signal(dut, skip_cmd_setting=True, in_complete_callback=start_complete_callback_2)

    send_byte_complete_callback_state = 0
    def send_byte_complete_callback():
        nonlocal dut
        nonlocal send_byte_complete_callback_state
        if send_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        send_byte_complete_callback_state += 1
    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback)

    await _impl_stop_signal(dut, skip_cmd_setting=True)


@cocotb.test(skip=not g_test_case_enable_settings['start_send_send_stop'] and not g_run_all)
async def start_send_send_stop(dut):
    '''
    测试用例：完整地进行一次发送和接收字节流程，包括发送开始和结束信号
    '''
    byte_to_send = 0b11000101
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send = byte_to_send
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)

    send_byte_complete_callback_state = 0
    def send_byte_complete_callback():
        nonlocal dut
        nonlocal byte_to_send
        nonlocal send_byte_complete_callback_state
        if send_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_SEND_BYTE
            dut.in_byte_to_send = byte_to_send
        send_byte_complete_callback_state += 1
    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback)

    send_byte_complete_callback_state_2 = 0
    def send_byte_complete_callback_2():
        nonlocal dut
        nonlocal send_byte_complete_callback_state_2
        if send_byte_complete_callback_state_2 == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        send_byte_complete_callback_state_2 += 1
    await _impl_send_byte(dut, byte_to_send, skip_cmd_setting=True, in_complete_callback=send_byte_complete_callback_2)

    await _impl_stop_signal(dut, skip_cmd_setting=True)

    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


@cocotb.test(skip=not g_test_case_enable_settings['start_receive_receive_stop'] and not g_run_all)
async def start_receive_receive_stop(dut):
    '''
    测试用例：完整地进行一次发送和接收字节流程，包括发送开始和结束信号
    '''
    byte_to_receive = 0b10011010
    # try_debug()
    # 创建一个时钟对象，驱动in_clk输入信号，每2ns为一个周期
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start()) # 告诉时钟对象可以开始工作，并直接返回。此时时钟就绪，模拟器还没开始运作
    await reset_signal(dut)
    print("Start Simulate")

    start_complete_callback_state = 0
    def start_complete_callback():
        nonlocal dut
        nonlocal start_complete_callback_state
        if start_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_RECV_BYTE
        start_complete_callback_state += 1

    await _impl_start_signal(dut, skip_cmd_setting=False, in_complete_callback=start_complete_callback)


    recv_byte_complete_callback_state = 0
    def recv_byte_complete_callback():
        nonlocal dut
        nonlocal recv_byte_complete_callback_state
        if recv_byte_complete_callback_state == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_RECV_BYTE
        recv_byte_complete_callback_state += 1

    await _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting=True, in_complete_callback=recv_byte_complete_callback)

    recv_byte_complete_callback_state_2 = 0
    def recv_byte_complete_callback_2():
        nonlocal dut
        nonlocal recv_byte_complete_callback_state_2
        if recv_byte_complete_callback_state_2 == 0:
            dut.in_enable.value = 1
            dut.in_instruction.value = IIC_INST_STOP_TX
        recv_byte_complete_callback_state_2 += 1

    await _impl_receive_byte(dut, byte_to_receive, skip_cmd_setting=True, in_complete_callback=recv_byte_complete_callback_2)

    await _impl_stop_signal(dut, skip_cmd_setting=True)

    await RisingEdge(dut.in_clk)
    check_end_of_sigs(dut)


def main():
    proj_path = os.path.dirname(os.path.abspath(__file__))

    always_run_build_step = True
    generate_wave = True

    source_dirs = [ os.path.join(proj_path, "../../IIC_Master.v") ]
    include_dirs = [ os.path.join(proj_path, "../../") ]
    build_dir = os.path.join(proj_path, 'tb_build')
    pre_defines = {'DEBUG_TEST_BENCH': '1'}
    top_level_module = 'IIC_Master'

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

    runner.test(hdl_toplevel=top_level_module, test_module='tb_IICMaster,', waves=generate_wave)


if __name__ == '__main__':
    main()

