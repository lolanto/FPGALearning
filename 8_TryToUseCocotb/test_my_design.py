import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

@cocotb.test()
async def test(dut):
    dut.in_sig.value = 1
    await Timer(1, units='ns')
    assert(dut.out_sig.value == 1)