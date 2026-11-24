`timescale 1ns/1ps
module tb_pipe;
    reg clk = 0, rst = 1;
    wire [31:0] imem_addr, dmem_addr, dmem_wdata;
    wire        dmem_we, dmem_re;
    wire [31:0] imem_rdata, dmem_rdata;
    reg  [31:0] imem [0:63];
    reg  [31:0] dmem [0:63];
    integer i;

    rv32i_pipe dut (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata)
    );

    assign imem_rdata = imem[imem_addr[7:2]];
    assign dmem_rdata = dmem[dmem_addr[7:2]];

    always @(posedge clk)
        if (dmem_we) dmem[dmem_addr[7:2]] <= dmem_wdata;

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] expected, input [63:0] name);
        begin
            if (got === expected) $display("PASS  %0s = %0d", name, got);
            else $display("FAIL  %0s  got %0d  expected %0d", name, got, expected);
        end
    endtask

    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            imem[i] = 32'h00000013;
            dmem[i] = 32'b0;
        end
        imem[0]  = 32'h00500093;  // addi x1, x0, 5
        imem[1]  = 32'h00700113;  // addi x2, x0, 7
        imem[2]  = 32'h002081B3;  // add  x3, x1, x2     (forwarding)
        imem[3]  = 32'h00302023;  // sw   x3, 0(x0)      (store data forwarding)
        imem[4]  = 32'h00002203;  // lw   x4, 0(x0)
        imem[5]  = 32'h001202B3;  // add  x5, x4, x1     (load-use stall)
        imem[6]  = 32'h00418463;  // beq  x3, x4, +8     (taken, skips next)
        imem[7]  = 32'h06300313;  // addi x6, x0, 99     (must be skipped)
        imem[8]  = 32'h00100393;  // addi x7, x0, 1
        imem[9]  = 32'h0080046F;  // jal  x8, +8         (skips next)
        imem[10] = 32'h06300493;  // addi x9, x0, 99     (must be skipped)
        imem[11] = 32'h00300513;  // addi x10, x0, 3
        imem[12] = 32'h0000006F;  // jal  x0, 0          (loop forever)

        for (i = 1; i < 32; i = i + 1) dut.rf.regs[i] = 32'b0;

        #22 rst = 0;
        #400;

        check(dut.rf.regs[1],  5,  "x1");
        check(dut.rf.regs[2],  7,  "x2");
        check(dut.rf.regs[3],  12, "x3");
        check(dmem[0],         12, "MEM0");
        check(dut.rf.regs[4],  12, "x4");
        check(dut.rf.regs[5],  17, "x5");
        check(dut.rf.regs[6],  0,  "x6skip");
        check(dut.rf.regs[7],  1,  "x7");
        check(dut.rf.regs[8],  40, "x8link");
        check(dut.rf.regs[9],  0,  "x9skip");
        check(dut.rf.regs[10], 3,  "x10");
        $finish;
    end
endmodule
