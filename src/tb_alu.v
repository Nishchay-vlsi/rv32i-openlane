`timescale 1ns/1ps
module tb_alu;
    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    alu dut (.a(a), .b(b), .alu_ctrl(alu_ctrl), .result(result), .zero(zero));

    task check(input [31:0] expected, input [63:0] name);
        begin
            #1;
            if (result === expected)
                $display("PASS  %0s", name);
            else
                $display("FAIL  %0s  got %h  expected %h", name, result, expected);
        end
    endtask

    initial begin
        a = 10;           b = 3;          alu_ctrl = 4'b0000; check(32'd13,        "ADD");
        a = 10;           b = 3;          alu_ctrl = 4'b0001; check(32'd7,         "SUB");
        a = 1;            b = 4;          alu_ctrl = 4'b0010; check(32'd16,        "SLL");
        a = 32'hFFFFFFFF; b = 1;          alu_ctrl = 4'b0011; check(32'd1,         "SLT");
        a = 32'hFFFFFFFF; b = 1;          alu_ctrl = 4'b0100; check(32'd0,         "SLTU");
        a = 32'hF0F0F0F0; b = 32'hFFFF0000; alu_ctrl = 4'b0101; check(32'h0F0FF0F0, "XOR");
        a = 32'h80000000; b = 4;          alu_ctrl = 4'b0110; check(32'h08000000,  "SRL");
        a = 32'h80000000; b = 4;          alu_ctrl = 4'b0111; check(32'hF8000000,  "SRA");
        a = 32'h000000F0; b = 32'h0F;     alu_ctrl = 4'b1000; check(32'h000000FF,  "OR");
        a = 32'h000000FF; b = 32'h0F;     alu_ctrl = 4'b1001; check(32'h0000000F,  "AND");
        $finish;
    end
endmodule
