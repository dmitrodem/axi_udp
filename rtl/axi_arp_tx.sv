`default_nettype none
import axi_udp_pkg::*;
module axi_arp_tx #(
  parameter DEBUG   = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,

  input wire         arp_req,
  output wire        arp_ack,
  input wire [15:0]  arp_opcode,
  input wire [47:0]  arp_src_mac,
  input wire [31:0]  arp_src_ip,
  input wire [47:0]  arp_dst_mac,
  input wire [31:0]  arp_dst_ip,

  output wire        eth_req,
  input wire         eth_ack,
  output wire [47:0] eth_dst_mac,
  output wire [47:0] eth_src_mac,
  output wire [15:0] eth_ethertype,
  output wire [7:0]  eth_axis_tdata,
  output wire        eth_axis_tlast,
  output wire        eth_axis_tvalid,
  input wire         eth_axis_tready);

  localparam string TAG = "axi_arp_tx";



  typedef enum bit [7:0] {
    S_LISTEN,
    S_REQ_TX,
    S_SEND_REPLY
  } state_t;

  typedef struct packed {
    state_t state;
    bit ack;
    bit req;
    bit [7:0] tdata;
    bit       tlast;
    bit       tvalid;
    bit [7:0] index;
  } reg_t;

  localparam     reg_t RES_reg = '{
    state : S_LISTEN,
    ack : 1'b0,
    req : 1'b0,
    tdata : 'h0,
    tlast : 'h0,
    tvalid : 'h0,
    index : 'h0
  };

  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v = r;

    v.tvalid = 1'b0;
    case (r.state)
      S_LISTEN: begin
        if (arp_req) begin
          v.req   = 1'b1;
          v.state = S_REQ_TX;
        end
      end
      S_REQ_TX: begin
        if (eth_ack) begin
          v.req    = 1'b0;
          v.state  = S_SEND_REPLY;
          v.tdata  = ARP_HW_TYPE[15-:8];
          v.tlast  = 1'b0;
          v.tvalid = 1'b1;
          v.index = 'h0;
        end
      end
      S_SEND_REPLY : begin
        v.tvalid = 1'b1;
        if (eth_axis_tready) begin
          case (r.index)
            'h00 : v.tdata = ARP_HW_TYPE[ 7-:8];
            'h01 : v.tdata = ARP_PROTO_TYPE[15-:8];
            'h02 : v.tdata = ARP_PROTO_TYPE[ 7-:8];
            'h03 : v.tdata = ARP_HW_SIZE;
            'h04 : v.tdata = ARP_PROTO_SIZE;
            'h05 : v.tdata = arp_opcode[15-:8];
            'h06 : v.tdata = arp_opcode[ 7-:8];
            'h07 : v.tdata = arp_src_mac[47-:8];
            'h08 : v.tdata = arp_src_mac[39-:8];
            'h09 : v.tdata = arp_src_mac[31-:8];
            'h0a : v.tdata = arp_src_mac[23-:8];
            'h0b : v.tdata = arp_src_mac[15-:8];
            'h0c : v.tdata = arp_src_mac[ 7-:8];
            'h0d : v.tdata = arp_src_ip[31-:8];
            'h0e : v.tdata = arp_src_ip[23-:8];
            'h0f : v.tdata = arp_src_ip[15-:8];
            'h10 : v.tdata = arp_src_ip[ 7-:8];
            'h11 : v.tdata = arp_dst_mac[47-:8];
            'h12 : v.tdata = arp_dst_mac[39-:8];
            'h13 : v.tdata = arp_dst_mac[31-:8];
            'h14 : v.tdata = arp_dst_mac[23-:8];
            'h15 : v.tdata = arp_dst_mac[15-:8];
            'h16 : v.tdata = arp_dst_mac[ 7-:8];
            'h17 : v.tdata = arp_dst_ip[31-:8];
            'h18 : v.tdata = arp_dst_ip[23-:8];
            'h19 : v.tdata = arp_dst_ip[15-:8];
            'h1a : begin
              v.tdata = arp_dst_ip[ 7-:8];
              v.tlast = 1'b1;
              v.ack   = 1'b1;
              v.state = S_LISTEN;
            end
          endcase // case (r.index)
          v.index = r.index + 1;
        end
      end
      default:;
    endcase // case (r.state)

    if (~aresetn) begin
      v = RES_reg;
    end
    rin = v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
    if (DEBUG) begin
      if ((r.state == S_REQ_TX) && eth_axis_tready) begin
        $display("%t : %-12s : hw.type = %04h, proto.type = %04h, hw.size = %02h, proto.size = %02h, OP %02h, SMAC %012h, SADDR %08h, DMAC %012h, DADDR %08h",
                 $time(), TAG,
                 ARP_HW_TYPE, ARP_PROTO_TYPE, ARP_HW_SIZE, ARP_PROTO_SIZE,
                 arp_opcode,
                 arp_src_mac, arp_src_ip,
                 arp_dst_mac, arp_dst_ip);
      end
    end

  end

  assign arp_ack = r.ack;
  assign eth_req = r.req;

  assign eth_dst_mac     = arp_dst_mac;
  assign eth_src_mac     = arp_src_mac;
  assign eth_ethertype   = ETHERTYPE_ARP;
  assign eth_axis_tdata  = r.tdata;
  assign eth_axis_tlast  = r.tlast;
  assign eth_axis_tvalid = r.tvalid;

endmodule : axi_arp_tx
`default_nettype wire
