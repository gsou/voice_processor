library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Special Register Bank
entity voice_special is
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    -- Passthrough
    instr_i : in std_logic_vector(23 downto 0);
    sc_i : in std_logic_vector(23 downto 0);
    -- Write port (for midi)
    midi_key : in std_logic_vector(7 downto 0);
    midi_vel : in std_logic_vector(6 downto 0);
    midi_mod : in std_logic_vector(6 downto 0);

    -- Read port A
    read1_addr_i : in std_logic_vector(3 downto 0);
    read1_data_o : out std_logic_vector(23 downto 0);

    -- Read port B
    read2_addr_i : in std_logic_vector(3 downto 0);
    read2_data_o : out std_logic_vector(23 downto 0));
end entity;

architecture rtl of voice_special is

begin

  -- Special registers
  process (read1_addr_i, read2_addr_i, instr_i, sc_i, midi_key, midi_vel, midi_mod)
  begin
    case read1_addr_i is
      when x"0" => read1_data_o <= instr_i;
      when x"1" => read1_data_o <= sc_i;
      when x"2" => read1_data_o <= x"0000" & midi_key;
      when x"3" => read1_data_o <= x"0000" & '0' & midi_vel;
      when x"4" => read1_data_o <= x"0000" & '0' & midi_mod;
      when x"7" => read1_data_o <= x"00000C";
      when x"8" => read1_data_o <= x"000000";
      when x"9" => read1_data_o <= x"000001";
      when x"A" => read1_data_o <= x"000002";
      when x"B" => read1_data_o <= x"000003";
      when x"C" => read1_data_o <= x"000004";
      when x"D" => read1_data_o <= x"000005";
      when x"E" => read1_data_o <= x"000006";
      when x"F" => read1_data_o <= x"000007";
      when others => read1_data_o <= x"000000";
    end case;
    case read2_addr_i is
      when x"0" => read2_data_o <= instr_i;
      when x"1" => read2_data_o <= sc_i;
      when x"2" => read2_data_o <= x"0000" & midi_key;
      when x"3" => read2_data_o <= x"0000" & '0' & midi_vel;
      when x"4" => read2_data_o <= x"0000" & '0' & midi_mod;
      when x"7" => read2_data_o <= x"00000C";
      when x"8" => read2_data_o <= x"000000";
      when x"9" => read2_data_o <= x"000001";
      when x"A" => read2_data_o <= x"000002";
      when x"B" => read2_data_o <= x"000003";
      when x"C" => read2_data_o <= x"000004";
      when x"D" => read2_data_o <= x"000005";
      when x"E" => read2_data_o <= x"000006";
      when x"F" => read2_data_o <= x"000007";
      when others => read2_data_o <= x"000000";
    end case;
  end process;

end rtl;
