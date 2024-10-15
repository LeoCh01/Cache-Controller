library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CacheController is
  port ( 
    clk : in  STD_LOGIC;
    ADDR : out  STD_LOGIC_VECTOR(15 downto 0);
    RDY, WR_RD, MEMSTRB, WEN : out STD_LOGIC
  );
end CacheController;

architecture Behavioral of CacheController is
---------------------------------------------------------
-- Components
---------------------------------------------------------
  component CPU_gen
    port ( 
      clk : in  STD_LOGIC;
      rst : in  STD_LOGIC;
      trig : in  STD_LOGIC;
      Address : out  STD_LOGIC_VECTOR (15 downto 0);
      wr_rd : out  STD_LOGIC;
      cs : out  STD_LOGIC;
      DOut : out  STD_LOGIC_VECTOR (7 downto 0)
    );
  end component;

  component SRAM
    port (
     clka : in STD_LOGIC;
     wea : in STD_LOGIC_VECTOR(0 downto 0);
     addra : in STD_LOGIC_VECTOR(7 downto 0);
     dina : in STD_LOGIC_VECTOR(7 downto 0);
     douta : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component SDRAM_Controller
    port (
      clk : in  STD_LOGIC;
      ADDR : in  STD_LOGIC_VECTOR (15 downto 0);
      WR_RD : in  STD_LOGIC;
      MEMSTRB : in  STD_LOGIC;
      DIN : in  STD_LOGIC_VECTOR (7 downto 0);
      DOUT : out STD_LOGIC_VECTOR (7 downto 0)
    );
  end component;

  component icon
    port (
      CONTROL0 : inout STD_LOGIC_VECTOR(35 downto 0);
      CONTROL1 : inout STD_LOGIC_VECTOR(35 downto 0)
    );
  end component;
  
  component ila
    port (
      CONTROL: inout STD_LOGIC_VECTOR(35 downto 0);
      CLK : in STD_LOGIC;
      DATA : in STD_LOGIC_VECTOR(63 downto 0);
      TRIG0 : in STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component vio
    port (
      CONTROL : inout STD_LOGIC_VECTOR(35 downto 0);
      ASYNC_OUT : out STD_LOGIC_VECTOR(35 downto 0)
    );
  end component;

---------------------------------------------------------
-- signals
---------------------------------------------------------
  signal CPU_addr : STD_LOGIC_VECTOR(15 downto 0);
  signal CPU_wr_rd : STD_LOGIC;
  signal CPU_cs : STD_LOGIC;
  signal CPU_trig : STD_LOGIC;
  signal CPU_rst : STD_LOGIC;
  signal CPU_Din, CPU_DOut : STD_LOGIC_VECTOR(7 downto 0);

  signal sram_addr : STD_LOGIC_VECTOR(7 downto 0);
  signal sram_din, sram_dout : STD_LOGIC_VECTOR(7 downto 0);
  signal sram_wen : STD_LOGIC_VECTOR(0 downto 0);

  signal sdram_addr : STD_LOGIC_VECTOR(15 downto 0);
  signal sdram_wr_rd : STD_LOGIC;
  signal sdram_memstrb : STD_LOGIC;
  signal sdram_din, sdram_dout : STD_LOGIC_VECTOR(7 downto 0);

  type tags is array(0 to 7) of STD_LOGIC_VECTOR(7 downto 0);
  signal cache_tags : tags := (others => (others => '0'));
  signal d_bit : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
  signal v_bit : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
  signal cache_tag : STD_LOGIC_VECTOR(7 downto 0);
  signal cache_index : STD_LOGIC_VECTOR(2 downto 0);
  signal cache_offset : STD_LOGIC_VECTOR(4 downto 0);
  signal mem_counter : integer := 0;

  signal control0 : STD_LOGIC_VECTOR(35 downto 0);
  signal control1 : STD_LOGIC_VECTOR(35 downto 0);
  signal ila_data : STD_LOGIC_VECTOR(63 downto 0);
  signal trig0 : STD_LOGIC_VECTOR(7 downto 0);
  signal vio_out : STD_LOGIC_VECTOR(35 downto 0);
  signal sram_mux : STD_LOGIC := 0;
  signal counter: std_logic_vector(15 downto 0);

  type cache_state is (START, IDLE, COMPARE, WRITE_BACK, LOAD_FROM_MEMORY, CACHE_HIT);
  signal current_state : cache_state := START;

---------------------------------------------------------
-- functions
---------------------------------------------------------
  function state_to_bin(state: cache_state) return std_logic_vector is
    begin
    case state is
      when IDLE => return "000";
      when COMPARE => return "001";
      when WRITE_BACK => return "010";
      when LOAD_FROM_MEMORY => return "011";
    when START => return "100";
    when CACHE_HIT => return "101";
      when others => return "111";
    end case;
  end function;

---------------------------------------------------------
-- port maps
---------------------------------------------------------
  begin
  CPU_inst : CPU_gen port map (
    clk => clk,
    rst => CPU_rst,
    trig => CPU_trig,
    Address => CPU_addr,
    wr_rd => CPU_wr_rd,
    cs => CPU_cs,
    DOut => CPU_DOut
  );

  SRAM_inst : SRAM port map (
    clka => clk,
    wea => sram_wen,
    addra => sram_addr,
    dina => sram_din,
    douta => sram_dout
  );

  SDRAM_Controller_inst : SDRAM_Controller port map (
    clk => clk,
    ADDR => sdram_addr,
    WR_RD => sdram_wr_rd,
    MEMSTRB => sdram_memstrb,
    DIN => sram_dout,
    DOUT => sdram_dout
  );

  icon_inst : icon port map (
    CONTROL0 => control0,
    CONTROL1 => control1
  );

  ila_inst : ila port map (
    CONTROL => control0,
    CLK => clk,
    DATA => ila_data,
    TRIG0 => trig0
  );

  vio_inst : vio port map (
    CONTROL => control1,
    ASYNC_OUT => vio_out
  );

---------------------------------------------------------
-- State Machine
--------------------------------------------------------- 
  process(clk)
    begin
    if (clk'Event and clk='1') then
      cache_tag <= CPU_addr(15 downto 8);
      cache_index <= CPU_addr(7 downto 5);
      cache_offset <= CPU_addr(4 downto 0);
    
      case current_state is
        when IDLE => 
          CPU_trig <= '1';
          if (CPU_cs = '1') then
            test2 <= '1';
            current_state <= COMPARE;
            CPU_trig <= '0';
          end if;

        when COMPARE =>
          if (v_bit(to_integer(unsigned(cache_index))) = '1' and cache_tags(to_integer(unsigned(cache_index))) = cache_tag) then
            -- hit
            if (CPU_wr_rd = '1') then
              -- write
              sram_wen(0) <= '1';
              sram_din <= CPU_DOut;
              sram_mux <= '0';
              d_bit(to_integer(unsigned(cache_index))) <= '1';
            else
              -- read
              sram_wen(0) <= '0';
            end if;

            sram_addr <= cache_index & cache_offset;
            current_state <= CACHE_HIT;
          else
            -- miss
            if (d_bit(to_integer(unsigned(cache_index))) = '1') then
              current_state <= WRITE_BACK;
            else
              current_state <= LOAD_FROM_MEMORY;
            end if;
          end if;

        when WRITE_BACK =>
          if (mem_counter = 64) then
            mem_counter <= 0;
            sdram_memstrb <= '0';
            d_bit(to_integer(unsigned(cache_index))) <= '0';
            current_state <= LOAD_FROM_MEMORY;
          else
            -- load cache first, then write to memory
            if (mem_counter mod 2 = 0) then
              sdram_memstrb <= '0';
              sram_wen(0) <= '0';
              sram_addr <= cache_index & std_logic_vector(to_unsigned(mem_counter / 2, 5));
            else
              sdram_wr_rd <= '0';
              sdram_addr <= cache_tags(to_integer(unsigned(cache_index))) & cache_index & std_logic_vector(to_unsigned(mem_counter / 2, 5));
              sdram_din <= sram_dout;
              sdram_memstrb <= '1';
            end if;
            mem_counter <= mem_counter + 1;
          end if;

        when LOAD_FROM_MEMORY =>
          if (mem_counter = 64) then
            mem_counter <= 0;
            v_bit(to_integer(unsigned(cache_index))) <= '1';
            cache_tags(to_integer(unsigned(cache_index))) <= cache_tag;
            current_state <= COMPARE;
          else
            -- load memory first, then write to cache
            if (mem_counter mod 2 = 0) then
              sdram_wr_rd <= '1';
              sdram_addr <= cache_tag & cache_index & std_logic_vector(to_unsigned(mem_counter / 2, 5));
              sdram_memstrb <= '1';
            else
              sram_wen(0) <= '1';
              sram_addr <= cache_index & std_logic_vector(to_unsigned(mem_counter / 2, 5));
              -- sram_din <= sdram_dout;
              sram_mux <= '1';
              sdram_memstrb <= '0';
            end if;
            mem_counter <= mem_counter + 1;
          end if;

        when CACHE_HIT =>
          CPU_Din <= sram_dout;
       cache_tags(to_integer(unsigned(cache_index))) <= cache_tag;
          current_state <= IDLE;
      
      when START =>
        CPU_trig <= '0';
          current_state <= IDLE;
      when others =>
          current_state <= IDLE;	
      end case;
    end if;
  end process;

  process(sram_mux)
  begin
    if (sram_mux = '1') then
      sram_din <= sdram_dout;
    else
      sram_din <= CPU_DOut;
    end if;
  end process;
  
---------------------------------------------------------
-- ILA ports
---------------------------------------------------------
  -- ila_data(7 downto 0) <= d_bit;
  -- ila_data(15 downto 8) <= v_bit;
  -- ila_data(23 downto 16) <= cache_tag;
  -- ila_data(26 downto 24) <= cache_index;
  -- ila_data(31 downto 27) <= cache_offset;
  -- ila_data(32) <= CPU_wr_rd;
  -- ila_data(33) <= CPU_cs;
  -- ila_data(34) <= CPU_trig;
  -- ila_data(35) <= sram_wen(0);
  -- ila_data(37 downto 35) <= state_to_bin(current_state);
  

end Behavioral;