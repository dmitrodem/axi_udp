`default_nettype none
import axi_udp_pkg::*;
module axi_arp_fsm #(
  parameter DEBUG   = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,

  input wire         arp_rx_valid,
  output wire        arp_rx_ready,
  input wire [15:0]  arp_rx_opcode,
  input wire [47:0]  arp_rx_src_mac,
  input wire [31:0]  arp_rx_src_ip,
  input wire [47:0]  arp_rx_dst_mac,
  input wire [31:0]  arp_rx_dst_ip,

  output wire        arp_tx_req,
  input wire         arp_tx_ack,
  output wire [15:0] arp_tx_opcode,
  output wire [47:0] arp_tx_src_mac,
  output wire [31:0] arp_tx_src_ip,
  output wire [47:0] arp_tx_dst_mac,
  output wire [31:0] arp_tx_dst_ip,

  input wire [31:0]  arp_lookup_ip,
  input wire         arp_lookup_req,
  output wire [47:0] arp_lookup_mac,
  output wire        arp_lookup_valid
);

  localparam string TAG          = "axi_arp_fsm";

  localparam bit [47:0] THIS_MAC = {MAC_MSB[23:0], MAC_LSB[23:0]};
  localparam bit [31:0] THIS_IP  = {IP_MSB[15:0],   IP_LSB[15:0]};

  typedef struct packed {
    bit [31:0] ip;
    bit [47:0] mac;
    bit        valid;
  } arp_cache_entry_t;

  localparam arp_cache_entry_t RES_arp_cache_entry = '{
    ip: 'h0,
    mac: 'h0,
    valid: 'b0
  };

  typedef enum bit [7:0] {
    S_RESET,
    S_GRATUITOUS,
    S_LISTEN,
    S_WAIT_TX_ACK0,
    S_WAIT_TX_ACK1,
    S_WAIT_LOOKUP_REPLY0,
    S_WAIT_LOOKUP_REPLY1
  } state_t;

  typedef struct packed {
    state_t state;
    state_t nstate;
    bit [47:0] target_mac;
    bit [31:0] target_ip;
    bit [15:0] opcode;
    bit        req;
    bit        req1;
    arp_cache_entry_t arp_cache;
    bit [15:0] arp_lookup_timeout;
  } reg_t;

  localparam reg_t RES_reg = '{
    state : S_RESET,
    nstate : S_RESET,
    target_mac : BROADCAST_MAC,
    target_ip : BROADCAST_IP,
    opcode : ARP_OPER_NONE,
    req : 1'b0,
    req1 : 1'b0,
    arp_cache: RES_arp_cache_entry,
    arp_lookup_timeout: 'h0
  };

  reg_t r;
  reg_t rin;

  bit v_arp_lookup_valid;
  assign v_arp_lookup_valid = r.arp_cache.valid && (r.arp_cache.ip == arp_lookup_ip);

  always_comb begin
    reg_t v;
    v = r;

    v.req1 = 1'b0;
    case (r.state)
      S_RESET: begin
        v.state = S_GRATUITOUS;
      end
      S_GRATUITOUS: begin
        v.state      = S_WAIT_TX_ACK0;
        v.nstate     = S_LISTEN;
        v.target_mac = BROADCAST_MAC;
        v.target_ip  = {IP_MSB[15:0],  IP_LSB[15:0]};
        v.opcode     = ARP_OPER_REPLY;
        v.req        = 1'b1;
        v.req1       = 1'b1;
      end
      S_LISTEN: begin
        if (arp_rx_valid) begin
          case (arp_rx_opcode)
            ARP_OPER_REQUEST: begin
              if (((arp_rx_dst_mac == BROADCAST_MAC) ||
                   (arp_rx_dst_mac == THIS_MAC)) &&
                  (arp_rx_dst_ip == THIS_IP)) begin
                v.state            = S_WAIT_TX_ACK0;
                v.nstate           = S_LISTEN;
                v.target_mac       = arp_rx_src_mac;
                v.target_ip        = arp_rx_src_ip;
                v.opcode           = ARP_OPER_REPLY;
                v.req              = 1'b1;
                v.req1             = 1'b1;
              end
            end // case: ARP_OPER_REQUEST
            ARP_OPER_REPLY: begin
              v.arp_cache.valid = 1'b1;
              v.arp_cache.ip    = arp_rx_src_ip;
              v.arp_cache.mac   = arp_rx_src_mac;
            end
            default:;
          endcase // case (arp_rx_opcode)
        end else if (arp_lookup_req && !v_arp_lookup_valid) begin // if (arp_rx_valid)
          v.state      = S_WAIT_TX_ACK0;
          v.nstate     = S_WAIT_LOOKUP_REPLY0;
          v.target_mac = BROADCAST_MAC;
          v.target_ip  = arp_lookup_ip;
          v.opcode     = ARP_OPER_REQUEST;
          v.req        = 1'b1;
          v.req1       = 1'b1;
        end
      end
      S_WAIT_TX_ACK0: begin
        if (arp_tx_ack) begin
          v.opcode = ARP_OPER_NONE;
          v.req    = 1'b0;
          v.state  = S_WAIT_TX_ACK1;
        end
      end
      S_WAIT_TX_ACK1: begin
        v.state = r.nstate;
      end
      S_WAIT_LOOKUP_REPLY0: begin
        v.arp_lookup_timeout = 16'hffff;
        v.state = S_WAIT_LOOKUP_REPLY1;
      end
      S_WAIT_LOOKUP_REPLY1: begin
        if (r.arp_lookup_timeout == 'h0) begin
          v.state      = S_WAIT_TX_ACK0;
          v.nstate     = S_WAIT_LOOKUP_REPLY0;
          v.target_mac = BROADCAST_MAC;
          v.target_ip  = arp_lookup_ip;
          v.opcode     = ARP_OPER_REQUEST;
          v.req        = 1'b1;
          v.req1       = 1'b1;
        end else begin
          v.arp_lookup_timeout = r.arp_lookup_timeout - 1;
        end
        if ((arp_rx_valid) &&
            (arp_rx_opcode == ARP_OPER_REPLY) &&
            (arp_rx_src_ip == arp_lookup_ip)) begin
          v.arp_cache.valid = 1'b1;
          v.arp_cache.ip    = arp_rx_src_ip;
          v.arp_cache.mac   = arp_rx_src_mac;
          v.state           = S_LISTEN;
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
      if (r.req1) begin
        $display("%t : %-12s : MAC %012h, IP %08h",
                 $time, TAG,
                 r.target_mac, r.target_ip);
      end
    end
  end

  assign arp_rx_ready = (r.state == S_LISTEN);

  assign arp_tx_req     = r.req;
  assign arp_tx_opcode  = r.opcode;
  assign arp_tx_src_mac = {MAC_MSB[23:0], MAC_LSB[23:0]};
  assign arp_tx_src_ip  = {IP_MSB[15:0],  IP_LSB[15:0]};
  assign arp_tx_dst_mac = r.target_mac;
  assign arp_tx_dst_ip  = r.target_ip;

  assign arp_lookup_mac     = r.arp_cache.mac;
  assign arp_lookup_valid   = v_arp_lookup_valid;
endmodule : axi_arp_fsm
`default_nettype wire
