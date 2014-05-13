#include "integer.h"
#include "regs.h"
#include "pause.h"
#include "printf.h"
#include "joystick.h"

#include "simpledir.h"
#include "simplefile.h"
#include "fileselector.h"

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

BIT_REG_RO(,0x1,4,hotkey_softboot,zpu_in1)
BIT_REG_RO(,0x1,5,hotkey_coldboot,zpu_in1)
BIT_REG_RO(,0x1,6,hotkey_fileselect,zpu_in1)
BIT_REG_RO(,0x1,7,hotkey_settings,zpu_in1)

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
int debug_adjust;
unsigned char volatile * baseaddr;

void clearscreen()
{
	unsigned volatile char * screen;
	for (screen=(unsigned volatile char *)40000+atari_regbase; screen!=(unsigned volatile char *)(atari_regbase+40000+1024); ++screen)
		*screen = 0x00;
}

void char_out ( void* p, char c)
{
	unsigned char val = toatarichar(c);
	if (debug_pos>=0)
	{
		*(baseaddr+debug_pos) = val|debug_adjust;
		++debug_pos;
	}
}

// Memory usage...
// 0x410000-0x41FFFF (0xc10000 in zpu space) = directory cache - 64k
// 0x420000-0x43FFFF (0xc20000 in zpu space) = freeze backup

struct SimpleFile * files[4];

int main(void)
{
	int i;
	for (i=0; i!=4; ++i)
	{
		files[i] = (struct SimpleFile *)alloca(file_struct_size());
	}

	freeze_init((void*)0xc20000); // 128k

	debug_pos = -1;
	debug_adjust = 0;
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

char const * get_ram()
{
	switch(get_ram_select())
	{
	case 0:
		return "64K";
	case 1:
		return "128";
	case 2:
		return "320K(Compy)";
	case 3:
		return "320K(Rambo)";
	case 4:
		return "576K(Compy)";
	case 5:
		return "576K(Rambo)";
	case 6:
		return "1MB";
	case 7:
		return "4MB";
	}
}

void settings()
{
	struct joystick_status joy;
	joy.x_ = joy.y_ = joy.fire_ = 0;

	int row = 0;

	for (;;)
	{
		// Render
		clearscreen();
		debug_pos = 20;
		debug_adjust = 0;
		printf("Settings");
		debug_pos = 80;
		debug_adjust = row==0 ? 128 : 0;
		printf("Turbo:%dx", get_turbo_6502());
		debug_pos = 120;
		debug_adjust = row==1 ? 128 : 0;
		printf("Ram:%s", get_ram());
		debug_pos = 160;
		debug_adjust = row==2 ? 128 : 0;
		printf("Rom bank:%d", get_rom_select());

		// Slow it down a bit
		wait_us(100000);

		// move
		joystick_wait(&joy,WAIT_QUIET);
		joystick_wait(&joy,WAIT_EITHER);

		if (joy.fire_) break;
		row+=joy.y_;
		if (row<0) row = 0;
		if (row>2) row = 2;
		switch (row)
		{
		case 0:
			{
				int turbo = get_turbo_6502();
				if (joy.x_==1) turbo<<=1;
				if (joy.x_==-1) turbo>>=1;
				if (turbo>16) turbo = 16;
				if (turbo<1) turbo = 1;
				set_turbo_6502(turbo);
			}
			break;
		case 1:
			{
				int ram_select = get_ram_select();
				ram_select+=joy.x_;
				if (ram_select<0) ram_select = 0;
				if (ram_select>7) ram_select = 7;
				set_ram_select(ram_select);
			}
			break;
		case 2:
			{
				int rom_select = get_rom_select();
				rom_select+=joy.x_;
				if (rom_select<0) rom_select = 0;
				if (rom_select>7) rom_select = 7; // TODO
				set_rom_select(rom_select);
			}
			break;
		}
	}
}

void actions()
{
	// Show some activity!
	//*atari_colbk = *atari_random;
	
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
		settings();
		debug_pos = -1;
		restore();
		set_pause_6502(0);
	}
	else if (get_hotkey_fileselect())
	{
		set_pause_6502(1);
		freeze();
		file_selector(files[0]);
		debug_pos = -1;
		restore();
		set_drive_status(0,files[0]);
		reboot(1);
	}
}


