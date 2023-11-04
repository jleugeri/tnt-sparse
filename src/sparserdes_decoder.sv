
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
