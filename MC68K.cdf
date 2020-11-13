/* Quartus II 64-Bit Version 15.0.0 Build 145 04/22/2015 SJ Web Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Ign)
		Device PartName(SOCVHPS) MfrSpec(OpMask(0));
	P ActionCode(Cfg)
		Device PartName(5CSEMA5F31) Path("C:/M68kV6.0 - 800by48/") File("MC68K.sof") MfrSpec(OpMask(1) SEC_Device(EPCS128) Child_OpMask(1 0));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
