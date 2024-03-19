#!/usr/bin/env python3

import sys, os
import asyncio
import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.types import LogicArray
from cocotbext.axi.axis import (
    AxiStreamBus, AxiStreamSource, AxiStreamSink,
    AxiStreamMonitor)
import codecs
import struct
import fcntl

def create_tap(ifname = "tap0"):
    TUNSETIFF = 0x400454ca
    IFF_TUN   = 0x00000001
    IFF_TAP   = 0x00000002
    IFF_NO_PI = 0x00001000

    dev = open("/dev/net/tun", "r+b", buffering = 0)

    ifr = struct.pack("16sH", ifname.encode(), IFF_TAP | IFF_NO_PI)
    ret = fcntl.ioctl(dev, TUNSETIFF, ifr)
    fl  = fcntl.fcntl(dev, fcntl.F_GETFL)
    ret = fcntl.fcntl(dev, fcntl.F_SETFL, fl | os.O_NONBLOCK)

    return dev

@cocotb.test()
async def tap_to_axis(dut):

    # init hanging signals
    dut.arp_lookup_req.setimmediatevalue(0)
    dut.arp_lookup_ip.setimmediatevalue(0)

    dut.ip2icmp_axis_tready.setimmediatevalue(1)
    dut.ip2udp_axis_tready.setimmediatevalue(1)

    async def gen_reset():
        dut.aresetn.setimmediatevalue(0)
        for _ in range(10):
            await cocotb.triggers.RisingEdge(dut.clk)
        dut.aresetn.value = 1

    clock = cocotb.clock.Clock(signal = dut.clk, period = 1, units = "us")
    cocotb.start_soon(clock.start(start_high = False))
    await gen_reset()

    tap0 = create_tap("tap0")

    s_axis = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk, dut.aresetn, reset_active_level = False)
    m_axis = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.aresetn, reset_active_level = False)

    tx_done = cocotb.triggers.Event()
    async def tap2hdl():
        while not tx_done.is_set():
            eth_pkt = tap0.read(2048)
            if eth_pkt:
                await s_axis.send(eth_pkt)
            else:
                await cocotb.triggers.RisingEdge(dut.clk)

    rx_done = cocotb.triggers.Event()
    async def hdl2tap():
        while not rx_done.is_set():
            eth_pkt = await m_axis.read()
            if eth_pkt:
                tap0.write(bytes(eth_pkt))

    tx_task = cocotb.start_soon(tap2hdl())
    rx_task = cocotb.start_soon(hdl2tap())

    async def make_arp_request():
        await cocotb.triggers.Timer(10, units = "ms")
        await cocotb.triggers.RisingEdge(dut.clk)
        dut.arp_lookup_ip.value = (192<<24) | (168 << 16) | (6 << 8) | (1 << 0)
        dut.arp_lookup_req.value = 1
        await cocotb.triggers.RisingEdge(dut.clk)
        while dut.arp_lookup_valid.value == 0:
            await cocotb.triggers.RisingEdge(dut.clk)
        dut.arp_lookup_req.value = 0
        dut._log.info(f"MAC = {dut.arp_lookup_mac.value.buff.hex()}")

    lookup_task = cocotb.start_soon(make_arp_request())
    await cocotb.triggers.Combine(tx_task, rx_task, lookup_task)

# Local Variables:
# pyvenv-activate: "../venv"
# End:
