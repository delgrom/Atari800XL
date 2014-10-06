#include <stdint.h>
#include <string.h>
#include "regs.h"
#include "memory.h"
#include "linux_memory.h"

void* SRAM_BASE;
void* SDRAM_BASE;
void* atari_regbase;
void* atari_regmirror;
void* config_regbase;
void* CARTRIDGE_MEM;

#define SRAM_SIZE (512*1024)
#define SDRAM_SIZE (8*1024*1024)
#define ATARI_SIZE (64*1024)
#define CONFIG_SIZE (256)
#define CARTRIDGE_SIZE (2*1024*1024)

uint8_t sram_memory[SRAM_SIZE];
uint32_t sdram_memory[SDRAM_SIZE / 4];
uint8_t atari_memory[ATARI_SIZE];
uint8_t atari_mirror_memory[ATARI_SIZE];
uint32_t config_memory[CONFIG_SIZE/4];
uint32_t cartridge_memory[CARTRIDGE_SIZE / 4];

void init_memory(void)
{
	memset(sram_memory, SRAM_SIZE, 0);
	memset(sdram_memory, SDRAM_SIZE, 0);
	memset(atari_memory, ATARI_SIZE, 0);
	memset(atari_mirror_memory, ATARI_SIZE, 0);
	memset(config_memory, CONFIG_SIZE, 0);
	memset(cartridge_memory, CARTRIDGE_SIZE, 0);

	SRAM_BASE = sram_memory;
	SDRAM_BASE = sdram_memory;
	atari_regbase = atari_memory;
	atari_regmirror = atari_mirror_memory;
	config_regbase = config_memory;
	CARTRIDGE_MEM = cartridge_memory;

	// command line is high
	*zpu_sio = 1;
	// no trigger pressed
	*atari_trig0 = 1;
}

