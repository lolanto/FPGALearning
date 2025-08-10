import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.runner import get_runner
from IICChecker import *


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



g_run_all = True

g_test_case_enable_settings = {
    'idle': False,
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


@cocotb.test(skip=not g_test_case_enable_settings['idle'] and not g_run_all)
async def idle_signal(dut):
    c = Clock(dut.in_clk, 2, units='ns')
    await cocotb.start(c.start())
    await reset_signal(dut)
    print("Start Simulate")
    dut.in_trigger.value =1
    await RisingEdge(dut.in_clk)
    dut.in_trigger.value = 0
    for _ in range(1024 * 3):
        await RisingEdge(dut.in_clk)


def main():
    proj_path = os.path.dirname(os.path.abspath(__file__))

    always_run_build_step = True
    generate_wave = True

    source_dirs = [ os.path.join(proj_path, "../../top.v") ]
    include_dirs = [ os.path.join(proj_path, "../../") ]
    build_dir = os.path.join(proj_path, 'tb_build')
    pre_defines = {'DEBUG_TEST_BENCH': '1'}
    top_level_module = 'Top'

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

    runner.test(hdl_toplevel=top_level_module, test_module='tb_top_IICMaster,', waves=generate_wave)


if __name__ == '__main__':
    main()

