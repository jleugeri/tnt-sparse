
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
                        end
                    end

                    // 3'b001: refractory state (give parent one cycle to stop requesting)
                    3'b001 : begin
                        state <= 3'b000;
                        done <= 0;
                        serialized_bit <= 0;
                        write_high <= 0;
                        write_low <= 0;
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
                        write_low <= 1;
                        write_high <= 0;
                        // next, go to receiving high bit state
                        state <= 3'b111;
                    end

                    // 3'b111: receiving high bit and then go to refractory state
                    3'b111 : begin
                        // send the high bit
                        write_high <= 1;
                        write_low <= 0;
                        // next, go to refractory state
                        state <= 3'b001;
                        // we're done now
                        done <= 1;
                    end

                    default: begin
                        state <= 3'b000;
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
                        state <= 3'b000;
                    end
                endcase
            end
        end
    end

endmodule : sparserdes_node
