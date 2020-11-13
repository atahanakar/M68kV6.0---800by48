//////////////////////////////////////////////////////////////////////////////////////
// Simple Cache controller
//
// designed to work with TG68 (68000 based) cpu with 16 bit data bus and 32 bit address bus
// separate upper and lowe data stobes for individual byte and also 16 bit word access
//
// Copyright PJ Davies August 2017
///////////////////////////////////////////////////////////////////////////////////////

module M68kCacheController(
	input Clock,		// used to drive the state machine - state changes occur on positive edge
	input Reset_L,		// active low reset
	input CacheHit_H,	// high when cache contains matching address during read
	input ValidBitIn_H, // indicates if the cache line is valid

	// signals to 68k

	input DramSelect68k_H,						// active high signal indicating Dram is being addressed by 68000
	input  [31:0] AddressBusInFrom68k,	// address bus from 68000
	input  [15:0] DataBusInFrom68k,		// data bus in from 68000
	output reg  [15:0] DataBusOutTo68k, // data bus out from Cache controller back to 68000 (during read)
	input UDS_L,								// active low signal driven by 68000 when 68000 transferring data over data bit 15-8
	input LDS_L,								// active low signal driven by 68000 when 68000 transferring data over data bit 7-0
	input WE_L,									// active low write signal, otherwise assumed to be read
	input AS_L,
	input DtackFromDram_L, // dtack back from Dram
	input CAS_Dram_L,	   // cas to Dram so we can count 2 clock delays before 1st data
	input RAS_Dram_L,	   // so we can detect diference between a read and a refresh command

	input  [15:0] DataBusInFromDram,			   // data bus in from Dram
	output reg [15:0] DataBusOutToDramController, // data bus out to Dram (during write)
	input [15:0] DataBusInFromCache,			   // data bus in from Cache
	output reg UDS_DramController_L,					   // active low signal driven by 68000 when 68000 transferring data over data bit 7-0
	output reg LDS_DramController_L,					   // active low signal driven by 68000 when 68000 transferring data over data bit 15-8
	output reg DramSelectFromCache_L,
	output reg WE_DramController_L, 	// active low Dram controller write signal
	output reg AS_DramController_L,
	output reg DtackTo68k_L, 			// Dtack back to 68k at end of operation

	// Cache memory write signals
	output reg TagCache_WE_L,  // to store an address in Cache
	output reg DataCache_WE_L, // to store data in Cache
	output reg ValidBit_WE_L,  // to store a valid bit

	output reg [31:0] AddressBusOutToDramController, // address bus from Cache to Dram controller
	output reg [18:0] TagDataOut,					  // tag data to store in the tag Cache - 19 bits now
	output reg [2:0] WordAddress,					  // up to 8 bytes in a Cache line
	output reg ValidBitOut_H,								  // indicates the cache line is valid
	output reg [12:4] Index,						  // 9 bit index in this example cache

	output  [4:0] CacheState // for debugging
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Initialisation States
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
parameter Reset = 5'b00000;						// 0
parameter InvalidateCache = 5'b00001;			// 1
parameter Inactive = 5'b00010;					// 2
parameter CheckForCacheHit = 5'b00011;			// 3
parameter ReadDataFromDramIntoCache = 5'b00100;	// 4
parameter CASDelay1 = 5'b00101;					// 5
parameter CASDelay2 = 5'b00110;					// 6
parameter BurstFill = 5'b00111;					// 7
parameter EndBurstFill = 5'b01000;				// 8
parameter WriteDataToDram = 5'b01001;			// 9
parameter WaitForEndOfCacheRead = 5'b01010;		// 10

// 5 bit variables to hold current and next state of the state machine
reg [4:0] CurrentState; // holds the current state of the Cache controller
reg [4:0] NextState;	 // holds the next state of the Cache controller

// counter for the read burst fill
reg [31:0] BurstCounter; // counts for at least 8 during a burst Dram read also counts lines when flusing the cache
reg BurstCounterReset_L;		  // reset for the above counter

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// concurrent process state registers
// this process RECORDS the current state of the system.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign CacheState = CurrentState; // for debugging purposes only

always @(posedge Clock, negedge Reset_L) begin
	if (Reset_L == 0)
		CurrentState <= Reset;
	else
		CurrentState <= NextState;
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Burst read counter: Used to provide a 3 bit address to the data Cache during burst reads from Dram and up to 2^12 cache lines
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge Clock) begin
	if (BurstCounterReset_L == 0) // synchronous reset
		BurstCounter <= 0;
	else
		BurstCounter <= BurstCounter + 1;
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// next state and output logic
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	always @(*) begin
		// start with default inactive values for everything and override as necessary, so we do not infer storage for signals inside this process
		NextState = Inactive; // default is to go to this state
		DataBusOutTo68k = DataBusInFromCache;
		DataBusOutToDramController = DataBusInFrom68k;

		// default is to give the Dram the 68k's signals directly (unless we want to change something)
		AddressBusOutToDramController[31:4] = AddressBusInFrom68k [31:4];
		AddressBusOutToDramController[3:1] = 0; // all reads to Dram have lower 3 address lines set to 0 for a Cache line regardless of 68k address
		AddressBusOutToDramController[0] = 0;	  // to avoid inferring a latch for this bit

		TagDataOut = AddressBusInFrom68k[31:13];
		Index = AddressBusInFrom68k [12:4]; // cache index is 68ks address bits [12:4]

		UDS_DramController_L = UDS_L;
		LDS_DramController_L = LDS_L;
		WE_DramController_L = WE_L;
		AS_DramController_L = AS_L;

		DtackTo68k_L = 1;			// don't supply until we are ready
		TagCache_WE_L = 1;			// don't write Cache address
		DataCache_WE_L = 1;		// don't write Cache data
		ValidBit_WE_L = 1;			// don't write valid data
		ValidBitOut_H = 0;			// line invalid
		DramSelectFromCache_L = 1; // don't give the Dram controller a select signal since we might not always want to cycle the Dram if we have a hit during a read
		WordAddress = 0;			// default is byte 0 in 8 byte Cache line

		BurstCounterReset_L = 1; // default is that burst counter can run (and wrap around if needed), we'll control when to reset it

		case (CurrentState)
			// Initial State following a reset
			Reset: begin							// 0, if we are in the Reset state
				BurstCounterReset_L = 0;			// reset the burst counter (synchronously)
				NextState = InvalidateCache;		// go flush the cache
			end
			// This state will flush the cache before entering idle state
			InvalidateCache: begin					// 1
				// burst counter should now be 0 when we first enter this state, as it was reset in state above
				if (BurstCounter == 512) // if we have done all cache lines
					NextState = Inactive;
				else begin
					NextState = InvalidateCache;		// assume we stay here
					Index = BurstCounter[8:0];			// 9 bit address for Index for 512 lines of cache
					// clear the validity bit for each cache line
					ValidBitOut_H = 0;
					ValidBit_WE_L = 0;
				end
			end
			// Main IDLE state:
			Inactive: begin							// 2
				if (AS_L == 0 && DramSelect68k_H == 1) begin // if AS_L is active and DramSelect68_H is active
					if (WE_L == 1) begin // if the 68k's access is a read, i.e. WE_L is high
						// activate UDS and LDS to the Dram Controller to grab both bytes from Cache or Dram regardless of what 68k asks
						UDS_DramController_L = 0;
						LDS_DramController_L = 0;
						NextState = CheckForCacheHit;
					end
					else begin // must be a write, so write the 68k data to Dram and invalidate the line as we don’t cache written data
						if (ValidBitIn_H == 1) begin
							ValidBitOut_H = 0; // Set ValidBitOut_H to invalid
							ValidBit_WE_L = 0; // Activate ValidBit_WE_L to perform the write to the Valid memory in the cache. This occurs  on next clock edge
						end
						DramSelectFromCache_L = 0; // Activate DramSelectFromCache_L to zero to start the Dram controller to perform the write a.s.a.p.
						NextState = WriteDataToDram; // to perform the write
					end
				end
			end
			// Check if we have a Cache HIT. If so give data to 68k or if not, go generate a burst fill
			CheckForCacheHit: begin // 3, if we are looking for Cache hit
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				/* At this point, the Tag and Valid block will have clocked in the CPU address and output their Valid and Tag address
				   to the comparator so we can see if the cache has a hit or not. */
				if (CacheHit_H == 1 && ValidBitIn_H == 1) begin // give the 68k the data from the cache
				/*	Remember by default DataBusOutTo68k is set to DataBusInFromCache,
					so get the data from the Cache corresponding to the CPU address we are reading from */
					WordAddress = AddressBusInFrom68k[3:1]; // give the cache line the correct 3 bit word address specified by 68k
					DtackTo68k_L = 0; // Activate the DtackTo68k_L signal
					NextState = WaitForEndOfCacheRead;
				end
				else begin // we don't have the data Cached so get it from the Dram and Cache data and address
					DramSelectFromCache_L = 0; // start the Dram controller to perform the read a.s.a.p.
					NextState = ReadDataFromDramIntoCache;
				end
			end
			// Got a Cache hit, so give the 68k the Cache data now, then wait for the 68k to end bus cycle
			WaitForEndOfCacheRead: begin // 10
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				// remember by default DataBusOutTo68k is set to DataBusInFromCache
				WordAddress = AddressBusInFrom68k[3:1]; // give the cache line the correct 3 bit address specified by 68k
				DtackTo68k_L = 0; // Active the DtackTo68k_L signal

				if (AS_L == 0)
					NextState = WaitForEndOfCacheRead; // stay in this state until AS_L deactivated
			end
			// Start of operation to Read from Dram State : Remember that CAS latency is 2 clocks before 1st item of burst data appears
			ReadDataFromDramIntoCache: begin // 4
				NextState = ReadDataFromDramIntoCache; // unless overridden below
				/* We need to wait for a valid CAS signal to be presented to the Dram by the Dram controller.
				   We can’t just look at CAS, since a refresh also drives CAS low. */
				if (CAS_Dram_L == 0 && RAS_Dram_L == 1) // a read and not a refresh
					NextState = CASDelay1; // move to next state to wait 2 Clock period (CAS latency)
				// Keep Kicking the Dram controller to perform a burst read and fill a Line in the cache
				DramSelectFromCache_L = 0; // keep reading from Dram
				DtackTo68k_L = 1; // Deactivate DtackTo68k_L signal, no dtack to 68k until burst fill complete

				/* Because we are burst filling a line of cache from Dram, we have to store the TAG (i.e. the 68k's m.s.bits of address bus)
				   into the Tag Cache to mark the fact that we will have the data at that address and move on to next state to get Dram data */
				// By Default:  TagDataOut set to AddressBusInFrom68k(31 downto 9);
				TagCache_WE_L = 0; // write the 68k's address with each clock as long as we are in this state

				// we also have to set the Valid bit in the Valid Memory to indicate line in the cache is now valid
				ValidBitOut_H = 1; // Make Cache Line Valid
				ValidBit_WE_L = 0;  // Write the above Valid Bit

				/*	perform a Dram WORD READ(i.e. 16 bits), even if 68k is only reading a BYTE so we get both bytes as cache word is 16 bits wide
					By Default : Address bus to Dram is already set to the 68k's address bus by default
					By Default: AS_L, WE_L to Dram are already set to 68k's equivalent by default */
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
			end
			// Wait for 1st CAS clock (latency)
			CASDelay1: begin // 5, wait for Dram case signal to go low
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				// By Default : Address bus to Dram is already set to the 68k's address bus by default
				// By Default: AS_L, WE_L to Dram are already set to 68k's equivalent by default
				DramSelectFromCache_L = 0; // keep reading from Dram
				DtackTo68k_L = 1; // Deactivate DtackTo68k_L signal, no dtack to 68k until burst fill complete
				NextState = CASDelay2; // go and wait for 2nd CAS clock latency
			end
			// Wait for 2nd CAS Clock Latency
			CASDelay2: begin // 6, wait for Dram case signal to go low
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				/* By Default : Address bus to Dram is already set to the 68k's address bus by default
				   By Default: AS_L, WE_L to Dram are already set to 68k's equivalent by default */
				DramSelectFromCache_L = 0; // keep reading from Dram
				DtackTo68k_L = 1; // Deactivate DtackTo68k_L signal, no dtack to 68k until burst fill complete

				BurstCounterReset_L = 0; // reset the counter to supply 3 bit burst address to Cache memory
				NextState = BurstFill;
			end
			// Start of burst fill from Dram into Cache (data should be available at Dram in this state)
			BurstFill: begin // 7, wait for Dram case signal to go low
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				/* By Default : Address bus to Dram is already set to the 68k's address bus by default
				   By Default: AS_L, WE_L to Dram are already set to 68k's equivalent by default */
				DramSelectFromCache_L = 0; // keep reading from Dram
				DtackTo68k_L = 1; // Deactivate DtackTo68k_L signal, no dtack to 68k until burst fill complete
				// burst counter should now be 0 when we first enter this state, as reset was synchronous and will count with each clock
				if (BurstCounter == 16'd8)
					NextState = EndBurstFill;
				else begin
					WordAddress = BurstCounter[2:0]; // Set WordAddress to cache memory to lowest 3 bits of BurstCounter
					// By Default: Index address to cache Memory is bits [8:4] of the 68ks address bus for a 32 line cache
					DataCache_WE_L = 0; // Activate DataCache_WE_L to store  next word from Dram into data Cache on next clock edge
					NextState = BurstFill;
				end
			end
			// End Burst fill
			EndBurstFill: begin // 8, wait for Dram case signal to go low
				DramSelectFromCache_L = 1; // Deactivate DramSelectFromCache_L signal, deactivate Dram controller
				DtackTo68k_L = 0; // Activate DtackTo68k_L signal, give dtack to 68k until end of 68k's bus cycle
				// Keep activating UDS and LDS to Dram/Cache Memory controller to grab both bytes
				UDS_DramController_L = 0;
				LDS_DramController_L = 0;
				// get the data from the Cache corresponding the REAL 68k address we are reading from
				WordAddress = AddressBusInFrom68k[3:1];
				DataBusOutTo68k = DataBusInFromCache; // get data from the Cache and give to cpu
				// now wait for the 68k to terminate the read by removing either AS_L or DRamSelect68k_H
				if (AS_L == 1 || DramSelect68k_H == 0) // if AS_L is INactive or DramSelect68k_H is INactive
					NextState = Inactive; // go to Inactive state ending the Dram access
				else
					NextState = EndBurstFill; // else stay in this state
			end
			// Write Data to Dram State (no Burst)
			WriteDataToDram: begin // 9, if we are writing data to Dram
				AddressBusOutToDramController = AddressBusInFrom68k; // override lower 3 bits
				// Data Bus out to Dram is already set to 68k's data bus out by default
				// By Default: AS_L, WE_L to Dram are already set to 68k's equivalent by default
				DramSelectFromCache_L = 0; // Keep Activating DramSelectFromCache_L signal, keep kicking the Dram controller to perform the write
				DtackTo68k_L = DtackFromDram_L; // give the 68k the dtack from the Dram controller
				// now wait for the 68k to terminate the read by removing either AS_L or DRamSelect68k_H
				if (AS_L == 1 || DramSelect68k_H == 0) // if AS_L is INactive or DramSelect68k_H is INactive
					NextState = Inactive;
				else
					NextState = WriteDataToDram; // else stay in this state until the 68k finishes the write
			end
		endcase
	end
endmodule
