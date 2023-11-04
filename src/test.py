import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.utils import get_sim_time
import numpy as np

async def reset(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 1)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

#reversed(bin(i)[2:])

async def set_bits(dut, indices, size):
    bits = np.zeros(size)
    for i in indices:
        bits[i] = 1

    for j,b in enumerate(bits):
        dut.uio_in.value = 0b00000101 if b == 1 else 0b00000110
        dut.ui_in.value = j
        await ClockCycles(dut.clk, 1)

    dut.uio_in.value = 0b00000000
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

async def trigger_reception(dut, bits=None, dev=0):
    dut.uio_in.value = 0b00000111 | (0b1000 if dev else 0b0000)
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0b00000000
    dut.ui_in.value = 0

    if bits is not None:
        for j,b in enumerate(bits):
            dut.uio_in[5].value = b
            await RisingEdge(dut.clk)
            await FallingEdge(dut.clk)

async def iterate(dut, start=0):
    # Now trigger the read from address start
    dut.ui_in.value = start
    dut.uio_in.value = 0b00000011
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0b00000000
    dut.ui_in.value = 0
    
    sequence = []
    timedout = True
    for j in range(1000):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        sequence.append(dut.uio_out[6].value.integer)
        if dut.uio_out[7].value == 1:
            timedout = False
            break

    assert timedout==False, "Timeout!"
    
    return sequence

@cocotb.test()
async def test(dut):
    dut = dut.top
    dut._log.info("Running test!")
    
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    clock = dut.clk

    # set initial values to determined state
    num_bits = dut.SIZE.value
    dut.rst_n.value = 1
    dut.ui_in.value = 0b00000000
    dut.uio_in.value = 0b00000000

    # reset
    await reset(dut)

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    
    await trigger_reception(dut, [1, 0, 0, 0, 0, 1, 0])

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    """
    # set bits
    await set_bits(dut, [3], num_bits)

    # wait for a bit
    await ClockCycles(dut.clk, 10)

    # Now trigger the read from address 0
    bits = await iterate(dut, 0)
    print(bits)

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    """
    """
    dut.uio_in.value = 0b00000001 
    dut.ui_in.value = 3
    await ClockCycles(dut.clk, 1)

    # Now trigger the read from address 0
    dut.uio_in.value = 0b00000011
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0b00000000 
    dut.ena.value = 1
    await ClockCycles(dut.clk, 1)
    
    timedout = True
    for j in range(1000):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        if dut.uio_out[7].value == 1:
            timedout = False
            break

    dut.ena.value = 0

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    sequences = []

    for i in range(2**8):
        # set/cear bit i
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value = 0b00000000
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 1)

        # wait for a bit
        await ClockCycles(dut.clk, 10)

        # Now trigger the read from address 0
        dut.ui_in.value = 0
        dut.uio_in.value = 0b00000011
        await ClockCycles(dut.clk, 1)
        dut.ena.value = 1
        dut.uio_in.value = 0b00000000
        
        sequence = []
        timedout = True
        for j in range(1000):
            await RisingEdge(dut.clk)
            await FallingEdge(dut.clk)
            sequence.append(dut.uio_out[6].value.integer)
            if dut.uio_out[7].value == 1:
                timedout = False
                dut.ena.value = 0
                break

        assert timedout==False, "Timeout!"

        print(bin(i), ":\t", "".join(map(str,sequence)))

        sequences.append(sequence)
        
        await ClockCycles(dut.clk, 20)
    """