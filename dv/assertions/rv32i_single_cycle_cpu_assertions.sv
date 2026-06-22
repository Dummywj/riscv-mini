`timescale 1ns/1ps

module rv32i_single_cycle_cpu_assertions (
    input logic        clk,
    input logic        rst_n,
    input logic [31:0] pc,
    input logic [31:0] imem_addr,
    input logic [31:0] dmem_addr,
    input logic        dmem_we,
    input logic [3:0]  dmem_be,
    input logic        trap,
    input logic        trap_set_d,
    input logic        reg_we_d,
    input logic [31:0] x0_value
);

    logic        prev_trap;
    logic [31:0] prev_pc;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prev_trap <= 1'b0;
            prev_pc <= 32'h0000_0000;
        end else begin
            assert (x0_value == 32'h0000_0000)
                else $error("ASSERT_X0_ZERO failed: x0=%08x", x0_value);

            if (!trap && !trap_set_d) begin
                assert (imem_addr[1:0] == 2'b00)
                    else $error("ASSERT_ALIGNED_NORMAL_FETCH failed: imem_addr=%08x", imem_addr);
            end

            if (trap || trap_set_d) begin
                assert (!dmem_we)
                    else $error("ASSERT_NO_DMEM_WRITE_ON_TRAP failed");
                assert (!reg_we_d)
                    else $error("ASSERT_NO_REG_WRITE_ON_TRAP failed");
            end

            if (prev_trap) begin
                assert (trap)
                    else $error("ASSERT_TRAP_HOLD failed: trap deasserted before reset");
                assert (pc == prev_pc)
                    else $error("ASSERT_TRAP_PC_STABLE failed: pc=%08x prev_pc=%08x", pc, prev_pc);
                assert (!dmem_we)
                    else $error("ASSERT_TRAP_NO_STORE failed");
                assert (!reg_we_d)
                    else $error("ASSERT_TRAP_NO_REG_WRITE failed");
            end

            if (dmem_we) begin
                unique case (dmem_be)
                    4'b0001: assert (dmem_addr[1:0] == 2'b00)
                        else $error("ASSERT_STORE_BE_SB0 failed: addr=%08x", dmem_addr);
                    4'b0010: assert (dmem_addr[1:0] == 2'b01)
                        else $error("ASSERT_STORE_BE_SB1 failed: addr=%08x", dmem_addr);
                    4'b0100: assert (dmem_addr[1:0] == 2'b10)
                        else $error("ASSERT_STORE_BE_SB2 failed: addr=%08x", dmem_addr);
                    4'b1000: assert (dmem_addr[1:0] == 2'b11)
                        else $error("ASSERT_STORE_BE_SB3 failed: addr=%08x", dmem_addr);
                    4'b0011: assert (dmem_addr[1:0] == 2'b00)
                        else $error("ASSERT_STORE_BE_SH0 failed: addr=%08x", dmem_addr);
                    4'b1100: assert (dmem_addr[1:0] == 2'b10)
                        else $error("ASSERT_STORE_BE_SH2 failed: addr=%08x", dmem_addr);
                    4'b1111: assert (dmem_addr[1:0] == 2'b00)
                        else $error("ASSERT_STORE_BE_SW failed: addr=%08x", dmem_addr);
                    default: assert (1'b0)
                        else $error("ASSERT_STORE_BE_VALID failed: be=%04b addr=%08x", dmem_be, dmem_addr);
                endcase
            end

            prev_trap <= trap;
            prev_pc <= pc;
        end
    end

endmodule
