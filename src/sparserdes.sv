// *Sp*arse *ar*ray *ser*ializer/*des*erializer

module sparserdes_node #(
    parameter LEAF = 0
) (
    // clock signal
    input logic clk,

    // reset signal
    input logic reset,

    // input, signals if the low sub-sub-tree is nonempty (1) or empty (0)
    input logic nonempty_low,

    // input, signals if the high sub-sub-tree is nonempty (1) or empty (0)
    input logic nonempty_high,

    // output, signals to the parent if this sub-tree is nonempty (1) or empty (0)
    output logic nonempty,

    // input, serialized bits coming from low sub-sub-tree
    input logic serialized_bit_low,

    // input, serialized bits coming from high sub-sub-tree
    input logic serialized_bit_high,

    // output, sends the bits generated during serialization to the parent
    output logic serialized_bit,

    // output, signals to the low sub-sub-tree that it should start serializing
    output logic read_low,

    // output, signals to the high sub-sub-tree that it should start serializing
    output logic read_high,

    // input, signals that the parents want to read from this sub-tree
    input logic read,

    // input, signals that the low sub-sub-tree is done serializing
    input logic done_low,

    // input, signals that the high sub-sub-tree is done serializing
    input logic done_high,

    // output, signals to the parent that this sub-tree is done serializing
    output logic done,

    // === DESERIALIZATION ===
    // output, deserialized bits going to low sub-sub-tree
    output logic deserialized_bit_low,

    // output, deserialized bits going to high sub-sub-tree
    output logic deserialized_bit_high,

    // input, gets deserialized bit from the parent
    input logic deserialized_bit,

    // output, signals to the low sub-sub-tree that it should start deserializing
    output logic write_low,

    // output, signals to the high sub-sub-tree that it should start deserializing
    output logic write_high,

    // input, signals that the parents want to write to this sub-tree
    input logic write
);

    logic [2:0] state;

    if (LEAF) begin
        assign nonempty = nonempty_low | nonempty_high;

        always_ff @ (posedge clk) begin
            if ( reset ) begin
                state <= 3'b000;
                done <= 0;
                read_low <= 0;
                read_high <= 0;
                serialized_bit <= 0;
                write_low <= 0;
                write_high <= 0;
                deserialized_bit_low <= 0;
                deserialized_bit_high <= 0;
            end
            else begin
                case (state)
                    // 3'b000: idle, i.e. do nothing, but wait for trigger from above
                    // when triggered, immediately send/receive the low bit, then move to sending/receiving high bit state
                    3'b000: begin
                        if ( read ) begin
                            // now send the low bit
                            serialized_bit <= nonempty_low;
                            // next state will be sending high bit
                            state <= 3'b010;
                        end
                        else if (write) begin
                            if (deserialized_bit) begin
                                // next state will be idle-before-wait-low
                                state <= 3'b100;
                            end
                            else begin
                                // next state will be idle-before-wait-high
                                state <= 3'b101;
                            end
                        end
                        else begin
                            serialized_bit <= 0;
                            deserialized_bit_low <= 0;
                            deserialized_bit_high <= 0;
                        end
                    end

                    // 3'b001: refractory state (give parent one cycle to stop requesting)
                    3'b001 : begin
                        state <= 3'b000;
                        done <= 0;
                        serialized_bit <= 0;
                        deserialized_bit_low <= 0;
                        deserialized_bit_high <= 0;
                    end

                    // 3'b010: sending high bit and then go to refractory state
                    3'b010 : begin
                        // send the high bit
                        serialized_bit <= nonempty_high;
                        // next, go to refractory state
                        state <= 3'b001;
                        // we're done now
                        done <= 1;
                    end

                    // 3'b100: idle-before-low
                    3'b100 : begin
                        state <= 3'b110;
                    end

                    // 3'b101: idle-before-high
                    3'b101 : begin
                        state <= 3'b111;
                    end

                    // 3'b110: receiving low bit
                    3'b110 : begin
                        // send the low bit
                        deserialized_bit_low <= deserialized_bit;
                        // next, go to receiving high bit state
                        state <= 3'b111;
                    end

                    // 3'b111: receiving high bit and then go to refractory state
                    3'b111 : begin
                        // send the high bit
                        deserialized_bit_high <= deserialized_bit;
                        // next, go to refractory state
                        state <= 3'b001;
                        // we're done now
                        done <= 1;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end 
    else begin
        always_ff @( posedge clk ) begin
            if(reset) begin
                nonempty <= 0;
                state <= 3'b000;
                done <= 0;
                read_low <= 0;
                read_high <= 0;
                serialized_bit <= 0;
                write_low <= 0;
                write_high <= 0;
                deserialized_bit_low <= 0;
                deserialized_bit_high <= 0;
            end 
            else begin
                nonempty <= nonempty_low | nonempty_high;

                case (state)
                    // 3'b000: idle, i.e. do nothing, but wait for trigger from above
                    3'b000: begin
                        // if we should read from this sub-tree, check which sub-sub-tree to descend into
                        if (read) begin
                            // first try to go into the low sub-sub-tree
                            // if there is nothing there, instead go into the high sub-sub-tree 
                            // (it should be either of the two, otherwise we wouldn't be here)
                            if (nonempty_low) begin
                                // next state will be wait-low
                                state <= 3'b010;
                                // send out bit 1 (did descend) for the low sub-sub-tree
                                serialized_bit <= 1;
                                // inform low sub-sub-tree, that it's its turn now
                                read_low <= 1;
                                read_high <= 0;
                            end
                            else begin
                                // next state will be wait-high
                                state <= 3'b011;
                                // send out bit 0 (did not descend) for the low sub-sub-tree
                                // implicitly, this also means we did descend into the high sub-sub-tree 
                                serialized_bit <= 1'b0;
                                // inform high sub-sub-tree, that it's its turn now
                                read_low <= 0;
                                read_high <= 1;
                            end
                        end
                        // if we should write to this sub-tree, check which sub-sub-tree to descend into
                        else if (write) begin
                            if (deserialized_bit) begin
                                // next state will be idle-before-wait-low
                                state <= 3'b100;
                            end
                            else begin
                                // next state will be idle-before-wait-high
                                state <= 3'b101;
                            end
                        end
                        else begin
                            serialized_bit <= 1'b0;
                        end

                        // we're definitely not done yet
                        done <= 0;
                    end

                    // 3'b001: refractory state (give parent one cycle to stop requesting)
                    3'b001 : begin
                        state <= 3'b000;
                        done <= 0;
                        serialized_bit <= 1'b0;
                        deserialized_bit_low <= 0;
                        deserialized_bit_high <= 0;
                    end

                    // 3'b010: wait-low
                    3'b010: begin
                        // pass on whatever output comes from the low sub-sub-tree
                        serialized_bit <= serialized_bit_low;

                        // when the low sub-sub-tree is finished, we can move on
                        if ( done_low ) begin
                            // if there is also something in the high sub-sub-tree, go there next
                            if ( nonempty_high ) begin
                                // next state will be wait-high
                                state <= 3'b011;
                                // inform high sub-sub-tree, that it's its turn now
                                read_low <= 0;
                                read_high <= 1;
                            end
                            // otherwise we're done!
                            else begin
                                // next, go to refractory state
                                state <= 3'b001;
                                // signal up that we're done
                                done <= 1;
                                // leave the sub-sub-trees alone now
                                read_low <= 0;
                                read_high <= 0;
                            end
                        end
                    end

                    // 3'b011: wait-high
                    3'b011: begin
                        // pass on whatever output comes from the low sub-sub-tree
                        serialized_bit <= serialized_bit_high;

                        // when the low sub-sub-tree is finished, we're done!
                        if ( done_high ) begin
                            // next, go to refractory state
                            state <= 3'b001;
                            // signal up that we're done
                            done <= 1;
                            // leave the sub-sub-trees alone now
                            read_low <= 0;
                            read_high <= 0;
                        end
                    end

                    // 3'b100: idle-before-wait-low
                    3'b100 : begin
                        state <= 3'b110;
                        // inform low sub-sub-tree, that it's its turn now
                        write_low <= 1;
                        write_high <= 0;
                    end

                    // 3'b101: idle-before-wait-high
                    3'b101 : begin
                        state <= 3'b111;
                        // inform high sub-sub-tree, that it's its turn now
                        write_low <= 0;
                        write_high <= 1;
                    end

                    // 3'b110: wait-low
                    3'b110: begin
                        // pass on whatever input comes for the low sub-sub-tree
                        deserialized_bit_low <= deserialized_bit;

                        // when the low sub-sub-tree is finished, we can move on
                        if ( done_low ) begin
                            // if there is also something in the high sub-sub-tree, go there next
                            if ( deserialized_bit ) begin
                                // next state will be wait-high
                                state <= 3'b111;
                                // inform high sub-sub-tree, that it's its turn now
                                write_low <= 0;
                                write_high <= 1;
                            end
                            // otherwise we're done!
                            else begin
                                // next, go to refractory state
                                state <= 3'b001;
                                // signal up that we're done
                                done <= 1;
                                // leave the sub-sub-trees alone now
                                write_low <= 0;
                                write_high <= 0;
                            end
                        end
                    end

                    // 3'b111: wait-high
                    3'b111: begin
                        // pass on whatever output comes from the low sub-sub-tree
                        deserialized_bit_high <= deserialized_bit;

                        // when the low sub-sub-tree is finished, we're done!
                        if ( done_high ) begin
                            // next, go to refractory state
                            state <= 3'b001;
                            // signal up that we're done
                            done <= 1;
                            // leave the sub-sub-trees alone now
                            write_low <= 0;
                            write_high <= 0;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule : sparserdes_node

module sparserdes_decoder #(
    parameter int SIZE
) (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic bitstream,
    output logic valid,
    output logic [$clog2(SIZE)-1:0] addr_out
);

    localparam DEPTH = $clog2(SIZE);
    logic [$clog2(DEPTH)-1:0] level;

    logic [2:0] state;
    
    always_ff @( posedge clk ) begin
        if (reset) begin
            level <= DEPTH-1;
            valid <= 0;
            addr_out <= 0;
            state <= 3'b000;
        end
        else begin
            case (state)
                // 3'b000: wait for enable signal
                3'b000: begin
                    if (enable) begin
                        state <= 3'b001;
                    end
                end

                // 3'b001: delay by one cycle
                3'b001: begin
                    state <= 3'b010;
                end

                // 3'b010: enter node from above, start at the LSB
                3'b010: begin
                    
                    // if we reached the leaf nodes, don't go down any further
                    if ( level == 0 ) begin
                        // if the current bit is set, we have a valid address
                        if (bitstream) begin
                            addr_out[0] <= 0;
                            valid <= 1;
                        end
                        else begin
                            valid <= 0;
                        end

                        // go to MSB
                        state <= 3'b010;
                    end
                    // otherwise, go down
                    else begin
                        level <= level - 1;
                        state <= 3'b001; // delay by one cycle
                        // if the current bit is set, descend into the low sub-sub-tree, otherwise into the high sub-sub-tree
                        addr_out[level] <= ~bitstream;
                    end
                end

                // 3'b011: enter MSB node
                3'b011: begin
                    addr_out[level] <= 1;

                    // if we reached the leaf nodes, don't go down any further
                    if ( level == 0 ) begin
                        // if the current bit is set, we have a valid address
                        if (bitstream) begin
                            addr_out <= addr_out;
                            valid <= 1;
                        end
                        else begin
                            valid <= 0;
                        end

                        // go up
                    end
                    else begin
                    end
                end

                default: begin
                    state <= 3'b000;
                end
            endcase



/*
                    // 2'b00: moving down
                    2'b00: begin
                        // if the bit is one, we go down the low sub-sub-tree / write the low value, otherwise the high

                        // on the lowest level, just write valid addresses out
                        if (level == 0) begin
                            if (bitstream) begin
                                addr_bits[level] <= 0;
                                addr_out <= addr_bits;
                                valid <= 1;
                            end
                            else begin
                                valid <= 0;
                            end

                            state <= 2'b01;
                        end
                        // on higher levels, go further down - either to the low or the high sub-sub-tree
                        else begin
                            level <= level - 1;
                            state <= 2'b11;
                        end
                    end

                    // 2'b01: for high bit of leaf, either write the high value or go directly up
                    2'b01: begin
                        // on the lowest level, write the address out (if valid)
                        // otherwise, go up
                        if (bitstream) begin
                            addr_bits[level] <= 1;
                            addr_out <= addr_bits;
                            valid <= 1;
                        end
                        else begin
                            valid <= 0;
                        end
                        state <= 2'b10;
                    end

                    // 2'b10: going up
                    2'b10: begin
                        // if we're on the highest level, we're done
                        if (level == DEPTH-1) begin
                            state <= 2'b00;
                        end
                        // otherwise, go up
                        else begin
                            level <= level + 1;
                            state <= 2'b00;
                        end
                    end
                    
                    // 2'b11: going down, but skipping an empty bit
                    2'b11: begin
                        state <= 2'b00;
                    end
                endcase
                */
        end
    end

endmodule : sparserdes_decoder

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
    logic [SIZE-1:0] read_select;
    logic [SIZE-1:0] write_select;

    genvar l, n;
    generate
        for (l = 0; l < DEPTH; l = l + 1) begin : level
            wire [SIZE-1:0] nonempty_in;
            wire [SIZE-1:0] nonempty_out;
            wire [SIZE-1:0] serialized_bits_in;
            wire [SIZE-1:0] serialized_bits_out;
            wire [SIZE-1:0] read_in;
            wire [SIZE-1:0] read_out1;
            wire [SIZE-1:0] read_out2;

            wire [SIZE-1:0] deserialized_bits_in;
            wire [SIZE-1:0] deserialized_bits_out1;
            wire [SIZE-1:0] deserialized_bits_out2;
            wire [SIZE-1:0] write_in;
            wire [SIZE-1:0] write_out1;
            wire [SIZE-1:0] write_out2;

            wire [SIZE-1:0] done_in;
            wire [SIZE-1:0] done_out;

            if (l == 0) begin
                assign nonempty_in = leafs;
                assign done_in = {SIZE{1'b0}};
                assign serialized_bits_in = {SIZE{1'b0}};
                assign leafs_shadow = deserialized_bits_out1 | deserialized_bits_out2;
            end else begin
                // bottom up signals
                assign nonempty_in = level[l-1].nonempty_out;
                assign done_in = level[l-1].done_out;
                assign serialized_bits_in = level[l-1].serialized_bits_out;

                // top-down signals
                assign level[l-1].read_in = read_out1 | read_out2;
                assign level[l-1].write_in = write_out1 | write_out2;
                assign level[l-1].deserialized_bits_in = deserialized_bits_out1 | deserialized_bits_out2;
            end
            
            for (n = 0; n < SIZE; n = n + 1) begin : node
                sparserdes_node #( .LEAF(l==0) ) node ( 
                    .clk(clk), 
                    .reset(reset), 
                    .nonempty_low(nonempty_in[n]), 
                    .nonempty_high(nonempty_in[(n+(1 << l)) % SIZE]), 
                    .nonempty(nonempty_out[n]),
                    .serialized_bit_low(serialized_bits_in[n]),
                    .serialized_bit_high(serialized_bits_in[(n+(1 << l)) % SIZE]),
                    .serialized_bit(serialized_bits_out[n]),
                    .deserialized_bit_low(deserialized_bits_out1[n]),
                    .deserialized_bit_high(deserialized_bits_out2[(n+(1 << l)) % SIZE]),
                    .deserialized_bit(deserialized_bits_in[n]),
                    .read_low(read_out1[n]),
                    .read_high(read_out2[(n+(1 << l)) % SIZE]),
                    .write_low(write_out1[n]),
                    .write_high(write_out2[(n+(1 << l)) % SIZE]),
                    .read(read_in[n]),
                    .write(write_in[n]),
                    .done_low(done_in[n]),
                    .done_high(done_in[(n+(1 << l)) % SIZE]),
                    .done(done_out[n])
                );
            end
        end
    endgenerate

    // connect to level to module's signals
    assign level[DEPTH-1].read_in = read_select;
    assign bitstream_out = level[DEPTH-1].serialized_bits_out[0];
    assign level[DEPTH-1].write_in = write_select;
    assign level[DEPTH-1].deserialized_bits_in[0] = bitstream_in;

    assign level[DEPTH-1].deserialized_bits_in[7:1] = 7'b0000000;

    logic enable_decoder;
    /*
    // add the address decoder
    sparserdes_decoder #(
        .SIZE(8)
    ) d (
        .clk(clk),
        .reset(reset),
        .enable(enable_decoder),
        .bitstream(level[DEPTH-1].serialized_bits_out[0]),
        .addr_out(addr_out),
        .valid(decode_valid)
    );*/
    
    always_ff @( posedge clk ) begin
        if (reset) begin
            state <= 3'b000;
            leafs <= 8'b0000_0000;
            read_select <= 0;
            write_select <= 0;
            done <= 0;
            enable_decoder <= 0;
            addr_out <= 0;
        end
        else begin
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

                        // 3'b010: reserved
                        3'b010: begin
                        end

                        // 3'b011: start iterating once inputs have settled
                        3'b011: begin
                            state <= 3'b001;
                            countdown <= DEPTH;
                        end

                        // 3'b100: reserved
                        3'b100: begin
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
                            write_select <= (1'b1 << addr_in);
                        end
                    endcase
                end

                // 3'b001: waiting for inputs to settle
                3'b001: begin
                    if (countdown == 0) begin
                        state <= 3'b010;
                        enable_decoder <= 1;
                        read_select <= (1'b1 << addr_in);

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
                    enable_decoder <= 0;
                end

                // 3'b100: receiving bits from bitstream
                3'b100: begin
                    if (level[DEPTH-1].done_out[0]) begin
                        state <= 3'b011;
                        done <= 1;
                        write_select <= 0;
                    end
                end
            endcase
        end
    end

endmodule : sparserdes
