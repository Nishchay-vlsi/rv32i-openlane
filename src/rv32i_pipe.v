module rv32i_pipe (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata
);

    localparam [31:0] NOP = 32'h00000013;

    // ---------------- Pipeline registers ----------------
    reg [31:0] pc;

    // IF/ID
    reg [31:0] ifid_pc, ifid_instr;

    // ID/EX
    reg [31:0] idex_pc, idex_rd1, idex_rd2, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg [2:0]  idex_funct3;
    reg        idex_reg_write, idex_alu_src_b, idex_mem_read, idex_mem_write;
    reg        idex_mem_to_reg, idex_branch, idex_jal, idex_jalr;
    reg [1:0]  idex_a_sel;
    reg [3:0]  idex_alu_ctrl;

    // EX/MEM
    reg [31:0] exmem_result, exmem_wdata;
    reg [4:0]  exmem_rd;
    reg        exmem_reg_write, exmem_mem_read, exmem_mem_write, exmem_mem_to_reg;

    // MEM/WB
    reg [31:0] memwb_result, memwb_load;
    reg [4:0]  memwb_rd;
    reg        memwb_reg_write, memwb_mem_to_reg;

    wire [31:0] wb_data = memwb_mem_to_reg ? memwb_load : memwb_result;

    // ---------------- IF stage ----------------
    assign imem_addr = pc;

    // ---------------- ID stage ----------------
    wire [4:0] id_rs1    = ifid_instr[19:15];
    wire [4:0] id_rs2    = ifid_instr[24:20];
    wire [4:0] id_rd     = ifid_instr[11:7];
    wire [2:0] id_funct3 = ifid_instr[14:12];

    wire        c_reg_write, c_alu_src_b, c_mem_read, c_mem_write, c_mem_to_reg;
    wire        c_branch, c_jal, c_jalr;
    wire [1:0]  c_a_sel;
    wire [3:0]  c_alu_ctrl;

    control cu (
        .opcode(ifid_instr[6:0]), .funct3(id_funct3), .funct7_5(ifid_instr[30]),
        .reg_write(c_reg_write), .alu_src_b(c_alu_src_b), .mem_read(c_mem_read),
        .mem_write(c_mem_write), .mem_to_reg(c_mem_to_reg), .branch(c_branch),
        .jal(c_jal), .jalr(c_jalr), .a_sel(c_a_sel), .alu_ctrl(c_alu_ctrl)
    );

    wire [31:0] id_imm;
    imm_gen ig (.instr(ifid_instr), .imm(id_imm));

    wire [31:0] rf_rd1, rf_rd2;
    regfile rf (
        .clk(clk), .we(memwb_reg_write),
        .rs1(id_rs1), .rs2(id_rs2), .rd(memwb_rd), .wd(wb_data),
        .rd1(rf_rd1), .rd2(rf_rd2)
    );

    // Write-back to decode bypass (same-cycle write and read)
    wire [31:0] id_rd1 = (memwb_reg_write && memwb_rd != 5'd0 && memwb_rd == id_rs1) ? wb_data : rf_rd1;
    wire [31:0] id_rd2 = (memwb_reg_write && memwb_rd != 5'd0 && memwb_rd == id_rs2) ? wb_data : rf_rd2;

    // Load-use hazard: stall one cycle
    wire stall = idex_mem_read && (idex_rd != 5'd0) &&
                 ((idex_rd == id_rs1) || (idex_rd == id_rs2));

    // ---------------- EX stage ----------------
    // Forwarding
    wire fa_mem = exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs1);
    wire fa_wb  = memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs1);
    wire fb_mem = exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs2);
    wire fb_wb  = memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs2);

    wire [31:0] ex_rs1 = fa_mem ? exmem_result : fa_wb ? wb_data : idex_rd1;
    wire [31:0] ex_rs2 = fb_mem ? exmem_result : fb_wb ? wb_data : idex_rd2;

    wire [31:0] alu_a = (idex_a_sel == 2'b01) ? 32'b0 :
                        (idex_a_sel == 2'b10) ? idex_pc : ex_rs1;
    wire [31:0] alu_b = idex_alu_src_b ? idex_imm : ex_rs2;
    wire [31:0] alu_result;
    alu alu0 (.a(alu_a), .b(alu_b), .alu_ctrl(idex_alu_ctrl), .result(alu_result), .zero());

    // Branch decision
    wire eq  = (ex_rs1 == ex_rs2);
    wire lt  = ($signed(ex_rs1) < $signed(ex_rs2));
    wire ltu = (ex_rs1 < ex_rs2);
    reg  take;
    always @(*) begin
        case (idex_funct3)
            3'b000: take = eq;
            3'b001: take = ~eq;
            3'b100: take = lt;
            3'b101: take = ~lt;
            3'b110: take = ltu;
            3'b111: take = ~ltu;
            default: take = 1'b0;
        endcase
    end

    wire        redirect    = (idex_branch & take) | idex_jal | idex_jalr;
    wire [31:0] redirect_pc = idex_jalr ? {alu_result[31:1], 1'b0} : (idex_pc + idex_imm);
    wire [31:0] ex_result   = (idex_jal | idex_jalr) ? (idex_pc + 32'd4) : alu_result;

    // ---------------- MEM stage ----------------
    assign dmem_addr  = exmem_result;
    assign dmem_wdata = exmem_wdata;
    assign dmem_we    = exmem_mem_write;
    assign dmem_re    = exmem_mem_read;

    // ---------------- Sequential logic ----------------
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
            ifid_pc <= 32'b0;  ifid_instr <= NOP;
            idex_pc <= 32'b0;  idex_rd1 <= 32'b0; idex_rd2 <= 32'b0; idex_imm <= 32'b0;
            idex_rs1 <= 5'b0;  idex_rs2 <= 5'b0;  idex_rd <= 5'b0;   idex_funct3 <= 3'b0;
            idex_reg_write <= 0; idex_alu_src_b <= 0; idex_mem_read <= 0; idex_mem_write <= 0;
            idex_mem_to_reg <= 0; idex_branch <= 0; idex_jal <= 0; idex_jalr <= 0;
            idex_a_sel <= 2'b0; idex_alu_ctrl <= 4'b0;
            exmem_result <= 32'b0; exmem_wdata <= 32'b0; exmem_rd <= 5'b0;
            exmem_reg_write <= 0; exmem_mem_read <= 0; exmem_mem_write <= 0; exmem_mem_to_reg <= 0;
            memwb_result <= 32'b0; memwb_load <= 32'b0; memwb_rd <= 5'b0;
            memwb_reg_write <= 0; memwb_mem_to_reg <= 0;
        end else begin
            // MEM/WB
            memwb_result     <= exmem_result;
            memwb_load       <= dmem_rdata;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_mem_to_reg <= exmem_mem_to_reg;

            // EX/MEM
            exmem_result     <= ex_result;
            exmem_wdata      <= ex_rs2;
            exmem_rd         <= idex_rd;
            exmem_reg_write  <= idex_reg_write;
            exmem_mem_read   <= idex_mem_read;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_to_reg <= idex_mem_to_reg;

            // ID/EX (bubble on stall or taken branch/jump)
            if (redirect || stall) begin
                idex_reg_write <= 0; idex_alu_src_b <= 0; idex_mem_read <= 0; idex_mem_write <= 0;
                idex_mem_to_reg <= 0; idex_branch <= 0; idex_jal <= 0; idex_jalr <= 0;
                idex_a_sel <= 2'b0; idex_alu_ctrl <= 4'b0; idex_rd <= 5'b0;
            end else begin
                idex_pc <= ifid_pc;  idex_rd1 <= id_rd1;  idex_rd2 <= id_rd2;  idex_imm <= id_imm;
                idex_rs1 <= id_rs1;  idex_rs2 <= id_rs2;  idex_rd <= id_rd;    idex_funct3 <= id_funct3;
                idex_reg_write <= c_reg_write;   idex_alu_src_b <= c_alu_src_b;
                idex_mem_read <= c_mem_read;     idex_mem_write <= c_mem_write;
                idex_mem_to_reg <= c_mem_to_reg; idex_branch <= c_branch;
                idex_jal <= c_jal;               idex_jalr <= c_jalr;
                idex_a_sel <= c_a_sel;           idex_alu_ctrl <= c_alu_ctrl;
            end

            // PC and IF/ID
            if (redirect) begin
                pc <= redirect_pc;
                ifid_instr <= NOP;
                ifid_pc <= 32'b0;
            end else if (!stall) begin
                pc <= pc + 32'd4;
                ifid_instr <= imem_rdata;
                ifid_pc <= pc;
            end
        end
    end

endmodule
