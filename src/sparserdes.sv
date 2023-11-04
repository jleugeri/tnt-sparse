// *Sp*arse *ar*ray *ser*ializer/*des*erializer

module sparserdes #(
    parameter int SIZE
) (
    input logic clk,
    input logic reset, 
    input logic enable,
    input logic [2:0] instruction,
    input logic [$clog2(SIZE)-1:0] addr_in,
    output logic [$clog2(SIZE)-1:0] addr_out,
    input logic bitstream_in,
    output logic bitstream_out,
    output logic done
);

    logic [2:0] state;

    localparam DEPTH = $clog2(SIZE);

    logic [$clog2(DEPTH)-1:0] countdown;

    logic [SIZE-1:0] leafs;
    logic [SIZE-1:0] leafs_shadow;
    logic read_select, write_select;

    genvar l, n;
    generate
        for (l = 0; l < DEPTH; l = l + 1) begin : level
            wire [(SIZE>>l)-1:0] nonempty_in;
            wire [(SIZE>>(l+1))-1:0] nonempty_out;
            wire [(SIZE>>l)-1:0] serialized_bits_in;
            wire [(SIZE>>(l+1))-1:0] serialized_bits_out;
            wire [(SIZE>>(l+1))-1:0] read_in;
            wire [(SIZE>>l)-1:0] read_out;

            wire [(SIZE>>(l+1))-1:0] write_in;
            wire [(SIZE>>l)-1:0] write_out;

            wire [(SIZE>>l)-1:0] done_in;
            wire [(SIZE>>(l+1))-1:0] done_out;

            if (l == 0) begin
                assign nonempty_in = leafs;
                assign done_in = {SIZE{1'b0}};
                assign serialized_bits_in = {SIZE{1'b0}};
                assign leafs_shadow = write_out;
            end else begin
                // bottom up signals
                assign nonempty_in = level[l-1].nonempty_out;
                assign done_in = level[l-1].done_out;
                assign serialized_bits_in = level[l-1].serialized_bits_out;

                // top-down signals
                assign level[l-1].read_in = read_out;
                assign level[l-1].write_in = write_out;
            end
            
            for (n = 0; n < (SIZE>>(l+1)); n = n + 1) begin : node
                sparserdes_node #( .LEAF(l==0) ) node ( 
                    .clk(clk), 
                    .reset(reset), 
                    .nonempty_low(nonempty_in[2*n]), 
                    .nonempty_high(nonempty_in[2*n+1]), 
                    .nonempty(nonempty_out[n]),
                    .serialized_bit_low(serialized_bits_in[2*n]),
                    .serialized_bit_high(serialized_bits_in[2*n+1]),
                    .serialized_bit(serialized_bits_out[n]),
                    .deserialized_bit(bitstream_in),
                    .read_low(read_out[2*n]),
                    .read_high(read_out[2*n+1]),
                    .write_low(write_out[2*n]),
                    .write_high(write_out[2*n+1]),
                    .read(read_in[n]),
                    .write(write_in[n]),
                    .done_low(done_in[2*n]),
                    .done_high(done_in[2*n+1]),
                    .done(done_out[n])
                );
            end
        end
    endgenerate

    // connect to level to module's signals
    assign level[DEPTH-1].read_in = read_select;
    assign level[DEPTH-1].write_in = write_select;
    assign bitstream_out = level[DEPTH-1].serialized_bits_out;

    
    always_ff @( posedge clk ) begin
        if (reset) begin
            state <= 3'b000;
            leafs <= 8'b0000_0000;
            read_select <= 0;
            write_select <= 0;
            done <= 0;
            addr_out <= 0;
        end
        else if (enable) begin
            case (state)
                // 3'b000: collecting inputs
                3'b000: begin
                    case (instruction)
                        // 3'b000: do nothing
                        3'b000: begin
                        end

                        // 3'b001: read bit
                        3'b001: begin
                            addr_out <= ($clog2(SIZE))'(leafs[addr_in]);
                        end

                        // 3'b010: clear all bits
                        3'b010: begin
                            leafs <= 0;
                        end

                        // 3'b011: start iterating once inputs have settled
                        3'b011: begin
                            state <= 3'b001;
                            countdown <= ($clog2(SIZE))'(DEPTH);
                        end

                        // 3'b100: shift the leaf nodes (e.g. directly before or after iteration)
                        3'b100: begin
                            // circular shift of the leaf values by the value given in addr_in
                            leafs <= (leafs << addr_in) | (leafs >> (SIZE - addr_in));
                        end

                        // 3'b101: directly set bit
                        3'b101: begin
                            leafs[addr_in] <= 1;
                        end

                        // 3'b110: directly clear bit
                        3'b110: begin
                            leafs[addr_in] <= 0;
                        end

                        // 3'b111: start receiving bits from bitstream
                        3'b111: begin
                            state <= 3'b100;
                            write_select <= 1;
                        end
                    endcase
                end

                // 3'b001: waiting for inputs to settle
                3'b001: begin
                    if (countdown == 0) begin
                        state <= 3'b010;
                        //enable_decoder <= 1;
                        read_select <= 1;

                    end
                    else begin
                        countdown <= countdown - 1;
                    end
                end

                // 3'b010: iterating over tree
                3'b010: begin
                    if (level[DEPTH-1].done_out[0]) begin
                        state <= 3'b011;
                        done <= 1;
                        read_select <= 0;
                    end
                end

                // 3'b011: refractory state (give host one cycle to collect data)
                3'b011: begin
                    state <= 3'b000;
                    done <= 0;
                    //enable_decoder <= 0;
                end

                // 3'b100: receiving bits from bitstream
                3'b100: begin
                    leafs <= leafs | leafs_shadow;
                    if (level[DEPTH-1].done_out[0]) begin
                        state <= 3'b011;
                        done <= 1;
                        write_select <= 0;
                    end
                end

                default: begin
                    state <= 3'b000;
                end
            endcase
        end
    end

endmodule : sparserdes
