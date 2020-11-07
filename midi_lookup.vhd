

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Special lookup table based saw oscllator used to feed other oscillators. It
-- takes a midi frequency and a counter value and outputs the index value for
-- the oscillator
entity midi_lookup is
  port (
    midi_i : in std_logic_vector(6 downto 0);
    counter_i : in unsigned(23 downto 0);
    freq_o : out std_logic_vector(23 downto 0)
    );
end entity;

architecture rtl of midi_lookup is

  type LUT_t is array (127 downto 0) of unsigned(23 downto 0);

  signal LUT : LUT_t;
  signal freq_all : unsigned(47 downto 0);

begin

    freq_all <= counter_i * LUT(to_integer(unsigned(midi_i)));
    freq_o <= std_logic_vector(freq_all(23 downto 0));
    LUT(0) <= to_unsigned(3110, 24);
    LUT(1) <= to_unsigned(3295, 24);
    LUT(2) <= to_unsigned(3491, 24);
    LUT(3) <= to_unsigned(3698, 24);
    LUT(4) <= to_unsigned(3918, 24);
    LUT(5) <= to_unsigned(4151, 24);
    LUT(6) <= to_unsigned(4398, 24);
    LUT(7) <= to_unsigned(4660, 24);
    LUT(8) <= to_unsigned(4937, 24);
    LUT(9) <= to_unsigned(5230, 24);
    LUT(10) <= to_unsigned(5542, 24);
    LUT(11) <= to_unsigned(5871, 24);
    LUT(12) <= to_unsigned(6220, 24);
    LUT(13) <= to_unsigned(6590, 24);
    LUT(14) <= to_unsigned(6982, 24);
    LUT(15) <= to_unsigned(7397, 24);
    LUT(16) <= to_unsigned(7837, 24);
    LUT(17) <= to_unsigned(8303, 24);
    LUT(18) <= to_unsigned(8797, 24);
    LUT(19) <= to_unsigned(9320, 24);
    LUT(20) <= to_unsigned(9874, 24);
    LUT(21) <= to_unsigned(10461, 24);
    LUT(22) <= to_unsigned(11084, 24);
    LUT(23) <= to_unsigned(11743, 24);
    LUT(24) <= to_unsigned(12441, 24);
    LUT(25) <= to_unsigned(13181, 24);
    LUT(26) <= to_unsigned(13965, 24);
    LUT(27) <= to_unsigned(14795, 24);
    LUT(28) <= to_unsigned(15675, 24);
    LUT(29) <= to_unsigned(16607, 24);
    LUT(30) <= to_unsigned(17594, 24);
    LUT(31) <= to_unsigned(18641, 24);
    LUT(32) <= to_unsigned(19749, 24);
    LUT(33) <= to_unsigned(20923, 24);
    LUT(34) <= to_unsigned(22168, 24);
    LUT(35) <= to_unsigned(23486, 24);
    LUT(36) <= to_unsigned(24882, 24);
    LUT(37) <= to_unsigned(26362, 24);
    LUT(38) <= to_unsigned(27930, 24);
    LUT(39) <= to_unsigned(29590, 24);
    LUT(40) <= to_unsigned(31350, 24);
    LUT(41) <= to_unsigned(33214, 24);
    LUT(42) <= to_unsigned(35189, 24);
    LUT(43) <= to_unsigned(37282, 24);
    LUT(44) <= to_unsigned(39499, 24);
    LUT(45) <= to_unsigned(41847, 24);
    LUT(46) <= to_unsigned(44336, 24);
    LUT(47) <= to_unsigned(46972, 24);
    LUT(48) <= to_unsigned(49765, 24);
    LUT(49) <= to_unsigned(52725, 24);
    LUT(50) <= to_unsigned(55860, 24);
    LUT(51) <= to_unsigned(59181, 24);
    LUT(52) <= to_unsigned(62701, 24);
    LUT(53) <= to_unsigned(66429, 24);
    LUT(54) <= to_unsigned(70379, 24);
    LUT(55) <= to_unsigned(74564, 24);
    LUT(56) <= to_unsigned(78998, 24);
    LUT(57) <= to_unsigned(83695, 24);
    LUT(58) <= to_unsigned(88672, 24);
    LUT(59) <= to_unsigned(93945, 24);
    LUT(60) <= to_unsigned(99531, 24);
    LUT(61) <= to_unsigned(105450, 24);
    LUT(62) <= to_unsigned(111720, 24);
    LUT(63) <= to_unsigned(118363, 24);
    LUT(64) <= to_unsigned(125402, 24);
    LUT(65) <= to_unsigned(132858, 24);
    LUT(66) <= to_unsigned(140759, 24);
    LUT(67) <= to_unsigned(149129, 24);
    LUT(68) <= to_unsigned(157996, 24);
    LUT(69) <= to_unsigned(167391, 24);
    LUT(70) <= to_unsigned(177345, 24);
    LUT(71) <= to_unsigned(187890, 24);
    LUT(72) <= to_unsigned(199063, 24);
    LUT(73) <= to_unsigned(210900, 24);
    LUT(74) <= to_unsigned(223441, 24);
    LUT(75) <= to_unsigned(236727, 24);
    LUT(76) <= to_unsigned(250804, 24);
    LUT(77) <= to_unsigned(265717, 24);
    LUT(78) <= to_unsigned(281518, 24);
    LUT(79) <= to_unsigned(298258, 24);
    LUT(80) <= to_unsigned(315993, 24);
    LUT(81) <= to_unsigned(334783, 24);
    LUT(82) <= to_unsigned(354690, 24);
    LUT(83) <= to_unsigned(375781, 24);
    LUT(84) <= to_unsigned(398126, 24);
    LUT(85) <= to_unsigned(421800, 24);
    LUT(86) <= to_unsigned(446882, 24);
    LUT(87) <= to_unsigned(473455, 24);
    LUT(88) <= to_unsigned(501608, 24);
    LUT(89) <= to_unsigned(531435, 24);
    LUT(90) <= to_unsigned(563036, 24);
    LUT(91) <= to_unsigned(596516, 24);
    LUT(92) <= to_unsigned(631986, 24);
    LUT(93) <= to_unsigned(669566, 24);
    LUT(94) <= to_unsigned(709381, 24);
    LUT(95) <= to_unsigned(751563, 24);
    LUT(96) <= to_unsigned(796253, 24);
    LUT(97) <= to_unsigned(843601, 24);
    LUT(98) <= to_unsigned(893764, 24);
    LUT(99) <= to_unsigned(946910, 24);
    LUT(100) <= to_unsigned(1003216, 24);
    LUT(101) <= to_unsigned(1062871, 24);
    LUT(102) <= to_unsigned(1126072, 24);
    LUT(103) <= to_unsigned(1193032, 24);
    LUT(104) <= to_unsigned(1263973, 24);
    LUT(105) <= to_unsigned(1339133, 24);
    LUT(106) <= to_unsigned(1418762, 24);
    LUT(107) <= to_unsigned(1503126, 24);
    LUT(108) <= to_unsigned(1592507, 24);
    LUT(109) <= to_unsigned(1687202, 24);
    LUT(110) <= to_unsigned(1787529, 24);
    LUT(111) <= to_unsigned(1893821, 24);
    LUT(112) <= to_unsigned(2006433, 24);
    LUT(113) <= to_unsigned(2125742, 24);
    LUT(114) <= to_unsigned(2252145, 24);
    LUT(115) <= to_unsigned(2386065, 24);
    LUT(116) <= to_unsigned(2527947, 24);
    LUT(117) <= to_unsigned(2678267, 24);
    LUT(118) <= to_unsigned(2837525, 24);
    LUT(119) <= to_unsigned(3006253, 24);
    LUT(120) <= to_unsigned(3185014, 24);
    LUT(121) <= to_unsigned(3374405, 24);
    LUT(122) <= to_unsigned(3575058, 24);
    LUT(123) <= to_unsigned(3787642, 24);
    LUT(124) <= to_unsigned(4012867, 24);
    LUT(125) <= to_unsigned(4251484, 24);
    LUT(126) <= to_unsigned(4504291, 24);
    LUT(127) <= to_unsigned(4772130, 24);
end rtl;
