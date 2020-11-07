library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

entity voice_processor is
  generic (NUMREGS : natural := 16);
  port (
    rst_i : in std_logic;
    clk_i : in std_logic;
    -- Control

    ctrl_mux_o : out std_logic_vector(3 downto 0);
    ctrl_read1_o : out std_logic_vector(4 downto 0);
    ctrl_read2_o : out std_logic_vector(4 downto 0);
    ctrl_write_o : out integer range 0 to NUMREGS - 1;

    ctrl_inc_pc_o : out std_logic;
    done_o : out std_logic;
    -- Data
    start_i : in std_logic;
    instr_i : in std_logic_vector(23 downto 0));
end entity;

architecture rtl of voice_processor is

  type state_t is (STDBY, START, INSTRUCTION, IMMEDIATE, DONE);
  signal state : state_t := STDBY;

  -- Instruction decode
  signal opcode : std_logic_vector(3 downto 0);
  signal reg1 : std_logic_vector(3 downto 0);
  signal reg2 : std_logic_vector(3 downto 0);
  signal regW : std_logic_vector(3 downto 0);
  signal last_regW : std_logic_vector(3 downto 0);
  signal special1 : std_logic;
  signal special2 : std_logic;
  signal imm : std_logic;
  signal stop : std_logic;

begin

  -- Instruction decode
  opcode <= instr_i(3 downto 0);
  reg1 <= instr_i (7 downto 4);
  reg2 <= instr_i (11 downto 8);
  regW <= instr_i (15 downto 12);
  special1 <= instr_i(16);
  special2 <= instr_i(17);
  imm <= instr_i(22);
  stop <= instr_i(23);


  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      last_regW <= (others => '0');
    elsif rising_edge(clk_i) then
      last_regW <= regW;
    end if;
  end process;

  -- Statemachine control
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= STDBY;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY       => if start_i = '1' then state <= START; end if;
        when START       => state <= INSTRUCTION;
        when INSTRUCTION => if stop = '1' then state <= DONE; elsif imm = '1' then state <= IMMEDIATE; end if;
        when IMMEDIATE   => state <= INSTRUCTION;
        when DONE        => state <= STDBY;
        when others      => state <= STDBY;
      end case;
    end if;
  end process;

  -- Statemachine data
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      ctrl_mux_o <= (others => '0');
      ctrl_read1_o <= (others => '0');
      ctrl_read2_o <= (others => '0');
      ctrl_write_o <= 0;
      ctrl_inc_pc_o <= '0';
      done_o <= '0';
    elsif rising_edge(clk_i) then
      case state is
        when STDBY       =>
          ctrl_mux_o <= (others => '0');
          ctrl_read1_o <= (others => '0');
          ctrl_read2_o <= (others => '0');
          ctrl_write_o <= 0;
          ctrl_inc_pc_o <= '0';
          done_o <= '0';
        when START       =>
          ctrl_mux_o <= (others => '0');
          ctrl_read1_o <= (others => '0');
          ctrl_read2_o <= (others => '0');
          ctrl_write_o <= 0;
          ctrl_inc_pc_o <= '1';
          done_o <= '0';
        when INSTRUCTION =>
          ctrl_mux_o <= opcode;
          ctrl_read1_o <= special1 & reg1;
          ctrl_read2_o <= special2 & reg2;
          ctrl_write_o <= to_integer(unsigned(regW));
          ctrl_inc_pc_o <= '1';
          done_o <= '0';
        when IMMEDIATE   =>
          ctrl_mux_o <= (others => '0');
          ctrl_read1_o <= (others => '0');
          ctrl_read2_o <= (others => '0');
          ctrl_write_o <= 0;
          ctrl_inc_pc_o <= '1';
          done_o <= '0';
        when DONE        =>
          ctrl_mux_o <= (others => '0');
          ctrl_read1_o <= (others => '0');
          ctrl_read2_o <= (others => '0');
          ctrl_write_o <= 0;
          ctrl_inc_pc_o <= '0';
          done_o <= '1';
        when others      =>
          ctrl_mux_o <= (others => '0');
          ctrl_read1_o <= (others => '0');
          ctrl_read2_o <= (others => '0');
          ctrl_write_o <= 0;
          ctrl_inc_pc_o <= '0';
          done_o <= '0';
      end case;
    end if;
  end process;
end rtl;
