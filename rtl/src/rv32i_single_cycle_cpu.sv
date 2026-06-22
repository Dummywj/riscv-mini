`include "rv32i_defs.svh"

module rv32i_single_cycle_cpu #(
    parameter logic [31:0] RESET_PC = 32'h0000_0000,
    parameter int unsigned XLEN = 32,
    parameter int unsigned IMEM_ADDR_WIDTH = 32,
    parameter int unsigned DMEM_ADDR_WIDTH = 32,
    parameter bit TRAP_ON_UNSUPPORTED = 1'b1
) (
    input  logic                         clk,
    input  logic                         rst_n,
    output logic [IMEM_ADDR_WIDTH-1:0]   imem_addr,
    input  logic [31:0]                  imem_rdata,
    output logic [DMEM_ADDR_WIDTH-1:0]   dmem_addr,
    output logic [31:0]                  dmem_wdata,
    input  logic [31:0]                  dmem_rdata,
    output logic                         dmem_we,
    output logic [3:0]                   dmem_be,
    output logic                         trap,
    output logic [3:0]                   trap_cause,
    output logic [31:0]                  pc
);

    localparam int unsigned RegCount = 32;

    logic [31:0] pc_q;
    logic        trap_q;
    logic [3:0]  trap_cause_q;
    logic [31:0] regs_q [RegCount];

    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;
    logic [31:0] pc_plus4;
    logic [31:0] target_addr;
    logic [31:0] load_raw;

    logic        reg_we_d;
    logic [4:0]  reg_waddr_d;
    logic [31:0] reg_wdata_d;
    logic [31:0] next_pc_d;
    logic        trap_set_d;
    logic [3:0]  trap_cause_d;
    logic        branch_taken;
    logic        store_misaligned;
    logic        load_misaligned;
    logic        legal_fence;

    int unsigned reg_idx;

    assign instr = imem_rdata;
    assign opcode = instr[6:0];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign funct7 = instr[31:25];

    assign rs1_data = (rs1 == 5'd0) ? 32'h0000_0000 : regs_q[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'h0000_0000 : regs_q[rs2];

    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'h000};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    assign pc_plus4 = pc_q + 32'd4;

    assign imem_addr = pc_q[IMEM_ADDR_WIDTH-1:0];
    assign pc = pc_q;
    assign trap = trap_q;
    assign trap_cause = trap_cause_q;

    always_comb begin
        reg_we_d = 1'b0;
        reg_waddr_d = rd;
        reg_wdata_d = 32'h0000_0000;
        next_pc_d = pc_plus4;
        trap_set_d = 1'b0;
        trap_cause_d = `RV32I_TRAP_NONE;
        branch_taken = 1'b0;
        target_addr = 32'h0000_0000;
        load_raw = 32'h0000_0000;
        load_misaligned = 1'b0;
        store_misaligned = 1'b0;
        legal_fence = 1'b0;

        dmem_addr = {DMEM_ADDR_WIDTH{1'b0}};
        dmem_wdata = 32'h0000_0000;
        dmem_we = 1'b0;
        dmem_be = 4'b0000;

        if (pc_q[1:0] != 2'b00) begin
            trap_set_d = 1'b1;
            trap_cause_d = `RV32I_TRAP_PC_MISALIGN;
        end else begin
            unique case (opcode)
                `RV32I_OPCODE_LUI: begin
                    reg_we_d = 1'b1;
                    reg_wdata_d = imm_u;
                end

                `RV32I_OPCODE_AUIPC: begin
                    reg_we_d = 1'b1;
                    reg_wdata_d = pc_q + imm_u;
                end

                `RV32I_OPCODE_JAL: begin
                    target_addr = pc_q + imm_j;
                    if (target_addr[1:0] != 2'b00) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_TARGET_MISALIGN;
                    end else begin
                        reg_we_d = 1'b1;
                        reg_wdata_d = pc_plus4;
                        next_pc_d = target_addr;
                    end
                end

                `RV32I_OPCODE_JALR: begin
                    target_addr = (rs1_data + imm_i) & 32'hffff_fffe;
                    if (funct3 != 3'b000) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_ILLEGAL;
                    end else if (target_addr[1:0] != 2'b00) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_TARGET_MISALIGN;
                    end else begin
                        reg_we_d = 1'b1;
                        reg_wdata_d = pc_plus4;
                        next_pc_d = target_addr;
                    end
                end

                `RV32I_OPCODE_BRANCH: begin
                    unique case (funct3)
                        3'b000: branch_taken = (rs1_data == rs2_data);
                        3'b001: branch_taken = (rs1_data != rs2_data);
                        3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));
                        3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
                        3'b110: branch_taken = (rs1_data < rs2_data);
                        3'b111: branch_taken = (rs1_data >= rs2_data);
                        default: begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_ILLEGAL;
                        end
                    endcase

                    target_addr = pc_q + imm_b;
                    if (!trap_set_d && branch_taken) begin
                        if (target_addr[1:0] != 2'b00) begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_TARGET_MISALIGN;
                        end else begin
                            next_pc_d = target_addr;
                        end
                    end
                end

                `RV32I_OPCODE_LOAD: begin
                    target_addr = rs1_data + imm_i;
                    dmem_addr = target_addr[DMEM_ADDR_WIDTH-1:0];
                    unique case (funct3)
                        3'b000: begin
                            unique case (target_addr[1:0])
                                2'b00: load_raw = {24'h000000, dmem_rdata[7:0]};
                                2'b01: load_raw = {24'h000000, dmem_rdata[15:8]};
                                2'b10: load_raw = {24'h000000, dmem_rdata[23:16]};
                                default: load_raw = {24'h000000, dmem_rdata[31:24]};
                            endcase
                            dmem_be = 4'b0001 << target_addr[1:0];
                            reg_wdata_d = {{24{load_raw[7]}}, load_raw[7:0]};
                        end
                        3'b001: begin
                            load_misaligned = target_addr[0];
                            dmem_be = target_addr[1] ? 4'b1100 : 4'b0011;
                            load_raw = target_addr[1]
                                ? {16'h0000, dmem_rdata[31:16]}
                                : {16'h0000, dmem_rdata[15:0]};
                            reg_wdata_d = {{16{load_raw[15]}}, load_raw[15:0]};
                        end
                        3'b010: begin
                            load_misaligned = (target_addr[1:0] != 2'b00);
                            dmem_be = 4'b1111;
                            reg_wdata_d = dmem_rdata;
                        end
                        3'b100: begin
                            unique case (target_addr[1:0])
                                2'b00: reg_wdata_d = {24'h000000, dmem_rdata[7:0]};
                                2'b01: reg_wdata_d = {24'h000000, dmem_rdata[15:8]};
                                2'b10: reg_wdata_d = {24'h000000, dmem_rdata[23:16]};
                                default: reg_wdata_d = {24'h000000, dmem_rdata[31:24]};
                            endcase
                            dmem_be = 4'b0001 << target_addr[1:0];
                        end
                        3'b101: begin
                            load_misaligned = target_addr[0];
                            dmem_be = target_addr[1] ? 4'b1100 : 4'b0011;
                            reg_wdata_d = target_addr[1]
                                ? {16'h0000, dmem_rdata[31:16]}
                                : {16'h0000, dmem_rdata[15:0]};
                        end
                        default: begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_ILLEGAL;
                        end
                    endcase

                    if (!trap_set_d && load_misaligned) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_LOAD_MISALIGN;
                    end else if (!trap_set_d) begin
                        reg_we_d = 1'b1;
                    end
                end

                `RV32I_OPCODE_STORE: begin
                    target_addr = rs1_data + imm_s;
                    dmem_addr = target_addr[DMEM_ADDR_WIDTH-1:0];
                    unique case (funct3)
                        3'b000: begin
                            unique case (target_addr[1:0])
                                2'b00: begin
                                    dmem_be = 4'b0001;
                                    dmem_wdata = {24'h000000, rs2_data[7:0]};
                                end
                                2'b01: begin
                                    dmem_be = 4'b0010;
                                    dmem_wdata = {16'h0000, rs2_data[7:0], 8'h00};
                                end
                                2'b10: begin
                                    dmem_be = 4'b0100;
                                    dmem_wdata = {8'h00, rs2_data[7:0], 16'h0000};
                                end
                                default: begin
                                    dmem_be = 4'b1000;
                                    dmem_wdata = {rs2_data[7:0], 24'h000000};
                                end
                            endcase
                        end
                        3'b001: begin
                            store_misaligned = target_addr[0];
                            dmem_be = target_addr[1] ? 4'b1100 : 4'b0011;
                            dmem_wdata = target_addr[1]
                                ? {rs2_data[15:0], 16'h0000}
                                : {16'h0000, rs2_data[15:0]};
                        end
                        3'b010: begin
                            store_misaligned = (target_addr[1:0] != 2'b00);
                            dmem_be = 4'b1111;
                            dmem_wdata = rs2_data;
                        end
                        default: begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_ILLEGAL;
                            dmem_be = 4'b0000;
                        end
                    endcase

                    if (!trap_set_d && store_misaligned) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_STORE_MISALIGN;
                    end else if (!trap_set_d) begin
                        dmem_we = 1'b1;
                    end
                end

                `RV32I_OPCODE_OP_IMM: begin
                    reg_we_d = 1'b1;
                    unique case (funct3)
                        3'b000: reg_wdata_d = rs1_data + imm_i;
                        3'b010: reg_wdata_d = ($signed(rs1_data) < $signed(imm_i)) ? 32'd1 : 32'd0;
                        3'b011: reg_wdata_d = (rs1_data < imm_i) ? 32'd1 : 32'd0;
                        3'b100: reg_wdata_d = rs1_data ^ imm_i;
                        3'b110: reg_wdata_d = rs1_data | imm_i;
                        3'b111: reg_wdata_d = rs1_data & imm_i;
                        3'b001: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data << instr[24:20];
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b101: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data >> instr[24:20];
                            end else if (funct7 == 7'b0100000) begin
                                reg_wdata_d = $signed(rs1_data) >>> instr[24:20];
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        default: begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_ILLEGAL;
                            reg_we_d = 1'b0;
                        end
                    endcase
                end

                `RV32I_OPCODE_OP: begin
                    reg_we_d = 1'b1;
                    unique case (funct3)
                        3'b000: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data + rs2_data;
                            end else if (funct7 == 7'b0100000) begin
                                reg_wdata_d = rs1_data - rs2_data;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b001: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data << rs2_data[4:0];
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b010: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = ($signed(rs1_data) < $signed(rs2_data))
                                    ? 32'd1
                                    : 32'd0;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b011: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = (rs1_data < rs2_data) ? 32'd1 : 32'd0;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b100: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data ^ rs2_data;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b101: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data >> rs2_data[4:0];
                            end else if (funct7 == 7'b0100000) begin
                                reg_wdata_d = $signed(rs1_data) >>> rs2_data[4:0];
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b110: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data | rs2_data;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        3'b111: begin
                            if (funct7 == 7'b0000000) begin
                                reg_wdata_d = rs1_data & rs2_data;
                            end else begin
                                trap_set_d = 1'b1;
                                trap_cause_d = `RV32I_TRAP_ILLEGAL;
                                reg_we_d = 1'b0;
                            end
                        end
                        default: begin
                            trap_set_d = 1'b1;
                            trap_cause_d = `RV32I_TRAP_ILLEGAL;
                            reg_we_d = 1'b0;
                        end
                    endcase
                end

                `RV32I_OPCODE_MISC_MEM: begin
                    legal_fence = (funct3 == 3'b000);
                    if (!legal_fence) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_ILLEGAL;
                    end
                end

                `RV32I_OPCODE_SYSTEM: begin
                    if (instr == 32'h0000_0073) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_ECALL;
                    end else if (instr == 32'h0010_0073) begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_EBREAK;
                    end else begin
                        trap_set_d = 1'b1;
                        trap_cause_d = `RV32I_TRAP_ILLEGAL;
                    end
                end

                default: begin
                    trap_set_d = TRAP_ON_UNSUPPORTED ? 1'b1 : 1'b0;
                    trap_cause_d = TRAP_ON_UNSUPPORTED ? `RV32I_TRAP_ILLEGAL : `RV32I_TRAP_NONE;
                end
            endcase
        end

        if (trap_q || trap_set_d) begin
            reg_we_d = 1'b0;
            dmem_we = 1'b0;
            dmem_be = 4'b0000;
            next_pc_d = pc_q;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc_q <= RESET_PC;
            trap_q <= 1'b0;
            trap_cause_q <= `RV32I_TRAP_NONE;
            for (reg_idx = 0; reg_idx < RegCount; reg_idx++) begin
                regs_q[reg_idx] <= 32'h0000_0000;
            end
        end else if (trap_q) begin
            pc_q <= pc_q;
            trap_q <= trap_q;
            trap_cause_q <= trap_cause_q;
            regs_q[0] <= 32'h0000_0000;
        end else if (trap_set_d) begin
            pc_q <= pc_q;
            trap_q <= 1'b1;
            trap_cause_q <= trap_cause_d;
            regs_q[0] <= 32'h0000_0000;
        end else begin
            pc_q <= next_pc_d;
            trap_q <= 1'b0;
            trap_cause_q <= `RV32I_TRAP_NONE;
            regs_q[0] <= 32'h0000_0000;
            if (reg_we_d && (reg_waddr_d != 5'd0)) begin
                regs_q[reg_waddr_d] <= reg_wdata_d;
            end
        end
    end

endmodule
