#include "simpledir.h"
#include "simplefile.h"

#include "atari_drive_emulator.h"

#include "stdio.h"
#include "stdlib.h"

#include <sys/time.h>

extern char native_command;
extern char receive_buffer[];
extern int receive_buffer_pos;
extern int receive_buffer_last;

double start_time;
double now()
{
	struct timeval tv;
	gettimeofday(&tv,0);

	return ((double)tv.tv_sec + (double)tv.tv_usec/1e6);
}

void char_out ( void* p, char c)
{
	putc(c, stderr);
}

int main(void)
{
	init_printf(NULL, char_out);

	struct SimpleDirEntry * entry;
	char * mem = (char *)malloc(8192);
	if (SimpleFile_OK != dir_init(mem, 8192))
	{
		fprintf(stderr,"Failed to open dir!");
		return -1;
	}
	entry = dir_entries("");
	entry = dir_next(dir_next(dir_next(entry)));
	fprintf(stderr, " Name:%s", dir_filename(entry));
	struct SimpleFile * file = alloca(file_struct_size());
	//file_open_dir(entry,file);
	file_open_name("GUNPOWDR.ATR",file);

	int read = 0;
	char buffer[1024];
	//file_seek(file,100);
	file_read(file,&buffer[0],1024,&read);
	int i;
	for (i=0; i!=read; ++i)
	{
		fprintf(stderr,"|%02x", (unsigned char)buffer[i]);
		//fprintf(stderr,"%c", buffer[i]);
	}

	fprintf(stderr,"\n");

	native_command = 1;

	init_drive_emulator();

	set_drive_status(0,file);

	start_time = now();
	run_drive_emulator();

	return 0;
}

void actions()
{
	// USART_TransmitByte();
	// native_command

	double when = now();
	if ((when-start_time) > 1.0 && (when-start_time)<1.1)
	{
		native_command = 0;

		static int once = 0;
		if (!once)
		{
			once = 1;

			receive_buffer[receive_buffer_last++] = 0x31;
			//receive_buffer[receive_buffer_last++] = 0x32;
			receive_buffer[receive_buffer_last++] = 0x52;
			receive_buffer[receive_buffer_last++] = 0x01;
			receive_buffer[receive_buffer_last++] = 0x00;
			receive_buffer[receive_buffer_last++] = 0x84;
			//receive_buffer[receive_buffer_last++] = 0x85;
		}
		else
		{
			native_command = 1;
		}
	}
	else
	{
		native_command = 1;
	}
}

void
wait_us(int unsigned num)
{
	usleep(num);
}

