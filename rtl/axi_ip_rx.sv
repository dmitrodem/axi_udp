`default_nettype none
module axi_ip_rx #(
  parameter DEBUG = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,

  input wire         s_axis_tvalid,
  input wire [7:0]   s_axis_tdata,
  input wire         s_axis_tlast,
  output wire        s_axis_tready,

  output wire        ip_valid,
  output wire [7:0]  ip_ttl,
  output wire [15:0] ip_id,
  output wire [31:0] ip_source_ip,
  output wire [31:0] ip_target_ip,
  output wire        ip_checksum_valid,
  output wire        ip_checksum_ok,

  output wire        icmp_axis_tvalid,
  output wire [7:0]  icmp_axis_tdata,
  output wire        icmp_axis_tlast,
  input wire         icmp_axis_tready,

  output wire        udp_axis_tvalid,
  output wire [7:0]  udp_axis_tdata,
  output wire        udp_axis_tlast,
  input wire         udp_axis_tready
);

  localparam string TAG = "axi_ip_rx";

  typedef enum bit [7:0] {
    S_HEADER,
    S_PROTOCOL,
    S_SKIP
  } state_t;

  typedef enum bit [1:0] {
    CHK_ST0,
    CHK_ST1,
    CHK_ST2
  } chk_state_t;

  typedef struct packed {
    state_t state;
    bit valid;
    bit pvalid;
    bit [7:0] index;
    bit [15:0] id;
    bit [31:0] source_ip;
    bit [31:0] target_ip;
    bit [7:0]  ttl;
    bit [7:0]  protocol;
    bit [3:0]  ihl;
    bit [7:0]  prev_byte;
    bit [23:0] chksum;
    chk_state_t chk_state;
  } reg_t;

  localparam reg_t RES_reg = '{
    state : S_HEADER,
    valid : 'b0,
    pvalid : 'b0,
    index: 'h0,
    id : 'h0,
    source_ip : 'h0,
    target_ip : 'h0,
    ttl: 'h0,
    protocol: 'h0,
    ihl: 'h0,
    prev_byte : 'h0,
    chksum : 'h0,
    chk_state : CHK_ST0
  };

  reg_t r;
  reg_t rin;

  bit tready;

  always_comb begin
    reg_t v;
    v        = r;

    v.pvalid = r.valid;
    case (r.state)
      S_HEADER: begin
        if (s_axis_tvalid) begin
          v.valid = 1'b0;
          v.chk_state = CHK_ST0;
          case (r.index)
            'h000: if (s_axis_tdata != {IP_VERSION[3:0], IP_HDR_LENGTH[3:0]}) v.state = S_SKIP;
            'h001: ; // ignore DSCP/ECN
            'h002: ; // ignore total_length
            'h003: ; // ignore total_length
            'h004: v.id[15-:8] = s_axis_tdata;
            'h005: v.id[ 7-:8] = s_axis_tdata;
            'h006: ;// ignore flags
            'h007: ;// ignore flags
            'h008: v.ttl      = s_axis_tdata;
            'h009: v.protocol = s_axis_tdata;
            'h00a: ; // checksum[15:8]
            'h00b: ; // checksum[7:0]
            'h00c: v.source_ip[31-:8] = s_axis_tdata;
            'h00d: v.source_ip[23-:8] = s_axis_tdata;
            'h00e: v.source_ip[15-:8] = s_axis_tdata;
            'h00f: v.source_ip[ 7-:8] = s_axis_tdata;
            'h010: v.target_ip[31-:8] = s_axis_tdata;
            'h011: v.target_ip[23-:8] = s_axis_tdata;
            'h012: v.target_ip[15-:8] = s_axis_tdata;
            'h013: begin
              v.target_ip[ 7-:8] = s_axis_tdata;
              v.valid = 1'b1;
              if (s_axis_tlast) begin
                v.state = S_HEADER;
                v.index = 'h0;
              end else begin
                v.state = S_PROTOCOL;
                v.chk_state = CHK_ST0;
              end
            end
          endcase // case (r.index)
          v.index     = r.index + 1;
          v.prev_byte = s_axis_tdata;
          if (r.index[0] == 1'b1) begin
            v.chksum = r.chksum + {8'h00, r.prev_byte, v.prev_byte};
          end
        end // if (s_axis_tvalid)
      end
      S_PROTOCOL: begin
        if (s_axis_tvalid && s_axis_tlast) begin
          v.state = S_HEADER;
          v.index = 'h0;
          v.valid = 1'b0;
        end
        case (r.chk_state)
          CHK_ST0: begin
            v.chksum    = {8'h00, r.chksum[15:0]} + {16'h0000, r.chksum[23:16]};
            v.chk_state = CHK_ST1;
          end
          CHK_ST1: begin
            v.chksum    = ~{8'h00, r.chksum[15:0]} + {16'h0000, r.chksum[23:16]};
            v.chk_state = CHK_ST2;
          end
          CHK_ST2:;
          default:;
        endcase // case (r.chk_state)
      end
      default:;
    endcase // case (r.state)/

    if (~aresetn) begin
      v = RES_reg;
    end
    rin    = v;

    tready = 1'b0;
    case (r.state)
      S_HEADER: tready = 1'b1;
      S_PROTOCOL: begin
        case (r.protocol)
          IP_PROTO_ICMP: tready = icmp_axis_tready;
          IP_PROTO_UDP : tready = udp_axis_tready;
          default      : tready = 1'b1;
        endcase // case (r.protocol)
      end
      default:;
    endcase // case (r.state)
  end

  always_ff @(posedge clk) begin
    r <= rin;
    if (DEBUG) begin
      if (r.valid && ~r.pvalid) begin
        $display("%t : %-12s : FROM %0d.%0d.%0d.%0d TO %0d.%0d.%0d.%0d, PROTO %s",
                 $time(), TAG,
                 r.source_ip[31-:8], r.source_ip[23-:8], r.source_ip[15-:8], r.source_ip[7-:8],
                 r.target_ip[31-:8], r.target_ip[23-:8], r.target_ip[15-:8], r.target_ip[7-:8],
                 (r.protocol == IP_PROTO_ICMP) ? "ICMP" :
                 ((r.protocol == IP_PROTO_UDP) ? "UDP" : "OTHER"));
      end
    end
  end

  assign icmp_axis_tvalid = s_axis_tvalid && r.valid && (r.protocol == IP_PROTO_ICMP);
  assign icmp_axis_tdata  = s_axis_tdata;
  assign icmp_axis_tlast  = s_axis_tlast;

  assign udp_axis_tvalid = s_axis_tvalid && r.valid && (r.protocol == IP_PROTO_UDP);
  assign udp_axis_tdata  = s_axis_tdata;
  assign udp_axis_tlast  = s_axis_tlast;

  assign s_axis_tready = tready;

  assign ip_valid = r.valid;
  assign ip_ttl   = r.ttl;
  assign ip_id    = r.id;
  assign ip_source_ip = r.source_ip;
  assign ip_target_ip = r.target_ip;

  assign ip_checksum_valid = (r.chk_state == CHK_ST2);
  assign ip_checksum_ok    = (r.chksum[15:0] == 'h0);

endmodule : axi_ip_rx
`default_nettype wire
