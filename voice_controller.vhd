library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

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
    -- busy_o : out std_logic;

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
  type imem_t is array (3 downto 0) of std_logic_vector(23 downto 0);
  signal program_counter : integer range 0 to 3;
  signal instruction_memory : imem_t;

begin

  -- Hardcoded instruction memory for testing
  instruction_memory(0) <= x"001008"; -- Load immediate to reg 1
  instruction_memory(1) <= x"00002D"; -- R1 := 45
  instruction_memory(2) <= x"00F016"; -- Midi sample note at R1, write to R15 (output)
  instruction_memory(3) <= x"00000F"; -- Return

  instr <= instruction_memory(program_counter);

  -- Main statemachine
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= STDBY;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => if sample_i = '1' then state <= STARTVOICE; end if;
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
      -- TODO Add instr reading from array
      start_proc <= '0';
      ctrl_bank <= 0; -- Current voice
      sample_o <= (others => '0');
      program_counter <= 0;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => start_proc <= '0'; ctrl_bank <= 0;
        when STARTVOICE => start_proc <= '1';
        when WAITVOICE  => start_proc <= '0'; if inc_pc = '1' then program_counter <= program_counter + 1; end if;
        when MIXSAMPLE  => start_proc <= '0'; -- TODO Add together voices when
                                              -- there are multiple
        when NEXTVOICE  => start_proc <= '0'; ctrl_bank <= ctrl_bank + 1; program_counter <= 0;
        when PUSH       => start_proc <= '0'; sample_o <= data_sample; sample_counter <= std_logic_vector(unsigned(sample_counter) + 1);
        when others     => start_proc <= '0'; ctrl_bank <= 0; sample_o <= (others => '0'); program_counter <= 0;
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
    port map (ctrl_mux_i => ctrl_mux, data_in1_i => data_read1_imm, data_in2_i => data_read2, data_out_o => data_write);

  processor : voice_processor generic map (NUMREGS => NUMREGS)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_mux_o => ctrl_mux, ctrl_read1_o => ctrl_read1,
              ctrl_read2_o => ctrl_read2, ctrl_write_o => ctrl_write, ctrl_inc_pc_o => inc_pc,
              done_o => done, start_i => start_proc, instr_i => instr);

  -- TODO FX processor

end rtl;
