`default_nettype none
import axi_udp_pkg::*;
module axi_eth_rx #(
   parameter MAC_MSB = 24'h010203,
   parameter MAC_LSB = 24'h040506,
   parameter IP_MSB = 16'hc0a8,
   parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,


  input wire [7:0]   mac_s_axis_tdata,
  input wire         mac_s_axis_tlast,
  input wire         mac_s_axis_tvalid,
  output wire        mac_s_axis_tready,

  output wire        arp_m_axis_tvalid,
  output wire [7:0]  arp_m_axis_tdata,
  output wire        arp_m_axis_tlast,
  input wire         arp_m_axis_tready,

  output wire        ip_m_axis_tvalid,
  output wire [7:0]  ip_m_axis_tdata,
  output wire        ip_m_axis_tlast,
  input wire         ip_m_axis_tready,

  output wire        eth_hdr_valid;
  output wire [47:0] eth_hdr_dst_mac;
  output wire [47:0] eth_hdr_src_mac;
  output wire [15:0] eth_hdr_ethertype
);

  typedef struct packed {
    bit [7:0]  index;
    bit [47:0] destination_mac;
    bit [47:0] source_mac;
    bit [15:0] ethertype;
    bit        valid;
  } reg_t;

  localparam reg_t RES_reg = '{
    index: 'h0,
    destination_mac : 'h0,
    source_mac : 'h0,
    ethertype : 'h0,
    valid : 'h0
  };

  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v = r;

    if (mac_s_axis_tvalid) begin
      if (r.index == 0) begin
        v.valid = 0;
      end

      case (r.index)
        'h00: v.destination_mac[47-:8] = mac_s_axis_tdata;
        'h01: v.destination_mac[39-:8] = mac_s_axis_tdata;
        'h02: v.destination_mac[31-:8] = mac_s_axis_tdata;
        'h03: v.destination_mac[23-:8] = mac_s_axis_tdata;
        'h04: v.destination_mac[15-:8] = mac_s_axis_tdata;
        'h05: v.destination_mac[ 7-:8] = mac_s_axis_tdata;
        'h06: v.source_mac[47-:8]      = mac_s_axis_tdata;
        'h07: v.source_mac[39-:8]      = mac_s_axis_tdata;
        'h08: v.source_mac[31-:8]      = mac_s_axis_tdata;
        'h09: v.source_mac[23-:8]      = mac_s_axis_tdata;
        'h0a: v.source_mac[15-:8]      = mac_s_axis_tdata;
        'h0b: v.source_mac[ 7-:8]      = mac_s_axis_tdata;
        'h0c: v.ethertype[15-:8]       = mac_s_axis_tdata;
        'h0d: v.ethertype[ 7-:8]       = mac_s_axis_tdata;
      endcase // case (r.index)

      if (r.index == 'h0d) begin
        v.valid = 1'b1;
      end else begin
        v.index = r.index + 1;
      end

      if (mac_s_axis_tlast) begin
        v.index = 'h0;
      end
    end

    if (~aresetn) begin
      v = RES_reg;
    end

    rin <= v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
  end

  assign arp_m_axis_tdata  = mac_s_axis_tdata;
  assign arp_m_axis_tlast  = mac_s_axis_tlast;
  assign arp_m_axis_tvalid = mac_s_axis_tvalid && r.valid && (r.ethertype == ETHERTYPE_ARP);

  assign ip_m_axis_tdata  = mac_s_axis_tdata;
  assign ip_m_axis_tlast  = mac_s_axis_tlast;
  assign ip_m_axis_tvalid = mac_s_axis_tvalid && r.valid && (r.ethertype == ETHERTYPE_IP);

  assign mac_s_axis_tready = 1'b1;

  assign eth_hdr_valid = r.valid;
  assign eth_hdr_dst_mac = r.destination_mac;
  assign eth_hdr_src_mac = r.source_mac;
  assign eth_hdr_ethertype = r.ethertype;

endmodule : axi_eth_rx
`default_nettype wire
