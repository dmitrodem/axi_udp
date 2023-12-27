#!/usr/bin/env python3

import sys
import cocotb
from pytun import TunTapDevice, IFF_TAP, IFF_NO_PI
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.types import LogicArray
import codecs
import struct
import fcntl

# eth0 = TunTapDevice(name = "sim0", flags = IFF_TAP | IFF_NO_PI)

def create_tap(name = "tap0")
    TUNSETIFF = 0x400454ca
    TUNSETOWNER = TUNSETIFF + 2
    IFF_TUN = 0x0001
    IFF_TAP = 0x0002
    IFF_NO_PI = 0x1000
    dev = open('/dev/net/tun', 'r+b')
    ifr = struct.pack('16sH', name, IFF_TAP | IFF_NO_PI)
    fcntl.ioctl(tun, TUNSETIFF, ifr)
    return dev

def lookahead(iterable):
    """Pass through all values from the given iterable, augmented by the
    information if there are more values to come after the current one
    (True), or if it is the last value (False).
    """
    # Get an iterator and pull the first value.
    it = iter(iterable)
    last = next(it)
    # Run the iterator to exhaustion (starting from the second value).
    for val in it:
        # Report the *previous* value (more to come).
        yield last, False
        last = val
    # Report the last value.
    yield last, True

    
async def listener(clk, tdata, tlast, tvalid, tready):
    npackets = 0
    tready.value = 1
    while True:
        data = eth0.read(eth0.mtu)
        print(f"<<< {data.hex()}")
        for i, ch in enumerate(data):            
            tlast.value = 0 if i < len(data)-1 else 1
            tdata.value = ch
            tvalid.value = 1
            await RisingEdge(clk)

        tvalid.value = 0
        await RisingEdge(clk)

        npackets += 1
        if (npackets > 20):
            break

async def sender(clk, tdata, tlast, tvalid, tready):
    packet = bytearray()
    tready.value = 1
    while True:        
        await RisingEdge(clk)
        if (tvalid.value == 1):
            packet.append(tdata.value.integer)            
            if (tlast.value == 1):
                # print(f">>>> {packet.hex()}")
                eth0.write(bytes(packet))
                packet = bytearray()

async def send_packet(pkt, clk, tdata, tlast, tvalid, tready):    
    for xdata, xlast in lookahead(pkt):
        await RisingEdge(clk)
        tdata.value = xdata
        tlast.value = int(xlast)
        tvalid.value = 1
        while (tready.value != 1):
            await RisingEdge(clk)
    await RisingEdge(clk)
    tvalid.value = 0

async def receive_packet(clk, tdata, tlast, tvalid, tready):
    await RisingEdge(clk)
    tready.value = 1
    pkt = bytearray()
    while True:
        await RisingEdge(clk)
        if tvalid.value == 1:
            pkt.append(tdata.value)
            if (tlast.value == 1):
                break
    tready.value = 0
    return bytes(pkt)
                
@cocotb.test()
async def tb_axi_udp_rx(dut):
    dut.aresetn.value = 0;
    
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start(start_high=False))

    dut.s_axis_tlast.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.m_axis_tready.value = 0;
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.aresetn.value = 1;
    await RisingEdge(dut.clk)
    
    # cocotb.start_soon(sender(dut.clk, dut.m_axis_tdata, dut.m_axis_tlast, dut.m_axis_tvalid, dut.m_axis_tready))
    # await listener(dut.clk, dut.s_axis_tdata, dut.s_axis_tlast, dut.s_axis_tvalid, dut.s_axis_tready)
    tpkt = codecs.decode("ffffffffffffbe4f933c359f08060001080006040001be4f933c359fc0a80601000000000000c0a80602", "hex")
    dut._log.info(tpkt.hex())
    cocotb.start_soon(send_packet(tpkt, dut.clk, dut.s_axis_tdata, dut.s_axis_tlast, dut.s_axis_tvalid, dut.s_axis_tready))
    rpkt = await receive_packet(dut.clk, dut.m_axis_tdata, dut.m_axis_tlast, dut.m_axis_tvalid, dut.m_axis_tready)
    dut._log.info(rpkt.hex())
    for i in range(100):
        await RisingEdge(dut.clk)
