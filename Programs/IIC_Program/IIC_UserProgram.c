#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>

/*********************************************************************************************
**	RS232 port addresses
*********************************************************************************************/

#define RS232_Control *(volatile unsigned char *)(0x00400040)
#define RS232_Status *(volatile unsigned char *)(0x00400040)
#define RS232_TxData *(volatile unsigned char *)(0x00400042)
#define RS232_RxData *(volatile unsigned char *)(0x00400042)
#define RS232_Baud *(volatile unsigned char *)(0x00400044)

/*********************************************************************************************
**  Subroutine to initialise the RS232 Port by writing some commands to the internal registers
*********************************************************************************************/
void Init_RS232(void)
{
	RS232_Control = 0x15; //  %00010101 set up 6850 uses divide by 16 clock, set RTS low, 8 bits no parity, 1 stop bit, transmitter interrupt disabled
	RS232_Baud = 0x1;	  // program baud rate generator 001 = 115k, 010 = 57.6k, 011 = 38.4k, 100 = 19.2, all others = 9600
}

/*********************************************************************************************************
**  Subroutine to provide a low level output function to 6850 ACIA
**  This routine provides the basic functionality to output a single character to the serial Port
**  to allow the board to communicate with HyperTerminal Program
**
**  NOTE you do not call this function directly, instead you call the normal putchar() function
**  which in turn calls _putch() below). Other functions like puts(), printf() call putchar() so will
**  call _putch() also
*********************************************************************************************************/

int _putch(int c)
{
	while ((RS232_Status & (char)(0x02)) != (char)(0x02)) // wait for Tx bit in status register or 6850 serial comms chip to be '1'
		;

	RS232_TxData = (c & (char)(0x7f)); // write to the data register to output the character (mask off bit 8 to keep it 7 bit ASCII)
	return c;						   // putchar() expects the character to be returned
}

/*********************************************************************************************************
**  Subroutine to provide a low level input function to 6850 ACIA
**  This routine provides the basic functionality to input a single character from the serial Port
**  to allow the board to communicate with HyperTerminal Program Keyboard (your PC)
**
**  NOTE you do not call this function directly, instead you call the normal getchar() function
**  which in turn calls _getch() below). Other functions like gets(), scanf() call getchar() so will
**  call _getch() also
*********************************************************************************************************/
int _getch(void)
{
	char c;
	while ((RS232_Status & (char)(0x01)) != (char)(0x01)) // wait for Rx bit in 6850 serial comms chip status register to be '1'
		;

	return (RS232_RxData & (char)(0x7f)); // read received character, mask off top bit and return as 7 bit ASCII character
}

// converts hex char to 4 bit binary equiv in range 0000-1111 (0-F)
// char assumed to be a valid hex char 0-9, a-f, A-F

char xtod(int c)
{
	if ((char)(c) <= (char)('9'))
		return c - (char)(0x30);	  // 0 - 9 = 0x30 - 0x39 so convert to number by sutracting 0x30
	else if ((char)(c) > (char)('F')) // assume lower case
		return c - (char)(0x57);	  // a-f = 0x61-66 so needs to be converted to 0x0A - 0x0F so subtract 0x57
	else
		return c - (char)(0x37); // A-F = 0x41-46 so needs to be converted to 0x0A - 0x0F so subtract 0x37
}

int Get2HexDigits(char *CheckSumPtr)
{
	register int i = (xtod(_getch()) << 4) | (xtod(_getch()));

	if (CheckSumPtr)
		*CheckSumPtr += i;

	return i;
}

int Get4HexDigits(char *CheckSumPtr)
{
	return (Get2HexDigits(CheckSumPtr) << 8) | (Get2HexDigits(CheckSumPtr));
}

int Get6HexDigits(char *CheckSumPtr)
{
	return (Get4HexDigits(CheckSumPtr) << 8) | (Get2HexDigits(CheckSumPtr));
}

int Get8HexDigits(char *CheckSumPtr)
{
	return (Get4HexDigits(CheckSumPtr) << 16) | (Get4HexDigits(CheckSumPtr));
}

/*************************************************************
** PCF 8591 chip (ADC/DAC converter)
**************************************************************/
/* The PCF 8591 chip actually has pins labelled A0, A1 and A2 that would in theory allows up to 8 of these devices
to exist in a system, but only A0 is brought out for configuration.
The A1 and A2 pins of the PCF 8591 chip have been wired to logic '0' on the PCB, so only
two of these modules could hang off the same IIC controller, one with A0=0, the other
with A0 = 1.
On my breadboard, the A0 pin of the PCF 8591 chip has been connected to logic 0 (GND). */
#define CONVERTER_ADDR (unsigned char)0x90 // table 5. The control byte for AD channel 1 is 8'b1001_0000 = 0x90
// commands
#define CONVERTER_WRITE (unsigned char)0x00 // write is active low
#define CONVERTER_READ (unsigned char)0x01	// read is active high

/*If the auto-increment mode is desired in applications where the internal oscillator is used,
the analog output enable flag must be set in the control byte (bit 6). This allows the
internal oscillator to run continuously, by this means preventing conversion errors
resulting from oscillator start-up delay. (data sheet)*/
// set bit 6 of the control byte to enable analog output
#define DAC (unsigned char)0x40 // 8'b0100_0000

// The following info is from handout Page 6

#define ADC_CHAN_1 (unsigned char)0x01
#define ADC_CHAN_2 (unsigned char)0x02
#define ADC_CHAN_3 (unsigned char)0x03
/*************************************************************
** IIC Controller registers
**************************************************************/
/*
Name	   Address  Width  Access			Description								Register Addr in 68k System
PRERlo		0x00	  8      RW       Clock Prescale register lo - byte					0x408000
PRERhi		0x01      8      RW       Clock Prescale register hi - byte					0x408002
CTR			0x02      8      RW       Control register									0x408004
TXR			0x03      8       W       Transmit register									0x408006
RXR			0x03      8       R       Receive register									0x408006
CR			0x04      8       W       Command register									0x408008
SR			0x04      8       R       Status register									0x408008
*/
#define IIC_PRERlo (*(volatile unsigned char *)(0x408000))
#define IIC_PRERhi (*(volatile unsigned char *)(0x408002))
#define IIC_CTR (*(volatile unsigned char *)(0x408004))
#define IIC_TXR (*(volatile unsigned char *)(0x408006))
#define IIC_RXR (*(volatile unsigned char *)(0x408006))
#define IIC_CR (*(volatile unsigned char *)(0x408008))
#define IIC_SR (*(volatile unsigned char *)(0x408008))

/*		Control Byte for the slave
The A1 and A2 pins of the EEPROM are connected to logic 0 (ground) on the breadboard.
When we want to read/write the first block of EEProm, the control byte is 8'b1010_0000 = 0xA0 with B0 = 0
When we want to read/write the second block of EEProm, the control byte is 8'b1010_1000 = 0xA8 with B0 = 1
*/
#define EEPROM_LO (unsigned char)0xA0 // I2C-bus slave address of the lower block of the EEPROM (addr space of the block: 00000-0FFFF)
#define EEPROM_HI (unsigned char)0xA8 // I2C-bus slave address of the upper block of the EEPROM (addr space of the block: 10000-1FFFF)

#define READ_EEPROM (unsigned char)0x01	 // in the control byte, the R/W_L bit is the LSB!, 1 means read
#define WRITE_EEPROM (unsigned char)0x00 // in the control byte, the R/W_L bit is the LSB!, 0 means write

// useful IIC bit positions that can be used to synthesize commands
//
#define WR (unsigned char)0x10	// 8'b0001_0000, WR = CR[4] = 1
#define RD (unsigned char)0x20	// 8'b0010_0000, RD = CR[5] = 1
#define STO (unsigned char)0x40 // 8'b0100_0000, STO = CR[6] = 1
#define STA (unsigned char)0x80 // 8'b1000_0000, STA = CR[7] = 1

#define NACK (unsigned char)0x08 // 8'b0000_1000
#define IACK (unsigned char)0x01 // 8'b0000_0001, IACK = CR[0] = 1

/* Commands synthesized by using the bit position info. Please note that all reserved bits are read as zeros.
 * To ensure forward compatibility, they should be written as zeros.
 */
#define WRITE_START (WR | STA)
#define WRITE_STOP (WR | STO)
#define READ_END (STO | RD | NACK)

// useful IIC status register values
#define IF (unsigned char)0x01			// interrupt flag, 8'b0000_0001, IACK = SR[0] = 1
#define TIP (unsigned char)0x02			// TIP, Transfer in progress. 1 when transferring data, 0 when transfer complete
#define NO_ACK_BACK (unsigned char)0x80 // SR[7] = 1, No acknowledge received from the addressed slave.

// useful IIC control register values
#define IIC_ENABLE (unsigned char)0x80	// CTR[7:6] = 2'b10, this will enable the core as well as disable interrupt
#define IIC_DISABLE (unsigned char)0x00 // CTR[7:6] = 0, the core is disabled, the interrupt is disabled

#define NUM_CHAN_SAMPLES 10 // number of channel samples to be read
/*************************************************************
** IIC Interface and EEPROM function prototypes
**************************************************************/
void WaitForACK(void);
void WaitForCompletion(void);
void IIC_Init(void);
void writeByte_IIC(unsigned char data, unsigned char command);
void waitWriteComplete_EEPROM(unsigned char control_byte, unsigned char command);
unsigned char selectEEPRomBlock(unsigned int addr);
void writeByte_EEPROM(unsigned char control_byte, unsigned short addr, unsigned data);
void readByte_IIC(unsigned char *data, unsigned char command);
void random_readByte_EEPROM(unsigned char control_byte, unsigned short addr, unsigned char *recevied_data);
void byte_write_test(void);
void byte_read_test(void);
void read_EEPROM_page(unsigned int addr, unsigned char *data, unsigned int size);
void readBlock_test(void);
void generateWaveform(void);
void read_ADC_Channel(void);
void writeBlock_test(void);
void writePage(unsigned char id, unsigned short address, unsigned char *data, unsigned long size);
void readPage(unsigned char id, unsigned short address, unsigned char *data, unsigned long size);

/*************************************************************
** IIC Interface and EEPROM function definitions
**************************************************************/
// don't forget to wait for the ACK back from the slave AFTER each write.
void WaitForACK(void)
{
	while ((IIC_SR & NO_ACK_BACK) == NO_ACK_BACK)
		;
}

// Check the status register TIP bit (bit 1) to see when transmit has finished
void WaitForCompletion(void)
{
	while ((IIC_SR & TIP) == TIP)
		;
}

// Important: If you are using the version that doesn't have the cache (i.e., CPU clock freq = 25 MHz), then IIC_PRERlo and IIC_PRERhi need to be changed!
void IIC_Init(void)
{
	// Change the value of the prescale register only when the EN bit is cleared.
	IIC_CTR = IIC_DISABLE; // disable IIC controller

	/* set the clock frequency for 100Khz
	 * clock freq of the SPI controller = CPU_clock_freq = 25 MHz (with cache), desired_SCL = 100 KHz (from lab handout),
	 * prescale = CPU_clock_freq / (5 * desired_SCL) - 1 = 25 * 1000 / (5 * 100) - 1 = 49 = 0x31
	 */
	IIC_PRERlo = (unsigned char)0x31;
	IIC_PRERhi = (unsigned char)0x00;

	IIC_CTR = IIC_ENABLE;
}

void writeByte_IIC(unsigned char data, unsigned char command)
{
	/* send data */
	IIC_TXR = data;	  // put the data to be transmitted into TX register
	IIC_CR = command; // write something to the command register that indicates that you want to write something

	// Check the status register TIP bit (bit 1) to see when transmit has finished
	WaitForCompletion();
	// don't forget to wait for the ACK back from the slave AFTER each write.
	WaitForACK();
}

/* This function checks for EEPROM internal write completion.
 * If the internal write is not complete, the master will wait until it is complete.
 */
void waitWriteComplete_EEPROM(unsigned char control_byte, unsigned char command)
{
	while (1)
	{
		/* send control_byte */
		IIC_TXR = control_byte;
		IIC_CR = command;

		WaitForCompletion();

		if ((IIC_SR & NO_ACK_BACK) != NO_ACK_BACK)
			break;
	}
}

/* The EEPROM chip is physically organised as 2 x 64Kbyte chips packaged inside the same physical device;
so a different IIC address is required to access the lower 64k vs. the upper 64k halves.
The block select bit B0 in the control byte should be set differently based on the value of the address.
If the address is in the range [0x0, 0x0FFFF], B0 is set to 0.
If the address is in the range [0x10000, 1FFFF], B0 is set to 1.
This function takes the address you want to access in the EEPROM chip, and returns
the corresponding control byte.
*/
unsigned char selectEEPRomBlock(unsigned int addr)
{
	unsigned char block_select_bit = (unsigned char)((addr >> 16) & 0xFF);
	if (block_select_bit == 0)
	{
		//printf("\r\nThe lower 64Kbyte block is selected.");
		return EEPROM_LO;
	}
	else
	{
		//printf("\r\nThe upper 64Kbyte block is selected.");
		return EEPROM_HI;
	}
}

void writeByte_EEPROM(unsigned char control_byte, unsigned short addr, unsigned data)
{
	unsigned char addr_hi = (unsigned char)((addr >> 8) & 0xFF);
	unsigned char addr_lo = (unsigned char)(addr & 0xFF);

	/* Send the control byte to the EEPROM*/
	writeByte_IIC(control_byte, WRITE_START);

	/* Send the address to write the data */
	writeByte_IIC(addr_hi, WR); // send upper byte addr
	writeByte_IIC(addr_lo, WR); // send lower byte addr

	/* Send data */
	writeByte_IIC(data, WRITE_STOP);

	waitWriteComplete_EEPROM(control_byte, WRITE_START);
}

/*
pass arguments: *data    - pointer to data that is received
				*command - action to the data
*/
void readByte_IIC(unsigned char *data, unsigned char command)
{
	// send command
	IIC_CR = command;

	WaitForCompletion();

	// retrieve data from the IIC core
	*data = IIC_RXR;
}

void random_readByte_EEPROM(unsigned char control_byte, unsigned short addr, unsigned char *recevied_data)
{
	unsigned char addr_hi = (unsigned char)((addr >> 8) & 0xFF);
	unsigned char addr_lo = (unsigned char)(addr & 0xFF);

	// send control byte, write and start commands
	writeByte_IIC(control_byte, WRITE_START);

	// send the address from which we read the data
	writeByte_IIC(addr_hi, WR); // send upper byte addr
	writeByte_IIC(addr_lo, WR); // send lower byte addr

	/* After the word address is sent, the master
	generates a Start condition following the acknowledge.
	This terminates the write operation, but not before the
	internal Address Pointer is set. Then, the master issues
	the control byte again, but with the R/W bit set to a one. */
	writeByte_IIC((control_byte | READ_EEPROM), WRITE_START); // send read command

	// retrieve data
	readByte_IIC(recevied_data, READ_END);
}

void byte_write_test(void)
{
	unsigned int addr;
	//unsigned short read_addr;
	unsigned char data_sent;
	unsigned char data_received = (unsigned char)0xFF; // default value

	unsigned short control_byte = (unsigned short)0;
	unsigned short eeprom_byte_addr;

	int i = 0;

	// request address from the user
	printf("\r\nEnter the address (6 hex digits) you want to write data to: ");
	addr = Get6HexDigits(0); // read 32 bit value from user keyboard
	printf("\r\n----> Address entered: %x", addr);
	eeprom_byte_addr = (unsigned short)(addr & 0xFFFF);

	// request data from the user
	printf("\r\nEnter the byte data (2 hex digits) you want to store in the EEPROM: ");
	data_sent = Get2HexDigits(0);
	printf("\r\n----> Byte data entered: %x", data_sent);

	// set the B0 bit in the control byte to select the correct block to write
	control_byte = selectEEPRomBlock(addr);

	// send a byte to EEPROM
	writeByte_EEPROM(control_byte, eeprom_byte_addr, data_sent);

	// verify the write operation
	random_readByte_EEPROM(control_byte, eeprom_byte_addr, &data_received);
	if (data_received == data_sent)
		printf("\r\n----> Byte data is successfully written to the EEPROM!");
	else
		printf("\r\n----> Byte data failed to be written to the EEPROM!");
}

void byte_read_test(void)
{
	unsigned int addr;
	unsigned char data_received = (unsigned char)0xFF; // default
	unsigned char control_byte = (unsigned char)0;	   // default
	unsigned short eeprom_byte_addr;

	// request address from the user
	printf("\r\nEnter the address (6 hex digits) you want to read data from: ");
	addr = Get6HexDigits(0); // read 32 bit value from user keyboard
	printf("\r\n----> Address entered: %x", addr);
	eeprom_byte_addr = (unsigned short)(addr & 0xFFFF);

	// set the B0 bit in the control byte to select the correct block to read
	control_byte = selectEEPRomBlock(addr);

	// read data from the address
	random_readByte_EEPROM(control_byte, eeprom_byte_addr, &data_received);

	printf("\r\n----> The data read from the address is %x.", data_received);
}

void read_EEPROM_page(unsigned int addr, unsigned char *data, unsigned int size)
{
	unsigned int i = 0;

	unsigned char control_byte = (unsigned char)0;		// default
	unsigned char curr_control_byte = (unsigned char)0; // default
	unsigned short eeprom_byte_addr;

	unsigned char addr_high;
	unsigned char addr_low;
	eeprom_byte_addr = (unsigned short)(addr & 0xFFFF);

	// set the B0 bit in the control byte to select the correct block to read
	control_byte = selectEEPRomBlock(addr);
	curr_control_byte = control_byte;

	addr_high = (unsigned char)((eeprom_byte_addr >> 8) & 0x00FF);
	addr_low = (unsigned char)(eeprom_byte_addr & 0x00FF);

	writeByte_IIC(addr_high, WR);
	writeByte_IIC(addr_low, WR);

	writeByte_IIC(control_byte, WRITE_START);

	// send read command
	writeByte_IIC((control_byte | READ_EEPROM), WRITE_START);

	for (i = 0; i < size; i++)
	{
		if (i != size - 1)
		{
			if (control_byte != curr_control_byte)
			{ // if the address crosses the boundary of the two blocks in the EEPROM
				// we need to end the read process, and generate the new internal address to read the other block
				readByte_IIC((data + i), READ_END);
				eeprom_byte_addr = (unsigned short)(addr & 0xFFFF);
				addr_high = (unsigned char)((eeprom_byte_addr >> 8) & 0x00FF);
				addr_low = (unsigned char)(eeprom_byte_addr & 0x00FF);
				writeByte_IIC(addr_high, WR);
				writeByte_IIC(addr_low, WR);
				writeByte_IIC(curr_control_byte, WRITE_START);
			}
			readByte_IIC((data + i), (RD & ~NACK));
			printf("\r\nRead Address: %x		Read Value: %x", addr, *data);
		}
		else
		{
			readByte_IIC((data + i), READ_END);
		}
		addr++;
		curr_control_byte = selectEEPRomBlock(addr);
	}
}

void readBlock_test(void)
{
	unsigned char data[128] = {(unsigned char)0xAA};
	unsigned char data_read[128] = {0};
	unsigned long start_address = (unsigned long)0x000000;
	unsigned long end_address = (unsigned long)0x000000;
	unsigned long new_end_address = (unsigned long)0x000000;
	unsigned long new_start_address = (unsigned long)0x000000;
	unsigned char id_1 = (unsigned char)0x00;
	unsigned char id_2 = (unsigned char)0x00;

	int i = 0;
	int i1 = 0;
	int i2 = 0;
	unsigned long size = 128;
	int flag = 0;
	int val;
	int size_1;
	int size_2;

	printf("\r\nEnter the address (6 hex digits) you want to read data from: ");
	start_address = Get6HexDigits(0);
	printf("\r\n----> Address entered: %x", start_address);
	id_1 = selectEEPRomBlock(start_address);

	printf("\r\nEnter the block size (6 hex digits):");
	size = Get6HexDigits(0);
	printf("\r\n----> Block size entered: %x", size);

	end_address = size + start_address + 1;
	id_2 = selectEEPRomBlock(end_address);

	if (id_1 == EEPROM_LO & id_2 == EEPROM_HI)
	{
		size_1 = 0x00FFFF - start_address;
		size_2 = end_address - 0x00FFFF;
		size = size_1 + size_2;
	}
	//Lower address and upper address
	if (id_1 == EEPROM_LO & id_2 == EEPROM_HI)
	{
		for (i = start_address / 128; i < 512; i++)
		{
			readPage(EEPROM_LO, (unsigned short)(128 * i), &data, (unsigned char)128);
			if (i == start_address / 128)
			{ //Do it just for the first cycle
				for (i1 = start_address % 128; i1 < start_address % 128 + size_1; i1++)
				{
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + i1), data[i1]);
				}
			}
			else
			{
				for (i1 = 0; i1 < size_1 - 1; i1++)
				{
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + i1), data[i1]);
				}
			}
		}

		//Block 2
		for (i = 0; i < end_address / (128 * 512); i++)
		{
			readPage(EEPROM_HI, (unsigned short)(128 * i), &data, (unsigned char)128);
			if (i == end_address / (128 * 512))
			{
				for (i1 = 0; i1 < end_address % 128; i1++)
				{ //for the last cycle
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + 512 * 128 + i1 - 65536), data[i1]);
				}
				if (size < 128)
					break;
			}
			else
				for (i1 = 0; i1 < size_2 - 1; i1++)
				{
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + 512 * 128 + i1 - 65536), data[i1]);
				}
		}
	}

	//higher addresses for both
	else if (id_1 == EEPROM_HI & id_2 == EEPROM_HI)
	{
		readPage(EEPROM_HI, (unsigned short)(128 * i), &data, (unsigned char)128);

		if (size < 128)
		{
			for (i1 = start_address % 128; i1 < size + start_address % 128; i1++)
			{
				printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + 512 * 128 + i1 - 65536), data[i1]);
			}

			{
				for (i1 = 0; i1 < size - 1; i1++)
				{
					if (size < 128)
						break;
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + 512 * 128 + i1 - 65536), data[i1]);
				}
			}
		}
		else
			for (i1 = start_address % 128; i1 < size + start_address % 128; i1++)
			{
				printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + 512 * 128 + i1 - 65536), data[i1]);
			}
	}

	//both lower addresses
	else if (id_1 == EEPROM_LO & id_2 == EEPROM_LO)
	{

		readPage(EEPROM_LO, (unsigned short)(128 * i), &data, (unsigned char)128);
		//Do it just for the first cycle
		if (size < 128)
		{
			for (i1 = start_address % 128; i1 < size + start_address % 128; i1++)
			{
				printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + i1), data[i1]);
			}

			new_start_address = start_address + i1;
			{
				for (i1 = 0; i1 < size - 1; i1++)
				{
					if (size < 128)
						break;
					printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(new_start_address + i1), data[i1]);
				}
			}
		}
		else
			for (i1 = start_address % 128; i1 < size + start_address % 128; i1++)
			{
				printf("\r\n Address : 0x%x ----  Data : 0x%x", (unsigned long)(start_address + i1), data[i1]);
			}
	}
}

void generateWaveform(void)
{
	unsigned char i = 0; // max value is 255

	printf("\r\nGenerating triangle waveform ...");
	printf("\r\nPress Reset button to exit. ");

	writeByte_IIC(CONVERTER_ADDR, WRITE_START);

	writeByte_IIC(DAC, WR);

	while (1)
	{
		for (i = 0; i < 255; i++)
			writeByte_IIC((unsigned char)i, WR);
		for (i = 255; i > 0; i--)
			writeByte_IIC((unsigned char)i, WR);
	}
}

void read_ADC_Channel(void)
{
	unsigned char data = (unsigned char)0;
	int option = 0;
	unsigned int i = 0;
	unsigned int j = 0;
	printf("\r\nSelect ADC channel to read by entering the channel number followed by Enter...");
	printf("\r\nChannel 1: On board potentiometer to supply a variable voltage.");
	printf("\r\nChannel 2: On board thermistor to measure temperature");
	printf("\r\nChannel 3: On board photo resistor to measure light intensity");
	printf("\r\n# ");
	scanf("%d", &option);

	writeByte_IIC((CONVERTER_ADDR | CONVERTER_WRITE), WRITE_START);

	if (option == 1)
		writeByte_IIC(ADC_CHAN_1, WRITE_STOP);
	else if (option == 2)
		writeByte_IIC(ADC_CHAN_2, WRITE_STOP);
	else if (option == 3)
		writeByte_IIC(ADC_CHAN_3, WRITE_STOP);
	else
	{
		printf("\r\nInvalid option!");
		return;
	}

	writeByte_IIC((CONVERTER_ADDR | CONVERTER_READ), WRITE_START);

	for (j = 0; j < NUM_CHAN_SAMPLES; j++)
	{
		if (j != NUM_CHAN_SAMPLES - 1)
		{
			readByte_IIC(&data, (RD & ~NACK));
			if (j != 0)
			{
				printf("\r\n Data Read from channel %d is 0x%x", option, data);
				for (i = 0; i < 1000000; i++)
					; // wait so that the readings can be printed slowly
			}
		}
		else
		{
			readByte_IIC(&data, (STO | RD | (~(0xF7))));
			printf("\r\n Data Read from channel %d is 0x%x", option, data);
		}
	}
	return;
}
void writeBlock_test(void)
{
	unsigned char data[128] = {(unsigned char)0xAA};
	unsigned char data_read = (unsigned char)0xAA;
	unsigned long start_address = (unsigned long)0x000000;
	unsigned long end_address = (unsigned long)0x000000;
	unsigned char id_1 = (unsigned char)0x00;
	unsigned char id_2 = (unsigned char)0x00;

	int i = 0;
	int i1 = 0;
	int i2 = 0;
	unsigned long size = 128;
	int flag = 0;
	int val;
	unsigned long size_1 = 128;
	unsigned long size_2 = 128;

	printf("\r\nEnter the start address (6 hex digits) for block write operation:");
	start_address = Get6HexDigits(0);
	printf("\r\n----> Address entered: %x", start_address);
	id_1 = selectEEPRomBlock(start_address);

	printf("\r\nEnter the byte data (2 hex digits) you want to store in the EEPROM: ");
	data_read = Get2HexDigits(0);
	printf("\r\n----> Byte data entered: %x", data_read);

	printf("\r\nEnter the block size (6 hex digits): ");
	size = Get6HexDigits(0);
	printf("\r\n----> Block size entered: %u", size);

	end_address = start_address + size + 1;
	id_2 = selectEEPRomBlock(end_address);

	if (size > 128)
		val = 1;
	else
		val = -1;

	for (i = 0; i < 128; i++)
	{
		data[i] = data_read;
	}

	// Write to Block 1 and Block 2
	if (id_1 == EEPROM_LO & id_2 == EEPROM_HI)
	{
		size_1 = 0x00FFFF - start_address;
		size_2 = end_address - 0x00FFFF;
		size = size_1 + size_2;
	}
	// Write to Block 1 and Block 2
	//One lower one higher
	if (id_1 == EEPROM_LO & id_2 == EEPROM_HI)
	{

		writePage(EEPROM_LO, (unsigned short)(start_address), &data, (unsigned char)size_1);
		//Write to the first page first

		writePage(EEPROM_HI, (unsigned short)(0), &data, (unsigned char)size_2);
	}
	//Both Higher
	else if (id_1 == EEPROM_HI & id_2 == EEPROM_HI)
	{
		writePage(EEPROM_HI, (unsigned short)(start_address - 65536), &data, (unsigned char)size);
	}
	//Both lower
	else if (id_1 == EEPROM_LO & id_2 == EEPROM_LO)
	{
		writePage(EEPROM_LO, (unsigned short)(start_address), &data, (unsigned char)size);
	}

	printf("\r\nBlock write operation is complete");
	for (i = 0; i < 100000; i++)
	{
	}
}
void writePage(unsigned char id, unsigned short address, unsigned char *data, unsigned long size)
{
	int i = 0;

	unsigned char address_high = (unsigned char)((address >> 8) & 0x00FF);
	unsigned char address_low = (unsigned char)((address)&0x00FF);

	writeByte_IIC((id), (WR | STA)); // 0b1010_0000

	writeByte_IIC(address_high, WR);
	writeByte_IIC(address_low, WR);

	for (i = 0; i < size; i++)
	{
		writeByte_IIC(*(data + i), WR);

		if (i == (size - 1))
		{
			IIC_CR = STO;
			while ((IIC_SR & TIP) == TIP)
			{
				//Wait for transfer ...
			}
		}
	}
}

void readPage(unsigned char id, unsigned short address, unsigned char *data, unsigned long size)
{
	int i = 0;
	unsigned char address_high = (unsigned char)((address >> 8) & 0x00FF);
	unsigned char address_low = (unsigned char)((address)&0x00FF);

	writeByte_IIC((id), (WR | STA)); // 0b1010_0000

	writeByte_IIC(address_high, WR);
	writeByte_IIC(address_low, WR);

	// Reading ...
	writeByte_IIC((id | 0x01), (WR | STA));

	for (i = 0; i < size; i++)
	{
		if (i != size - 1)
		{
			readByte_IIC((data + i), (RD & 0xF7));
		}
		else
			readByte_IIC((data + i), (STO | RD | (~(0xF7))));
	}
}
/******************************************************************************************************************************
* Start of user program
******************************************************************************************************************************/
void main()
{
	unsigned int choice = 0;
	Init_RS232(); // initialise the RS232 port for use with hyper terminal
	IIC_Init();

	while (1)
	{
		printf("\r\nThis is CPEN 412 IIC Bus Interface Demo Menu ...");
		printf("\r\nPress the number key to select the test you want to run followed by Enter key");
		printf("\r\n1. Single byte write test from a specified starting address for the EEPROM chip");
		printf("\r\n2. Single byte read test from a specified starting address for the EEPROM chip");
		printf("\r\n3. Block write test for any specified size up to 128K Bytes for the EEPROM chip");
		printf("\r\n4. Block read test for any specified size up to 128K Bytes for the EEPROM chip");
		printf("\r\n5. Generate a waveform out of the DAC to create visual effects.");
		printf("\r\n6. Read analog input from an ADC channel.");
		printf("\r\n# ");
		scanf("%u", &choice);
		if (choice == 1)
			byte_write_test();
		else if (choice == 2)
			byte_read_test();
		else if (choice == 3)
			writeBlock_test();
		else if (choice == 4)
			readBlock_test();
		else if (choice == 5)
			generateWaveform();
		else if (choice == 6)
			read_ADC_Channel();
		else
			printf("\r\nInvalid Option. Please choose again.");
	};

	// programs should NOT exit as there is nothing to Exit TO !!!!!!
	// There is no OS - just press the reset button to end program and call debug
}