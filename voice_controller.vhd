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

    -- Memory interface
    i_addr_o : out std_logic_vector(4 downto 0);
    i_data_i : in std_logic_vector(23 downto 0);

    -- Accept Midi commands
    midi_ev_i : in std_logic;
    midi_rel_i : in std_logic;
    midi_key_i : in std_logic_vector(6 downto 0);
    midi_vel_i : in std_logic_vector(6 downto 0);

    busy_o : out std_logic;

    sample_o : out std_logic_vector(23 downto 0));

end entity;

architecture rtl of voice_controller is

  type state_t is (STDBY, MIDICMD, STARTVOICE, WAITVOICE, MIXSAMPLE, NEXTVOICE, PUSH);
  signal state : state_t := STDBY;

  signal read1 : integer range 0 to NUMREGS - 1;

  -- Control interconnects
  signal ctrl_read1_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read2_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read1 : std_logic_vector(4 downto 0);
  signal ctrl_read2 : std_logic_vector(4 downto 0);
  signal ctrl_write : integer range 0 to NUMREGS - 1;
  signal ctrl_mux   : std_logic_vector(3 downto 0);
  signal data_read1 : std_logic_vector(23 downto 0);
  signal data_read1_imm : std_logic_vector(23 downto 0);
  signal data_read1_sp : std_logic_vector(23 downto 0);
  signal data_read2 : std_logic_vector(23 downto 0);
  signal data_read2_imm : std_logic_vector(23 downto 0);
  signal data_read2_sp : std_logic_vector(23 downto 0);
  signal data_write : std_logic_vector(23 downto 0);
  signal data_sample : std_logic_vector(23 downto 0);

  -- Master Statemachine IO
  signal ctrl_bank : integer range 0 to VOICES - 1;
  signal inc_pc : std_logic;
  signal done : std_logic;
  signal start_proc : std_logic;
  signal instr : std_logic_vector(23 downto 0);

  signal sample_counter : std_logic_vector(23 downto 0);

  signal program_counter : std_logic_vector(3 downto 0);

  signal last_sample : std_logic;

  -- Midi commands and registers
  signal midi_key_f : std_logic_vector(6 downto 0);
  signal midi_vel_f : std_logic_vector(6 downto 0);
  signal midi_rel_f : std_logic;
  signal midi_ev_f : std_logic;
  signal reg_midi_key : std_logic_vector(7 downto 0);
  signal reg_midi_vel : std_logic_vector(6 downto 0);

begin

  instr <= i_data_i;
  i_addr_o <= '0' & program_counter;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      last_sample <= sample_i;
      midi_key_f <= midi_key_i;
      midi_vel_f <= midi_vel_i;
      midi_rel_f <= midi_rel_i;
      midi_ev_f <= midi_ev_i;
    end if;
  end process;

  -- Main statemachine
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= STDBY;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => if midi_ev_i = '1' and midi_ev_f = '0' then state <= MIDICMD; elsif sample_i = '1' and last_sample = '0' then state <= STARTVOICE; end if;
        when MIDICMD    => state <= STDBY;
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
      reg_midi_key <= x"45"; -- TODO Real value (others => '0');
      reg_midi_vel <= (others => '0');
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => busy_o <= '0'; start_proc <= '0'; ctrl_bank <= 0;
        when MIDICMD    => busy_o <= '1'; start_proc <= '0'; reg_midi_key <= midi_rel_f & midi_key_f; reg_midi_vel <= midi_vel_f; if midi_rel_f = '0' then sample_counter <= (others => '0'); end if;
        when STARTVOICE => busy_o <= '1'; start_proc <= '1'; program_counter <= (others => '0');
        when WAITVOICE  => busy_o <= '1'; start_proc <= '0'; if inc_pc = '1' then program_counter <= std_logic_vector(unsigned(program_counter) + 1); end if;
        when MIXSAMPLE  => busy_o <= '1'; start_proc <= '0'; -- TODO Add together voices
        when NEXTVOICE  => busy_o <= '1'; start_proc <= '0'; program_counter <= (others => '0'); -- ctrl_bank <= ctrl_bank + 1
        when PUSH       => busy_o <= '1'; start_proc <= '0'; sample_o <= data_sample; sample_counter <= std_logic_vector(unsigned(sample_counter) + 1);
        when others     => busy_o <= '1'; start_proc <= '0'; ctrl_bank <= 0; sample_o <= (others => '0'); program_counter <= (others => '0');
      end case;
    end if;
  end process;

  data_read1_imm <= data_read1_sp when ctrl_read1(4) = '1' else data_read1;
  data_read2_imm <= data_read2_sp when ctrl_read2(4) = '1' else data_read2;

  -- Special registers
  process (ctrl_read1, ctrl_read2, instr, sample_counter, reg_midi_key, reg_midi_vel)
  begin
    case ctrl_read1(3 downto 0) is
      when x"0" => data_read1_sp <= instr;
      when x"1" => data_read1_sp <= sample_counter;
      when x"2" => data_read1_sp <= x"0000" & reg_midi_key;
      when x"3" => data_read1_sp <= x"0000" & '0' & reg_midi_vel;
      when x"7" => data_read1_sp <= x"00000C";
      when x"8" => data_read1_sp <= x"000000";
      when x"9" => data_read1_sp <= x"000001";
      when x"A" => data_read1_sp <= x"000002";
      when x"B" => data_read1_sp <= x"000003";
      when x"C" => data_read1_sp <= x"000004";
      when x"D" => data_read1_sp <= x"000005";
      when x"E" => data_read1_sp <= x"000006";
      when x"F" => data_read1_sp <= x"000007";
      when others => data_read1_sp <= x"000000";
    end case;
    case ctrl_read2(3 downto 0) is
      when x"0" => data_read2_sp <= instr;
      when x"1" => data_read2_sp <= sample_counter;
      when x"2" => data_read2_sp <= x"0000" & reg_midi_key;
      when x"3" => data_read2_sp <= x"0000" & '0' & reg_midi_vel;
      when x"7" => data_read2_sp <= x"00000C";
      when x"8" => data_read2_sp <= x"000000";
      when x"9" => data_read2_sp <= x"000001";
      when x"A" => data_read2_sp <= x"000002";
      when x"B" => data_read2_sp <= x"000003";
      when x"C" => data_read2_sp <= x"000004";
      when x"D" => data_read2_sp <= x"000005";
      when x"E" => data_read2_sp <= x"000006";
      when x"F" => data_read2_sp <= x"000007";
      when others => data_read2_sp <= x"000000";
    end case;
  end process;

  ctrl_read1_bank <= to_integer(unsigned(ctrl_read1(3 downto 0)));
  ctrl_read2_bank <= to_integer(unsigned(ctrl_read2(3 downto 0)));

  -- Register bank
  register_bank : voice_bank generic map (VOICES => VOICES, NUMREGS => 16, WIDTH_REGS => 24)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_bank_i => ctrl_bank, ctrl_read1_i => ctrl_read1_bank,
              ctrl_read2_i => ctrl_read2_bank, ctrl_write_i => ctrl_write,
              data_write_i => data_write, data_read1_o => data_read1, data_read2_o => data_read2, data_sample_o => data_sample);

  alu: voice_data generic map (WIDTH_REGS => 24)
    port map (ctrl_mux_i => ctrl_mux, data_in1_i => data_read1_imm, data_in2_i => data_read2_imm, data_out_o => data_write);

  processor : voice_processor generic map (NUMREGS => NUMREGS)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_mux_o => ctrl_mux, ctrl_read1_o => ctrl_read1,
              ctrl_read2_o => ctrl_read2, ctrl_write_o => ctrl_write, ctrl_inc_pc_o => inc_pc,
              done_o => done, start_i => start_proc, instr_i => instr);

  -- TODO FX processor

end rtl;
