`timescale 1ns/1ps
`default_nettype none

module boseben_cache( input wire clk,
                      input wire [31:0] cpu_address,
                      input wire [7:0] write_data,
                      input wire we,
                      input wire re,
                      input wire rst,
                      output wire [7:0] read_data_out,
                      output wire stall_cpu
);

reg [31:0] data_bank_1 [0:511];
reg [31:0] data_bank_2 [0:511];

reg [31:0] temp_data_1;
reg [31:0] temp_data_2;
reg [7:0] read_data;
assign read_data_out = read_data;

reg dirty_bit_1 [0:511];
reg valid_bit_1 [0:511];
reg LRU_bit_1 [0:511];
reg dirty_bit_2 [0:511];
reg valid_bit_2 [0:511];
reg LRU_bit_2 [0:511];

reg [20:0] tag_1 [0:511];
reg [20:0] tag_2 [0:511];

wire[8:0] index;
wire[1:0]offset;
wire [19:0] tag;

assign tag[19:0] = cpu_address[31:11];
assign index[8:0] = cpu_address[10:2];
assign offset[1:0] = cpu_address[1:0];

// Declaration of memory variables

reg memory_we, memory_re;
reg [31:0] memory_out;
reg [31:0] memory_in;
reg [31:0] memory_addr;

wire memory_we_ram, memory_re_ram;
wire [31:0] memory_out_ram;
wire [31:0] memory_in_ram;
wire [31:0] memory_addr_ram;
  
assign memory_we_ram = memory_we;
assign memory_re_ram = memory_re;
assign memory_out_ram = memory_out;
assign memory_in_ram = memory_in;
assign memory_addr_ram = memory_addr;

///////////////////////////////////

// Memory waiting operation

wire mem_wait;

// prev_state write cache or read cache 
reg [1:0] rd_or_wr;

// memory_counter
reg [2:0] counter;
wire [2:0] counter_out;

reg count_yes;
assign counter_out = counter;

always @(posedge clk) begin

    if(count_yes == 0)
    begin
        counter <= 3'b0;
    end
    else begin
    counter <= counter + 1;
    end
end

boseben_ram ram1 ( .clk(clk),
                  .mem_we(memory_we_ram),
                  .mem_re(memory_re_ram),
                  .mem_addr(memory_addr_ram),
                  .mem_data_out(memory_out_ram),
                  .mem_data_in(memory_in_ram)
);


integer i;
// Write the initial block for populating the data into the memory
initial begin
    //$readmemb("ram1.txt", data_bank_1);
    //$readmemb("ram2.txt", data_bank_2);

    for(i = 0; i<512 ; i = i + 1)
    begin 
        valid_bit_1[i] = 1'b0;
        valid_bit_2[i] = 1'b0;
        dirty_bit_1[i] = 1'b0;
        dirty_bit_2[i] = 1'b0;
        LRU_bit_1[i] = 1'b0;
        LRU_bit_2[i] = 1'b0;
    end

end


// Temperory latch to store entire data in both ways

always @(posedge clk) begin
temp_data_1 <= data_bank_1[index];
temp_data_2 <= data_bank_2[index];
end 

// assign temp_data_1 = data_bank_1[index];
// assign temp_data_2 = data_banl_2[index];


reg [2:0] state, next_state;

// parameter declaration for states of the FSM

parameter IDLE = 3'b000,
          READ_CACHE = 3'b001,
          WRITE_CACHE = 3'b010,
          UPDATE_MEM  = 3'b011,
          WAIT_MEM = 3'b100,
          READ_MEM = 3'b101,
          UPDATE_CACHE = 3'b110;


// State Increment
always @(posedge clk or posedge rst) begin

if(rst == 1) begin 
    state <= IDLE;
end
else begin
    state <= next_state;
end 
end 


/* State Description of the FSM for the Cache Controller

1. IDLE = This state is achieved when both write enabe and read enable signals are low 
2. If the read_enable is high the state is transffered to the READ_CACHE. 
3. If hit i.e valid == 1 ,tag == match, return to IDLE , return data on read_data signal
4. if valid == 0 || tag != match , find LRU , if dirty bit == 0, move to READ_MEM, read the new 2 32 bit data.
5. After READ_MEM, move to UPDATE_CACHE, move to IDLE
6. if dirty_bit == 1, move to UPDATE_MEM, then to UPDATE_CACHE and so on...
7. if write_enable is high, state transferred from IDLE to WRITE_CACHE.
8. If hit, move back to the IDLE state. 
9. If miss, find LRU, if dirty_bit == 0, move to READ_MEM -> UPDATE_CACHE -> IDLE
10. If dirty bit == 1 , move to UPDATE_MEM -> UPDATE_CACHE -> IDLE
*/

always @(*) begin
counter <= 3'b0;
case(state)

IDLE : begin
        if(we == 1) begin 
            next_state = WRITE_CACHE;
        end
        else if (re == 1) begin 
            next_state = READ_CACHE;
        end
        else  begin
            next_state = IDLE;
        end
       end

READ_CACHE : begin
              if(tag == tag_1[index] && valid_bit_1[index] == 1) begin
                read_data = (offset == 2'b00)?temp_data_1[7:0]:
                            (offset == 2'b01)?temp_data_1[15:8]:
                            (offset == 2'b10)?temp_data_1[23:16]:
                            (offset == 2'b11)?temp_data_1[31:24]:
                            8'b0;
                
                LRU_bit_1[index] = 1;
                LRU_bit_2[index] = 0;

                next_state = IDLE;
              end
              else if(tag == tag_2[index] && valid_bit_2[index] == 1) begin
                read_data = (offset == 2'b00)?temp_data_2[7:0]:
                            (offset == 2'b01)?temp_data_2[15:8]:
                            (offset == 2'b10)?temp_data_2[23:16]:
                            (offset == 2'b11)?temp_data_2[31:24]:
                            8'b0;

                LRU_bit_1[index] = 0;
                LRU_bit_2[index] = 1;

                next_state = IDLE;                
              end
              else if((valid_bit_1[index] == 0 || tag != tag_1[index]) && dirty_bit_1[index] == 0) begin 
                next_state = READ_MEM;
                rd_or_wr = 2'b1;
              end
              else if((valid_bit_2[index] == 0 || tag != tag_2[index]) && dirty_bit_2[index] == 0) begin
                next_state = READ_MEM;
                rd_or_wr = 2'b1;
              end 
              else begin
                next_state = UPDATE_MEM;
                rd_or_wr = 2'b10;
              end
             end

WRITE_CACHE : begin
                if(tag == tag_1[index] && valid_bit_1[index] == 1 && dirty_bit_1[index] == 0)
                begin
                    data_bank_1[index] = (offset == 2'b00)?{temp_data_1[31:8],write_data}:
                                        (offset == 2'b01)?{temp_data_1[31:16],write_data,temp_data_1[7:0]}:
                                        (offset == 2'b10)?{temp_data_1[31:24],write_data,temp_data_1[15:0]}:
                                        (offset == 2'b11)?{write_data,temp_data_1[23:0]}:
                                        temp_data_1;

                    dirty_bit_1[index] = 1;
                    LRU_bit_1[index] = 1;
                    LRU_bit_2[index] = 0;
                    valid_bit_1[index] = 1;
                    next_state = IDLE;
                end
                else if(tag == tag_2[index] && valid_bit_2[index] == 1 && dirty_bit_2[index] == 0)
                begin
                    data_bank_2[index] = (offset == 2'b00)?{temp_data_2[31:8],write_data}:
                                        (offset == 2'b01)?{temp_data_2[31:16],write_data,temp_data_2[7:0]}:
                                        (offset == 2'b10)?{temp_data_2[31:24],write_data,temp_data_2[15:0]}:
                                        (offset == 2'b11)?{write_data,temp_data_2[23:0]}:
                                        temp_data_2;

                    dirty_bit_2[index] = 1;
                    LRU_bit_1[index] = 0;
                    LRU_bit_2[index] = 1;
                    valid_bit_2[index] = 1;
                    next_state = IDLE;
                end
                else if((tag != tag_1[index] || valid_bit_1[index] == 0) && dirty_bit_1[index] == 0 ) begin 
                    next_state = READ_MEM;
                    rd_or_wr = 2'b1;
                end
                else if((tag != tag_2[index] || valid_bit_2[index] == 0) && dirty_bit_2[index] == 0 ) begin 
                    next_state = READ_MEM;
                end
                else if(dirty_bit_1[index] == 1) begin 
                    next_state = UPDATE_MEM;
                end
                else if(dirty_bit_2[index] == 1) begin
                    next_state = UPDATE_MEM;
                end
              end

UPDATE_MEM : begin

                //function call for the memory instantiation will come here 

                // memory write enable == 1;
                // the line with dirty bit will be passed to the memory.
                if(LRU_bit_1[index] == 1'b0 && valid_bit_1[index] == 1'b1) begin
                    memory_in = data_bank_1[index];
                    memory_addr = {tag_1[index],index,offset};
                    memory_re = 1'b0;
                    memory_we = 1'b1;
                    rd_or_wr = 2'b10;
                    next_state = WAIT_MEM;
                    count_yes = 1;
                end
                else if(LRU_bit_2[index] == 1'b0 && valid_bit_2[index] == 1'b1) begin
                    memory_in = data_bank_2[index];
                    memory_addr = {tag_2[index],index,offset};
                    memory_re = 1'b0;
                    memory_we = 1'b1;
                    rd_or_wr = 2'b10;
                    next_state = WAIT_MEM;
                    count_yes = 1;
                end
             end

UPDATE_CACHE : begin
                
                // Get the data from memory and update the line in cache
                // update the dirty bit, tags and LRU, valid bits also

            if(re == 1 && tag == tag_1[index] && valid_bit_1[index] == 1) begin
                read_data = (offset == 2'b00)?temp_data_1[7:0]:
                            (offset == 2'b01)?temp_data_1[15:8]:
                            (offset == 2'b10)?temp_data_1[23:16]:
                            (offset == 2'b11)?temp_data_1[31:24]:
                            8'b0;
                
                LRU_bit_1[index] = 1;
                LRU_bit_2[index] = 0;
                next_state = IDLE;
              end
            else if(re == 1 && tag == tag_2[index] && valid_bit_2[index] == 1) begin
                read_data = (offset == 2'b00)?temp_data_2[7:0]:
                            (offset == 2'b01)?temp_data_2[15:8]:
                            (offset == 2'b10)?temp_data_2[23:16]:
                            (offset == 2'b11)?temp_data_2[31:24]:
                            8'b0;

                LRU_bit_1[index] = 0;
                LRU_bit_2[index] = 1;

                next_state = IDLE;                
              end
            else if(we == 1 && tag == tag_1[index] && valid_bit_1[index] == 1 && dirty_bit_1[index] == 0)
                begin
                    data_bank_1[index] = (offset == 2'b00)?{temp_data_1[31:8],write_data}:
                                        (offset == 2'b01)?{temp_data_1[31:16],write_data,temp_data_1[7:0]}:
                                        (offset == 2'b10)?{temp_data_1[31:24],write_data,temp_data_1[15:0]}:
                                        (offset == 2'b11)?{write_data,temp_data_1[23:0]}:
                                        temp_data_1;

                    dirty_bit_1[index] = 1;
                    LRU_bit_1[index] = 1;
                    LRU_bit_2[index] = 0;
                    valid_bit_1[index] = 1;
                    next_state = IDLE;
                end
            else if(we == 1 && tag == tag_2[index] && valid_bit_2[index] == 1 && dirty_bit_2[index] == 0)
                begin
                    data_bank_2[index] = (offset == 2'b00)?{temp_data_2[31:8],write_data}:
                                        (offset == 2'b01)?{temp_data_2[31:16],write_data,temp_data_2[7:0]}:
                                        (offset == 2'b10)?{temp_data_2[31:24],write_data,temp_data_2[15:0]}:
                                        (offset == 2'b11)?{write_data,temp_data_2[23:0]}:
                                        temp_data_2;

                    dirty_bit_2[index] = 1;
                    LRU_bit_1[index] = 0;
                    LRU_bit_2[index] = 1;
                    valid_bit_2[index] = 1;
                    next_state = IDLE;
                end

            end

WAIT_MEM : begin
                // 8 cycle delay timer
                if(counter_out == 3'b111 && rd_or_wr == 2'b01 && LRU_bit_1[index] == 1'b0) begin
                    next_state = UPDATE_CACHE;
                    count_yes = 0;
                    data_bank_1[index] = memory_out;
                    tag_1[index] = memory_addr[31:11];
                    // LRU_bit_1[index] = 1'b1;
                    // LRU_bit_2[index] = 1'b0;
                    valid_bit_1[index] = 1'b1;
                    dirty_bit_1[index] = 1'b0;
                end
                else if(counter_out == 3'b111 && rd_or_wr == 2'b01 && LRU_bit_2[index] == 1'b0) begin
                    next_state = UPDATE_CACHE;
                    count_yes = 0;
                    data_bank_2[index] = memory_out;
                    tag_2[index] = memory_addr[31:11];
                    valid_bit_2[index] = 1'b1;
                    dirty_bit_2[index] = 1'b0;
                end
                else if(counter_out == 3'b111 && rd_or_wr == 2'b10) begin
                    next_state = READ_MEM;
                    counter <= 3'b000;
                    count_yes = 0;
                end
                else begin
                    next_state = WAIT_MEM;
                end
               end

READ_MEM : begin
    
            // Read the memory and store in a latch
            // Move to the Update cache
            next_state = WAIT_MEM;
            memory_addr = cpu_address;
            memory_re = 1'b1;
            memory_we = 1'b0;
            rd_or_wr = 2'b1;
            count_yes = 1;
           end

endcase

end



endmodule