module rv32i_core (
    input  wire        clk,
    input  wire        rst,
    // Instruction memory port
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    // Data memory port
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata
);

    reg  [31:0] pc;
    wire [31:0] instr = imem_rdata;
    assign imem_addr = pc;

    // Instruction fields
    wire [6:0] opcode   = instr[6:0];
    wire [4:0] rd       = instr[11:7];
    wire [2:0] funct3   = instr[14:12];
    wire [4:0] rs1      = instr[19:15];
    wire [4:0] rs2      = instr[24:20];
    wire       funct7_5 = instr[30];

    // Control signals
    wire        reg_write, alu_src_b, mem_read, mem_write, mem_to_reg;
    wire        branch, jal, jalr;
    wire [1:0]  a_sel;
    wire [3:0]  alu_ctrl;

    control cu (
        .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
        .reg_write(reg_write), .alu_src_b(alu_src_b), .mem_read(mem_read),
        .mem_write(mem_write), .mem_to_reg(mem_to_reg), .branch(branch),
        .jal(jal), .jalr(jalr), .a_sel(a_sel), .alu_ctrl(alu_ctrl)
    );

    // Immediate
    wire [31:0] imm;
    imm_gen ig (.instr(instr), .imm(imm));

    // Register file
    wire [31:0] rd1, rd2;
    wire [31:0] wb_data;
    regfile rf (
        .clk(clk), .we(reg_write),
        .rs1(rs1), .rs2(rs2), .rd(rd), .wd(wb_data),
        .rd1(rd1), .rd2(rd2)
    );

    // ALU
    wire [31:0] alu_a = (a_sel == 2'b01) ? 32'b0 :
                        (a_sel == 2'b10) ? pc    : rd1;
    wire [31:0] alu_b = alu_src_b ? imm : rd2;
    wire [31:0] alu_result;
    alu alu0 (.a(alu_a), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero());

    // Branch comparison
    wire eq  = (rd1 == rd2);
    wire lt  = ($signed(rd1) < $signed(rd2));
    wire ltu = (rd1 < rd2);
    reg  take;
    always @(*) begin
        case (funct3)
            3'b000: take = eq;     // BEQ
            3'b001: take = ~eq;    // BNE
            3'b100: take = lt;     // BLT
            3'b101: take = ~lt;    // BGE
            3'b110: take = ltu;    // BLTU
            3'b111: take = ~ltu;   // BGEU
            default: take = 1'b0;
        endcase
    end
    wire branch_taken = branch & take;

    // Next PC
    wire [31:0] pc_plus4  = pc + 32'd4;
    wire [31:0] pc_target = pc + imm;
    wire [31:0] pc_next   = jalr ? {alu_result[31:1], 1'b0} :
                            (jal | branch_taken) ? pc_target : pc_plus4;

    always @(posedge clk) begin
        if (rst) pc <= 32'b0;
        else     pc <= pc_next;
    end

    // Data memory
    assign dmem_addr  = alu_result;
    assign dmem_wdata = rd2;
    assign dmem_we    = mem_write;
    assign dmem_re    = mem_read;

    // Write-back
    assign wb_data = (jal | jalr) ? pc_plus4 :
                     mem_to_reg   ? dmem_rdata : alu_result;

endmodule
