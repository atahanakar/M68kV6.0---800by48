module SramBlockDecoder_Verilog( 
		input unsigned [16:0] Address, // lower 17 lines of address bus from 68k
		input SRamSelect_H,				 // from main (top level) address decoder indicating 68k is talking to Sram
		
		// 4 separate block select signals that parition 256kbytes (128k words) into 4 blocks of 64k (32 k words)
		output reg Block0_H, 
		output reg Block1_H, 
		output reg Block2_H, 
		output reg Block3_H 
);	

	always@(*)	begin
	
		// default block selects are inactive - override as appropriate later
		
		Block0_H <= 0; 
		Block1_H <= 0;
		Block2_H <= 0; 
		Block3_H <= 0;
	
		// decode the top two address lines plus SRamSelect to provide 4 block select signals
		// for 4 blocks of 64k bytes (32k words) to give 256k bytes in total
	
		// TODO
		if (SRamSelect_H)
		casex(Address) 
		17'b0_0xxx_xxxx_xxxx_xxxx:{Block0_H,Block1_H,Block2_H,Block3_H}<=4'b1000; //Activate Block 0
		17'b0_1xxx_xxxx_xxxx_xxxx:{Block0_H,Block1_H,Block2_H,Block3_H}<=4'b0100;//Activate Block 1
		17'b1_0xxx_xxxx_xxxx_xxxx:{Block0_H,Block1_H,Block2_H,Block3_H}<=4'b0010;//Activate Block 2
		17'b1_1xxx_xxxx_xxxx_xxxx:{Block0_H,Block1_H,Block2_H,Block3_H}<=4'b0001;//Activate Block 3
		endcase

		
		
		
	end
endmodule
