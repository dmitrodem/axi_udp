#!/usr/bin/env python3

import cocotb

@cocotb.test()
async def tb_axi_udp_rx(dut):
    print(dut)
