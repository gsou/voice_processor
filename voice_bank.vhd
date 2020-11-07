library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.voice.ALL;

entity voice_bank is
  generic (VOICES : natural := 4;
           NUMREGS : natural := 16;
           WIDTH_REGS : natural := 24);
  port (
    rst_i : in std_logic; -- Active high reset
    clk_i : in std_logic;
    -- Control ports
    ctrl_bank_i  : in integer range 0 to VOICES - 1;
    ctrl_read1_i : in integer range 0 to NUMREGS - 1;
    ctrl_read2_i : in integer range 0 to NUMREGS - 1;
    ctrl_write_i : in integer range 0 to NUMREGS - 1;
    -- Data ports
    data_write_i : in  std_logic_vector(WIDTH_REGS   - 1 downto 0);
    data_read1_o : out std_logic_vector(WIDTH_REGS   - 1 downto 0);
    data_read2_o : out std_logic_vector(WIDTH_REGS   - 1 downto 0);
    data_sample_o : out std_logic_vector(WIDTH_REGS - 1 downto 0)
    );
end entity;

architecture rtl of voice_bank is

  type REGMAP is array(VOICES-1 downto 0, NUMREGS - 1 downto 0) of std_logic_vector(WIDTH_REGS - 1 downto 0);
  -- Should infer BRAM
  signal regs : REGMAP;

begin

  -- Async reads, this should be inferred as an Async bloc ram read
  data_read1_o <= regs(ctrl_bank_i, ctrl_read1_i);
  data_read2_o <= regs(ctrl_bank_i, ctrl_read2_i);
  -- Last register is always output sample
  data_sample_o <= regs(ctrl_bank_i, WIDTH_REGS - 1);
  -- Sync Writes
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      for b in 0 to VOICES - 1 loop
        for r in 0 to NUMREGS-1 loop
          regs(b, r) <= (others => '0');
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      regs(ctrl_bank_i, ctrl_write_i) <= data_write_i;
    end if;
  end process;

end rtl;
