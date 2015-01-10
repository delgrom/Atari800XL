---------------------------------------------------------------------------
-- (c) 2014 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY avalon_arm_regs IS
GENERIC
(
	platform : integer := 1 -- So ROM can detect which type of system...
);
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	POKEY_ENABLE : in std_logic;
	
	-- avalon signals
	CHIPSELECT : IN STD_LOGIC;
	ADDRESS : IN STD_LOGIC_VECTOR(10 downto 0);
	READ: IN STD_LOGIC;
	READDATA : OUT STD_LOGIC_VECTOR(31 downto 0);
	WRITE : IN STD_LOGIC;
	WRITEDATA : IN STD_LOGIC_VECTOR(31 downto 0);
	BYTEENABLE : IN STD_LOGIC_VECTOR(3 downto 0);
	
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
	OUT5 : out  std_logic_vector(31 downto 0); 
	OUT6 : out  std_logic_vector(31 downto 0); 
	
	-- ATARI interface (in future we can also turbo load by directly hitting memory...)
	SIO_DATA_IN  : out std_logic;
	SIO_COMMAND : in std_logic;
	SIO_DATA_OUT : in std_logic
);
END avalon_arm_regs;

ARCHITECTURE vhdl OF avalon_arm_regs IS

	function vectorize(s: std_logic) return std_logic_vector is
	variable v: std_logic_vector(0 downto 0);
	begin
		v(0) := s;
		return v;
	end;
	
	signal device_decoded : std_logic_vector(7 downto 0);	
	signal device_wr_en : std_logic_vector(7 downto 0);	
	signal device_rd_en : std_logic_vector(7 downto 0);	
	signal addr_decoded : std_logic_vector(15 downto 0);	
	
	signal out1_next : std_logic_vector(31 downto 0);
	signal out1_reg : std_logic_vector(31 downto 0);
	signal out2_next : std_logic_vector(31 downto 0);
	signal out2_reg : std_logic_vector(31 downto 0);
	signal out3_next : std_logic_vector(31 downto 0);
	signal out3_reg : std_logic_vector(31 downto 0);
	signal out4_next : std_logic_vector(31 downto 0);
	signal out4_reg : std_logic_vector(31 downto 0);
	signal out5_next : std_logic_vector(31 downto 0);
	signal out5_reg : std_logic_vector(31 downto 0);
	signal out6_next : std_logic_vector(31 downto 0);
	signal out6_reg : std_logic_vector(31 downto 0);
	
	signal pokey_data_out : std_logic_vector(7 downto 0);
	
	signal subtimer_next : std_logic_vector(10 downto 0);
	signal subtimer_reg : std_logic_vector(10 downto 0);

	signal timer_next : std_logic_vector(31 downto 0);
	signal timer_reg : std_logic_vector(31 downto 0);

	signal data_out_regs : std_logic_vector(31 downto 0);
	signal data_out_mux : std_logic_vector(31 downto 0);

	signal read_sel : std_logic;
	signal write_sel : std_logic;
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			out1_reg <= (others=>'0');
			out2_reg <= (others=>'0');
			out3_reg <= (others=>'0');
			out4_reg <= (others=>'0');
			out5_reg <= (others=>'0');
			out6_reg <= (others=>'0');
			
			subtimer_reg <= (others=>'0');
			timer_reg <= (others=>'0');
		elsif (clk'event and clk='1') then	
			out1_reg <= out1_next;
			out2_reg <= out2_next;
			out3_reg <= out3_next;
			out4_reg <= out4_next;
			out5_reg <= out5_next;
			out6_reg <= out6_next;
			
			subtimer_reg <= subtimer_next;
			timer_reg <= timer_next;
		end if;
	end process;

	-- decode address
	decode_addr : entity work.complete_address_decoder
		generic map(width=>4)
		port map (addr_in=>address(3 downto 0), addr_decoded=>addr_decoded);

	decode_device : entity work.complete_address_decoder
		generic map(width=>3)
		port map (addr_in=>address(10 downto 8), addr_decoded=>device_decoded);

	-- device decode
	-- 0x000 - own regs (0)
	-- 0x100 - pokey (1)

	write_sel <= write and chipselect;
	read_sel <= read and chipselect;
	device_wr_en <= device_decoded and (write_sel&write_sel&write_sel&write_sel&write_sel&write_sel&write_sel&write_sel);
	device_rd_en <= device_decoded and (read_sel&read_sel&read_sel&read_sel&read_sel&read_sel&read_sel&read_sel);
	
	-- uart - another Pokey! Running at atari frequency.
	-- with a state machine to capture command packets
	-- can not easily poll frequently enough with zpu when also polling usb
--	pokey1 : entity work.pokey
--		port map (clk=>clk,ENABLE_179=>pokey_enable,addr=>addr(3 downto 0),data_in=>WRITEDATA(7 downto 0),wr_en=>device_wr_en(1), 
--		reset_n=>reset_n,keyboard_response=>"11",pot_in=>X"00",
--		sio_in1=>sio_data_out,sio_in2=>'1',sio_in3=>'1', -- TODO, pokey dir...
--		data_out=>pokey_data_out, 
--		sio_out1=>sio_data_in);

pokey1 : entity work.sio_device
PORT  MAP
( 
	CLK => CLK,
	ADDR => address(4 downto 0),
	CPU_DATA_IN => WRITEDATA(7 downto 0),
	EN => device_rd_en(1),
	WR_EN => device_wr_en(1),
	
	RESET_N => reset_n,

	POKEY_ENABLE => pokey_enable,

	SIO_DATA_IN  => sio_data_in,
	SIO_COMMAND => sio_command,
	SIO_DATA_OUT => sio_data_out,
	
	-- CPU interface
	DATA_OUT => pokey_data_out
);

	-- timer for approx ms
	process(timer_reg,subtimer_reg, pokey_enable)
	begin
		timer_next <= timer_reg;
		subtimer_next <= subtimer_reg;

		if (pokey_enable = '1') then
			subtimer_next <= std_logic_vector(unsigned(subtimer_reg)-1);
		end if;

		if (subtimer_reg = "000"&x"00") then
			subtimer_next <= std_logic_vector(to_unsigned(11#1790#,11));
			timer_next <= std_logic_vector(unsigned(timer_reg)+1);
		end if;

	end process;

	process(device_decoded, data_out_regs, pokey_data_out)
	begin
		data_out_mux <= (others=>'0');
		if (device_decoded(0) = '1') then
			data_out_mux <= data_out_regs;
		end if;

		if (device_decoded(1) = '1') then
			data_out_mux(7 downto 0) <= pokey_data_out;
		end if;

	end process;

	-- hardware regs for ZPU
	--
	-- 0-3: GENERIC INPUT (RO)
	-- 4-7: GENERIC OUTPUT (R/W)
	--  8: W:PAUSE, R:Timer (1ms)
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
	--  13 : SPI_DMA
	--    W(15 downto 0 = addr),(31 downto 16 = endAddr)
	--  14-15 : GENERIC OUTPUT (R/W)
	--  16-31: POKEY! Low bytes only... i.e. pokey reg every 4 bytes...
				
	-- Writes to registers
	process(WRITEDATA,device_wr_en,address,addr_decoded, out1_reg, out2_reg, out3_reg, out4_reg, out5_reg, out6_reg, pokey_enable)
	begin
		out1_next <= out1_reg;
		out2_next <= out2_reg;
		out3_next <= out3_reg;
		out4_next <= out4_reg;
		out5_next <= out5_reg;
		out6_next <= out6_reg;

		if (device_wr_en(0) = '1') then
			if(addr_decoded(4) = '1') then
				out1_next <= WRITEDATA;
			end if;	
			
			if(addr_decoded(5) = '1') then
				out2_next <= WRITEDATA;
			end if;	

			if(addr_decoded(6) = '1') then
				out3_next <= WRITEDATA;
			end if;	

			if(addr_decoded(7) = '1') then
				out4_next <= WRITEDATA;
			end if;	

			if(addr_decoded(14) = '1') then
				out5_next <= WRITEDATA;
			end if;	

			if(addr_decoded(15) = '1') then
				out6_next <= WRITEDATA;
			end if;	
		end if;
	end process;
	
	-- Read from registers
	process(address,addr_decoded, in1, in2, in3, in4, out1_reg, out2_reg, out3_reg, out4_reg, out5_reg, out6_reg, SIO_COMMAND, timer_reg)
	begin
		data_out_regs <= (others=>'0');

		if (addr_decoded(0) = '1') then
			data_out_regs <= in1;
		end if;
		
		if (addr_decoded(1) = '1') then
			data_out_regs <= in2;
		end if;		
		
		if (addr_decoded(2) = '1') then
			data_out_regs <= in3;
		end if;		
		
		if (addr_decoded(3) = '1') then
			data_out_regs <= in4;
		end if;

		if (addr_decoded(4) = '1') then
			data_out_regs <= out1_reg;
		end if;
		
		if (addr_decoded(5) = '1') then
			data_out_regs <= out2_reg;
		end if;		
		
		if (addr_decoded(6) = '1') then
			data_out_regs <= out3_reg;
		end if;		
		
		if (addr_decoded(7) = '1') then
			data_out_regs <= out4_reg;
		end if;

		if (addr_decoded(14) = '1') then
			data_out_regs <= out5_reg;
		end if;

		if (addr_decoded(15) = '1') then
			data_out_regs <= out6_reg;
		end if;

		if (addr_decoded(8) = '1') then
			data_out_regs <= timer_reg;
		end if;

		if(addr_decoded(11) = '1') then
			data_out_regs(0) <= SIO_COMMAND;
		end if;	
		
		if (addr_decoded(12) = '1') then
			data_out_regs <= std_logic_vector(to_unsigned(platform,32));
		end if;
	end process;	
	
	-- outputs
	out1 <= out1_reg;
	out2 <= out2_reg;
	out3 <= out3_reg;
	out4 <= out4_reg;
	out5 <= out5_reg;
	out6 <= out6_reg;
	
	READDATA <= data_out_mux;
end vhdl;


