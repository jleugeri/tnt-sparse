`default_nettype none

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
    logic bitstream_internal;

    assign uio_oe     = 8'b11000000;
    assign uio_out[5:0] = 6'b000000;
    assign uio_out[6] = bitstream_internal;

    logic [2:0] instructions1;
    logic [2:0] instructions2;
    assign instructions1 = uio_in[3] ? 3'b000 : uio_in[2:0];
    assign instructions2 = uio_in[3] ? uio_in[2:0] : 3'b000;

    logic [$clog2(SIZE)-1:0] addr_in;
    assign addr_in = ui_in[$clog2(SIZE)-1:0];
    
    wire [7:$clog2(SIZE)] _ui_in_unused;
    assign _ui_in_unused = ui_in[7:$clog2(SIZE)];


    logic [$clog2(SIZE)-1:0] addr_out;
    assign uo_out[$clog2(SIZE)-1:0] = addr_out;
    assign uo_out[7:$clog2(SIZE)] = 0;

    logic bitstream_in, done;
    assign bitstream_in = uio_in[5];
    assign uio_out[7] = done;

    // instantiate the module
    sparserdes #(
        .SIZE(SIZE)
    ) s1 (
        .clk(clk),
        .reset(reset),
        .enable(ena),
        .instruction(instructions1),
        .addr_in(addr_in),
        .addr_out(addr_out),
        .bitstream_in(bitstream_in),
        .bitstream_out(bitstream_internal),
        .done(done)
    );

endmodule: tt_um_jleugeri_sparserdes
