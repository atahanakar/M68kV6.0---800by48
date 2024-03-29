module SPI_BUS_Decoder(
  input unsigned [31:0]Address,
  input SPI_Select_H,
  input AS_L,

  output reg SPI_Enable_H
  );

  always@(*)begin
    SPI_Enable_H<=0;
    if( (AS_L == 0) && SPI_Select_H==1 && (Address[15:0]>=16'h8020 && Address[15:0]<=16'h802F)) //Lower 16 bits,
      SPI_Enable_H<=1;
  end



endmodule
