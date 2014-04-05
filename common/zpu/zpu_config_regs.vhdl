---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY zpu_config_regs IS
GENERIC
(
	platform : integer := 1 -- So ROM can detect which type of system...
);
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	POKEY_ENABLE : in std_logic;
	
	ADDR : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
	CPU_DATA_IN : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	WR_EN : IN STD_LOGIC;
	
	-- GENERIC INPUT REGS (need to synchronize upstream...)
	IN1 : in std_logic_vector(31 downto 0); 
	IN2 : in std_logic_vector(31 downto 0); 
	IN3 : in std_logic_vector(31 downto 0); 
	IN4 : in std_logic_vector(31 downto 0); 
	
	-- GENERIC OUTPUT REGS
	OUT1 : out  std_logic_vector(31 downto 0); 
	OUT2 : out  std_logic_vector(31 downto 0); 
	OUT3 : out  std_logic_vector(31 downto 0); 
	OUT4 : out  std_logic_vector(31 downto 0); 
	
	-- SDCARD
	SDCARD_CLK : out std_logic;
	SDCARD_CMD : out std_logic;
	SDCARD_DAT : in std_logic;
	SDCARD_DAT3 : out std_logic;
	
	-- ATARI interface (in future we can also turbo load by directly hitting memory...)
	SIO_DATA_IN  : out std_logic;
	SIO_COMMAND : in std_logic;
	SIO_DATA_OUT : in std_logic;
	
	-- CPU interface
	DATA_OUT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	PAUSE_ZPU : out std_logic
);
END zpu_config_regs;

ARCHITECTURE vhdl OF zpu_config_regs IS
	function vectorize(s: std_logic) return std_logic_vector is
	variable v: std_logic_vector(0 downto 0);
	begin
		v(0) := s;
		return v;
	end;
	
	signal addr_decoded : std_logic_vector(15 downto 0);	
	
	signal out1_next : std_logic_vector(31 downto 0);
	signal out1_reg : std_logic_vector(31 downto 0);
	signal out2_next : std_logic_vector(31 downto 0);
	signal out2_reg : std_logic_vector(31 downto 0);
	signal out3_next : std_logic_vector(31 downto 0);
	signal out3_reg : std_logic_vector(31 downto 0);
	signal out4_next : std_logic_vector(31 downto 0);
	signal out4_reg : std_logic_vector(31 downto 0);
	
	signal spi_miso : std_logic;
	signal spi_mosi : std_logic;
	signal spi_busy : std_logic;	
	signal spi_enable : std_logic;
	signal spi_chip_select : std_logic_vector(0 downto 0);
	signal spi_clk_out : std_logic;
	
	signal spi_tx_data : std_logic_vector(7 downto 0);
	signal spi_rx_data : std_logic_vector(7 downto 0);
	
	signal spi_addr_next : std_logic;
	signal spi_addr_reg : std_logic;
	signal spi_addr_reg_integer : integer;
	signal spi_speed_next : std_logic_vector(7 downto 0);
	signal spi_speed_reg : std_logic_vector(7 downto 0);
	signal spi_speed_reg_integer : integer;

	signal pokey_data_out : std_logic_vector(7 downto 0);
	
	signal wr_en_pokey : std_logic;

	signal pause_next : std_logic_vector(31 downto 0);
	signal pause_reg : std_logic_vector(31 downto 0);
	signal paused_next : std_logic;
	signal paused_reg : std_logic;
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			out1_reg <= (others=>'0');
			out2_reg <= (others=>'0');
			out3_reg <= (others=>'0');
			out4_reg <= (others=>'0');
			
			spi_addr_reg <= '1';
			spi_speed_reg <= X"80";

			pause_reg <= (others=>'0');
			paused_reg <= '0';
		elsif (clk'event and clk='1') then	
			out1_reg <= out1_next;
			out2_reg <= out2_next;
			out3_reg <= out3_next;
			out4_reg <= out4_next;
			
			spi_addr_reg <= spi_addr_next;
			spi_speed_reg <= spi_speed_next;

			pause_reg <= pause_next;
			paused_reg <= paused_next;
		end if;
	end process;

	-- decode address
	decode_addr1 : entity work.complete_address_decoder
		generic map(width=>4)
		port map (addr_in=>addr(3 downto 0), addr_decoded=>addr_decoded);

	-- spi - for sd card access without bit banging...
	-- 200KHz to start with - probably fine for 8-bit, can up it later after init
					 
	-- spi-programming model:
	-- reg for write/read
	-- data (send/receive)
	-- busy
	-- speed - 0=400KHz, 1=10MHz? Start with 400KHz then atari800core...
	-- chip select
	
	-- uart - another Pokey! Running at atari frequency.
	wr_en_pokey <= addr(4) and wr_en;
	pokey1 : entity work.pokey
		port map (clk=>clk,CPU_MEMORY_READY=>pokey_enable,ANTIC_MEMORY_READY=>pokey_enable,addr=>addr(3 downto 0),data_in=>cpu_data_in(7 downto 0),wr_en=>wr_en_pokey, 
		reset_n=>reset_n,keyboard_response=>"11",pot_in=>X"00",
		sio_in1=>sio_data_out,sio_in2=>'1',sio_in3=>'1', -- TODO, pokey dir...
		data_out=>pokey_data_out, 
		sio_out1=>sio_data_in);

	-- hardware regs for ZPU
	--
	-- 0-3: GENERIC INPUT (RO)
	-- 4-7: GENERIC OUTPUT (R/W)
	--  8: PAUSE
	--   9: SPI_DATA
	-- SPI_DATA (DONE) 
	--		W - write data (starts transmission)
	--		R - read data (wait for complete first)
	--  10: SPI_STATE
	-- SPI_STATE/SPI_CTRL (DONE) 
	--    R: 0=busy
	--    W: 0=select_n, speed
	--  11: SIO
	-- SIO
	--    R: 0=CMD
	--  12: TYPE
	-- FPGA board (DONE) 
	--    R(32 bits) 0=DE1
	--  16-31: POKEY! Low bytes only... i.e. pokey reg every 4 bytes...
				
	-- Writes to registers
	process(cpu_data_in,wr_en,addr,addr_decoded, spi_speed_reg, spi_addr_reg, out1_reg, out2_reg, out3_reg, out4_reg, pause_reg)
	begin
		spi_speed_next <= spi_speed_reg;
		spi_addr_next <= spi_addr_reg;
		spi_tx_data <= (others=>'0');
		spi_enable <= '0';
		
		paused_next <= '0';
		if (not(pause_reg = X"00000000")) then
			pause_next <= std_LOGIC_VECTOR(unsigned(pause_reg)-to_unsigned(1,32));
			paused_next <= '1';
		end if;
	
		if (wr_en = '1' and addr(4) = '0') then
			if(addr_decoded(4) = '1') then
				out1_next <= cpu_data_in;
			end if;	
			
			if(addr_decoded(5) = '1') then
				out2_next <= cpu_data_in;
			end if;	

			if(addr_decoded(6) = '1') then
				out3_next <= cpu_data_in;
			end if;	

			if(addr_decoded(7) = '1') then
				out4_next <= cpu_data_in;
			end if;	

			if(addr_decoded(8) = '1') then
				pause_next <= cpu_data_in;
				paused_next <= '1';
			end if;	

			if(addr_decoded(9) = '1') then
				-- TODO, check overrun?
				spi_tx_data <= cpu_data_in(7 downto 0);
				spi_enable <= '1';
			end if;	

			if(addr_decoded(10) = '1') then
				spi_addr_next <= cpu_data_in(0);
				if (cpu_data_in(1) = '1') then
					spi_speed_next <= X"80"; -- slow, for init
				else
					spi_speed_next <= X"04"; -- turbo!
				end if;
			end if;	
			
		end if;
	end process;
	
	-- Read from registers
	process(addr,addr_decoded, in1, in2, in3, in4, out1_reg, out2_reg, out3_reg, out4_reg, SIO_COMMAND, spi_rx_data, spi_busy, pokey_data_out)
	begin
		data_out <= (others=>'0');

		if (addr(4) = '0') then
			if (addr_decoded(0) = '1') then
				data_out <= in1;
			end if;
			
			if (addr_decoded(1) = '1') then
				data_out <= in2;
			end if;		
			
			if (addr_decoded(2) = '1') then
				data_out <= in3;
			end if;		
			
			if (addr_decoded(3) = '1') then
				data_out <= in4;
			end if;

			if (addr_decoded(4) = '1') then
				data_out <= out1_reg;
			end if;
			
			if (addr_decoded(5) = '1') then
				data_out <= out2_reg;
			end if;		
			
			if (addr_decoded(6) = '1') then
				data_out <= out3_reg;
			end if;		
			
			if (addr_decoded(7) = '1') then
				data_out <= out4_reg;
			end if;

			if (addr_decoded(9) = '1') then
				data_out(7 downto 0) <= spi_rx_data;
			end if;

			if (addr_decoded(10) = '1') then
				data_out(0) <= spi_busy;
			end if;		

			if(addr_decoded(11) = '1') then
				data_out(0) <= SIO_COMMAND;
			end if;	
			
			if (addr_decoded(12) = '1') then
				data_out <= std_logic_vector(to_unsigned(platform,32));
			end if;
		else
			data_out(7 downto 0) <= pokey_data_out;
		end if;
	end process;	
	
	-- outputs
	PAUSE_ZPU <= paused_reg;

	out1 <= out1_reg;
	out2 <= out2_reg;
	out3 <= out3_reg;
	out4 <= out4_reg;
	
	SDCARD_CLK <= spi_clk_out;
	SDCARD_CMD <= spi_mosi;
	spi_miso <= SDCARD_DAT; -- INPUT!! XXX
	SDCARD_DAT3 <= spi_chip_select(0);
end vhdl;


