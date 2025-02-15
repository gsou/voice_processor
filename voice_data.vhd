library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

use work.voice.all;

entity voice_data is
  generic (WIDTH_REGS : natural := 24);
  port(
    -- Control ports
    ctrl_mux_i : in std_logic_vector(3 downto 0);
    -- Data ports
    data_in1_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
    data_in2_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
    data_out_o : out std_logic_vector(WIDTH_REGS - 1 downto 0);

    data_filter_i: in std_logic_vector(WIDTH_REGS - 1 downto 0);

    -- Flags
    flags_o : out std_logic_vector(1 downto 0));

end entity;

architecture rtl of voice_data is

  signal data_out : std_logic_vector(WIDTH_REGS - 1 downto 0);

  signal osc_type : std_logic_vector(1 downto 0);

  signal osc_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal env_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal rel_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal lp_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal add_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal sub_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal mul_out : std_logic_vector(2*WIDTH_REGS downto 0);
  signal mov_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal midi_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal and_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal shr_out : signed(WIDTH_REGS - 1 downto 0);
  signal shl_out : unsigned(WIDTH_REGS - 1 downto 0);

  signal sine_out : std_logic_vector(WIDTH_REGS - 1 downto 0);

  signal a_threshold : std_logic_vector(11 downto 0);
  signal d_threshold : std_logic_vector(23 downto 0);
  signal s_threshold : std_logic_vector(11 downto 0);
  signal a_level     : std_logic_vector(WIDTH_REGS + 11 downto 0);
  signal s_delta     : std_logic_vector(WIDTH_REGS + 11 downto 0);
  signal ad_sat      : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal s_level     : std_logic_vector(WIDTH_REGS + 11 downto 0);
  signal s_sat       : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal sus_level   : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal sus_comp    : std_logic_vector(WIDTH_REGS + 11 downto 0);

begin

  -- Output muxing
  data_out_o <= data_out;
  process (ctrl_mux_i, osc_out, env_out, lp_out, add_out, mul_out, mov_out, midi_out, shr_out, sub_out, shl_out, rel_out, data_filter_i)
  begin
    case ctrl_mux_i is
      when "0000" => data_out <= osc_out;
      when "0001" => data_out <= env_out;
      when "0010" => data_out <= rel_out;
      when "0011" => data_out <= add_out;
      when "0100" => data_out <= mul_out(2*WIDTH_REGS -1 downto WIDTH_REGS);
      when "0101" => data_out <= mov_out;
      when "0110" => data_out <= midi_out;
      when "0111" => data_out <= std_logic_vector(shr_out);
      when "1000" => data_out <= sub_out;
      when "1001" => data_out <= std_logic_vector(shl_out);
      when "1010" => data_out <= and_out;
      when "1011" => data_out <= data_filter_i;
      when "1100" => data_out <= mul_out(WIDTH_REGS - 1 downto 0);
      when others => data_out <= (others => '0');
    end case;
  end process;

  -- Flags
  flags_o(0) <= '1' when unsigned(data_out) = 0 else '0';
  flags_o(1) <= '1' when signed(data_out) > 0 else '0';

  -- Combinatorial Oscillator
  osc_type <= data_in2_i(1 downto 0);
  process (osc_type)
  begin
    case osc_type is
      when "00"   => osc_out <= sine_out;
                     -- Square
      when "01"   => osc_out(WIDTH_REGS - 1) <= data_in1_i(WIDTH_REGS-1);
                     osc_out(WIDTH_REGS - 2 downto 0) <= (others => not data_in1_i(WIDTH_REGS-1));
                     -- Saw
      when "10"   => osc_out <= data_in1_i; -- xor ('1' & (WIDTH_REGS-2 downto 0 => '0'));
                     -- Triangle
      when "11"   => if data_in1_i(WIDTH_REGS-1) = '1' then
                       osc_out <= data_in1_i(WIDTH_REGS - 2) & not (data_in1_i(WIDTH_REGS-3 downto 0) & '0');
                     else
                       osc_out <= (not data_in1_i(WIDTH_REGS - 2)) & (data_in1_i(WIDTH_REGS-3 downto 0) & '0');
                     end if;
      when others => osc_out <= (others => '0');
    end case;
  end process;

  -- Combinatorial Enveloppe
  attack  : time_lookup port map (lookup_i => data_in2_i(23 downto 18), der_o => a_threshold, time_o => open);
  delay   : time_lookup port map (lookup_i => data_in2_i(17 downto 12), der_o => open,        time_o => d_threshold);
  sustain : time_lookup port map (lookup_i => data_in2_i(11 downto  6), der_o => s_threshold, time_o => open);
  a_level <= std_logic_vector(unsigned(a_threshold) * unsigned(data_in1_i));
  ad_sat  <= a_level(WIDTH_REGS - 6 downto 0) & "00000" when unsigned(a_level(WIDTH_REGS + 10 downto WIDTH_REGS - 5)) = 0 else (others => '1');
  s_delta <= std_logic_vector ( ( unsigned(data_in1_i) - unsigned(d_threshold) ) * unsigned(s_threshold) );
  s_level <= std_logic_vector(  (WIDTH_REGS - 1 downto 0 => '1', WIDTH_REGS + 11 downto WIDTH_REGS => '0') -
                                (unsigned(s_delta(WIDTH_REGS - 6 downto 0)) & "00000")  );
  s_sat   <= sus_level when signed(s_level) < signed(sus_comp) or signed(s_level) < 0 else s_level(WIDTH_REGS-1 downto 0);
  sus_level(WIDTH_REGS - 1 downto WIDTH_REGS - 6) <= data_in2_i(5 downto 0);
  sus_level(WIDTH_REGS - 7 downto 0) <= (others => '1');
  sus_comp <= (11 downto 0 => '0') & sus_level ;
  env_out <= ad_sat when unsigned(data_in1_i) < unsigned(d_threshold) else s_sat;

  rel_out <= (others => data_in1_i(7));


  -- TODO Combinatorial Filter
  lp_out <= (others => '0');

  -- Combinatorial adder
  add_out <= std_logic_vector(unsigned(data_in1_i) + unsigned(data_in2_i));
  sub_out <= std_logic_vector(unsigned(data_in1_i) - unsigned(data_in2_i));

  -- Combinatorial multiplier, should be inferred as a hardware multiplier block
  mul_out <= std_logic_vector(signed(data_in1_i) * signed('0' & data_in2_i));

  -- Logic
  and_out <= data_in1_i and data_in2_i;

  -- Mov
  mov_out <= data_in1_i;

  -- Shifts
  shr_out <= shift_right(signed(data_in1_i), to_integer(unsigned(data_in2_i)));
  shl_out <= shift_left(unsigned(data_in1_i), to_integer(unsigned(data_in2_i)));

  -- Midi lookup
  midi : midi_lookup port map (midi_i => data_in1_i(6 downto 0), counter_i => unsigned(data_in2_i), freq_o => midi_out);

  -- Sine lookup
  sine : sine_lookup port map (counter_i => unsigned(data_in1_i(WIDTH_REGS - 1 downto WIDTH_REGS - 8)), freq_o => sine_out);

end;
