library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

entity dac is
  generic (SAMPLE_WIDTH : natural := 24);
  port (rst_i : in std_logic;
        clk_i : in std_logic;
        sample_i : in std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
        dac_o : out std_logic);
end entity;

architecture rtl of dac is

  signal acc : std_logic_vector(SAMPLE_WIDTH downto 0);
  signal sample : std_logic_vector(SAMPLE_WIDTH - 1 downto 0);

begin

  -- Convert from 24 bits 2-Complement to 24 bits unsigned
  sample(SAMPLE_WIDTH - 1) <= not sample_i(SAMPLE_WIDTH - 1);
  sample(SAMPLE_WIDTH - 2 downto 0) <= sample_i(SAMPLE_WIDTH - 2 downto 0);

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      acc <= std_logic_vector(unsigned('0' & acc(SAMPLE_WIDTH - 1 downto 0)) + unsigned('0' & sample));
    end if;
  end process;
  dac_o <= acc(SAMPLE_WIDTH);

end rtl;
