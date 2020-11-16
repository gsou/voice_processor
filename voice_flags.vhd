library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

use work.voice.all;

entity voice_flags is
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    exec_i : in std_logic_vector(2 downto 0);
    flags_i : in std_logic_vector(1 downto 0);
    enable_o : out std_logic

    );
end entity;

architecture rtl of voice_flags is

  signal flags : std_logic_vector(1 downto 0);

begin

  process(exec_i, flags)
  begin
    case exec_i is
      when "000" => enable_o <= '1';
      when "001" => enable_o <= flags(0);
      when "010" => enable_o <= flags(1);
      when "011" => enable_o <= flags(1) or flags(0);
      when "100" => enable_o <= not flags(0);
      when "101" => enable_o <= not flags(0) and not flags(1);
      when "110" => enable_o <= not flags(1);
      when "111" => enable_o <= '1';
      when others => enable_o <= '1';
  end case;
  end process;

  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      flags <= (others => '0');
    elsif rising_edge(clk_i) then
      if exec_i = "111" then
        flags <= flags_i;
      end if;
    end if;
  end process;

end rtl;
