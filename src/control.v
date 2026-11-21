module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_5,
    output reg        reg_write,
    output reg        alu_src_b,   // 1 = use immediate
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        branch,
    output reg        jal,
    output reg        jalr,
    output reg  [1:0] a_sel,       // 00 = rs1, 01 = zero (LUI), 10 = PC (AUIPC)
    output reg  [3:0] alu_ctrl
);

    function [3:0] alu_dec(input [2:0] f3, input f7, input is_r);
        case (f3)
            3'b000: alu_dec = (is_r && f7) ? 4'b0001 : 4'b0000; // SUB / ADD
            3'b001: alu_dec = 4'b0010;                          // SLL
            3'b010: alu_dec = 4'b0011;                          // SLT
            3'b011: alu_dec = 4'b0100;                          // SLTU
            3'b100: alu_dec = 4'b0101;                          // XOR
            3'b101: alu_dec = f7 ? 4'b0111 : 4'b0110;           // SRA / SRL
            3'b110: alu_dec = 4'b1000;                          // OR
            3'b111: alu_dec = 4'b1001;                          // AND
        endcase
    endfunction

    always @(*) begin
        reg_write  = 0;
        alu_src_b  = 0;
        mem_read   = 0;
        mem_write  = 0;
        mem_to_reg = 0;
        branch     = 0;
        jal        = 0;
        jalr       = 0;
        a_sel      = 2'b00;
        alu_ctrl   = 4'b0000;

        case (opcode)
            7'b0110011: begin  // R-type
                reg_write = 1;
                alu_ctrl  = alu_dec(funct3, funct7_5, 1'b1);
            end
            7'b0010011: begin  // I-type ALU
                reg_write = 1;
                alu_src_b = 1;
                alu_ctrl  = alu_dec(funct3, funct7_5, 1'b0);
            end
            7'b0000011: begin  // LW
                reg_write  = 1;
                alu_src_b  = 1;
                mem_read   = 1;
                mem_to_reg = 1;
            end
            7'b0100011: begin  // SW
                alu_src_b = 1;
                mem_write = 1;
            end
            7'b1100011: begin  // Branches
                branch   = 1;
                alu_ctrl = 4'b0001;
            end
            7'b0110111: begin  // LUI
                reg_write = 1;
                alu_src_b = 1;
                a_sel     = 2'b01;
            end
            7'b0010111: begin  // AUIPC
                reg_write = 1;
                alu_src_b = 1;
                a_sel     = 2'b10;
            end
            7'b1101111: begin  // JAL
                reg_write = 1;
                jal       = 1;
            end
            7'b1100111: begin  // JALR
                reg_write = 1;
                alu_src_b = 1;
                jalr      = 1;
            end
            default: ;
        endcase
    end

endmodule
