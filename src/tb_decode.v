`timescale 1ns/1ps
module tb_decode;
    reg  [31:0] instr;
    wire [31:0] imm;
    reg  [6:0]  opcode;
    reg  [2:0]  funct3;
    reg         funct7_5;
    wire        reg_write, alu_src_b, mem_read, mem_write, mem_to_reg, branch, jal, jalr;
    wire [1:0]  a_sel;
    wire [3:0]  alu_ctrl;

    imm_gen ig (.instr(instr), .imm(imm));
    control cu (.opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
                .reg_write(reg_write), .alu_src_b(alu_src_b), .mem_read(mem_read),
                .mem_write(mem_write), .mem_to_reg(mem_to_reg), .branch(branch),
                .jal(jal), .jalr(jalr), .a_sel(a_sel), .alu_ctrl(alu_ctrl));

    task check_imm(input [31:0] expected, input [63:0] name);
        begin
            #1;
            if (imm === expected) $display("PASS  imm  %0s", name);
            else $display("FAIL  imm  %0s  got %h  expected %h", name, imm, expected);
        end
    endtask

    task check_ctrl(input [3:0] e_alu, input e_rw, input e_mr, input e_mw, input e_br, input [63:0] name);
        begin
            #1;
            if (alu_ctrl === e_alu && reg_write === e_rw && mem_read === e_mr &&
                mem_write === e_mw && branch === e_br)
                $display("PASS  ctrl %0s", name);
            else
                $display("FAIL  ctrl %0s", name);
        end
    endtask

    initial begin
        // Immediate generator
        instr = 32'h00500093; check_imm(32'h00000005, "ADDI+5");
        instr = 32'hFFF00093; check_imm(32'hFFFFFFFF, "ADDI-1");
        instr = 32'h0020A423; check_imm(32'h00000008, "SW");
        instr = 32'h00208463; check_imm(32'h00000008, "BEQ");
        instr = 32'h123450B7; check_imm(32'h12345000, "LUI");
        instr = 32'h001000EF; check_imm(32'h00000800, "JAL");

        // Control unit
        opcode = 7'b0110011; funct3 = 3'b000; funct7_5 = 0; check_ctrl(4'b0000, 1, 0, 0, 0, "ADD");
        opcode = 7'b0110011; funct3 = 3'b000; funct7_5 = 1; check_ctrl(4'b0001, 1, 0, 0, 0, "SUB");
        opcode = 7'b0000011; funct3 = 3'b010; funct7_5 = 0; check_ctrl(4'b0000, 1, 1, 0, 0, "LW");
        opcode = 7'b0100011; funct3 = 3'b010; funct7_5 = 0; check_ctrl(4'b0000, 0, 0, 1, 0, "SW");
        opcode = 7'b1100011; funct3 = 3'b000; funct7_5 = 0; check_ctrl(4'b0001, 0, 0, 0, 1, "BEQ");
        $finish;
    end
endmodule
