-- Simple version that:
-- i) needs: CLK(58 or 28MHZ) SDRAM,joystick,keyboard
-- ii) provides: VIDEO,AUDIO
-- iii) passes upstream: DMA port, for attaching ZPU for SDCARD/drive emulation

-- THIS SHOULD DO FOR ALL PLATFORMS EXCEPT THOSE USING GPIO FOR PBI etc

ENTITY atari800core_simplesdram is
	GENERIC
	(
		-- use CLK of 1.79*cycle_length
		-- I've tested 16 and 32 only, but 4 and 8 might work...
		cycle_length : integer := 16 -- or 32...
	
		-- For initial port may help to have no
		internal_rom : integer := 1  -- if 0 expects it in sdram,is 1:16k os+basic, is 2:... TODO
		internal_ram : integer := 16384  -- at start of memory map
	);
	PORT
	(
		CLK :  IN  STD_LOGIC; -- cycle_length*1.79MHz
		RESET_N : IN STD_LOGIC;

		-- VIDEO OUT - PAL/NTSC, original Atari timings approx (may be higher res)
		VGA_VS :  OUT  STD_LOGIC;
		VGA_HS :  OUT  STD_LOGIC;
		VGA_B :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		VGA_G :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		VGA_R :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0);

		-- AUDIO OUT - Pokey/GTIA 1-bit and Covox all mixed
		-- TODO - choose stereo/mono pokey
		AUDIO_L : OUT std_logic_vector(15 downto 0);
		AUDIO_R : OUT std_logic_vector(15 downto 0);

		-- JOYSTICK
		JOY1_n : IN std_logic_vector(4 downto 0); -- FUPLR, 0=pressed
		JOY2_n : IN std_logic_vector(4 downto 0); -- FUPLR, 0=pressed

		-- Pokey keyboard matrix
		-- Standard component available to connect this to PS2
		KEYBOARD_RESPONSE : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		KEYBOARD_SCAN : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);

		-- SIO
		SIO_COMMAND : out std_logic;
		SIO_RXD : in std_logic;
		SIO_TXD : out std_logic;

		-- GTIA consol
		CONSOL_OPTION : IN STD_LOGIC;
		CONSOL_SELECT : IN STD_LOGIC;
		CONSOL_START : IN STD_LOGIC;

		-----------------------
		-- After here all FPGA implementation specific
		-- e.g. need to write up RAM/ROM
		-- we can dma from memory space
		-- etc.

		-- External RAM/ROM - adhere to standard memory map
		-- TODO - lower/upper memory split defined by generic
		-- (TODO SRAM lower ram, SDRAM upper ram - no overlap?)
		---- SDRAM memory map (8MB) (lower 512k if USE_SDRAM=1)
		---- base 64k RAM  - banks 0-3    "000 0000 1111 1111 1111 1111" (TOP)
		---- to 512k RAM   - banks 4-31   "000 0111 1111 1111 1111 1111" (TOP) 
		---- to 4MB RAM    - banks 32-255 "011 1111 1111 1111 1111 1111" (TOP)
		---- +64k          - banks 256-259"100 0000 0000 1111 1111 1111" (TOP)
		---- SCRATCH       - 4MB+64k-5MB
		---- CARTS         -              "101 YYYY YYY0 0000 0000 0000" (BOT) - 2MB! 8kb banks
		--SDRAM_CART_ADDR      <= "101"&cart_select& "0000000000000";
		---- BASIC/OS ROM  -              "111 XXXX XX00 0000 0000 0000" (BOT) (BASIC IN SLOT 0!), 2nd to last 512K				
		--SDRAM_BASIC_ROM_ADDR <= "111"&"000000"   &"00000000000000";
		--SDRAM_OS_ROM_ADDR    <= "111"&rom_select &"00000000000000";
		---- SYSTEM        -              "111 1000 0000 0000 0000 0000" (BOT) - LAST 512K
		-- TODO - review if we need to pass out so many of these
		-- Perhaps we can simplify address decoder and have an external layer?
		SDRAM_REQUEST : OUT std_logic;
		SDRAM_REQUEST_COMPLETE : IN std_logic;
		SDRAM_READ_ENABLE : out STD_LOGIC;
		SDRAM_WRITE_ENABLE : out std_logic;
		SDRAM_ADDR : out STD_LOGIC_VECTOR(22 DOWNTO 0);
		SDRAM_DO : in STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- DMA memory map differs
		-- e.g. some special addresses to read behind hardware registers
		-- 0x0000-0xffff: Atari registers + 3 mirrors (bit 16/17)
		-- 23 downto 21:
		-- 001 : SRAM,512k
		-- 010|011 : ROM, 4MB
		-- 10xx : SDRAM, 8MB (If you have more, its unmapped for now... Can bank switch! Atari can't access this much anyway...)
		DMA_FETCH : in STD_LOGIC; -- we want to read/write
		DMA_READ_ENABLE : in std_logic;
		DMA_32BIT_WRITE_ENABLE : in std_logic;
		DMA_16BIT_WRITE_ENABLE : in std_logic;
		DMA_8BIT_WRITE_ENABLE : in std_logic;
		DMA_ADDR : in std_logic_vector(23 downto 0);
		DMA_WRITE_DATA : in std_logic_vector(31 downto 0);
		MEMORY_READY_DMA : out std_logic; -- op complete

		-- Special config params
   		RAM_SELECT : in std_logic_vector(2 downto 0); -- 64K,128K,320KB Compy, 320KB Rambo, 576K Compy, 576K Rambo, 1088K, 4MB
    		ROM_SELECT : in std_logic_vector(5 downto 0); -- 16KB ROM Bank - 0 is illegal (slot used for BASIC!)
		PAL :  in STD_LOGIC;
		HALT : in std_logic
		THROTTLE_COUNT_6502 : in std_logic_vector(5 downto 0); -- standard speed is cycle_length-1
end atari800core_simplesdram;

ARCHITECTURE vhdl OF atari800core_simplesdram IS 
-- PIA
SIGNAL	CA1_IN :  STD_LOGIC;
SIGNAL	CA2_IN:  STD_LOGIC;
SIGNAL	CA2_OUT :  STD_LOGIC;
SIGNAL	CA2_DIR_OUT:  STD_LOGIC;
SIGNAL	CB2_OUT :  STD_LOGIC;
SIGNAL	CB2_DIR_OUT:  STD_LOGIC;
SIGNAL	CA2_IN:  STD_LOGIC;
SIGNAL	CB2_IN:  STD_LOGIC;
SIGNAL	PORTA_IN :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	PORTB_IN :  STD_LOGIC_VECTOR(7 DOWNTO 0);

-- CARTRIDGE ACCESS
SIGNAL	CART_RD4 :  STD_LOGIC;
SIGNAL	CART_RD5 :  STD_LOGIC;

-- PBI
SIGNAL PBI_WRITE_DATA : std_logic_vector(31 downto 0);

-- INTERNAL ROM/RAM
SIGNAL	RAM_ADDR :  STD_LOGIC_VECTOR(18 DOWNTO 0);
SIGNAL	RAM_DO :  STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL	RAM_REQUEST :  STD_LOGIC;
SIGNAL	RAM_REQUEST_COMPLETE :  STD_LOGIC;
SIGNAL	RAM_WRITE_ENABLE :  STD_LOGIC;

SIGNAL	ROM_ADDR :  STD_LOGIC_VECTOR(21 DOWNTO 0);
SIGNAL	ROM_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	ROM_REQUEST :  STD_LOGIC;
SIGNAL	ROM_REQUEST_COMPLETE :  STD_LOGIC;

BEGIN

-- PIA mapping
CA1_IN <= '1';
CB1_IN <= '1';
CA2_IN <= CA2_OUT when CA2_DIR_OUT='1' else '1';
CB2_IN <= CB2_OUT when CB2_DIR_OUT='1' else '1';
SIO_COMMAND <= CB2_OUT;
PORTA_IN <= ((JOY1_n(3)&JOY1_n(2)&JOY1_n(1)&JOY1_n(0)&JOY2_n(3)&JOY2_n(2)&JOY2_n(1)&JOY2_n(0)) and not (porta_dir_out)) or (porta_dir_out and porta_out);
PORTB_IN <= PORTB_OUT;

-- Cartridge not inserted
CART_RD4 <= '0';
CART_RD5 <= '0';

-- Internal rom/ram
internalromram1 : entity work.internalromram
	GENERIC MAP
	(
		internal_rom => internal_rom,
		internal_ram => internal_ram,
	);
	PORT MAP (
 		clock   => CLK,
		reset_n => RESET_N,

		ROM_ADDR => ROM_ADDR,
		ROM_REQUEST_COMPLETE => ROM_ADDR_COMPLETE,
		ROM_REQUEST => ROM_REQUEST,
		ROM_DATA => ROM_DO,
		
		RAM_ADDR => RAM_ADDR,
		RAM_WR_ENABLE => RAM_WR_ENABLE,
		RAM_DATA_IN => PBI_WRITE_DATA(7 downto 0),
		RAM_REQUEST_COMPLETE => RAM_REQUEST_COMPLETE,
		RAM_REQUEST => RAM_REQUEST,
		RAM_DATA => RAM_DO
	);
END internalromram;

atari800xl : entity work.atari800core
	GENERIC MAP
	(
		cycle_length => cycle_length
	);
	PORT MAP
	(
		CLK => CLK,
		RESET_N => RESET_N

		VGA_VS => VGA_VS,
		VGA_HS => VGA_HS,
		VGA_B => VGA_B,
		VGA_G => VGA_G,
		VGA_R => VGA_R,

		AUDIO_L => AUDIO_L,
		AUDIO_R => AUDIO_R,

		CA1_IN => CA1_IN,
		CB1_IN => CB1_IN,
		CA2_IN => CA2_IN,
		CA2_OUT => CA2_OUT,
		CA2_DIR_OUT => CA2_DIR_OUT,
		CB2_IN => CB2_IN,
		CB2_OUT => CB2_OUT,
		CB2_DIR_OUT => CB2_DIR_OUT,
		PORTA_IN => PORTA_IN,
		PORTA_DIR_OUT => PORTA_DIR_OUT,
		PORTA_OUT => PORTA_OUT,
		PORTB_IN => PORTB_IN,
		PORTB_DIR_OUT => PORTB_DIR_OUT,
		PORTB_OUT => PORTB_OUT,

		KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
		KEYBOARD_SCAN => KEYBOARD_SCAN,

		-- PBI
		PBI_ADDR => open,
		PBI_WRITE_ENABLE => open,
		PBI_SNOOP_DATA => open,
		PBI_WRITE_DATA => PBI_WRITE_DATA,
		PBI_WIDTH_8bit_ACCESS => open,
		PBI_WIDTH_16bit_ACCESS => open,
		PBI_WIDTH_32bit_ACCESS => open,

		PBI_ROM_DO => "11111111",
		PBI_REQUEST => open,
		PBI_REQUEST_COMPLETE => '1',

		CART_RD4 => CART_RD4,
		CART_RD5 => CART_RD5,
		CART_S4_n => open,
		CART_S5_N => open,
		CART_CCTL_N => open,

		SIO_RXD => SIO_RXD,
		SIO_TXD => SIO_TXD,

		CONSOL_OPTION => CONSOL_OPTION,
		CONSOL_SELECT => CONSOL_SELECT,
		CONSOL_START=> CONSOL_START,

		SDRAM_REQUEST => SDRAM_REQUEST,
		SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
		SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
		SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
		SDRAM_ADDR => SDRAM_ADDR,
		SDRAM_DO => SDRAM_DO,

		SDRAM_REFRESH => open, -- TODO

		RAM_ADDR => RAM_ADDR,
		RAM_DO => RAM_DO,
		RAM_REQUEST => RAM_REQUEST,
		RAM_REQUEST_COMPLETE => RAM_REQUEST_COMPLETE,
		RAM_WRITE_ENABLE => RAM_WRITE_ENABLE,
		
		ROM_ADDR => ROM_ADDR,
		ROM_DO => ROM_DO,
		ROM_REQUEST => ROM_REQUEST,
		ROM_REQUEST_COMPLETE => ROM_REQUEST_COMPLETE,

		DMA_FETCH => DMA_FETCH,
		DMA_READ_ENABLE => DMA_READ_ENABLE,
		DMA_32BIT_WRITE_ENABLE => DMA_32BIT_WRITE_ENABLE,
		DMA_16BIT_WRITE_ENABLE => DMA_16BIT_WRITE_ENABLE,
		DMA_8BIT_WRITE_ENABLE => DMA_8BIT_WRITE_ENABLE,
		DMA_ADDR => DMA_ADDR,
		DMA_WRITE_DATA => DMA_WRITE_DATA,
		MEMORY_READY_DMA => MEMORY_READY_DMA,

   		RAM_SELECT => RAM_SELECT,
    		ROM_SELECT => ROM_SELECT,
		CART_EMULATION_SELECT => "0000000",
		CART_EMULATION_ACTIVATE => '0',
		PAL => PAL,
		USE_SDRAM => USE_SDRAM,
		ROM_IN_RAM => ROM_IN_RAM,
		THROTTLE_COUNT_6502 => THROTTLE_COUNT_6502,
		HALT => HALT 
	);

end vhdl;

