`default_nettype none
import axi_udp_pkg::*;
module axi_eth_tx #(
  parameter DEBUG   = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire        clk,
  input wire        aresetn,

  input wire        port0_req,
  output wire       port0_ack,
  input wire [47:0] port0_dst_mac,
  input wire [47:0] port0_src_mac,
  input wire [15:0] port0_ethertype,
  input wire [7:0]  port0_axis_tdata,
  input wire        port0_axis_tlast,
  input wire        port0_axis_tvalid,
  output wire       port0_axis_tready,

  input wire        port1_req,
  output wire       port1_ack,
  input wire [47:0] port1_dst_mac,
  input wire [47:0] port1_src_mac,
  input wire [15:0] port1_ethertype,
  input wire [7:0]  port1_axis_tdata,
  input wire        port1_axis_tlast,
  input wire        port1_axis_tvalid,
  output wire       port1_axis_tready,

  input wire        port2_req,
  output wire       port2_ack,
  input wire [47:0] port2_dst_mac,
  input wire [47:0] port2_src_mac,
  input wire [15:0] port2_ethertype,
  input wire [7:0]  port2_axis_tdata,
  input wire        port2_axis_tlast,
  input wire        port2_axis_tvalid,
  output wire       port2_axis_tready,

  input wire        port3_req,
  output wire       port3_ack,
  input wire [47:0] port3_dst_mac,
  input wire [47:0] port3_src_mac,
  input wire [15:0] port3_ethertype,
  input wire [7:0]  port3_axis_tdata,
  input wire        port3_axis_tlast,
  input wire        port3_axis_tvalid,
  output wire       port3_axis_tready,

  output wire [7:0] mac_axis_tdata,
  output wire       mac_axis_tlast,
  output wire       mac_axis_tvalid,
  input wire        mac_axis_tready
);

  localparam string TAG = "axi_eth_tx";

  typedef enum bit [1:0] {
    E_PORT0, E_PORT1, E_PORT2, E_PORT3
  } arb_t;

  typedef enum bit [1:0] {
    S_IDLE,
    S_HEADER,
    S_PACKET
  } state_t;

  typedef struct packed {
    state_t state;
    arb_t   arb;
    bit [7:0] tdata;
    bit       header;
    bit       packet;
    bit       ack;
    bit [3:0] index;
  } reg_t;

  localparam     reg_t RES_reg = '{
    state : S_IDLE,
    arb   : E_PORT0,
    tdata : 'h0,
    header : 'h0,
    packet : 'h0,
    ack : 1'b0,
    index : 'h0
  };

  reg_t r;
  reg_t rin;

  bit [47:0] hdr_dst_mac;
  bit [47:0] hdr_src_mac;
  bit [15:0] hdr_ethertype;
  bit [7:0]  pkt_tdata;
  bit        pkt_tlast;
  bit        pkt_tvalid;

  always_comb begin
    reg_t v;
    v = r;

    if (r.arb == E_PORT0) begin
      hdr_dst_mac   = port0_dst_mac;
      hdr_src_mac   = port0_src_mac;
      hdr_ethertype = port0_ethertype;
      pkt_tdata     = port0_axis_tdata;
      pkt_tlast     = port0_axis_tlast;
      pkt_tvalid    = port0_axis_tvalid;
    end else if (r.arb == E_PORT1) begin
      hdr_dst_mac   = port1_dst_mac;
      hdr_src_mac   = port1_src_mac;
      hdr_ethertype = port1_ethertype;
      pkt_tdata     = port1_axis_tdata;
      pkt_tlast     = port1_axis_tlast;
      pkt_tvalid    = port1_axis_tvalid;
    end else if (r.arb == E_PORT2) begin
      hdr_dst_mac   = port2_dst_mac;
      hdr_src_mac   = port2_src_mac;
      hdr_ethertype = port2_ethertype;
      pkt_tdata     = port2_axis_tdata;
      pkt_tlast     = port2_axis_tlast;
      pkt_tvalid    = port2_axis_tvalid;
    end else if (r.arb == E_PORT3) begin
      hdr_dst_mac   = port3_dst_mac;
      hdr_src_mac   = port3_src_mac;
      hdr_ethertype = port3_ethertype;
      pkt_tdata     = port3_axis_tdata;
      pkt_tlast     = port3_axis_tlast;
      pkt_tvalid    = port3_axis_tvalid;
    end else begin
      hdr_dst_mac   = 'h0;
      hdr_src_mac   = 'h0;
      hdr_ethertype = 'h0;
      pkt_tdata     = 'h0;
      pkt_tlast     = 'h0;
      pkt_tvalid    = 'h0;
    end

    v.ack = 1'b0;
    case (r.state)
      S_IDLE: begin
        v.header = 1'b0;
        v.packet = 1'b0;
        if (port0_req || port1_req || port2_req || port3_req) begin
          if (r.arb == E_PORT0) begin
            if      (port1_req) v.arb = E_PORT1;
            else if (port2_req) v.arb = E_PORT2;
            else if (port3_req) v.arb = E_PORT3;
            else if (port0_req) v.arb = E_PORT0;
          end
          else if (r.arb == E_PORT1) begin
            if      (port2_req) v.arb = E_PORT2;
            else if (port3_req) v.arb = E_PORT3;
            else if (port0_req) v.arb = E_PORT0;
            else if (port1_req) v.arb = E_PORT1;
          end
          else if (r.arb == E_PORT2) begin
            if      (port3_req) v.arb = E_PORT3;
            else if (port0_req) v.arb = E_PORT0;
            else if (port1_req) v.arb = E_PORT1;
            else if (port2_req) v.arb = E_PORT2;
          end
          else if (r.arb == E_PORT3) begin
            if      (port0_req) v.arb = E_PORT0;
            else if (port1_req) v.arb = E_PORT1;
            else if (port2_req) v.arb = E_PORT2;
            else if (port3_req) v.arb = E_PORT3;
          end
          v.ack    = 1'b1;
          v.index  = 'h0;
          v.tdata  = hdr_dst_mac[47-:8];
          v.header = 1'b1;
          v.state  = S_HEADER;
        end
      end
      S_HEADER: begin
        if (mac_axis_tready) begin
          case (r.index)
            'h00: v.tdata = hdr_dst_mac[39-:8];
            'h01: v.tdata = hdr_dst_mac[31-:8];
            'h02: v.tdata = hdr_dst_mac[23-:8];
            'h03: v.tdata = hdr_dst_mac[15-:8];
            'h04: v.tdata = hdr_dst_mac[ 7-:8];
            'h05: v.tdata = hdr_src_mac[47-:8];
            'h06: v.tdata = hdr_src_mac[39-:8];
            'h07: v.tdata = hdr_src_mac[31-:8];
            'h08: v.tdata = hdr_src_mac[23-:8];
            'h09: v.tdata = hdr_src_mac[15-:8];
            'h0a: v.tdata = hdr_src_mac[ 7-:8];
            'h0b: v.tdata = hdr_ethertype[15-:8];
            'h0c: begin
              v.tdata = hdr_ethertype[ 7-:8];
              v.state = S_PACKET;
            end
          endcase // case (r.index)
          v.index = r.index + 1;
        end
      end // case: S_HEADER
      S_PACKET : begin
        v.header = 1'b0;
        v.packet = 1'b1;
        if (mac_axis_tready && pkt_tvalid && pkt_tlast) begin
          v.state = S_IDLE;
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
  end

  assign mac_axis_tdata  = (r.header) ? r.tdata : pkt_tdata;
  assign mac_axis_tlast  = (r.header) ? 1'b0    : pkt_tlast;
  assign mac_axis_tvalid = (r.header) ? 1'b1    : pkt_tvalid;

  assign port0_axis_tready = (r.header) ? 1'b0: ((r.arb == E_PORT0) ? mac_axis_tready : 1'b0);
  assign port1_axis_tready = (r.header) ? 1'b0: ((r.arb == E_PORT1) ? mac_axis_tready : 1'b0);
  assign port2_axis_tready = (r.header) ? 1'b0: ((r.arb == E_PORT2) ? mac_axis_tready : 1'b0);
  assign port3_axis_tready = (r.header) ? 1'b0: ((r.arb == E_PORT3) ? mac_axis_tready : 1'b0);

  assign port0_ack = r.ack && (r.arb == E_PORT0);
  assign port1_ack = r.ack && (r.arb == E_PORT1);
  assign port2_ack = r.ack && (r.arb == E_PORT2);
  assign port3_ack = r.ack && (r.arb == E_PORT3);

endmodule : axi_eth_tx
`default_nettype wire
