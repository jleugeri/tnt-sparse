
module tt_um_jleugeri_sparserdes (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


    logic reset;
    assign reset = ~rst_n;

    localparam SIZE = 8;
    logic decode_valid;
    logic bitstream_internal;

    assign uio_oe     = 8'b11000000;
    assign uio_out[5:0] = 6'b000000;
    assign uio_out[6] = bitstream_internal;

    logic [2:0] instructions1;
    logic [2:0] instructions2;
    assign instructions1 = uio_in[3] ? 3'b000 : uio_in[2:0];
    assign instructions2 = uio_in[3] ? uio_in[2:0] : 3'b000;

    // dummy wires
    logic [7:0] addr_in_dummy, addr_out_dummy;
    logic bistream_out_dummy, done_dummy;

    // instantiate the module
    sparserdes #(
        .SIZE(SIZE)
    ) s1 (
        .clk(clk),
        .reset(reset),
        .enable(ena),
        .instruction(instructions1),
        .addr_in(ui_in),
        .addr_out(uo_out),
        .bitstream_in(uio_in[5]),
        .bitstream_out(bitstream_internal),
        .done(uio_out[7])
    );


    sparserdes #(
        .SIZE(SIZE)
    ) s2 (
        .clk(clk),
        .reset(reset),
        .enable(ena),
        .instruction(instructions2),
        .addr_in(addr_in_dummy),
        .addr_out(addr_out_dummy),
        .bitstream_in(bitstream_internal),
        .bitstream_out(bitstream_out_dummy),
        .done(done_dummy)
    );

endmodule: tt_um_jleugeri_sparserdes