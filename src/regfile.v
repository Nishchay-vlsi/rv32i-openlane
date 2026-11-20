module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] regs [31:1];

    // Reads: register x0 is always zero
    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    // Write on clock edge, ignored for x0
    always @(posedge clk) begin
        if (we && rd != 5'd0)
            regs[rd] <= wd;
    end

endmodule
