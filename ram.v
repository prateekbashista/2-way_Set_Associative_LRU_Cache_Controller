`timescale 1ns/1ps
`default_nettype none

`timescale 1ns/1ps
`default_nettype none

module boseben_ram( input wire clk,
                    input wire mem_we,
                    input wire mem_re,
                    input wire [31:0] mem_addr,
                    output wire [31:0] mem_data_out,
                    input wire [31:0] mem_data_in
);


  reg [7:0] mem [0:65536];
reg [31:0] dataout;
reg [31:0] temp_data;

// initial begin
//     $readmemb("main_ram.txt", mem);

// end

always @(posedge clk)
begin

    if(mem_we==1 && mem_re==0 && mem_addr[1:0] == 2'b00) begin
      mem[mem_addr - 3] = mem_data_in[31:24];
        mem[mem_addr - 2] = mem_data_in[23:16];
        mem[mem_addr - 1] = mem_data_in[15:8];
        mem[mem_addr] = mem_data_in[7:0];
    end
    else if(mem_we==1 && mem_re==0 && mem_addr[1:0] == 2'b01) begin
      mem[mem_addr - 2] = mem_data_in[31:24];
        mem[mem_addr - 1] = mem_data_in[23:16];
        mem[mem_addr] = mem_data_in[15:8];
        mem[mem_addr+1] = mem_data_in[7:0];
    end
    else if(mem_we==1 && mem_re==0 && mem_addr[1:0] == 2'b10) begin
      mem[mem_addr - 1] = mem_data_in[31:24];
        mem[mem_addr] = mem_data_in[23:16];
        mem[mem_addr + 1] = mem_data_in[15:8];
        mem[mem_addr + 2] = mem_data_in[7:0];
    end
    else if(mem_we==1 && mem_re==0 && mem_addr[1:0] == 2'b11) begin
      mem[mem_addr] = mem_data_in[31:24];
        mem[mem_addr + 1] = mem_data_in[23:16];
        mem[mem_addr + 2] = mem_data_in[15:8];
        mem[mem_addr + 3] = mem_data_in[7:0];
    end
end

always @(posedge clk)
begin
    if(mem_re == 1 && mem_we == 0) begin

        temp_data = (mem_addr[1:0] == 2'b00) ? {mem[mem_addr - 3],mem[mem_addr - 2],mem[mem_addr - 1],mem[mem_addr]} :
                    (mem_addr[1:0] == 2'b01) ? {mem[mem_addr - 2],mem[mem_addr - 1],mem[mem_addr],mem[mem_addr+1]} :
                    (mem_addr[1:0] == 2'b10) ? {mem[mem_addr - 1],mem[mem_addr],mem[mem_addr + 1],mem[mem_addr + 2]} :
                    (mem_addr[1:0] == 2'b11) ? {mem[mem_addr],mem[mem_addr + 1],mem[mem_addr + 2],mem[mem_addr + 3]} :
                    32'b0; 
    end
end

assign mem_data_out = (mem_re) ? temp_data : 32'hz;

endmodule
