//////////////////////////////////////////////////////////////////////////////////////-
// Simple DRAM controller for the DE1 board, assuming a 50MHz controller/memory clock
// Assuming 64Mbytes SDRam organised as 32Meg x16 bits with 8192 rows (13 bit row addr
// 1024 columns (10 bit column address) and 4 banks (2 bit bank address)
// CAS latency is 2 clock periods
//
// designed to work with 68000 cpu using 16 bit data bus and 32 bit address bus
// separate upper and lower data stobes for individual byte and 16 bit word access
//
// Copyright PJ Davies June 2020
//////////////////////////////////////////////////////////////////////////////////////-


module M68kDramController_Verilog (
			input Clock,								// used to drive the state machine- stat changes occur on positive edge
			input Reset_L,     						// active low reset
			input unsigned [31:0] Address,		// address bus from 68000
			input unsigned [15:0] DataIn,			// data bus in from 68000
			input UDS_L,								// active low signal driven by 68000 when 68000 transferring data over data bit 15-8
			input LDS_L, 								// active low signal driven by 68000 when 68000 transferring data over data bit 7-0
			input DramSelect_L,     				// active low signal indicating dram is being addressed by 68000
			input WE_L,  								// active low write signal, otherwise assumed to be read
			input AS_L,									// Address Strobe

			output reg unsigned[15:0] DataOut, 				// data bus out to 68000
			output reg SDram_CKE_H,								// active high clock enable for dram chip
			output reg SDram_CS_L,								// active low chip select for dram chip
			output reg SDram_RAS_L,								// active low RAS select for dram chip
			output reg SDram_CAS_L,								// active low CAS select for dram chip
			output reg SDram_WE_L,								// active low Write enable for dram chip
			output reg unsigned [12:0] SDram_Addr,			// 13 bit address bus dram chip
			output reg unsigned [1:0] SDram_BA,				// 2 bit bank address
			inout  reg unsigned [15:0] SDram_DQ,			// 16 bit bi-directional data lines to dram chip

			output reg Dtack_L,									// Dtack back to CPU at end of bus cycle
			output reg ResetOut_L,								// reset out to the CPU

			// Use only if you want to simulate dram controller state (e.g. for debugging)
			output reg [4:0] DramState
		);

		// WIRES and REGs

		//reg  	[4:0] Command;										// 5 bit signal containing Dram_CKE_H, SDram_CS_L, SDram_RAS_L, SDram_CAS_L, SDram_WE_L

		reg	TimerLoad_H ;										// logic 1 to load Timer on next clock
		reg   TimerDone_H ;										// set to logic 1 when timer reaches 0
		reg 	unsigned	[15:0] Timer;							// 16 bit timer value
		reg 	unsigned	[15:0] TimerValue;					// 16 bit timer preload value

		reg	RefreshTimerLoad_H;								// logic 1 to load refresh timer on next clock
		reg   RefreshTimerDone_H ;								// set to 1 when refresh timer reaches 0
		reg 	unsigned	[15:0] RefreshTimer;					// 16 bit refresh timer value
		reg 	unsigned	[15:0] RefreshTimerValue;			// 16 bit refresh timer preload value

		reg   loop_counter_load_H;
		reg 	loop_counter_done_H;
		reg   unsigned  [15:0] loop_counter;							// 16-bit My timer
		reg 	unsigned	[15:0] loop_counter_value;
		reg cycle_done;

		reg NOP_counter_load_H;
		reg   NOP_counter_done_H;
		reg   unsigned NOP_counter;
		reg 	unsigned	[15:0] NOP_counter_value; 				//16-bit NOP counter preload

		reg CAS_counter_load_H;
		reg   CAS_counter_done_H;
		reg   unsigned CAS_counter;
		reg 	unsigned	[15:0] CAS_counter_value; 				//16-bit NOP counter preload

		reg   unsigned [4:0] CurrentState;					// holds the current state of the dram controller
		reg   unsigned [4:0] NextState;						// holds the next state of the dram controller

		reg  	unsigned [1:0] BankAddress;
		reg  	unsigned [12:0] DramAddress;

		reg	DramDataLatch_H;									// used to indicate that data from SDRAM should be latched and held for 68000 after the CAS latency period
		reg  	unsigned [15:0]SDramWriteData;

		reg  FPGAWritingtoSDram_H;								// When '1' enables FPGA data out lines leading to SDRAM to allow writing, otherwise they are set to Tri-State "Z"
		reg  CPU_Dtack_L;											// Dtack back to CPU
		reg  CPUReset_L;
		reg [4:0]Command;

		// 5 bit Commands to the SDRam

		parameter PoweringUp = 5'b00000 ;					// take CKE & CS low during power up phase, address and bank address = dont'care
		parameter DeviceDeselect  = 5'b11111;				// address and bank address = dont'care
		parameter NOP_command = 5'b10111;								// address and bank address = dont'care
		parameter BurstStop = 5'b10110;						// address and bank address = dont'care
		parameter ReadOnly = 5'b10101; 						// A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
		parameter ReadAutoPrecharge = 5'b10101; 			// A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
		parameter WriteOnly = 5'b10100; 						// A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = value
		parameter WriteAutoPrecharge = 5'b10100 ;			// A10 should be logic 1, BA0, BA1 should be set to a value, other addreses = value
		parameter AutoRefresh = 5'b10001;

		parameter BankActivate = 5'b10011;					// BA0, BA1 should be set to a value, address A11-0 should be value
		parameter PrechargeSelectBank = 5'b10010;			// A10 should be logic 0, BA0, BA1 should be set to a value, other addreses = don't care

		parameter PrechargeAllBanks = 5'b10010;			// A10 should be logic 1, BA0, BA1 are dont'care, other addreses = don't care
		parameter ModeRegisterSet = 5'b10000;				// A10=0, BA1=0, BA0=0, Address = don't care
		parameter ExtModeRegisterSet = 5'b10000;			// A10=0, BA1=1, BA0=0, Address = value


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-
// Define some states for our dram controller add to these as required - only 5 will be defined at the moment - add your own as required
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-

		parameter InitialisingState = 5'h00;				// power on initialising state
		parameter WaitingForPowerUpState = 5'h01	;		// waiting for power up state to complete
		parameter IssueFirstNOP = 5'h02;						// issuing 1st NOP after power up
		parameter PrechargingAllBanks = 5'h03;
		parameter Idle = 5'h04;  //4
		parameter IssueSecondNOP = 5'h05;
		parameter AutoRefreshState=5'h06;
		parameter SecondAutoRefreshState = 5'h07;
		parameter first_NOP = 5'h08;
		parameter second_NOP = 5'h09;
		parameter third_NOP = 5'h0A;
		parameter Program_Load_Reg =5'h0B;
		parameter last_NOP =  5'h0C;
		parameter DeviceReady= 5'h0D;
		parameter Idle_NOP = 5'h0E;
		parameter Idle_Refresh=5'h0F;
		parameter Three_NOP_Idle=5'h10;
		parameter Wait_for_refresh=5'h11;
		parameter MEM_States = 5'h12;
		parameter Read_DRAM = 5'h13;
		parameter Write_DRAM = 5'h14;
		parameter Write_Finish= 5'h15;
		parameter CAS_Latency1=5'h16;
		parameter Current_Cycle=5'h17;
		parameter First_NOP_Idle=5'h18;
	  parameter Second_NOP_Idle=5'h19;
		parameter Third_NOP_Idle=5'h1A;





		// TODO - Add your own states as per your own design


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// General Timer for timing and counting things: Loadable and counts down on each clock then produced a TimerDone signal and stops counting
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	always@(posedge Clock)
		if(TimerLoad_H == 1) 				// if we get the signal from another process to load the timer
			Timer <= TimerValue ;			// Preload timer
		else if(Timer != 16'd0) 			// otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock
			Timer <= Timer - 16'd1 ;		// subtract 1 from the timer value

	always@(Timer) begin
		TimerDone_H <= 0 ;					// default is not done

		if(Timer == 16'd0) 					// if timer has counted down to 0
			TimerDone_H <= 1 ;				// output '1' to indicate time has elapsed
	end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Refresh Timer: Loadable and counts down on each clock then produces a RefreshTimerDone signal and stops counting
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	always@(posedge Clock)
		if(RefreshTimerLoad_H == 1) 						// if we get the signal from another process to load the timer
			RefreshTimer  <= RefreshTimerValue ;		// Preload timer
		else if(RefreshTimer != 16'd0) 					// otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock
			RefreshTimer <= RefreshTimer - 16'd1 ;		// subtract 1 from the timer value

	always@(RefreshTimer) begin
		RefreshTimerDone_H <= 0 ;							// default is not done

		if(RefreshTimer == 16'd0) 								// if timer has counted down to 0
			RefreshTimerDone_H <= 1 ;						// output '1' to indicate time has elapsed
	end
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// LOOP COUNTER
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		always@(posedge Clock)
			if(loop_counter_load_H == 1) 						// if we get the signal from another process to load the timer
				loop_counter  <= loop_counter_value ;		// Preload timer
			else if((loop_counter != 16'd0) && cycle_done) 					// otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock
			loop_counter <= loop_counter - 16'd1 ;		// subtract 1 from the timer value
			else loop_counter<=loop_counter;

		always@(loop_counter) begin
			loop_counter_done_H <= 0 ;							// default is not done

			if(loop_counter == 16'd0) 								// if timer has counted down to 0
				loop_counter_done_H <= 1 ;						// output '1' to indicate time has elapsed
		end
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// NOP COUNTER
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			always@(posedge Clock)
				if(NOP_counter_load_H == 1) 						// if we get the signal from another process to load the timer
					NOP_counter  <= NOP_counter_value ;		// Preload timer
				else if(NOP_counter != 16'd0) 					// otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock
					NOP_counter <= NOP_counter - 16'd1 ;		// subtract 1 from the timer value

			always@(NOP_counter) begin
				NOP_counter_done_H <= 0 ;							// default is not done

				if(NOP_counter == 16'd0) 								// if timer has counted down to 0
					NOP_counter_done_H <= 1 ;						// output '1' to indicate time has elapsed
			end
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// CAS COUNTER
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

				always@(posedge Clock)
					if(CAS_counter_load_H == 1) 						// if we get the signal from another process to load the timer
						CAS_counter  <= CAS_counter_value ;		// Preload timer
					else if(NOP_counter != 16'd0) 					// otherwise, provided timer has not already counted down to 0, on the next rising edge of the clock
						CAS_counter <= CAS_counter - 16'd1 ;		// subtract 1 from the timer value

				always@(NOP_counter) begin
					CAS_counter_done_H <= 0 ;							// default is not done

					if(NOP_counter == 16'd0) 								// if timer has counted down to 0
						CAS_counter_done_H <= 1 ;						// output '1' to indicate time has elapsed
				end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-
// concurrent process state registers
// this process RECORDS the current state of the system.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   always@(posedge Clock, negedge Reset_L)
	begin
		if(Reset_L == 0) 							// asynchronous reset
			CurrentState <= InitialisingState ;

		else 	begin									// state can change only on low-to-high transition of clock
			CurrentState <= NextState;

			// these are the raw signals that come from the dram controller to the dram memory chip.
			// This process expects the signals in the form of a 5 bit bus within the signal Command. The various Dram commands are defined above just beneath the architecture)

			SDram_CKE_H <= Command[4];			// produce the Dram clock enable
			SDram_CS_L  <= Command[3];			// produce the Dram Chip select
			SDram_RAS_L <= Command[2];			// produce the dram RAS
			SDram_CAS_L <= Command[1];			// produce the dram CAS
			SDram_WE_L  <= Command[0];			// produce the dram Write enable

			SDram_Addr  <= DramAddress;		// output the row/column address to the dram
			SDram_BA   	<= BankAddress;		// output the bank address to the dram

			// signals back to the 68000

			Dtack_L 		<= CPU_Dtack_L ;			// output the Dtack back to the 68000
			ResetOut_L 	<= CPUReset_L ;			// output the Reset out back to the 68000

			// The signal FPGAWritingtoSDram_H can be driven by you when you need to turn on or tri-state the data bus out signals to the dram chip data lines DQ0-15
			// when you are reading from the dram you have to ensure they are tristated (so the dram chip can drive them)
			// when you are writing, you have to drive them to the value of SDramWriteData so that you 'present' your data to the dram chips
			// of course during a write, the dram WE signal will need to be driven low and it will respond by tri-stating its outputs lines so you can drive data in to it
			// remember the Dram chip has bi-directional data lines, when you read from it, it turns them on, when you write to it, it turns them off (tri-states them)

			if(FPGAWritingtoSDram_H == 1) 			// if CPU is doing a write, we need to turn on the FPGA data out lines to the SDRam and present Dram with CPU data
				SDram_DQ	<= SDramWriteData ;
			else
				SDram_DQ	<= 16'bZZZZZZZZZZZZZZZZ;			// otherwise tri-state the FPGA data output lines to the SDRAM for anything other than writing to it

			DramState <= CurrentState ;					// output current state - useful for debugging so you can see you state machine changing states etc
		end
	end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-
// Concurrent process to Latch Data from Sdram after Cas Latency during read
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-

// this process will latch whatever data is coming out of the dram data lines on the FALLING edge of the clock you have to drive DramDataLatch_H to logic 1
// remember there is a programmable CAS latency for the Zentel dram chip on the DE1 board it's 2 or 3 clock cycles which has to be programmed by you during the initialisation
// phase of the dram controller following a reset/power on
//
// During a read, after you have presented CAS command to the dram chip you will have to wait 2 clock cyles and then latch the data out here and present it back
// to the 68000 until the end of the 68000 bus cycle

	always@(negedge Clock)
	begin
		if(DramDataLatch_H == 1)      			// asserted during the read operation
			DataOut <= SDram_DQ ;					// store 16 bits of data regardless of width - don't worry about tri state since that will be handled by buffers outside dram controller
	end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////-
// next state and output logic
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	always@(*)
	begin

	// In Verilog/VHDL - you will recall - that combinational logic (i.e. logic with no storage) is created as long as you
	// provide a specific value for a signal in each and every possible path through a process
	//
	// You can do this of course, but it gets tedious to specify a value for each signal inside every process state and every if-else test within those states
	// so the common way to do this is to define default values for all your signals and then override them with new values as and when you need to.
	// By doing this here, right at the start of a process, we ensure the compiler does not infer any storage for the signal, i.e. it creates
	// pure combinational logic (which is what we want)
	//
	// Let's start with default values for every signal and override as necessary,
	//

		Command 	<= NOP_command ;												// assume no operation command for Dram chip
		NextState <= InitialisingState ;							// assume next state will always be idle state unless overridden the value used here is not important, we cimple have to assign something to prevent storage on the signal so anything will do

		TimerValue <= 16'h0000;										// no timer value
		RefreshTimerValue <= 16'd0 ;							// no refresh timer value
		TimerLoad_H <= 0;												// don't load Timer
		RefreshTimerLoad_H <= 0 ;									// don't load refresh timer
		DramAddress <= 13'h0000 ;									// no particular dram address
		BankAddress <= 2'b00 ;										// no particular dram bank address
		DramDataLatch_H <= 0;										// don't latch data yet
		CPU_Dtack_L <= 1 ;											// don't acknowledge back to 68000
		SDramWriteData <= 16'h0000 ;								// nothing to write in particular
	//CPUReset_L <= 0 ;												// default is reset to CPU (for the moment, though this will change when design is complete so that reset-out goes high at the end of the dram initialisation phase to allow CPU to resume)
	FPGAWritingtoSDram_H <= 0 ;								// default is to tri-state the FPGA data lines leading to bi-directional SDRam data lines, i.e. assume a read operation

		// put your current state/next state decision making logic here - here are a few states to get you started
		// during the initialising state, the drams have to power up and we cannot access them for a specified period of time (100 us)
		// we are going to load the timer above with a value equiv to 100us and then wait for timer to time out

		if(CurrentState == InitialisingState ) begin
			TimerValue <= 16'd5000;									// chose a value equivalent to 100us at 50Mhz clock - you might want to shorten it to somthing small for simulation purposes //EDITED
		//	TimerValue <= 16'h8;
			TimerLoad_H <= 1 ;										// on next edge of clock, timer will be loaded and start to time out
			CPUReset_L<=0;
			Command <= PoweringUp ;									// clock enable and chip select to the Zentel Dram chip must be held low (disabled) during a power up phase
			NextState <= WaitingForPowerUpState ;				// once we have loaded the timer, go to a new state where we wait for the 100us to elapse
		end

		else if(CurrentState == WaitingForPowerUpState) begin
			CPUReset_L<=0;
			Command <= PoweringUp ;									// no DRam clock enable or CS while witing for 100us timer
			if(TimerDone_H == 1) begin									// if timer has timed out i.e. 100us have elapsed
				NextState <= IssueFirstNOP ;						// take CKE and CS to active and issue a 1st NOP command
				end
			else
				NextState <= WaitingForPowerUpState ;			// otherwise stay here until power up time delay finished
		end

		else if(CurrentState == IssueFirstNOP) begin	 		// issue a valid NOP
			Command <= NOP_command ;											// send a valid NOP command to the dram chip
			NextState <= PrechargingAllBanks;
		end


		// add your other states and conditions and outputs here
		else if(CurrentState == PrechargingAllBanks)begin
			//parameter PrechargeAllBanks = 5'b10010;			// A10 should be logic 1, BA0, BA1 are dont'care, other addreses = don't care
			Command <= PrechargeAllBanks;
			NextState <= IssueSecondNOP;
		end

		else if(CurrentState==IssueSecondNOP)begin
			Command<=NOP_command;
			NextState <= 	AutoRefreshState;
			loop_counter_value<=29; //10*3-1
			loop_counter_load_H<=1;
		end

		else if(CurrentState == AutoRefreshState)begin
			loop_counter_load_H<=0;
			cycle_done=0;
			Command <= AutoRefresh;
			NextState <= first_NOP;
		end

		else if(CurrentState == first_NOP)begin
			Command<=NOP_command;
			NextState <= second_NOP;
		end

		else if(CurrentState == second_NOP)begin
			Command <= NOP_command;
			NextState <=third_NOP;
		end

		else if(CurrentState == third_NOP)begin
			Command<=NOP_command;
			NextState<=SecondAutoRefreshState;
			cycle_done<=1;
			if(loop_counter_done_H== 1) NextState<= Program_Load_Reg;
			else NextState <=AutoRefreshState;
		end

		else if(CurrentState == Program_Load_Reg)begin
			Command <= ModeRegisterSet;
			DramAddress <= 13'h0220;
			NextState <= last_NOP;
		end

		else if(CurrentState==last_NOP)begin
			Command <= NOP_command;
			RefreshTimerValue<=16'd375; //7.5 us
			RefreshTimerLoad_H<=1;
			NextState <= Idle;
			//*******************************END OF THE INISITALIZATION***********************************************
		end	//Should be ready for read/write operation

		else if(CurrentState == Idle)begin
						CAS_counter_load_H<=0;
						CPUReset_L<=1;
						if(RefreshTimerDone_H==1) // @REFRESH REQUESTS
						begin
						Command<=PrechargeAllBanks;
						DramAddress<=13'h0400; //A10 is 1
						NextState<=Idle_NOP;
					end
		// ***************************************START PART 2
					 else if ((DramSelect_L==0) && (AS_L==0))begin //@MEMORY THINGS
					DramAddress<= Address[23:11]; //Map 68k’s A23 - A11 to the row address (i.e. map them to A12 - A0 on the SDram)
					BankAddress<=Address[25:24]; //Issue a 2 bit Bank Address to the Sdram
					Command<= BankActivate; //Activate the bank
					if(WE_L==1) begin
						NextState<=Read_DRAM;
					end
					else NextState<=Write_DRAM;
					end
		//****************************************END PART 2
				else begin
					NextState<=Idle;
					Command<=NOP_command;
					end
				end


		else if(CurrentState == Idle_NOP)begin
			Command<=NOP_command;
			NextState<=Idle_Refresh;
		end

		else if(CurrentState == Idle_Refresh)begin
			Command<=AutoRefresh;
			NextState<= First_NOP_Idle;
		end

		else if(CurrentState == First_NOP_Idle)begin
			Command<=NOP_command;
			NextState<=Second_NOP_Idle;
		end

		else if(CurrentState==Second_NOP_Idle)begin
			Command<=NOP_command;
			NextState<=Third_NOP_Idle;
		end

		else if(CurrentState==Third_NOP_Idle)begin
			Command<=NOP_command;
			RefreshTimerValue<=16'd375; //7.5us
			RefreshTimerLoad_H<=1;
			NextState<= Idle;
		end

			/******************************PART2 *************************************************************************/
			else if(CurrentState == Write_DRAM)begin // ****************************WRITE
				CPUReset_L<=1;
				if((UDS_L==0) || (LDS_L==0))begin//NextState is one where we wait for 68k’s UDS or LDS signals to go low;
					Command<=WriteAutoPrecharge;
					DramAddress[10]<=1;
					DramAddress[9:0]<=Address[10:1];
					CPU_Dtack_L<=0;
					BankAddress<=Address[25:24];
					FPGAWritingtoSDram_H<=1;
					SDramWriteData<=DataIn;
					NextState<= Write_Finish;
				end
				else begin
					Command<=NOP_command;
					DramAddress[9:0]<=Address[10:1];
					NextState<=Write_DRAM;
				end
			end

			else if(CurrentState == Write_Finish)begin
						CPUReset_L<=1;
						CPU_Dtack_L<=0;
						FPGAWritingtoSDram_H<=1;
						SDramWriteData<=DataIn;
						Command<=NOP_command;
						NextState<=Current_Cycle;
			end
			else if(CurrentState == Read_DRAM)begin// *********************READ
				CPUReset_L<=1;
				Command<=ReadAutoPrecharge; //CAS*
				DramAddress[10]<=1; //A10 =1
				DramAddress[9:0]<=Address[10:1];
				BankAddress<= Address[25:24];
				TimerValue<=2;//2
				TimerLoad_H<=1;
				NextState<= CAS_Latency1;
			end

			//**********CAS LATENCY **********
			else if(CurrentState==CAS_Latency1)begin
					CPUReset_L<=1;
					CPU_Dtack_L<=0;
					Command<=NOP_command;
					if(TimerDone_H==1) begin
						NextState<=Current_Cycle;
						DramDataLatch_H<=1;
					end
					else NextState<=CAS_Latency1;
			end

			else if(CurrentState==Current_Cycle) begin
					CPUReset_L<=1;
					Command<=NOP_command;
					if((UDS_L==0) || (LDS_L==0))begin
						CPU_Dtack_L<=0;
						NextState<=Current_Cycle;
					end
					else begin
						NextState<=Idle;
					end
			end

			else begin
				Command<=NOP_command;
				CPUReset_L<=1;
				NextState<=Idle;
			end
			//***************************************END PART 2
	end	// always@ block
endmodule
