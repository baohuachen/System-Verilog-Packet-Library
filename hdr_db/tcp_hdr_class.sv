/*
Copyright (c) 2011, Sachin Gandhi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// ----------------------------------------------------------------------
//  This hdr_class generates TCP header
//  TCP header Format
//  +-------------------+
//  | src_prt    [15:0] | 
//  +-------------------+
//  | dst_prt    [15:0] | 
//  +-------------------+
//  | seq_number [31:0] | 
//  +-------------------+
//  | ack_number [31:0] | 
//  +-------------------+
//  | offset     [3:0]  | 
//  +-------------------+
//  | rsvd       [3:0]  | 
//  +-------------------+
//  | flags      [7:0]  | -> 8 bit flags as described below
//  | +---------------+ |
//  | |C|E|U|A|P|R|S|F| | 
//  | |W|C|R|C|S|S|Y|I| |
//  | |R|E|G|K|H|T|N|N| | 
//  | +---------------+ |
//  +-------------------+
//  | window     [15:0] |
//  +-------------------+
//  | checksum   [15:0] |
//  +-------------------+
//  | urgent_ptr [15:0] |
//  +-------------------+
//  | options[39:0][7:0]| -> options depends on offset
//  +-------------------+
// ----------------------------------------------------------------------
//  Control Variables :
//  ==================
//  +-------+---------+---------------------------+-------------------------------+
//  | Width | Default | Variable                  | Description                   |
//  +-------+---------+---------------------------+-------------------------------+
//  | 1     | 1'b0    | corrupt_offset            | If 1, corrupts offset         |
//  |       |         |                           | (offset < 4'h5                |
//  +-------+---------+---------------------------+-------------------------------+
//  | 1     | 1'b1    | cal_tcp_chksm             | If 1, calculates tcp checksum |
//  |       |         |                           | Otherwise it will be random   |
//  +-------+---------+---------------------------+-------------------------------+
//  | 1     | 1'b0    | corrupt_tcp_chksm         | If 1, corrupts tcp checksum   |
//  +-------+---------+---------------------------+-------------------------------+
//  | 16    | 16'hFFFF| corrupt_tcp_chksm_msk     | Msk used to corrupt tcp_chksm |
//  +-------+---------+---------------------------+-------------------------------+
//
// ----------------------------------------------------------------------

class tcp_hdr_class extends hdr_class; // {

  // ~~~~~~~~~~ Class members ~~~~~~~~~~
  rand  bit [15:0]    src_prt;
  rand  bit [15:0]    dst_prt;
  rand  bit [31:0]    seq_number;
  rand  bit [31:0]    ack_number;
  rand  bit [3:0]     offset;
  rand  bit [3:0]     rsvd;
  rand  bit [7:0]     flags;
  rand  bit           cwr;
  rand  bit           ece;
  rand  bit           urg;
  rand  bit           ack;
  rand  bit           psh;
  rand  bit           rst;
  rand  bit           syn;
  rand  bit           fin;
  rand  bit [15:0]    window;
  rand  bit [15:0]    checksum;
  rand  bit [15:0]    urgent_ptr;
  rand  bit [7:0]     options [];

  // ~~~~~~~~~~ Local Variables ~~~~~~~~~~

  // ~~~~~~~~~~ Control variables ~~~~~~~~~~
        bit           corrupt_offset        = 1'b0;
        bit           cal_tcp_chksm         = 1'b1;
        bit           corrupt_tcp_chksm     = 1'b0;
        bit [15:0]    corrupt_tcp_chksm_msk = 16'hffff;

  // ~~~~~~~~~~ Constraints begins ~~~~~~~~~~

  constraint tcp_hdr_user_constraint
  {
  }

  constraint legal_total_hdr_len
  {
    `LEGAL_TOTAL_HDR_LEN_CONSTRAINTS;
  }

  constraint legal_hdr_len 
  {
    (offset inside {[5:15]}) -> hdr_len == offset*4;
    (offset < 4'h5)          -> hdr_len == 20;
  }

  constraint legal_offset
  {
    (corrupt_offset == 1'b0) -> (offset inside {[5:15]});
    (corrupt_offset == 1'b1) -> (offset < 4'h5);
  }

  constraint legal_flags
  {
    flags[7] == cwr;
    flags[6] == ece;
    flags[5] == urg;
    flags[4] == ack;
    flags[3] == psh;
    flags[2] == rst;
    flags[1] == syn;
    flags[0] == fin;
  }

  constraint legal_checksum
  {
    checksum == 16'h0;
  }

  constraint legal_options_sz
  {
    (offset inside {[5:15]}) -> (options.size == (offset-5)*4);
    (offset < 4'h5)          -> (options.size == 0);
  }

  // ~~~~~~~~~~ Task begins ~~~~~~~~~~

  function new (pktlib_main_class plib,
                int               inst_no); // {
    super.new (plib);
    hid          = TCP_HID;
    this.inst_no = inst_no;
    $sformat (hdr_name, "tcp[%0d]",inst_no);
    super.update_hdr_db (hid, inst_no);
  endfunction : new // }

  function void post_randomize (); // {
    if (super) super.post_randomize();
    // Calculate options
    if (offset > 5)
    begin // {
        if (harray.data_pattern != "RND")
            harray.fill_array(options);
    end // }
  endfunction : post_randomize // }

  task pack_hdr (ref   bit [7:0] pkt [],
                 ref   int       index,
                 input bit       last_pack = 1'b0); // {
    int tcp_idx;
    tcp_idx = index;
    // making sure checksum is 0, incase pack_hdr was called before radomization
    if (cal_tcp_chksm && ~last_pack)
        checksum = 0;
    // pack class members
    pack_vec = {src_prt, dst_prt, seq_number, ack_number, offset, rsvd, flags, window, checksum, urgent_ptr};
    harray.pack_bit (pkt, pack_vec, index, 160);
    if (offset > 5)
        harray.pack_array_8(options, pkt, index);
    // pack next hdr
    if (~last_pack)
        nxt_hdr.pack_hdr (pkt, index);
    // checksum calulation
    if (~last_pack)
        post_pack (pkt, tcp_idx);
  endtask : pack_hdr // }

  task unpack_hdr (ref   bit [7:0] pkt   [],
                   ref   int       index,
                   ref   hdr_class hdr_q [$],
                   input int       mode        = DUMB_UNPACK,
                   input bit       last_unpack = 1'b0); // {
    hdr_class lcl_class;
    // unpack class members
    hdr_len   = 20;
    start_off = index;
    harray.unpack_array (pkt, pack_vec, index, hdr_len);
    {src_prt, dst_prt, seq_number, ack_number, offset, rsvd, flags, window, checksum, urgent_ptr} = pack_vec;
    hdr_len   = offset * 4;
    if (offset > 4'd5)
        harray.copy_array (pkt, options, index, (hdr_len - 20));
    // get next hdr and update common nxt_hdr fields
    if (mode == SMART_UNPACK)
    begin // {
        $cast (lcl_class, this);
        if (pkt.size > index)
            super.update_nxt_hdr_info (lcl_class, hdr_q, DATA_HID);
        else
            super.update_nxt_hdr_info (lcl_class, hdr_q, DATA_HID);
    end // } 
    // unpack next hdr
    if (~last_unpack)
        this.nxt_hdr.unpack_hdr (pkt, index, hdr_q, mode);
    // update all hdr
    if (mode == SMART_UNPACK)
        super.all_hdr = hdr_q;
  endtask : unpack_hdr // }

  function post_pack (ref bit [7:0] pkt [],
                          int       tcp_idx); // {
    bit [7:0]      chksm_data [];
    bit [15:0]     pseudo_chksm;
    int            cpy_idx, i;
    ipv4_hdr_class lcl_ip4;
    ipv6_hdr_class lcl_ip6;
    // Calulate tcp_chksm, corrupt it if asked
    if (cal_tcp_chksm)
    begin // {
        for (i = 0; i < this.cfg_id; i++)
        begin // {
            if (super.all_hdr[i].hid == IPV4_HID)
            begin // {
                lcl_ip4 = new (super.plib, `MAX_NUM_INSTS+1);
                $cast (lcl_ip4, super.all_hdr[i]);
                pseudo_chksm = lcl_ip4.pseudo_chksm;
            end // }
            if (super.all_hdr[i].hid == IPV6_HID)
            begin // {
                lcl_ip6 = new (super.plib, `MAX_NUM_INSTS+1);
                $cast (lcl_ip6, super.all_hdr[i]);
                pseudo_chksm = lcl_ip6.pseudo_chksm;
            end // }
        end // }
        cpy_idx = tcp_idx/8;
        harray.copy_array(pkt, chksm_data, cpy_idx, (pkt.size - cpy_idx));
        if (chksm_data.size%2 != 0)
        begin // {
            chksm_data                      = new [chksm_data.size + 1] (chksm_data);
            chksm_data [chksm_data.size -1] = 8'h00;
        end // }
        checksum = crc_chksm.chksm16(chksm_data, chksm_data.size(), 0, corrupt_tcp_chksm, corrupt_tcp_chksm_msk, pseudo_chksm);
        pack_hdr (pkt, tcp_idx, 1'b1);
    end // }
    else
    begin // {
        if (corrupt_tcp_chksm)
        begin // {
            checksum ^= corrupt_tcp_chksm_msk;
            pack_hdr (pkt, tcp_idx, 1'b1);
        end // }
    end // }
  endfunction : post_pack // }

  task cpy_hdr (hdr_class cpy_cls,
                bit       last_unpack = 1'b0); // {
    tcp_hdr_class lcl;
    super.cpy_hdr (cpy_cls);
    $cast (lcl, cpy_cls);
    // ~~~~~~~~~~ Class members ~~~~~~~~~~
    this.src_prt               = lcl.src_prt;             
    this.dst_prt               = lcl.dst_prt;
    this.src_prt               = lcl.src_prt;
    this.dst_prt               = lcl.dst_prt;
    this.seq_number            = lcl.seq_number;
    this.ack_number            = lcl.ack_number;
    this.offset                = lcl.offset;
    this.rsvd                  = lcl.rsvd;
    this.flags                 = lcl.flags;
    this.cwr                   = lcl.cwr;
    this.ece                   = lcl.ece;
    this.urg                   = lcl.urg;
    this.ack                   = lcl.ack;
    this.psh                   = lcl.psh;
    this.rst                   = lcl.rst;
    this.syn                   = lcl.syn;
    this.fin                   = lcl.fin;
    this.window                = lcl.window;
    this.checksum              = lcl.checksum;
    this.urgent_ptr            = lcl.urgent_ptr;
    this.options               = lcl.options;
    // ~~~~~~~~~~ Control variables ~~~~~~~~~~
    this.corrupt_offset        = lcl.corrupt_offset;        
    this.cal_tcp_chksm         = lcl.cal_tcp_chksm;        
    this.corrupt_tcp_chksm     = lcl.corrupt_tcp_chksm;    
    this.corrupt_tcp_chksm_msk = lcl.corrupt_tcp_chksm_msk;
    if (~last_unpack)
        this.nxt_hdr.cpy_hdr (cpy_cls.nxt_hdr, last_unpack);
  endtask : cpy_hdr // }

  task display_hdr (pktlib_display_class hdis,
                    hdr_class            cmp_cls,
                    int                  mode         = DISPLAY,
                    bit                  last_display = 1'b0); // {
    string flags_brk;
    tcp_hdr_class lcl;
    $cast (lcl, cmp_cls);
    $sformat(flags_brk, "=> CWR %b ECE %b URG %b ACK %b PSH %b RST %b SYN %b FIN %b", flags[7],flags[6],flags[5],flags[4],flags[3],flags[2],flags[1],flags[0]);
`ifdef DEBUG_CHKSM
    hdis.display_fld (mode, hdr_name, "hdr_len",      16, HEX, BIT_VEC, hdr_len,   lcl.hdr_len);
    hdis.display_fld (mode, hdr_name, "total_hdr_len",16, HEX, BIT_VEC, total_hdr_len,   lcl.total_hdr_len);
`endif
    hdis.display_fld (mode, hdr_name, "src_prt",      16, HEX, BIT_VEC, src_prt,   lcl.src_prt);
    hdis.display_fld (mode, hdr_name, "dst_prt",      16, HEX, BIT_VEC, dst_prt,   lcl.dst_prt);
    hdis.display_fld (mode, hdr_name, "seq_number",   32, HEX, BIT_VEC, seq_number,lcl.seq_number);
    hdis.display_fld (mode, hdr_name, "ack_number",   32, HEX, BIT_VEC, ack_number,lcl.ack_number);
    hdis.display_fld (mode, hdr_name, "offset",       04, HEX, BIT_VEC, offset,    lcl.offset);
    hdis.display_fld (mode, hdr_name, "rsvd",         04, HEX, BIT_VEC, rsvd,      lcl.rsvd);
    hdis.display_fld (mode, hdr_name, "flags",        08, HEX, BIT_VEC, flags,     lcl.flags,'{},'{}, flags_brk);
    hdis.display_fld (mode, hdr_name, "window",       16, HEX, BIT_VEC, window,    lcl.window);
    if (corrupt_tcp_chksm)
    hdis.display_fld (mode, hdr_name, "checksum",     16, HEX, BIT_VEC, checksum,  lcl.checksum,'{},'{}, "BAD");
    else
    hdis.display_fld (mode, hdr_name, "checksum",     16, HEX, BIT_VEC, checksum,  lcl.checksum,'{},'{}, "GOOD");
    hdis.display_fld (mode, hdr_name, "urgent_ptr",   16, HEX, BIT_VEC, urgent_ptr,lcl.urgent_ptr);
    if (options.size() !== 0)
    hdis.display_fld (mode, hdr_name, "options",      00, DEF, ARRAY, 0, 0, options, lcl.options);
    if (~last_display & (cmp_cls.nxt_hdr.hid === nxt_hdr.hid))
        this.nxt_hdr.display_hdr (hdis, cmp_cls.nxt_hdr, mode);
  endtask : display_hdr // }

endclass : tcp_hdr_class // }