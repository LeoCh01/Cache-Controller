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

	component SDRAM_controller
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
		CONTROL0 : inout STD_LOGIC_VECTOR(35 downto 0));
	end component;
	
	component ila
	port (
		CONTROL: inout STD_LOGIC_VECTOR(35 downto 0);
		CLK : in STD_LOGIC;
		DATA : in STD_LOGIC_VECTOR(99 downto 0);
		TRIG0 : in STD_LOGIC_VECTOR(0 to 0));
	end component;

---------------------------------------------------------
-- signals
---------------------------------------------------------
	signal CPU_addr : STD_LOGIC_VECTOR(15 downto 0);
	signal CPU_wr_rd : STD_LOGIC;
	signal CPU_cs : STD_LOGIC;
	signal CPU_rdy : STD_LOGIC;
	signal CPU_Din, CPU_DOut : STD_LOGIC_VECTOR(7 downto 0);

	signal sram_addr : STD_LOGIC_VECTOR(7 downto 0);
	signal sram_din, sram_dout : STD_LOGIC_VECTOR(7 downto 0);
	signal sram_wen : STD_LOGIC;

	signal sdram_addr : STD_LOGIC_VECTOR(15 downto 0);
	signal sdram_wr_rd : STD_LOGIC;
	signal sdram_memstrb : STD_LOGIC;
	signal sdram_din, sdram_dout : STD_LOGIC_VECTOR(7 downto 0);

	signal v_bit, d_bit : STD_LOGIC(7 downto 0);
	signal cache_tag : STD_LOGIC_VECTOR(7 downto 0);
	signal cache_index : STD_LOGIC_VECTOR(2 downto 0);
	signal cache_offset : STD_LOGIC_VECTOR(4 downto 0);

	signal control0 : STD_LOGIC_VECTOR(35 downto 0);
	signal ila_data : STD_LOGIC_VECTOR(99 downto 0);
	signal trig0 : STD_LOGIC_VECTOR(0 downto 0);

	type cache_state is (IDLE, COMPARE, WRITE_BACK, LOAD_FROM_MEMORY);
	signal current_state : cache_state := IDLE;

	begin
---------------------------------------------------------
-- port maps
---------------------------------------------------------
		CPU_inst : CPU_gen port map (
			clk => clk,
			rst => '0',
			trig => CPU_rdy,
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

		SDRAM_Controller_inst : SDRAM_controller port map (
			clk => clk,
			ADDR => sdram_addr,
			WR_RD => sdram_wr_rd,
			MEMSTRB => sdram_memstrb,
			DIN => sdram_din,
			DOUT => sdram_dout
		);

		icon_inst : icon port map (
			CONTROL0 => control0
		);

		ila_inst : ila port map (
			CONTROL => control0,
			CLK => clk,
			DATA => ila_data,
			TRIG0 => trig0
		);

---------------------------------------------------------
-- State Machine
---------------------------------------------------------
	process(clk)
		begin
			if (clk'Event and clk='1') then
				case current_state is
					when IDLE => 
						CPU_rdy <= '1';
						if (CPU_cs = '1') then
							current_state <= COMPARE;
						end if;

					when COMPARE =>
						cache_tag <= CPU_addr(15 downto 8);
						cache_index <= CPU_addr(7 downto 5);
						cache_offset <= CPU_addr(4 downto 0);

						if (v_bit(cache_index) = '1' and cache_tag = d_bit(cache_index)) then
							-- hit
							if (CPU_wr_rd = '1') then
								-- write
								sram_wen <= '1';
								sram_din <= CPU_DOut;
								d_bit(cache_index) <= '1';
							else
								-- read
								sram_wen <= '0';
								CPU_Din <= sram_dout;
							end if;

							sram_addr <= cache_index & cache_offset;
							current_state <= IDLE;
						else
							-- miss
							if (d_bit(cache_index) = '1') then
								current_state <= WRITE_BACK;
							else
								current_state <= LOAD_FROM_MEMORY;
							end if;
						end if;

					when WRITE_BACK =>
						sdram_wr_rd <= '1';
						sdram_addr <= CPU_addr;
						sdram_memstrb <= '1';

						
						-- sdram_addr <= cache_tag & cache_index & cache_offset;
						-- sdram_wr_rd <= '1';
						-- sdram_memstrb <= '1';
						-- sdram_din <= d_bit(cache_index);
						-- current_state <= LOAD_FROM_MEMORY;

					when LOAD_FROM_MEMORY =>
						-- sdram_addr <= CPU_addr;
						-- sdram_wr_rd <= CPU_wr_rd;
						-- sdram_memstrb <= '0';
						-- sdram_din <= CPU_DOut;
						-- current_state <= IDLE;

					when others =>
						current_state <= IDLE;	
				end case;
			end if;
	end process;

---------------------------------------------------------
-- Connections?
---------------------------------------------------------
		-- ADDR <= CPU_addr;
		-- RDY <= CPU_rdy;
		-- WR_RD <= CPU_wr_rd;
		-- MEMSTRB <= sdram_memstrb;
		-- WEN <= sram_wen;

---------------------------------------------------------
-- functions
---------------------------------------------------------
	function state_to_bin(state: cache_state) return std_logic_vector is
		begin
			case state is
				when IDLE => return "00";
				when COMPARE => return "01";
				when WRITE_BACK => return "10";
				when LOAD_FROM_MEMORY => return "11";
				when others => return "00";
			end case;
	end function;

---------------------------------------------------------
-- ILA ports
---------------------------------------------------------
	ila_data(15 downto 0) <= CPU_addr;
	ila_data(23 downto 16) <= cache_tag;
	ila_data(26 downto 24) <= cache_index;
	ila_data(31 downto 27) <= cache_offset;
	ila_data(32) <= CPU_wr_rd;
	ila_data(33) <= CPU_cs;
	ila_data(34) <= CPU_rdy;
	ila_data(35) <= sram_wen;
	ila_data(43 downto 36) <= d_bit;
	ila_data(51 downto 44) <= v_bit;
	ila_data(55 downto 54) <= state_to_bin(current_state);

end Behavioral;
