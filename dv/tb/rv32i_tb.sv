`timescale 1ns/1ps
`include "rv32i_defs.svh"

module rv32i_tb;
    localparam int unsigned MEM_WORDS = 256;
    localparam logic [31:0] NOP = 32'h0000_0013;

    logic clk;
    logic rst_n;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic dmem_we;
    logic [3:0] dmem_be;
    logic trap;
    logic [3:0] trap_cause;
    logic [31:0] pc;

    logic [31:0] imem [0:MEM_WORDS-1];
    logic [31:0] dmem [0:MEM_WORDS-1];
    string test_name;
    integer trace_en;
    integer errors;
    integer store_count;
    integer be_sb0_seen;
    integer be_sb1_seen;
    integer be_sb2_seen;
    integer be_sb3_seen;
    integer be_sh0_seen;
    integer be_sh2_seen;
    integer be_sw_seen;

    rv32i_single_cycle_cpu dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .trap(trap),
        .trap_cause(trap_cause),
        .pc(pc)
    );

    rv32i_single_cycle_cpu_assertions u_assertions (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .imem_addr(imem_addr),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .trap(trap),
        .trap_set_d(dut.trap_set_d),
        .reg_we_d(dut.reg_we_d),
        .x0_value(dut.regs_q[0])
    );

    always #5 clk = ~clk;

    assign imem_rdata = imem[imem_addr[31:2] % MEM_WORDS];
    assign dmem_rdata = dmem[dmem_addr[31:2] % MEM_WORDS];

    always_ff @(posedge clk) begin
        if (trace_en && rst_n) begin
            $display("TRACE pc=%08x instr=%08x trap=%0b cause=%0h we=%0b rd=%0d wdata=%08x dmem_we=%0b be=%04b addr=%08x",
                     pc, imem_rdata, trap, trap_cause, dut.reg_we_d, dut.reg_waddr_d,
                     dut.reg_wdata_d, dmem_we, dmem_be, dmem_addr);
        end
        if (rst_n && dmem_we) begin
            store_count <= store_count + 1;
            unique case (dmem_be)
                4'b0001: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][7:0] <= dmem_wdata[7:0];
                    be_sb0_seen <= 1;
                end
                4'b0010: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][15:8] <= dmem_wdata[15:8];
                    be_sb1_seen <= 1;
                end
                4'b0100: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][23:16] <= dmem_wdata[23:16];
                    be_sb2_seen <= 1;
                end
                4'b1000: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][31:24] <= dmem_wdata[31:24];
                    be_sb3_seen <= 1;
                end
                4'b0011: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][15:0] <= dmem_wdata[15:0];
                    be_sh0_seen <= 1;
                end
                4'b1100: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS][31:16] <= dmem_wdata[31:16];
                    be_sh2_seen <= 1;
                end
                4'b1111: begin
                    dmem[dmem_addr[31:2] % MEM_WORDS] <= dmem_wdata;
                    be_sw_seen <= 1;
                end
                default: begin
                    errors <= errors + 1;
                    $error("Invalid store byte enable %04b", dmem_be);
                end
            endcase
        end
    end

    function automatic logic [31:0] r_type(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        r_type = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] i_type(
        input logic [11:0] imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        i_type = {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] s_type(
        input logic [11:0] imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], `RV32I_OPCODE_STORE};
    endfunction

    function automatic logic [31:0] b_type(
        input logic [12:0] imm,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        b_type = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], `RV32I_OPCODE_BRANCH};
    endfunction

    function automatic logic [31:0] u_type(
        input logic [31:0] imm,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        u_type = {imm[31:12], rd, opcode};
    endfunction

    function automatic logic [31:0] j_type(
        input logic [20:0] imm,
        input logic [4:0] rd
    );
        j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd, `RV32I_OPCODE_JAL};
    endfunction

    task automatic clear_memories;
        int idx;
        begin
            for (idx = 0; idx < MEM_WORDS; idx++) begin
                imem[idx] = NOP;
                dmem[idx] = 32'h0000_0000;
            end
        end
    endtask

    task automatic reset_core;
        begin
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            #1;
        end
    endtask

    task automatic init_test;
        begin
            clear_memories();
            store_count = 0;
            be_sb0_seen = 0;
            be_sb1_seen = 0;
            be_sb2_seen = 0;
            be_sb3_seen = 0;
            be_sh0_seen = 0;
            be_sh2_seen = 0;
            be_sw_seen = 0;
            reset_core();
        end
    endtask

    task automatic run_cycles(input int count);
        int idx;
        begin
            for (idx = 0; idx < count; idx++) begin
                @(posedge clk);
                @(negedge clk);
            end
        end
    endtask

    task automatic expect_eq(input string label, input logic [31:0] actual, input logic [31:0] expected);
        begin
            if (actual !== expected) begin
                errors++;
                $error("%s expected %08x actual %08x", label, expected, actual);
            end
        end
    endtask

    task automatic expect_bool(input string label, input logic actual, input logic expected);
        begin
            if (actual !== expected) begin
                errors++;
                $error("%s expected %0d actual %0d", label, expected, actual);
            end
        end
    endtask

    task automatic expect_reg(input int reg_idx, input logic [31:0] expected);
        begin
            expect_eq($sformatf("x%0d", reg_idx), dut.regs_q[reg_idx], expected);
        end
    endtask

    task automatic expect_trap(input logic [3:0] expected_cause);
        begin
            expect_bool("trap", trap, 1'b1);
            expect_eq("trap_cause", {28'h0, trap_cause}, {28'h0, expected_cause});
            expect_bool("dmem_we_in_trap", dmem_we, 1'b0);
            run_cycles(2);
            expect_bool("trap_hold", trap, 1'b1);
            expect_eq("trap_hold_cause", {28'h0, trap_cause}, {28'h0, expected_cause});
            expect_bool("dmem_we_trap_hold", dmem_we, 1'b0);
        end
    endtask

    task automatic check_reset_state;
        begin
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            expect_eq("reset_pc", pc, 32'h0000_0000);
            expect_bool("reset_trap", trap, 1'b0);
            expect_eq("reset_trap_cause", {28'h0, trap_cause}, {28'h0, `RV32I_TRAP_NONE});
            expect_bool("reset_dmem_we", dmem_we, 1'b0);
            for (int idx = 0; idx < 32; idx++) begin
                expect_eq($sformatf("reset_x%0d", idx), dut.regs_q[idx], 32'h0000_0000);
            end
            @(negedge clk);
            rst_n = 1'b1;
            #1;
        end
    endtask

    task automatic test_reset_x0_alu;
        begin
            clear_memories();
            check_reset_state();
            init_test();
            imem[0]  = i_type(12'd5,    5'd0, 3'b000, 5'd1,  `RV32I_OPCODE_OP_IMM);
            imem[1]  = i_type(12'd9,    5'd1, 3'b000, 5'd0,  `RV32I_OPCODE_OP_IMM);
            imem[2]  = i_type(12'hffd,  5'd1, 3'b000, 5'd2,  `RV32I_OPCODE_OP_IMM);
            imem[3]  = i_type(12'd3,    5'd2, 3'b010, 5'd3,  `RV32I_OPCODE_OP_IMM);
            imem[4]  = i_type(12'd3,    5'd2, 3'b011, 5'd4,  `RV32I_OPCODE_OP_IMM);
            imem[5]  = i_type(12'h00f,  5'd1, 3'b100, 5'd5,  `RV32I_OPCODE_OP_IMM);
            imem[6]  = i_type(12'h120,  5'd0, 3'b110, 5'd6,  `RV32I_OPCODE_OP_IMM);
            imem[7]  = i_type(12'h0f0,  5'd6, 3'b111, 5'd7,  `RV32I_OPCODE_OP_IMM);
            imem[8]  = i_type({7'b0000000, 5'd3}, 5'd1, 3'b001, 5'd8, `RV32I_OPCODE_OP_IMM);
            imem[9]  = i_type({7'b0000000, 5'd1}, 5'd8, 3'b101, 5'd9, `RV32I_OPCODE_OP_IMM);
            imem[10] = i_type(12'hff8,  5'd0, 3'b000, 5'd10, `RV32I_OPCODE_OP_IMM);
            imem[11] = i_type({7'b0100000, 5'd2}, 5'd10, 3'b101, 5'd11, `RV32I_OPCODE_OP_IMM);
            imem[12] = u_type(32'h1234_5000, 5'd12, `RV32I_OPCODE_LUI);
            imem[13] = u_type(32'h0001_0000, 5'd13, `RV32I_OPCODE_AUIPC);
            imem[14] = 32'h0000_0073;
            run_cycles(16);
            expect_reg(0, 32'h0000_0000);
            expect_reg(1, 32'h0000_0005);
            expect_reg(2, 32'h0000_0002);
            expect_reg(3, 32'h0000_0001);
            expect_reg(4, 32'h0000_0001);
            expect_reg(5, 32'h0000_000a);
            expect_reg(6, 32'h0000_0120);
            expect_reg(7, 32'h0000_0020);
            expect_reg(8, 32'h0000_0028);
            expect_reg(9, 32'h0000_0014);
            expect_reg(10, 32'hffff_fff8);
            expect_reg(11, 32'hffff_fffe);
            expect_reg(12, 32'h1234_5000);
            expect_reg(13, 32'h0001_0034);
            expect_trap(`RV32I_TRAP_ECALL);
        end
    endtask

    task automatic test_alu_reg_fence;
        begin
            init_test();
            imem[0]  = i_type(12'd10,   5'd0, 3'b000, 5'd1,  `RV32I_OPCODE_OP_IMM);
            imem[1]  = i_type(12'd3,    5'd0, 3'b000, 5'd2,  `RV32I_OPCODE_OP_IMM);
            imem[2]  = i_type(12'hff8,  5'd0, 3'b000, 5'd3,  `RV32I_OPCODE_OP_IMM);
            imem[3]  = r_type(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd5,  `RV32I_OPCODE_OP);
            imem[4]  = r_type(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd6,  `RV32I_OPCODE_OP);
            imem[5]  = r_type(7'b0000000, 5'd2, 5'd2, 3'b001, 5'd7,  `RV32I_OPCODE_OP);
            imem[6]  = r_type(7'b0000000, 5'd2, 5'd3, 3'b010, 5'd8,  `RV32I_OPCODE_OP);
            imem[7]  = r_type(7'b0000000, 5'd2, 5'd3, 3'b011, 5'd9,  `RV32I_OPCODE_OP);
            imem[8]  = r_type(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd10, `RV32I_OPCODE_OP);
            imem[9]  = r_type(7'b0000000, 5'd2, 5'd3, 3'b101, 5'd11, `RV32I_OPCODE_OP);
            imem[10] = r_type(7'b0100000, 5'd2, 5'd3, 3'b101, 5'd12, `RV32I_OPCODE_OP);
            imem[11] = r_type(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd13, `RV32I_OPCODE_OP);
            imem[12] = r_type(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd14, `RV32I_OPCODE_OP);
            imem[13] = 32'h0000_000f;
            imem[14] = 32'h0010_0073;
            run_cycles(16);
            expect_reg(5,  32'h0000_000d);
            expect_reg(6,  32'h0000_0007);
            expect_reg(7,  32'h0000_0018);
            expect_reg(8,  32'h0000_0001);
            expect_reg(9,  32'h0000_0000);
            expect_reg(10, 32'h0000_0009);
            expect_reg(11, 32'h1fff_ffff);
            expect_reg(12, 32'hffff_ffff);
            expect_reg(13, 32'h0000_000b);
            expect_reg(14, 32'h0000_0002);
            expect_trap(`RV32I_TRAP_EBREAK);
        end
    endtask

    task automatic test_branch_jump_link;
        begin
            init_test();
            imem[0]  = i_type(12'd5, 5'd0, 3'b000, 5'd1, `RV32I_OPCODE_OP_IMM);
            imem[1]  = i_type(12'd5, 5'd0, 3'b000, 5'd2, `RV32I_OPCODE_OP_IMM);
            imem[2]  = b_type(13'd8, 5'd2, 5'd1, 3'b000);
            imem[3]  = i_type(12'd1, 5'd0, 3'b000, 5'd3, `RV32I_OPCODE_OP_IMM);
            imem[4]  = i_type(12'd2, 5'd0, 3'b000, 5'd3, `RV32I_OPCODE_OP_IMM);
            imem[5]  = b_type(13'd8, 5'd2, 5'd1, 3'b001);
            imem[6]  = i_type(12'd4, 5'd0, 3'b000, 5'd4, `RV32I_OPCODE_OP_IMM);
            imem[7]  = i_type(12'hfff, 5'd0, 3'b000, 5'd5, `RV32I_OPCODE_OP_IMM);
            imem[8]  = b_type(13'd8, 5'd1, 5'd5, 3'b100);
            imem[9]  = i_type(12'd6, 5'd0, 3'b000, 5'd6, `RV32I_OPCODE_OP_IMM);
            imem[10] = b_type(13'd8, 5'd5, 5'd1, 3'b101);
            imem[11] = i_type(12'd7, 5'd0, 3'b000, 5'd7, `RV32I_OPCODE_OP_IMM);
            imem[12] = b_type(13'd8, 5'd1, 5'd5, 3'b110);
            imem[13] = i_type(12'd8, 5'd0, 3'b000, 5'd8, `RV32I_OPCODE_OP_IMM);
            imem[14] = b_type(13'd8, 5'd1, 5'd5, 3'b111);
            imem[15] = i_type(12'd9, 5'd0, 3'b000, 5'd9, `RV32I_OPCODE_OP_IMM);
            imem[16] = j_type(21'd8, 5'd10);
            imem[17] = i_type(12'd11, 5'd0, 3'b000, 5'd11, `RV32I_OPCODE_OP_IMM);
            imem[18] = i_type(12'd12, 5'd0, 3'b000, 5'd12, `RV32I_OPCODE_OP_IMM);
            imem[19] = i_type(12'd88, 5'd0, 3'b000, 5'd20, `RV32I_OPCODE_OP_IMM);
            imem[20] = i_type(12'd0, 5'd20, 3'b000, 5'd13, `RV32I_OPCODE_JALR);
            imem[21] = i_type(12'd14, 5'd0, 3'b000, 5'd14, `RV32I_OPCODE_OP_IMM);
            imem[22] = i_type(12'd15, 5'd0, 3'b000, 5'd15, `RV32I_OPCODE_OP_IMM);
            imem[23] = 32'h0000_0073;
            run_cycles(24);
            expect_reg(3,  32'h0000_0002);
            expect_reg(4,  32'h0000_0004);
            expect_reg(6,  32'h0000_0000);
            expect_reg(7,  32'h0000_0000);
            expect_reg(8,  32'h0000_0008);
            expect_reg(9,  32'h0000_0000);
            expect_reg(10, 32'h0000_0044);
            expect_reg(11, 32'h0000_0000);
            expect_reg(12, 32'h0000_000c);
            expect_reg(13, 32'h0000_0054);
            expect_reg(14, 32'h0000_0000);
            expect_reg(15, 32'h0000_000f);
            expect_trap(`RV32I_TRAP_ECALL);
        end
    endtask

    task automatic test_load_store;
        begin
            init_test();
            imem[0]  = i_type(12'd64, 5'd0, 3'b000, 5'd1, `RV32I_OPCODE_OP_IMM);
            imem[1]  = i_type(12'hfff, 5'd0, 3'b000, 5'd2, `RV32I_OPCODE_OP_IMM);
            imem[2]  = s_type(12'd0, 5'd2, 5'd1, 3'b010);
            imem[3]  = i_type(12'd0, 5'd1, 3'b000, 5'd3, `RV32I_OPCODE_LOAD);
            imem[4]  = i_type(12'd0, 5'd1, 3'b100, 5'd4, `RV32I_OPCODE_LOAD);
            imem[5]  = i_type(12'd0, 5'd1, 3'b001, 5'd5, `RV32I_OPCODE_LOAD);
            imem[6]  = i_type(12'd0, 5'd1, 3'b101, 5'd6, `RV32I_OPCODE_LOAD);
            imem[7]  = i_type(12'h07f, 5'd0, 3'b000, 5'd7, `RV32I_OPCODE_OP_IMM);
            imem[8]  = s_type(12'd1, 5'd7, 5'd1, 3'b000);
            imem[9]  = i_type(12'd1, 5'd1, 3'b100, 5'd8, `RV32I_OPCODE_LOAD);
            imem[10] = i_type(12'h080, 5'd0, 3'b000, 5'd9, `RV32I_OPCODE_OP_IMM);
            imem[11] = s_type(12'd2, 5'd9, 5'd1, 3'b000);
            imem[12] = i_type(12'd2, 5'd1, 3'b000, 5'd10, `RV32I_OPCODE_LOAD);
            imem[13] = u_type(32'h1234_5000, 5'd11, `RV32I_OPCODE_LUI);
            imem[14] = i_type(12'h678, 5'd11, 3'b000, 5'd11, `RV32I_OPCODE_OP_IMM);
            imem[15] = s_type(12'd4, 5'd11, 5'd1, 3'b001);
            imem[16] = i_type(12'd4, 5'd1, 3'b001, 5'd12, `RV32I_OPCODE_LOAD);
            imem[17] = s_type(12'd6, 5'd11, 5'd1, 3'b001);
            imem[18] = i_type(12'd6, 5'd1, 3'b101, 5'd13, `RV32I_OPCODE_LOAD);
            imem[19] = s_type(12'd3, 5'd7, 5'd1, 3'b000);
            imem[20] = s_type(12'd7, 5'd7, 5'd1, 3'b000);
            imem[21] = i_type(12'd7, 5'd1, 3'b000, 5'd15, `RV32I_OPCODE_LOAD);
            imem[22] = s_type(12'd8, 5'd7, 5'd1, 3'b000);
            imem[23] = i_type(12'd8, 5'd1, 3'b100, 5'd16, `RV32I_OPCODE_LOAD);
            imem[24] = 32'h0000_0073;
            run_cycles(26);
            expect_reg(3,  32'hffff_ffff);
            expect_reg(4,  32'h0000_00ff);
            expect_reg(5,  32'hffff_ffff);
            expect_reg(6,  32'h0000_ffff);
            expect_reg(8,  32'h0000_007f);
            expect_reg(10, 32'hffff_ff80);
            expect_reg(12, 32'h0000_5678);
            expect_reg(13, 32'h0000_5678);
            expect_reg(15, 32'h0000_007f);
            expect_reg(16, 32'h0000_007f);
            expect_eq("dmem_word_16", dmem[16], 32'h7f80_7fff);
            expect_eq("dmem_word_17", dmem[17], 32'h7f78_5678);
            expect_bool("be_sb0_seen", be_sb0_seen != 0, 1'b1);
            expect_bool("be_sb1_seen", be_sb1_seen != 0, 1'b1);
            expect_bool("be_sb2_seen", be_sb2_seen != 0, 1'b1);
            expect_bool("be_sb3_seen", be_sb3_seen != 0, 1'b1);
            expect_bool("be_sh0_seen", be_sh0_seen != 0, 1'b1);
            expect_bool("be_sh2_seen", be_sh2_seen != 0, 1'b1);
            expect_bool("be_sw_seen", be_sw_seen != 0, 1'b1);
            expect_trap(`RV32I_TRAP_ECALL);
        end
    endtask

    task automatic run_single_trap(input logic [31:0] insn0, input logic [3:0] expected_cause);
        begin
            init_test();
            imem[0] = insn0;
            run_cycles(2);
            expect_trap(expected_cause);
            expect_eq("no_store_on_single_trap", store_count, 0);
        end
    endtask

    task automatic test_trap_illegal_system;
        begin
            run_single_trap(32'h0000_0000, `RV32I_TRAP_ILLEGAL);
            run_single_trap(i_type({7'b0000001, 5'd1}, 5'd1, 3'b001, 5'd2, `RV32I_OPCODE_OP_IMM), `RV32I_TRAP_ILLEGAL);
            run_single_trap(32'h0000_0073, `RV32I_TRAP_ECALL);
            run_single_trap(32'h0010_0073, `RV32I_TRAP_EBREAK);
        end
    endtask

    task automatic test_trap_misaligned_data;
        begin
            init_test();
            dmem[0] = 32'ha5a5_5a5a;
            imem[0] = i_type(12'd1, 5'd0, 3'b000, 5'd1, `RV32I_OPCODE_OP_IMM);
            imem[1] = i_type(12'd0, 5'd1, 3'b010, 5'd2, `RV32I_OPCODE_LOAD);
            run_cycles(3);
            expect_reg(2, 32'h0000_0000);
            expect_trap(`RV32I_TRAP_LOAD_MISALIGN);

            init_test();
            dmem[0] = 32'ha5a5_5a5a;
            imem[0] = i_type(12'd1, 5'd0, 3'b000, 5'd1, `RV32I_OPCODE_OP_IMM);
            imem[1] = i_type(12'd85, 5'd0, 3'b000, 5'd2, `RV32I_OPCODE_OP_IMM);
            imem[2] = s_type(12'd0, 5'd2, 5'd1, 3'b010);
            run_cycles(4);
            expect_eq("misaligned_store_suppressed", dmem[0], 32'ha5a5_5a5a);
            expect_eq("misaligned_store_count", store_count, 0);
            expect_trap(`RV32I_TRAP_STORE_MISALIGN);
        end
    endtask

    task automatic test_trap_misaligned_control;
        begin
            init_test();
            imem[0] = b_type(13'd2, 5'd0, 5'd0, 3'b000);
            run_cycles(2);
            expect_trap(`RV32I_TRAP_TARGET_MISALIGN);

            init_test();
            imem[0] = j_type(21'd2, 5'd1);
            run_cycles(2);
            expect_reg(1, 32'h0000_0000);
            expect_trap(`RV32I_TRAP_TARGET_MISALIGN);

            init_test();
            imem[0] = i_type(12'd2, 5'd0, 3'b000, 5'd1, `RV32I_OPCODE_OP_IMM);
            imem[1] = i_type(12'd0, 5'd1, 3'b000, 5'd2, `RV32I_OPCODE_JALR);
            run_cycles(3);
            expect_reg(2, 32'h0000_0000);
            expect_trap(`RV32I_TRAP_TARGET_MISALIGN);

            init_test();
            force dut.pc_q = 32'h0000_0002;
            run_cycles(1);
            release dut.pc_q;
            run_cycles(1);
            expect_trap(`RV32I_TRAP_PC_MISALIGN);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        errors = 0;
        clear_memories();
        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "all";
        end
        trace_en = $test$plusargs("TRACE");

        $display("RV32I directed test start: %s", test_name);
        if (test_name == "reset_x0_alu" || test_name == "all") begin
            test_reset_x0_alu();
        end
        if (test_name == "alu_reg_fence" || test_name == "all") begin
            test_alu_reg_fence();
        end
        if (test_name == "branch_jump_link" || test_name == "all") begin
            test_branch_jump_link();
        end
        if (test_name == "load_store" || test_name == "all") begin
            test_load_store();
        end
        if (test_name == "trap_illegal_system" || test_name == "all") begin
            test_trap_illegal_system();
        end
        if (test_name == "trap_misaligned_data" || test_name == "all") begin
            test_trap_misaligned_data();
        end
        if (test_name == "trap_misaligned_control" || test_name == "all") begin
            test_trap_misaligned_control();
        end

        if (test_name != "reset_x0_alu" &&
            test_name != "alu_reg_fence" &&
            test_name != "branch_jump_link" &&
            test_name != "load_store" &&
            test_name != "trap_illegal_system" &&
            test_name != "trap_misaligned_data" &&
            test_name != "trap_misaligned_control" &&
            test_name != "all") begin
            errors++;
            $error("Unknown TEST plusarg: %s", test_name);
        end

        if (errors == 0) begin
            $display("TEST PASS: %s", test_name);
            $finish;
        end else begin
            $display("TEST FAIL: %s errors=%0d", test_name, errors);
            $fatal(1);
        end
    end

endmodule
