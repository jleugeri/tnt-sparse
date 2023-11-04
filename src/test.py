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

async def clear_all(dut):
    dut.uio_in.value = 0b00000010
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 1)


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

async def trigger_reception(dut, bits=None):
    dut.uio_in.value = 0b00000111
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

    timedout = True
    for j in range(1000):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        if dut.uio_out[7].value == 1:
            timedout = False
            break

    assert timedout==False, "Timeout!"

async def iterate(dut, size):
    # Now trigger the read from address start
    dut.ui_in.value = 0b00000000
    dut.uio_in.value = 0b00000011
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0b00000000
    dut.ui_in.value = 0
    
    ## wait fixed number of cycles for setup
    for j in range(np.log2(size).astype(int) + 1):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)

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

    # set initial values to determined state
    num_bits = dut.SIZE.value
    dut.rst_n.value = 1
    dut.ui_in.value = 0b00000000
    dut.uio_in.value = 0b00000000

    # reset
    await reset(dut)
    dut.ena = 1

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    
    tgt_sequence = [1, 0, 0, 0, 0, 1, 0]
    await trigger_reception(dut, tgt_sequence)

    # wait for a bit
    await ClockCycles(dut.clk, 10)

    rec_sequence = await iterate(dut, num_bits)
    
    assert np.all(np.array(tgt_sequence) == np.array(rec_sequence)), "Received sequence does not match transmitted sequence!"

    print(tgt_sequence, rec_sequence)

    # wait for a bit
    await ClockCycles(dut.clk, 10)
    

    for t in range(100):
        i, = np.nonzero(np.random.rand(num_bits) < 0.2)
        await set_bits(dut, [i], num_bits)
        await trigger_reception(dut)
        await ClockCycles(dut.clk, 10)
        tgt_sequence = await iterate(dut, num_bits)

        await ClockCycles(dut.clk, 10)

        # reset leafs
        await clear_all(dut)

        # play sequence back to set the leafs
        await trigger_reception(dut, tgt_sequence)

        # wait for a bit
        await ClockCycles(dut.clk, 10)

        # recover sequence from serdes
        rec_sequence = await iterate(dut, num_bits)

        print (tgt_sequence, rec_sequence)

        assert np.all(len(tgt_sequence) == len(rec_sequence) and np.array(tgt_sequence) == np.array(rec_sequence)), "Received sequence does not match transmitted sequence!"
