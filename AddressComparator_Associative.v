module AddressComparator_Associative(
  input [24:0] AddressBus,
  input [24:0] TagData,

  output reg Hit_H
);

always@(*)begin
  if(AddressBus == TagData) Hit_H=1;
  else Hit_H = 0;
end

endmodule
