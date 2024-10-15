library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity SDRAM_controller is
  port (
    clk : in  STD_LOGIC;
    ADDR : in  STD_LOGIC_VECTOR (15 downto 0);
    WR_RD : in  STD_LOGIC;
    MEMSTRB : in  STD_LOGIC;
    DIN : in  STD_LOGIC_VECTOR (7 downto 0);
    DOUT : out STD_LOGIC_VECTOR (7 downto 0)
  );
end SDRAM_controller;

architecture Behavioral of SDRAM_controller is
---------------------------------------------------------
-- Components
---------------------------------------------------------
  component SDRAM
    port (
      clka : in STD_LOGIC;
      wea : in STD_LOGIC_VECTOR(0 downto 0);
      addra : in STD_LOGIC_VECTOR(11 downto 0);
      dina : in STD_LOGIC_VECTOR(7 downto 0);
      douta : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

---------------------------------------------------------
-- signals
---------------------------------------------------------
  signal SDRAM_wea : STD_LOGIC_VECTOR(0 downto 0);
  signal SDRAM_addra : STD_LOGIC_VECTOR(11 downto 0);
  signal SDRAM_dina : STD_LOGIC_VECTOR(7 downto 0);
  signal SDRAM_douta : STD_LOGIC_VECTOR(7 downto 0);

---------------------------------------------------------
-- port maps
---------------------------------------------------------
  begin
  SDRAM_inst : SDRAM port map (
    clka => clk,
    wea => SDRAM_wea,
    addra => SDRAM_addra,
    dina => SDRAM_dina,
    douta => DOUT
  );

---------------------------------------------------------
-- process
---------------------------------------------------------
  process(clk)
    begin
    if (clk'Event and clk='1') then
      if (MEMSTRB = '1') then
        SDRAM_wea(0) <= not(WR_RD);
        SDRAM_addra <= ADDR(11 downto 0);
        SDRAM_dina <= DIN;
      end if;
    end if;

  end process;

end Behavioral;