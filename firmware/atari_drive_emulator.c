#include "atari_drive_emulator.h"

#include "uart.h"
#include "pause.h"
#include "simplefile.h"

#include "printf.h"
#include "integer.h"

#define send_ACK()	USART_Transmit_Byte('A');
#define send_NACK()	USART_Transmit_Byte('N');
#define send_CMPL()	USART_Transmit_Byte('C');
#define send_ERR()	USART_Transmit_Byte('E');

/* BiboDos needs at least 50us delay before ACK */
#define DELAY_T2_MIN wait_us(100);

/* the QMEG OS needs at least 300usec delay between ACK and complete */
#define DELAY_T5_MIN wait_us(300);

/* QMEG OS 3 needs a delay of 150usec between complete and data */
#define DELAY_T3_PERIPH wait_us(150);

#define speedslow 0x28
#define speedfast 0x6
#define XEX_SECTOR_SIZE 128

#define MAX_DRIVES 4

struct SimpleFile * drives[MAX_DRIVES];

struct ATRHeader
{
	u16 wMagic;
	u16 wPars;
	u16 wSecSize;
	u08 btParsHigh;
	u32 dwCRC;
} __attribute__((packed));
struct ATRHeader atr_header;
int speed;

int badcommandcount;
int commandcount;
int opendrive;

unsigned char atari_sector_buffer[256];

unsigned char get_checksum(unsigned char* buffer, u16 len);

#define    TWOBYTESTOWORD(ptr,val)           (*((u08*)(ptr)) = val&0xff);(*(1+(u08*)(ptr)) = (val>>8)&0xff);

void processCommand();
void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned short len);
void clearAtariSectorBuffer()
{
	int i=256;
	while (--i)
		atari_sector_buffer[i] = 0;
}

int offset;
int xex_loader;
int xex_size;
uint8_t boot_xex_loader[179] = {
	0x72,0x02,0x5f,0x07,0xf8,0x07,0xa9,0x00,0x8d,0x04,0x03,0x8d,0x44,0x02,0xa9,0x07,
	0x8d,0x05,0x03,0xa9,0x70,0x8d,0x0a,0x03,0xa9,0x01,0x8d,0x0b,0x03,0x85,0x09,0x60,
	0x7d,0x8a,0x48,0x20,0x53,0xe4,0x88,0xd0,0xfa,0x68,0xaa,0x8c,0x8e,0x07,0xad,0x7d,
	0x07,0xee,0x8e,0x07,0x60,0xa9,0x93,0x8d,0xe2,0x02,0xa9,0x07,0x8d,0xe3,0x02,0xa2,
	0x02,0x20,0xda,0x07,0x95,0x43,0x20,0xda,0x07,0x95,0x44,0x35,0x43,0xc9,0xff,0xf0,
	0xf0,0xca,0xca,0x10,0xec,0x30,0x06,0xe6,0x45,0xd0,0x02,0xe6,0x46,0x20,0xda,0x07,
	0xa2,0x01,0x81,0x44,0xb5,0x45,0xd5,0x43,0xd0,0xed,0xca,0x10,0xf7,0x20,0xd2,0x07,
	0x4c,0x94,0x07,0xa9,0x03,0x8d,0x0f,0xd2,0x6c,0xe2,0x02,0xad,0x8e,0x07,0xcd,0x7f,
	0x07,0xd0,0xab,0xee,0x0a,0x03,0xd0,0x03,0xee,0x0b,0x03,0xad,0x7d,0x07,0x0d,0x7e,
	0x07,0xd0,0x8e,0x20,0xd2,0x07,0x6c,0xe0,0x02,0x20,0xda,0x07,0x8d,0xe0,0x02,0x20,
	0xda,0x07,0x8d,0xe1,0x02,0x2d,0xe0,0x02,0xc9,0xff,0xf0,0xed,0xa9,0x00,0x8d,0x8e,
	0x07,0xf0,0x82 };
//  relokacni tabulka neni potreba, meni se vsechny hodnoty 0x07
//  (melo by byt PRESNE 20 vyskytu! pokud je jich vic, pak bacha!!!)

void byteswap(WORD * inw)
{
#ifndef LITTLE_ENDIAN
	unsigned char * in = (unsigned char *)inw;
	unsigned char temp = in[0];
	in[0] = in[1];
	in[1] = temp;
#endif
}

struct command
{
	u08 deviceId;
	u08 command;
	u08 aux1;
	u08 aux2;
	u08 chksum;
} __attribute__((packed));
void getCommand(struct command * cmd)
{
	int expchk;

	//printf("Waiting for command\n");
	//USART_Data_Ready();
	while (0 == USART_Command_Line());
	//printf("Init:");
	//printf("%d",*zpu_sio);
	USART_Init(speed+6);
	//printf("%d",speed);
	//printf("\n");
	while (1 == USART_Command_Line())
	{
		actions();
	}
	cmd->deviceId = USART_Receive_Byte();
	cmd->command = USART_Receive_Byte();
	cmd->aux1 = USART_Receive_Byte();
	cmd->aux2 = USART_Receive_Byte();
	cmd->chksum = USART_Receive_Byte();
	while (0 == USART_Command_Line())
	{
		actions();
	}
	printf("cmd:");
	//printf("Gone high\n");
	atari_sector_buffer[0] = cmd->deviceId;
	atari_sector_buffer[1] = cmd->command;
	atari_sector_buffer[2] = cmd->aux1;
	atari_sector_buffer[3] = cmd->aux2;
	expchk = get_checksum(&atari_sector_buffer[0],4);

	//printf("Device id:");
	printf("%d",cmd->deviceId);
	//printf("\n");
	//printf("command:");
	printf("%d",cmd->command);
	//printf("\n");
	//printf("aux1:");
	printf("%d",cmd->aux1);
	//printf("\n");
	//printf("aux2:");
	printf("%d",cmd->aux2);
	//printf("\n");
	//printf("chksum:");
	printf("%d",cmd->chksum);
	printf("%d",expchk);

	if (expchk!=cmd->chksum || USART_Framing_Error())
	{
		printf("ERR ");
		//wait_us(1000000);
		if (speed == speedslow)
		{
			speed = speedfast;
			printf("SPDF");
			printf("%d",speed);
		}
		else
		{
			speed = speedslow;
			printf("SPDS");
			printf("%d",speed);
		}
	}
	printf("\n");

	DELAY_T2_MIN;
}

int compare_ext(char const * filename, char const * ext)
{
	int dot = 0;

	while (1)
	{
		if (filename[dot] == '\0')
			break;
		if (filename[dot] != '.')
		{
			++dot;
			continue;
		}
		if (filename[dot+1] == ext[0])
			if (filename[dot+2] == ext[1])
				if (filename[dot+3] == ext[2])
				{
					return 1;
					break;
				}
		break;
	}

	return 0;
}

// Called whenever file changed
void set_drive_status(int driveNumber, struct SimpleFile * file)
{
	int read = 0;
	int xfd = 0;

	drives[driveNumber] = 0;

	if (!file) return;

	// Read header
	read = 0;
	file_seek(file,0);
	file_read(file,(unsigned char *)&atr_header, 16, &read);
	if (read!=16)
	{
		printf("Could not read header\n");
		return; //while(1);
	}
	byteswap(&atr_header.wMagic);
	byteswap(&atr_header.wPars);
	byteswap(&atr_header.wSecSize);
	/*printf("\nHeader:");
	printf("%d",atr_header.wMagic);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.wPars);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.wSecSize);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.btParsHigh);
	plotnext(toatarichar(' '));
	printf("%d",atr_header.dwCRC);
	printf("\n");
	*/

	xex_loader = 0;
	xfd = compare_ext(file_name(file),"XFD") || compare_ext(file_name(file),"xfd");

	if (xfd == 1)
	{
		printf("XFD ");
		// build a fake atr header
		offset = 0;
		atr_header.wMagic = 0x296;
		atr_header.wPars = file_size(file)/16;
		atr_header.wSecSize = 0x80;
	}
	else if (atr_header.wMagic == 0xFFFF) // XEX
	{
		int i;
		printf("XEX ");
		offset = -256;
		xex_loader = 1;
		atr_header.wMagic = 0xffff;
		xex_size = file_size(file);
		atr_header.wPars = xex_size/16;
		atr_header.wSecSize = XEX_SECTOR_SIZE;
	}
	else if (atr_header.wMagic == 0x296) // ATR
	{
		printf("ATR ");
		offset = 16;
	}
	else
	{
		printf("Unknown file type");
		return;
	}

	if (atr_header.wSecSize == 0x80)
	{
		if (atr_header.wPars>(720*128/16))
			printf("MD ");
		else
			printf("SD ");
	}
	else if (atr_header.wSecSize == 0x100)
	{
		printf("DD ");
	}
	else if (atr_header.wSecSize < 0x100)
	{
		printf("XD ");
	}
	else
	{
		printf("BAD sector size");
		return;
	}	
	printf("%d",atr_header.wPars);
	printf("0\n");

	drives[driveNumber] = file;
}

void init_drive_emulator()
{
	int i;

	commandcount = 0;
	badcommandcount = 0;
	opendrive = -1;
	speed = speedslow;
	USART_Init(speed+6);
	for (i=0; i!=MAX_DRIVES; ++i)
	{
		drives[i] = 0;
	}
}

void run_drive_emulator()
{
	while (1)
	{
		processCommand();
		actions();
	}
}

/////////////////////////

void processCommand()
{
	struct command command;

	getCommand(&command);

	++commandcount;
	/*FIXME if (commandcount==4 && (4==(4&(*zpu_switches))))
	{
		printf("Paused\n");
		pause_6502(1);
		while(1);
	}*/
	/*if (badcommandcount==8)
	{
		printf("Stuck?\n");
		pause_6502(1);
		while(1);
	}*/

	if (command.deviceId >= 0x31 && command.deviceId < 0x34)
	{
		int sent = 0;
		int drive = 0;
		struct SimpleFile * file = 0;

		drive = command.deviceId&0xf -1;
		printf("Drive:");
		printf("%d",drive);
		if (drive!=opendrive)
		{
			if (drive<MAX_DRIVES)
			{
				opendrive = drive;
			}
		}

		if (drive<0 || !drives[drive])
		{
			//USART_Transmit_Mode();
			//send_NACK();
			//USART_Wait_Transmit_Complete();
			//wait_us(100); // Wait for transmission to complete - Pokey bug, gets stuck active...
			//USART_Receive_Mode();

			printf("Drive not present");
			return;
		}

		file = drives[opendrive];

		switch (command.command)
		{
		case 0x3f:
			{
			printf("Speed:");
			int sector = ((int)command.aux1) + (((int)command.aux2&0x7f)<<8);
			USART_Transmit_Mode();
			send_ACK();
			clearAtariSectorBuffer();
			atari_sector_buffer[0] = speedfast;
			hexdump_pure(atari_sector_buffer,1);
			USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(1);
			sent = 1;
	if (sector == 0)
	{
		speed = speedfast;
		printf("SPDF");
		printf("%d",speed);
	}
	else
	{
		speed = speedslow;
		printf("SPDS");
		printf("%d",speed);
	}
			}
		case 0x53:
			{
			unsigned char status;
			printf("Stat:");
			USART_Transmit_Mode();
			send_ACK();
			clearAtariSectorBuffer();

			status = 0x10; // Motor on;
			status |= 0x08; // write protected; // no write support yet...
			if (atr_header.wSecSize == 0x80) // normal sector size
			{
				if (atr_header.wPars>(720*128/16))
				{
					status |= 0x80; // medium density - or a strange one...
				}
			}
			else
			{
				status |= 0x20; // 256 byte sectors
			}
			atari_sector_buffer[0] = status;
			atari_sector_buffer[1] = 0xff;
			atari_sector_buffer[2] = 0xe0;
			atari_sector_buffer[3] = 0x0;
			hexdump_pure(atari_sector_buffer,4); // Somehow with this...
			USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(4);
			sent = 1;
			printf("%d",atari_sector_buffer[0]); // and this... The wrong checksum is sent!!
			printf(":done\n");
			}
			break;
		case 0x50: // write
		case 0x57: // write with verify
		default:
			// TODO
			//USART_Transmit_Mode();
			//send_NACK();
			//USART_Wait_Transmit_Complete();
			//USART_Receive_Mode();
			break;
		case 0x52: // read
			{
			int sector = ((int)command.aux1) + (((int)command.aux2&0x7f)<<8);
			int sectorSize = 0;
			int read = 0;
			int location =0;

			USART_Transmit_Mode();
			send_ACK();
			printf("Sector:");
			printf("%d",sector);
			printf(":");
			if(xex_loader)         //n_sector>0 && //==0 se overuje hned na zacatku
			{
				//sektory xex bootloaderu, tj. 1 nebo 2
				u08 i,b;
				u08 *spt, *dpt;
				int file_sectors;

				//file_sectors se pouzije pro sektory $168 i $169 (optimalizace)
				//zarovnano nahoru, tj. =(size+124)/125
				file_sectors = ((xex_size+(u32)(XEX_SECTOR_SIZE-3-1))/((u32)XEX_SECTOR_SIZE-3));

				printf("XEX ");

				if (sector<=2)
				{
					printf("boot ");

					spt= &boot_xex_loader[(u16)(sector-1)*((u16)XEX_SECTOR_SIZE)];
					dpt= atari_sector_buffer;
					i=XEX_SECTOR_SIZE;
					do
					{
						b=*spt++;
						//relokace bootloaderu z $0700 na jine misto
						//TODO if (b==0x07) b+=bootloader_relocation;
						*dpt++=b;
						i--;
					} while(i);
				}
				else
				if(sector==0x168)
				{
					printf("numtobuffer ");
					//vrati pocet sektoru diskety
					//byty 1,2
					goto set_number_of_sectors_to_buffer_1_2;
				}
				else
				if(sector==0x169)
				{
					printf("name ");
					//fatGetDirEntry(FileInfo.vDisk.file_index,5,0);
					//fatGetDirEntry(FileInfo.vDisk.file_index,0); //ale musi to posunout o 5 bajtu doprava
		
					{
						u08 i,j;
						for(i=j=0;i<8+3;i++)
						{
							/*if( ((xex_name[i]>='A' && xex_name[i]<='Z') ||
								(xex_name[i]>='0' && xex_name[i]<='9')) )
							{
							  //znak je pouzitelny na Atari
							  atari_sector_buffer[j]=xex_name[i];
							  j++;
							}*/
							if ( (i==7) || (i==8+2) )
							{
								for(;j<=i;j++) atari_sector_buffer[j]=' ';
							}
						}
						//posune nazev z 0-10 na 5-15 (0-4 budou systemova adresarova data)
						//musi pozpatku
						for(i=15;i>=5;i--) atari_sector_buffer[i]=atari_sector_buffer[i-5];
						//a pak uklidi cely zbytek tohoto sektoru
						for(i=5+8+3;i<XEX_SECTOR_SIZE;i++)
							atari_sector_buffer[i]=0x00;
					}

					//teprve ted muze pridat prvnich 5 bytu na zacatek nulte adresarove polozky (pred nazev)
					//atari_sector_buffer[0]=0x42;							//0
					//jestlize soubor zasahuje do sektoru cislo 1024 a vic,
					//status souboru je $46 misto standardniho $42
					atari_sector_buffer[0]=(file_sectors>(0x400-0x171))? 0x46 : 0x42; //0

					TWOBYTESTOWORD(atari_sector_buffer+3,0x0171);			//3,4
set_number_of_sectors_to_buffer_1_2:
					TWOBYTESTOWORD(atari_sector_buffer+1,file_sectors);		//1,2
				}
				else
				if(sector>=0x171)
				{
					printf("data ");
					file_seek(file,((u32)sector-0x171)*((u32)XEX_SECTOR_SIZE-3));
					file_read(file,&atari_sector_buffer[0], XEX_SECTOR_SIZE-3, &read);

					if(read<(XEX_SECTOR_SIZE-3))
						sector=0; //je to posledni sektor
					else
						sector++; //ukazatel na dalsi

					atari_sector_buffer[XEX_SECTOR_SIZE-3]=((sector)>>8); //nejdriv HB !!!
					atari_sector_buffer[XEX_SECTOR_SIZE-2]=((sector)&0xff); //pak DB!!! (je to HB,DB)
					atari_sector_buffer[XEX_SECTOR_SIZE-1]=read;
				}
				printf(" sending\n");

				sectorSize = XEX_SECTOR_SIZE;
			}
			else
			{
				location = offset;
				if (sector>3)
				{
					sector-=4;
					location += 128*3;
					location += sector*atr_header.wSecSize;
					sectorSize = atr_header.wSecSize;
				}
				else
				{
					location += 128*(sector-1);
					sectorSize = 128;
				}
				printf("%d",location);
				printf("\n");
				file_seek(file,location);
				file_read(file,&atari_sector_buffer[0], sectorSize, &read);
			}

			//topofscreen();
			//hexdump_pure(atari_sector_buffer,sectorSize);
			//printf("Sending\n");
			USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(sectorSize);
			sent = 1;

			//pause_6502(1);
			//hexdump_pure(0x10000+0x400,128);
			unsigned char chksumreceive = 0; //get_checksum(0x10000+0x400, sectorSize);
			printf(" receive:");
			printf("%d",chksumreceive);
			printf("\n");
			//pause_6502(1);
			//while(1);
			}
			
			break;
		}

		//wait_us(100); // Wait for transmission to complete - Pokey bug, gets stuck active...

		if (sent)
			USART_Wait_Transmit_Complete();
		USART_Receive_Mode();
	}
	else
	{
		++badcommandcount;
	}
}
	
unsigned char get_checksum(unsigned char* buffer, u16 len)
{
	u16 i;
	u08 sumo,sum;
	sum=sumo=0;
	for(i=0;i<len;i++)
	{
		sum+=buffer[i];
		if(sum<sumo) sum++;
		sumo = sum;
	}
	return sum;
}

void USART_Send_Buffer(unsigned char *buff, u16 len)
{
	while(len>0) { USART_Transmit_Byte(*buff++); len--; }
}

void USART_Send_cmpl_and_atari_sector_buffer_and_check_sum(unsigned short len)
{
	u08 check_sum;
	printf("(send:");
	printf("%d",len);

	DELAY_T5_MIN;
	send_CMPL();

	// Hias: changed to 100us so that Qmeg3 works again with the
	// new bit-banging transmission code
	DELAY_T3_PERIPH;

	check_sum = 0;
	USART_Send_Buffer(atari_sector_buffer,len);
	// tx_checksum is updated by bit-banging USART_Transmit_Byte,
	// so we can skip separate calculation
	check_sum = get_checksum(atari_sector_buffer,len);
	USART_Transmit_Byte(check_sum);
	//hexdump_pure(atari_sector_buffer,len);
	printf(":chk:");
	printf("%d",check_sum);
	printf(")");
}
