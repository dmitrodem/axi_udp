#!/usr/bin/env python3
import struct
import fcntl
import asyncio
import codecs

def ip_checksum(d):
    chk = sum([int.from_bytes(d[i:i+2], byteorder = "big", signed = False) for i in range(0, len(d), 2)])

    while (chk > 0xffff):
        chk = (chk & 0xffff) + (chk >> 16)

    chk = chk ^ 0xffff;

    return chk.to_bytes(byteorder = "big", length = 2, signed = False)

def make_ip_header(src_ip, dest_ip, protocol, payload_len):
    ip_hdr_list = [
        b"\x45\x00",
        (20 + payload_len).to_bytes(byteorder = "big", length = 2, signed = False),
        b"\x00\x00",
        b"\x40\x00",
        b"\xff",
        protocol,
        b"\x00\x00",
        src_ip,
        dest_ip]
    ip_hdr_list[6] = ip_checksum(b"".join(ip_hdr_list))
    ip_hdr = b"".join(ip_hdr_list)
    return ip_hdr

def create_tap(name = "tap0"):
    TUNSETIFF = 0x400454ca
    TUNSETOWNER = TUNSETIFF + 2
    IFF_TUN = 0x0001
    IFF_TAP = 0x0002
    IFF_NO_PI = 0x1000
    dev = open("/dev/net/tun", "r+b", buffering = 0)
    ifr = struct.pack('16sH', name.encode(), IFF_TAP | IFF_NO_PI)
    fcntl.ioctl(dev, TUNSETIFF, ifr)
    return dev

class Parameters:
    mac = codecs.decode("010203040506", "hex")
    ip = None
    bootp_done = None
    finish = None

async def amain():
    dev = create_tap("sim0")
    loop = asyncio.get_event_loop()

    parameters = Parameters()
    parameters.bootp_done = loop.create_future()
    parameters.finish = loop.create_future()

    def reader(params):
        data = dev.read(2048)

        dmac = data[0:6]
        smac = data[6:12]
        ethertype = data[12:14]
        payload = data[14:]
        match ethertype:
            case b"\x08\x06":
                htype = payload[0:2]
                ptype = payload[2:4]
                hlen = payload[4:5]
                plen = payload[5:6]
                oper = payload[6:8]
                sha = payload[8:14]
                spa = payload[14:18]
                tha = payload[18:24]
                tpa = payload[24:28]

                if params.ip:
                    pkt = b"".join([
                        smac,
                        params.mac,
                        b"\x08\x06",
                        htype, ptype, hlen, plen,
                        b"\x00\x02",
                        params.mac, params.ip,
                        sha, spa])
                    dev.write(pkt)
            case b"\x08\x00":
                ver_hl = payload[0:1]
                dscp_ecn = payload[1:2]
                total_length = payload[2:4]
                identification = payload[4:6]
                flags_fragment = payload[6:8]
                ttl = payload[8:9]
                protocol = payload[9:10]
                checksum = payload[10:12]
                src_ip = payload[12:16]
                dst_ip = payload[16:20]
                ip_payload = payload[20:]
                ip_hdr_list = [
                    ver_hl, dscp_ecn,
                    total_length,
                    identification,
                    flags_fragment,
                    ttl,
                    protocol,
                    checksum,
                    src_ip,
                    dst_ip]
                match protocol:
                    case b"\x01": # ICMP
                        icmp_type = ip_payload[0:1]
                        icmp_code = ip_payload[1:2]
                        icmp_checksum = ip_payload[2:4]
                        icmp_id = ip_payload[4:6]
                        icmp_seq = ip_payload[6:8]
                        icmp_time = ip_payload[8:16]
                        icmp_data = ip_payload[16:]
                        match icmp_type:
                            case b"\x08":
                                eth_hdr = smac + params.mac + b"\x08\x00"
                                icmp_list = [
                                    b"\x00",
                                    icmp_code,
                                    b"\x00\x00",
                                    icmp_id,
                                    icmp_seq,
                                    icmp_time,
                                    icmp_data]
                                icmp_list[2] = ip_checksum(b"".join(icmp_list))
                                icmp_pkt = b"".join(icmp_list)

                                if params.ip:
                                    ip_hdr = make_ip_header(params.ip, src_ip, b"\x01", len(icmp_pkt))
                                    pkt = eth_hdr + ip_hdr + icmp_pkt
                                    dev.write(pkt)
                    case b"\x11": # UDP
                        udp_src_port = ip_payload[0:2]
                        udp_dst_port = ip_payload[2:4]
                        udp_length   = ip_payload[4:6]
                        udp_checksum = ip_payload[6:8]
                        udp_payload  = ip_payload[8:]

                        msg = None
                        match int.from_bytes(udp_dst_port, byteorder = "big", signed = False):
                            case 68: # BOOTP
                                bootp_op = udp_payload[0:1]
                                bootp_htype = udp_payload[1:2]
                                bootp_hlen = udp_payload[2:3]
                                bootp_hops = udp_payload[3:4]
                                bootp_xid = udp_payload[4:8]
                                bootp_secs = udp_payload[8:10]
                                bootp_flags = udp_payload[10:12]
                                bootp_ciaddr = udp_payload[12:16]
                                bootp_yiaddr = udp_payload[16:20]
                                bootp_siaddr = udp_payload[20:24]
                                bootp_giaddr = udp_payload[24:28]
                                bootp_chaddr = udp_payload[28:44]
                                bootp_sname = udp_payload[44:108]
                                bootp_file = udp_payload[108:236]
                                bootp_vend = udp_payload[236:300]
                                if (bootp_op == b"\x02") and (bootp_chaddr[0:6] == params.mac):
                                    my_ip = bootp_yiaddr
                                    my_ip_repr = ".".join([str(n) for n in my_ip])
                                    print(f"my_ip = {my_ip_repr}")
                                    params.ip = my_ip
                                    params.bootp_done.set_result(1)
                            case 1234:
                                match udp_payload.decode().split():
                                    case ["exit"]:
                                        params.finish.set_result(1)
                                        msg = "Exiting\n".encode()
                                    case ["info"]:
                                        msg = "Test UDP implementation\n".encode()
                                    case _:
                                        sport = int.from_bytes(udp_src_port, byteorder = "big", signed = False)
                                        msg = f"Hello, {sport}\n".encode()
                            case _:
                                msg = udp_payload

                        if msg:
                            eth_hdr = smac + params.mac + b"\x08\x00"
                            msg_len = (8+len(msg)).to_bytes(byteorder = "big", length = 2, signed = False)

                            udp_list = [
                                udp_dst_port,
                                udp_src_port,
                                msg_len,
                                b"\x00\x00",
                                msg]
                            udp_pkt = b"".join(udp_list)

                            if params.ip:
                                ip_hdr = make_ip_header(params.ip, src_ip, b"\x11", len(udp_pkt))
                                pkt = eth_hdr + ip_hdr + udp_pkt
                                dev.write(pkt)
            case _:
                print(f"Unhandled ETHERTYPE = {ethertype.hex()}")

    loop.add_reader(dev.fileno(), reader, parameters)

    async def send_bootp_request(params):
        eth_hdr = b"\xff\xff\xff\xff\xff\xff" + params.mac + b"\x08\x00"
        bootp_list = [
            b"\x01",
            b"\x06",
            b"\x06",
            b"\x00",
            b"\x00\x00\x00\x00",
            b"\x00\x00",
            b"\x80\x00",
            b"\x00\x00\x00\x00",
            b"\x00\x00\x00\x00",
            b"\x00\x00\x00\x00",
            b"\x00\x00\x00\x00",
            params.mac + 12*b"\x00",
            64*b"\x00",
            128*b"\x00",
            64*b"\x00"]
        bootp_pkt = b"".join(bootp_list)
        udp_list = [
            (68).to_bytes(byteorder = "big", length = 2, signed = False),
            (67).to_bytes(byteorder = "big", length = 2, signed = False),
            (8+len(bootp_pkt)).to_bytes(byteorder = "big", length = 2, signed = False),
            b"\x00\x00",
            bootp_pkt]
        udp_pkt = b"".join(udp_list)

        ip_hdr = make_ip_header(b"\x00\x00\x00\x00", b"\xff\xff\xff\xff", b"\x11", len(udp_pkt))
        pkt = eth_hdr + ip_hdr + udp_pkt
        for n in range(10):
            dev.write(pkt)
            try:
                await asyncio.wait_for(params.bootp_done, timeout = 1)
                return
            except asyncio.TimeoutError:
                print(f"Re-try {n}")
                params.bootp_done = asyncio.get_event_loop().create_future()

    await send_bootp_request(parameters)
    await parameters.finish
    dev.close()

asyncio.run(amain())
