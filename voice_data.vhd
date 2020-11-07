library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity voice_data is
  generic (WIDTH_REGS : natural := 24);
  port(
    -- Control ports
    ctrl_mux_i : in std_logic_vector(2 downto 0);
    -- Data ports
    data_in1_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
    data_in2_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
    data_out_o : out std_logic_vector(WIDTH_REGS - 1 downto 0));

end entity;

architecture rtl of voice_data is

  signal osc_type : std_logic_vector(1 downto 0);

  signal osc_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal env_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal lp_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal add_out : std_logic_vector(WIDTH_REGS downto 0);
  signal mul_out : std_logic_vector(2*WIDTH_REGS - 1 downto 0);
  signal mov_out : std_logic_vector(WIDTH_REGS - 1 downto 0);
  signal midi_out : std_logic_vector(WIDTH_REGS - 1 downto 0);

begin

  -- Output muxing
  process (ctrl_mux_i)
  begin
    case ctrl_mux_i is
      when "000" => data_out_o <= osc_out;
      when "001" => data_out_o <= env_out;
      when "010" => data_out_o <= lp_out;
      when "011" => data_out_o <= add_out;
      when "100" => data_out_o <= mul_out(2*WIDTH_REGS - 1 downto WIDTH_REGS);
      when "101" => data_out_o <= mov_out;
      when "110" => data_out_o <= midi_out;
      when others => data_out_o <= (others => '0');
    end case;
  end process;

  -- Combinatorial Oscillator
  osc_type <= data_in2_i(1 downto 0);
  process (osc_type)
  begin
    case osc_type is
                     -- No oscillator
      when "00"   => osc_out <= (others => '0');
                     -- Square
      when "01"   => osc_out(WIDTH_REGS - 1) <= data_in1_i(WIDTH_REGS-1);
                     osc_out(WIDTH_REGS - 2 downto 0) <= (others => not data_in1_i(WIDTH_REGS-1));
                     -- Saw
      when "10"   => osc_out <= data_in1_i; -- xor ('1' & (WIDTH_REGS-2 downto 0 => '0'));
                     -- TODO Triangle
      when "11"   => osc_out <= (others => '0');
      when others => osc_out <= (others => '0');
    end case;
  end process;

  -- TODO Combinatorial Enveloppe
  env_out <= (others => '0');

  -- TODO Combinatorial Filter
  lp_out <= (others => '0');

  -- Combinatorial adder
  add_out <= std_logic_vector(unsigned(data_in1_i) + unsigned(data_in2_i));

  -- Combinatorial multiplier, should be inferred as a hardware multiplier block
  mul_out <= std_logic_vector(signed(data_in1_i) * signed(data_in2_i));

  -- Mov
  mov_out <= data_in1_i;

  -- Midi lookup
  midi : midi_lookup port map (midi_i => data_in1_i(6 downto 0), counter_i => data_in2_i, freq_o => midi_out);
end;
