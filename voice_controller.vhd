library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

use work.voice.all;

entity voice_controller is
  generic (NUMREGS : natural := 16;
           VOICES : natural := 1);
  port (
    rst_i : in std_logic;
    clk_i : in std_logic;
    sample_i : in std_logic;

    -- TODO Preloading some midi values in the voice and accept commands
    -- midi_ev_i : in std_logic;
    -- midi_rel_i : in std_logic;
    -- midi_key_i : in std_logic_vector(6 downto 0);
    -- midi_vel_i : in std_logic_vector(6 downto 0);
    busy_o : out std_logic;

    sample_o : out std_logic_vector(23 downto 0));

end entity;

architecture rtl of voice_controller is

  type state_t is (STDBY, STARTVOICE, WAITVOICE, MIXSAMPLE, NEXTVOICE, PUSH);
  signal state : state_t := STDBY;

  signal read1 : integer range 0 to NUMREGS - 1;

  -- Control interconnects
  signal ctrl_read1 : integer range 0 to NUMREGS - 1;
  signal ctrl_read2 : integer range 0 to NUMREGS - 1;
  signal ctrl_write : integer range 0 to NUMREGS - 1;
  signal ctrl_mux   : std_logic_vector(2 downto 0);
  signal data_read1 : std_logic_vector(23 downto 0);
  signal data_read1_imm : std_logic_vector(23 downto 0);
  signal data_read2 : std_logic_vector(23 downto 0);
  signal data_read2_imm : std_logic_vector(23 downto 0);
  signal data_write : std_logic_vector(23 downto 0);
  signal data_sample : std_logic_vector(23 downto 0);

  -- Master Statemachine IO
  signal ctrl_bank : integer range 0 to VOICES - 1;
  signal inc_pc : std_logic;
  signal done : std_logic;
  signal start_proc : std_logic;
  signal instr : std_logic_vector(23 downto 0);

  signal sample_counter : std_logic_vector(23 downto 0);

  -- TODO Use loadable BRAM
  type imem_t is array (15 downto 0) of std_logic_vector(23 downto 0);
  signal program_counter : std_logic_vector(3 downto 0);
  signal instruction_memory : imem_t;

  signal last_sample : std_logic;

begin

  -- Hardcoded instruction memory for testing
  instruction_memory(0) <= x"00100D"; -- Load immediate to reg 1
  instruction_memory(1) <= x"000045"; -- R1 := A4
  instruction_memory(2) <= x"00F016"; -- Midi sample note at R1, write to R15 (output)
  instruction_memory(3) <= x"00100D"; -- Load immediate to reg 1
  instruction_memory(4) <= x"000003"; -- R1 := Triangle wave
  instruction_memory(5) <= x"00F1F0"; -- Run oscillator RF <= Triangle(RF)
  instruction_memory(6) <= x"00000F";
  instruction_memory(7) <= x"00000F";
  instruction_memory(8) <= x"00000F";
  instruction_memory(9) <= x"00000F"; -- Return
  instruction_memory(10) <= x"00000F";
  instruction_memory(11) <= x"00000F";
  instruction_memory(12) <= x"00000F";
  instruction_memory(13) <= x"00000F";
  instruction_memory(14) <= x"00000F";
  instruction_memory(15) <= x"00000F"; -- Return

  instr <= instruction_memory(to_integer(unsigned(program_counter)));

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      last_sample <= sample_i;
    end if;
  end process;

  -- Main statemachine
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= STDBY;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => if sample_i = '1' and last_sample = '0' then state <= STARTVOICE; end if;
        when STARTVOICE => state <= WAITVOICE;
        when WAITVOICE  => if done = '1' then state <= MIXSAMPLE; end if;
        when MIXSAMPLE  => if ctrl_bank = VOICES - 1 then state <= PUSH; else state <= NEXTVOICE; end if;
        when NEXTVOICE  => state <= STARTVOICE;
        when PUSH       => state <= STDBY;
        when others => state <= STDBY;
      end case;
    end if;
  end process;

  -- Statemachine Data
  -- Registers on ctrl_bank, sample_counter and sample_o here
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      start_proc <= '0';
      ctrl_bank <= 0; -- Current voice
      sample_o <= (others => '0');
      sample_counter <= (others => '0');
      program_counter <= (others => '0');
      busy_o <= '0';
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => busy_o <= '0'; start_proc <= '0'; ctrl_bank <= 0;
        when STARTVOICE => busy_o <= '1'; start_proc <= '1';
        when WAITVOICE  => busy_o <= '1'; start_proc <= '0'; if inc_pc = '1' then program_counter <= std_logic_vector(unsigned(program_counter) + 1); end if;
        when MIXSAMPLE  => busy_o <= '1'; start_proc <= '0'; -- TODO Add together voices
        when NEXTVOICE  => busy_o <= '1'; start_proc <= '0'; program_counter <= (others => '0'); -- ctrl_bank <= ctrl_bank + 1
        when PUSH       => busy_o <= '1'; start_proc <= '0'; sample_o <= data_sample; sample_counter <= std_logic_vector(unsigned(sample_counter) + 1);
        when others     => busy_o <= '1'; start_proc <= '0'; ctrl_bank <= 0; sample_o <= (others => '0'); program_counter <= (others => '0');
      end case;
    end if;
  end process;

  data_read1_imm <= instr          when ctrl_read1 = 0 else data_read1;
  data_read2_imm <= sample_counter when ctrl_read2 = 0 else data_read2;

  -- Register bank
  register_bank : voice_bank generic map (VOICES => VOICES, NUMREGS => 16, WIDTH_REGS => 24)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_bank_i => ctrl_bank, ctrl_read1_i => ctrl_read1,
              ctrl_read2_i => ctrl_read2, ctrl_write_i => ctrl_write,
              data_write_i => data_write, data_read1_o => data_read1, data_read2_o => data_read2, data_sample_o => data_sample);

  alu: voice_data generic map (WIDTH_REGS => 24)
    port map (ctrl_mux_i => ctrl_mux, data_in1_i => data_read1_imm, data_in2_i => data_read2_imm, data_out_o => data_write);

  processor : voice_processor generic map (NUMREGS => NUMREGS)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_mux_o => ctrl_mux, ctrl_read1_o => ctrl_read1,
              ctrl_read2_o => ctrl_read2, ctrl_write_o => ctrl_write, ctrl_inc_pc_o => inc_pc,
              done_o => done, start_i => start_proc, instr_i => instr);

  -- TODO FX processor

end rtl;
