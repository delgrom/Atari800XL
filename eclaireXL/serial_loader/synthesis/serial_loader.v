// serial_loader.v

// Generated using ACDS version 15.0 153

`timescale 1 ps / 1 ps
module serial_loader (
		input  wire  noe_in  // noe_in.noe
	);

	altera_serial_flash_loader #(
		.INTENDED_DEVICE_FAMILY  ("Cyclone V"),
		.ENHANCED_MODE           (1),
		.ENABLE_SHARED_ACCESS    ("OFF"),
		.ENABLE_QUAD_SPI_SUPPORT (1),
		.NCSO_WIDTH              (1)
	) serial_flash_loader_0 (
		.noe_in (noe_in)  // noe_in.noe
	);

endmodule
