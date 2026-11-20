`timescale 1ns/1ps
module tb_regfile;
    reg clk = 0, we = 0;
    reg [4:0] rs1, rs2, rd;
    reg [31:0] wd;
    wire [31:0] rd1, rd2;

    regfile dut (.clk(clk), .we(we), .rs1(rs1), .rs2(rs2),
                 .rd(rd), .wd(wd), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;

    initial begin
        we = 1; rd = 5; wd = 32'hDEADBEEF; #10;
        rd = 0; wd = 32'hFFFFFFFF; #10;
        we = 0;
        rs1 = 5; rs2 = 0; #1;
        $display("x5 = %h (expect deadbeef)", rd1);
        $display("x0 = %h (expect 00000000)", rd2);
        $finish;
    end
endmodule
