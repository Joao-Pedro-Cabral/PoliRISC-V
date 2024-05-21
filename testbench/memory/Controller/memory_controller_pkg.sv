
package memory_controller_pkg;

  localparam integer ProcDataSize = 32;
  localparam integer CacheDataSize = 128;
  localparam integer ProcAddrSize = 32;
  localparam integer PeriphAddrSize = 6;
  localparam integer ByteSize = 8;

  typedef virtual interface wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_proc;

  typedef virtual interface wishbone_if #(
      .DATA_SIZE(CacheDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(ProcAddrSize)
  ) wish_cache;

  typedef virtual interface wishbone_if #(
      .DATA_SIZE(ProcDataSize),
      .BYTE_SIZE(ByteSize),
      .ADDR_SIZE(PeriphAddrSize)
  ) wish_periph;

  virtual class wishbone_class #(
      parameter integer DATA_SIZE = 32,
      parameter integer BYTE_SIZE = 8,
      parameter integer ADDR_SIZE = 32
  );

    protected string name;

    function new(string name);
      this.name = name;
    endfunction

    function string get_name();
      return name;
    endfunction

    protected function void error_message(string wish_name, string check);
      $error("Error while testing %s with %s in the assert: %s", this.name, wish_name, check);
    endfunction

    pure virtual function void randomize_interface();

  endclass

  class wishbone_primary_class #(
      parameter integer DATA_SIZE = 32,
      parameter integer BYTE_SIZE = 8,
      parameter integer ADDR_SIZE = 32
  ) extends wishbone_class;

    local virtual interface wishbone_if #(
        .DATA_SIZE(DATA_SIZE),
        .BYTE_SIZE(BYTE_SIZE),
        .ADDR_SIZE(ADDR_SIZE)
    ).primary wish_p;

    function new(
        virtual interface wishbone_if #(
            .DATA_SIZE(DATA_SIZE),
            .BYTE_SIZE(BYTE_SIZE),
            .ADDR_SIZE(ADDR_SIZE)
        ).primary wish_p,
        string name);
      super.new(name);
      this.wish_p = wish_p;
    endfunction

    function virtual interface wishbone_if #(.DATA_SIZE(DATA_SIZE), .BYTE_SIZE(BYTE_SIZE),
                                             .ADDR_SIZE(ADDR_SIZE)) get_interface();
      return wish_p;
    endfunction

    function void randomize_interface();
      wish_p.cyc = $urandom();
      wish_p.stb = $urandom();
      wish_p.we = $urandom();
      wish_p.tgd = $urandom();
      wish_p.sel = $urandom();
      wish_p.addr = $urandom();
      wish_p.dat_o_p = $urandom();
    endfunction

    function void check_mem(wish_cache wish_s, string name_s);
      CHK_MEM_CYC :
      assert (wish_p.cyc === wish_s.cyc)
      else error_message(name_s, "cyc");
      CHK_MEM_STB :
      assert (wish_p.stb === wish_s.stb)
      else error_message(name_s, "stb");
      CHK_MEM_WE :
      assert (wish_p.we === wish_s.we)
      else error_message(name_s, "we");
      CHK_MEM_TGD :
      assert (wish_p.tgd === wish_s.tgd)
      else error_message(name_s, "tgd");
      CHK_MEM_SEL :
      assert (wish_p.sel === wish_s.sel)
      else error_message(name_s, "sel");
      CHK_MEM_ADDR :
      assert (wish_p.addr === wish_s.addr)
      else error_message(name_s, "addr");
      CHK_MEM_DAT_P :
      assert (wish_p.dat_o_p === wish_s.dat_i_s)
      else error_message(name_s, "dat_p");
    endfunction

    function void check_cache(wish_proc wish_s, string name_s);
      CHK_CACHE_CYC :
      assert (wish_p.cyc === wish_s.cyc)
      else error_message(name_s, "cyc");
      CHK_CACHE_STB :
      assert (wish_p.stb === wish_s.stb)
      else error_message(name_s, "stb");
      CHK_CACHE_WE :
      assert (wish_p.we === wish_s.we)
      else error_message(name_s, "we");
      CHK_CACHE_TGD :
      assert (wish_p.tgd === wish_s.tgd)
      else error_message(name_s, "tgd");
      CHK_CACHE_SEL :
      assert (wish_p.sel === wish_s.sel)
      else error_message(name_s, "sel");
      CHK_CACHE_ADDR :
      assert (wish_p.addr === wish_s.addr)
      else error_message(name_s, "addr");
      CHK_CACHE_DAT_P :
      assert (wish_p.dat_o_p === wish_s.dat_i_s)
      else error_message(name_s, "dat_p");
    endfunction

    function void check_periph(wish_periph wish_s, string name_s);
      CHK_PERIPH_CYC :
      assert (wish_p.cyc === wish_s.cyc)
      else error_message(name_s, "cyc");
      CHK_PERIPH_STB :
      assert (wish_p.stb === wish_s.stb)
      else error_message(name_s, "stb");
      CHK_PERIPH_WE :
      assert (wish_p.we === wish_s.we)
      else error_message(name_s, "we");
      CHK_PERIPH_TGD :
      assert (wish_p.tgd === wish_s.tgd)
      else error_message(name_s, "tgd");
      CHK_PERIPH_SEL :
      assert (wish_p.sel === wish_s.sel)
      else error_message(name_s, "sel");
      CHK_PERIPH_ADDR :
      assert (wish_p.addr[PeriphAddrSize-1:0] === wish_s.addr)
      else error_message(name_s, "addr");
      CHK_PERIPH_DAT_P :
      assert (wish_p.dat_o_p === wish_s.dat_i_s)
      else error_message(name_s, "dat_p");
    endfunction

    function reg is_accessing(input reg [31:0] addr, input reg [31:0] mask);
      return ((wish_p.addr & mask) == addr) && wish_p.cyc && wish_p.stb;
    endfunction

  endclass

  class wishbone_secondary_class #(
      parameter integer DATA_SIZE = 32,
      parameter integer BYTE_SIZE = 8,
      parameter integer ADDR_SIZE = 32
  ) extends wishbone_class;

    local virtual interface wishbone_if #(
        .DATA_SIZE(DATA_SIZE),
        .BYTE_SIZE(BYTE_SIZE),
        .ADDR_SIZE(ADDR_SIZE)
    ).secondary wish_s;

    function new(
        virtual interface wishbone_if #(
            .DATA_SIZE(DATA_SIZE),
            .BYTE_SIZE(BYTE_SIZE),
            .ADDR_SIZE(ADDR_SIZE)
        ).secondary wish_s,
        string name);
      super.new(name);
      this.wish_s = wish_s;
    endfunction

    function virtual interface wishbone_if #(.DATA_SIZE(DATA_SIZE), .BYTE_SIZE(BYTE_SIZE),
                                             .ADDR_SIZE(ADDR_SIZE)) get_interface();
      return wish_s;
    endfunction

    function void randomize_interface();
      wish_s.ack = $urandom();
      wish_s.dat_o_s = $urandom();
    endfunction

    function void check_cache(wish_cache wish_p, string name_p);
      CHK_CACHE_ACK :
      assert (wish_s.ack === wish_p.ack)
      else error_message(name_p, "ack");
      CHK_CACHE_DAT_S :
      assert (wish_s.dat_o_s === wish_p.dat_i_p)
      else error_message(name_p, "dat_s");
    endfunction

    function void check_proc(wish_proc wish_p, string name_p);
      CHK_PROC_ACK :
      assert (wish_s.ack === wish_p.ack)
      else error_message(name_p, "ack");
      CHK_PROC_DAT_S :
      assert (wish_s.dat_o_s === wish_p.dat_i_p)
      else error_message(name_p, "dat_s");
    endfunction

    function void check_disabled();
      CHK_DISABLED_CYC :
      assert (wish_s.cyc === 1'b0)
      else error_message("", "disabled cyc");
      CHK_DISABLED_STB :
      assert (wish_s.stb === 1'b0)
      else error_message("", "disabled stb");
    endfunction

  endclass

endpackage
