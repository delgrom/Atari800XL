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

LIBRARY work;

ENTITY zpucore IS 
	GENERIC
	(
		platform : integer := 1; -- So ROM can detect which type of system...
		spi_clock_div : integer := 4  -- see notes on zpu_config_regs
	);
	PORT
	(
		-- standard...
		CLK : in std_logic;
		RESET_N : in std_logic;

		-- dma bus master (with many waitstates...)
		ZPU_ADDR_FETCH : out std_logic_vector(23 downto 0);
		ZPU_DATA_OUT : out std_logic_vector(31 downto 0);
		ZPU_FETCH : out std_logic;
		ZPU_32BIT_WRITE_ENABLE : out std_logic;
		ZPU_16BIT_WRITE_ENABLE : out std_logic;
		ZPU_8BIT_WRITE_ENABLE : out std_logic;
		ZPU_READ_ENABLE : out std_logic;
		ZPU_MEMORY_READY : in std_logic;
		ZPU_MEMORY_DATA : in std_logic_vector(31 downto 0);

		-- rom bus master
		-- data on next cycle after addr
		ZPU_ADDR_ROM : out std_logic_vector(15 downto 0);
		ZPU_ROM_DATA : in std_logic_vector(31 downto 0);

		-- spi master
		-- Too painful to bit bang spi from zpu, so we have a hardware master in here
		ZPU_SD_DAT0 :  IN  STD_LOGIC;
		ZPU_SD_CLK :  OUT  STD_LOGIC;
		ZPU_SD_CMD :  OUT  STD_LOGIC;
		ZPU_SD_DAT3 :  OUT  STD_LOGIC;

		-- SIO
		-- Ditto for speaking to Atari, we have a built in Pokey
		ZPU_POKEY_ENABLE : in std_logic; -- if run at 1.79MHz we can use standard dividers...
		ZPU_SIO_TXD : out std_logic;
		ZPU_SIO_RXD : in std_logic;
		ZPU_SIO_COMMAND : in std_logic;

		-- external control
		-- switches etc. sector DMA blah blah.
		ZPU_IN1 : in std_logic_vector(31 downto 0);
		ZPU_IN2 : in std_logic_vector(31 downto 0);
		ZPU_IN3 : in std_logic_vector(31 downto 0);
		ZPU_IN4 : in std_logic_vector(31 downto 0);

		-- ouputs - e.g. Atari system control, halt, throttle, rom select
		ZPU_OUT1 : out std_logic_vector(31 downto 0);
		ZPU_OUT2 : out std_logic_vector(31 downto 0);
		ZPU_OUT3 : out std_logic_vector(31 downto 0);
		ZPU_OUT4 : out std_logic_vector(31 downto 0)
	);
END zpucore;

ARCHITECTURE vhdl OF zpucore IS 
	signal ZPU_PAUSE : std_logic;
	signal ZPU_RESET : std_logic;

	signal ZPU_DO : std_logic_vector(31 downto 0);

	signal ZPU_ADDR_ROM_RAM : std_logic_vector(15 downto 0);

	signal ZPU_RAM_DATA : std_logic_vector(31 downto 0);
	signal ZPU_STACK_WRITE : std_logic_vector(3 downto 0);

	signal ZPU_CONFIG_DO : std_logic_vector(31 downto 0);
	signal ZPU_CONFIG_WRITE_ENABLE : std_logic;
BEGIN 

ZPU_RESET <= not(reset_n);
zpu_and_glue : entity work.zpu_glue
PORT MAP(CLK => CLK,
		 RESET => ZPU_RESET,
		 PAUSE => ZPU_PAUSE,
		 MEMORY_READY => ZPU_MEMORY_READY,
		 ZPU_CONFIG_DI => ZPU_CONFIG_DO,
		 ZPU_DI => ZPU_MEMORY_DATA,
		 ZPU_RAM_DI => ZPU_RAM_DATA,
		 ZPU_ROM_DI => ZPU_ROM_DATA,
		 MEMORY_FETCH => ZPU_FETCH,
		 ZPU_READ_ENABLE => ZPU_READ_ENABLE,
		 ZPU_32BIT_WRITE_ENABLE => ZPU_32BIT_WRITE_ENABLE,
		 ZPU_16BIT_WRITE_ENABLE => ZPU_16BIT_WRITE_ENABLE,
		 ZPU_8BIT_WRITE_ENABLE => ZPU_8BIT_WRITE_ENABLE,
		 ZPU_CONFIG_WRITE => ZPU_CONFIG_WRITE_ENABLE,
		 ZPU_ADDR_FETCH => ZPU_ADDR_FETCH,
		 ZPU_ADDR_ROM_RAM => ZPU_ADDR_ROM_RAM,
		 ZPU_DO => ZPU_DO,
		 ZPU_STACK_WRITE => ZPU_STACK_WRITE);

config_regs : entity work.zpu_config_regs
GENERIC MAP (
	platform => platform,
	spi_clock_div => spi_clock_div
)
PORT MAP (
	CLK => CLK,
	RESET_N => RESET_N,
	
	POKEY_ENABLE => ZPU_POKEY_ENABLE,
	
	ADDR => ZPU_ADDR_ROM_RAM(6 DOWNTO 2),
	CPU_DATA_IN => ZPU_DO,
	WR_EN => ZPU_CONFIG_WRITE_ENABLE,
	
	IN1 => ZPU_IN1,
	IN2 => ZPU_IN2,
	IN3 => ZPU_IN3,
	IN4 => ZPU_IN4,
	
	OUT1 => ZPU_OUT1,
	OUT2 => ZPU_OUT2,
	OUT3 => ZPU_OUT3,
	OUT4 => ZPU_OUT4,
	
	SDCARD_DAT => ZPU_SD_DAT0,
	SDCARD_CLK => ZPU_SD_CLK,
	SDCARD_CMD => ZPU_SD_CMD,
	SDCARD_DAT3 => ZPU_SD_DAT3,
	
	SIO_DATA_IN => ZPU_SIO_TXD,
	SIO_DATA_OUT => ZPU_SIO_RXD,
	SIO_COMMAND => ZPU_SIO_COMMAND,
	
	DATA_OUT => ZPU_CONFIG_DO,
	PAUSE_ZPU => ZPU_PAUSE
	);

ram_31_24 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => 10,
		SPACE => 1024,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE(3),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM(11 DOWNTO 2),
		data => ZPU_DO(31 DOWNTO 24),
		q => ZPU_RAM_DATA(31 DOWNTO 24)
	);

ram23_16 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => 10,
		SPACE => 1024,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE(2),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM(11 DOWNTO 2),
		data => ZPU_DO(23 DOWNTO 16),
		q => ZPU_RAM_DATA(23 DOWNTO 16)
	);

ram_15_8 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => 10,
		SPACE => 1024,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE(1),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM(11 DOWNTO 2),
		data => ZPU_DO(15 DOWNTO 8),
		q => ZPU_RAM_DATA(15 DOWNTO 8)
	);

ram_7_0 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => 10,
		SPACE => 1024,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE(0),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM(11 DOWNTO 2),
		data => ZPU_DO(7 DOWNTO 0),
		q => ZPU_RAM_DATA(7 DOWNTO 0)
	);

	-- OUTPUT
	ZPU_ADDR_ROM <= ZPU_ADDR_ROM_RAM;
	ZPU_DATA_OUT <= ZPU_DO;

end vhdl;
