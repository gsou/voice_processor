library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

use work.voice.all;

entity voice_controller is
  generic (NUMREGS : natural := 16;
           VOICES : natural := 1; -- Serial voices, allows different sounds
                                  -- (different instructions)
           POLY : natural := 8    -- Polyphony, computer in parallel (must use
                                  -- same instructions)
           );
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

  type state_t is (STDBY, STARTVOICE, WAITVOICE, MIXSAMPLE, NEXTVOICE, PUSH);
  signal state : state_t := STDBY;

  signal read1 : integer range 0 to NUMREGS - 1;

  -- Control interconnects
  signal ctrl_read1_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read2_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read1 : std_logic_vector(4 downto 0);
  signal ctrl_read2 : std_logic_vector(4 downto 0);
  signal ctrl_write : integer range 0 to NUMREGS - 1;
  signal ctrl_mux   : std_logic_vector(3 downto 0);

  -- Master Statemachine IO (Serial voices)
  signal ctrl_bank : integer range 0 to VOICES - 1;
  signal inc_pc : std_logic;
  signal done : std_logic;
  signal start_proc : std_logic;
  signal instr : std_logic_vector(23 downto 0);
  signal sample_counter : std_logic_vector(23 downto 0);
  signal program_counter : std_logic_vector(4 downto 0);
  signal last_sample : std_logic;

  -- Midi commands and registers
  -- TODO Proper midi controller
  signal midi_key_f : std_logic_vector(6 downto 0);
  signal midi_vel_f : std_logic_vector(6 downto 0);
  signal midi_rel_f : std_logic;
  signal midi_ev_f : std_logic;
  signal midi_key_comb_f : std_logic_vector(7 downto 0);

  -- Parallel voices arrays

  type midi_write_t is array (POLY-1 downto 0) of std_logic;
  signal midi_write : midi_write_t;

  type midi_tap_key_t is array (POLY-1 downto 0) of std_logic_vector(7 downto 0);
  signal midi_tap_key : midi_tap_key_t;
  -- Algorithm to alloc next key. TODO Make it more usable (consider release)
  function which_to_alloc(signal taps : midi_tap_key_t) return integer is
  begin
    for i in taps'low to taps'high loop
      if taps(i)(7) = '0' then
        return i;
      end if;
    end loop;
    return 0;
  end function;
  -- This patches the fact that my keyboard controller spams the keyon function
  function allow_to_alloc(signal taps : midi_tap_key_t; signal key : std_logic_vector(6 downto 0)) return boolean is
  begin
    for i in taps'low to taps'high loop
      if taps(i)(6 downto 0) = key and taps(i)(7) = '1' then
        return false;
      end if;
    end loop;
    return true;
  end function;


  type data_poly_t is array (POLY-1 downto 0) of std_logic_vector(23 downto 0);
  signal data_sample : data_poly_t;
  signal data_write : data_poly_t;
  signal data_read1 : data_poly_t;
  signal data_read1_imm : data_poly_t;
  signal data_read1_sp : data_poly_t;
  signal data_read2 : data_poly_t;
  signal data_read2_imm : data_poly_t;
  signal data_read2_sp : data_poly_t;

  -- Mixing the parallel voices together
  function mix_samples(signal samples : data_poly_t) return std_logic_vector is
    variable acc : std_logic_vector(23 downto 0) := (others => '0');
  begin
    for n in samples'range loop
      acc := std_logic_vector(unsigned(acc) + unsigned(samples(n)));
    end loop;
    return acc;
  end function;


begin

  instr <= i_data_i;
  i_addr_o <= program_counter;

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
  midi_key_comb_f <= midi_rel_f & midi_key_f;

  -- Midi controller
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      for i in 0 to POLY-1 loop
        midi_write(i) <= '0';
      end loop;
    elsif rising_edge(clk_i) then
      for i in 0 to POLY-1 loop
        midi_write(i) <= '0';
      end loop;
      if midi_ev_i = '1' and midi_ev_f = '0' then
        if midi_rel_i = '0' then
          -- Clear voices that are using same key
          for i in 0 to POLY-1 loop
            if midi_tap_key(i)(6 downto 0) = midi_key_i(6 downto 0) then
              midi_write(i) <= '1';
            else
              midi_write(i) <= '0';
            end if;
          end loop;
        else
          -- This is a new key, we must find an unused voice
          if allow_to_alloc(midi_tap_key, midi_key_i) then
            midi_write( which_to_alloc(midi_tap_key) ) <= '1';
          end if;
        end if;
      end if;
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
        when STARTVOICE => busy_o <= '1'; start_proc <= '1'; program_counter <= (others => '0');
        when WAITVOICE  => busy_o <= '1'; start_proc <= '0'; if inc_pc = '1' then program_counter <= std_logic_vector(unsigned(program_counter) + 1); end if;
        when MIXSAMPLE  => busy_o <= '1'; start_proc <= '0'; -- TODO Add together voices
        when NEXTVOICE  => busy_o <= '1'; start_proc <= '0'; program_counter <= (others => '0'); -- ctrl_bank <= ctrl_bank + 1
        when PUSH       => busy_o <= '1'; start_proc <= '0';
                           -- TODO Proper sample mix (With saturation)
                           sample_o <= mix_samples(data_sample);
                           sample_counter <= std_logic_vector(unsigned(sample_counter) + 1);
        when others     => busy_o <= '1'; start_proc <= '0'; ctrl_bank <= 0; sample_o <= (others => '0'); program_counter <= (others => '0');
      end case;
    end if;
  end process;


  par_voices: for i in 0 to POLY-1 generate
    data_read1_imm(i) <= data_read1_sp(i) when ctrl_read1(4) = '1' else data_read1(i);
    data_read2_imm(i) <= data_read2_sp(i) when ctrl_read2(4) = '1' else data_read2(i);
    -- Special registers
    special_regs : voice_special port map (rst_i => rst_i, clk_i => clk_i, instr_i => instr, sc_i => sample_counter,
                                           midi_wr => midi_write(i), midi_key => midi_key_comb_f, midi_vel => midi_vel_f, tap_key => midi_tap_key(i),
                                           read1_addr_i => ctrl_read1(3 downto 0), read2_addr_i => ctrl_read2(3 downto 0),
                                           read1_data_o => data_read1_sp(i), read2_data_o => data_read2_sp(i));

    -- Register bank
    -- XXX Remove extra regs for serial?
    register_bank : voice_bank generic map (VOICES => VOICES, NUMREGS => 16, WIDTH_REGS => 24)
      port map (rst_i => rst_i, clk_i => clk_i, ctrl_bank_i => ctrl_bank, ctrl_read1_i => ctrl_read1_bank,
                ctrl_read2_i => ctrl_read2_bank, ctrl_write_i => ctrl_write,
                data_write_i => data_write(i), data_read1_o => data_read1(i), data_read2_o => data_read2(i), data_sample_o => data_sample(i));

    alu: voice_data generic map (WIDTH_REGS => 24)
      port map (ctrl_mux_i => ctrl_mux, data_in1_i => data_read1_imm(i), data_in2_i => data_read2_imm(i), data_out_o => data_write(i));
  end generate;

  ctrl_read1_bank <= to_integer(unsigned(ctrl_read1(3 downto 0)));
  ctrl_read2_bank <= to_integer(unsigned(ctrl_read2(3 downto 0)));

  processor : voice_processor generic map (NUMREGS => NUMREGS)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_mux_o => ctrl_mux, ctrl_read1_o => ctrl_read1,
              ctrl_read2_o => ctrl_read2, ctrl_write_o => ctrl_write, ctrl_inc_pc_o => inc_pc,
              done_o => done, start_i => start_proc, instr_i => instr);

  -- TODO FX processor

end rtl;
