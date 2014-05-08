#include "integer.h"
#include "regs.h"
#include "pause.h"
#include "printf.h"

#include "simpledir.h"
#include "simplefile.h"

#include "atari_drive_emulator.h"

// FUNCTIONS in here
// i) pff init - NOT USED EVERYWHERE
// ii) file selector - kind of crap, no fine scrolling - NOT USED EVERYWHERE
// iii) cold reset atari (clears base ram...)
// iv) start atari (begins paused)
// v) freeze/resume atari - NOT USED EVERYWHERE!
// vi) menu for various options - NOT USED EVERYWHERE!
// vii) pause - TODO - base this on pokey clock...

// standard ZPU IN/OUT use...
// OUT1 - 6502 settings (pause,reset,speed)
// pause_n: bit 0 
// reset_n: bit 1
// turbo: bit 2-4: meaning... 0=1.79Mhz,1=3.58MHz,2=7.16MHz,3=14.32MHz,4=28.64MHz,5=57.28MHz,etc.
// ram_select: bit 5-7: 
//   		RAM_SELECT : in std_logic_vector(2 downto 0); -- 64K,128K,320KB Compy, 320KB Rambo, 576K Compy, 576K Rambo, 1088K, 4MB
// rom_select: bit 8-13:
//    		ROM_SELECT : in std_logic_vector(5 downto 0); -- 16KB ROM Bank

#define BIT_REG(op,mask,shift,name,reg) \
int get_ ## name() \
{ \
	int val = *reg; \
	return op((val>>shift)&mask); \
} \
void set_ ## name(int param) \
{ \
	int val = *reg; \
	 \
	val = (val&~(mask<<shift)); \
	val |= op(param)<<shift; \
	 \
	*reg = val; \
}

#define BIT_REG_RO(op,mask,shift,name,reg) \
int get_ ## name() \
{ \
	int val = *reg; \
	return op((val>>shift)&mask); \
}

BIT_REG(,0x1,0,pause_6502,zpu_out1)
BIT_REG(,0x1,1,reset_6502,zpu_out1)
BIT_REG(,0x3f,2,turbo_6502,zpu_out1)
BIT_REG(,0x7,8,ram_select,zpu_out1)
BIT_REG(,0x3f,11,rom_select,zpu_out1)

BIT_REG_RO(,0x1,0,hotkey_softboot,zpu_in1)
BIT_REG_RO(,0x1,1,hotkey_coldboot,zpu_in1)
BIT_REG_RO(,0x1,2,hotkey_fileselect,zpu_in1)
BIT_REG_RO(,0x1,3,hotkey_settings,zpu_in1)

void
wait_us(int unsigned num)
{
	// pause counter runs at pokey frequency - should be 1.79MHz
	int unsigned cycles = (num*230)>>7;
	*zpu_pause = cycles;
}

void memset8(void * address, int value, int length)
{
	char * mem = address;
	while (length--)
		*mem++=value;
}

void memset32(void * address, int value, int length)
{
	int * mem = address;
	while (length--)
		*mem++=value;
}

void clear_64k_ram()
{
	memset8((void *)0x200000, 0, 65536); // SRAM, if present (TODO)
	memset32((void *)0x800000, 0, 16384);
}

void
reboot(int cold)
{
	set_reset_6502(1);
	if (cold)
	{
		clear_64k_ram();
	}
	set_reset_6502(0);
	set_pause_6502(0);
}

unsigned char toatarichar(int val)
{
	int inv = val>=128;
	if (inv)
	{
		val-=128;
	}
	if (val>='A' && val<='Z')
	{
		val+=-'A'+33;
	}
	else if (val>='a' && val<='z')
	{
		val+=-'a'+33+64;
	}
	else if (val>='0' && val<='9')
	{
		val+=-'0'+16;	
	}
	else if (val>=32 && val<=47)
	{
		val+=-32;
	}
	else
	{
		val = 0;
	}
	if (inv)
	{
		val+=128;
	}
	return val;
}

int debug_pos;
unsigned char volatile * baseaddr;

void char_out ( void* p, char c)
{
	unsigned char val = toatarichar(c);
	if (debug_pos>0)
	{
		*(baseaddr+debug_pos) = val;
		++debug_pos;
	}
}

// Memory usage...
// 0x410000-0x41FFFF (0xc10000 in zpu space) = directory cache - 64k
// 0x420000-0x43FFFF (0xc20000 in zpu space) = freeze backup

int main(void)
{
	freeze_init((void*)0xc20000); // 128k

	debug_pos = -1;
	baseaddr = (unsigned char volatile *)(40000 + atari_regbase);
	set_reset_6502(1);
	set_turbo_6502(1);

	init_printf(0, char_out);

	// TODO...

	printf("Hello World\n I am an Atari!\n");

	if (SimpleFile_OK == dir_init((void *)0xc10000, 65536))
	{
		printf("DIR init ok\n");
		init_drive_emulator();
		reboot(1);
		run_drive_emulator();
	}
	else
	{
		printf("DIR init failed\n");
	}
	reboot(1);
	for (;;) actions();
}

//		struct SimpleFile * file = alloca(file_struct_size());
//		printf("Opening file\n");
//		if (SimpleFile_OK == file_open_name("GUNPOWDR.ATR",file))
//		{
//			printf("FILE open ok\n");
//
//			set_drive_status(0,file);
//
//		}
//		else
//		{
//			printf("FILE open failed\n");
//		}

void actions()
{
	// Show some activity!
	*atari_colbk = *atari_random;
	
	// Hot keys
	if (get_hotkey_softboot())
	{
		reboot(0);	
	}
	else if (get_hotkey_coldboot())
	{
		reboot(1);	
	}
	else if (get_hotkey_settings())
	{
		set_pause_6502(1);
		freeze();
		debug_pos = 0;	
		printf("Hello world - settings");
		debug_pos = -1;
		wait_us(1000000);
		restore();
		set_pause_6502(0);
	}
	else if (get_hotkey_fileselect())
	{
		set_pause_6502(1);
		freeze();
		debug_pos = 0;	
		printf("Hello world - fileselect");
		debug_pos = -1;
		wait_us(1000000);
		restore();
		set_pause_6502(0);
	}
}


