-- Jiyao Chen
-- Fall 2019
-- CS232 Project 7
-- alu.vhd : the basis for the ALU circuit design. The circuit is completely asynchronous

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The alu circuit implements the specified operation on srcA and srcB, putting
-- the result in dest and setting the appropriate condition flags.

-- The opcode meanings are shown in the case statement below

-- condition outputs
-- cr(0) <= '1' if the result of the operation is 0
-- cr(1) <= '1' if there is a 2's complement overflow
-- cr(2) <= '1' if the result of the operation is negative
-- cr(3) <= '1' if the operation generated a carry of '1'

-- Note that the and/or/xor operations are defined on std_logic_vectors, so you
-- may have to convert the srcA and srcB signals to std_logic_vectors, execute
-- the operation, and then convert the result back to an unsigned.  You can do
-- this all within a single expression.


entity alu is
  
	port (
		srcA : in  unsigned(15 downto 0);         -- input A
		srcB : in  unsigned(15 downto 0);         -- input B
		op   : in  std_logic_vector(2 downto 0);  -- operation
	   cr   : out std_logic_vector(3 downto 0);  -- condition outputs
		dest : out unsigned(15 downto 0));        -- output value

end alu;

architecture test of alu is

	-- The signal tdest is an intermediate signal to hold the result and
	-- catch the carry bit in location 16.
	signal tdest : unsigned(16 downto 0);  
  
	-- Note that you should always put the carry bit into index 16, even if the
	-- carry is shifted out the right side of the number (into position -1) in
	-- the case of a shift or rotate operation.  This makes it easy to set the
	-- condition flag in the case of a carry out.

begin  -- test
	process (srcA, srcB, op)
	begin  -- process
		case op is
			when "000" =>        -- addition     dest = srcA + srcB
				tdest <= ('0' & srcA) + ('0' & srcB);
			when "001" =>        -- subtraction  dest = srcA - srcB
				tdest <= ('0' & srcA) - ('0' & srcB);
			when "010" =>        -- and          dest = srcA and srcB
				tdest <= '0' & (srcA and srcB);
			when "011" =>        -- or           dest = srcA or srcB
				tdest <= '0' & (srcA or srcB);
			when "100" =>        -- xor          dest = srcA xor srcB
				tdest <= '0' & (srcA xor srcB);
			when "101" =>        -- shift        dest = srcA shifted left arithmetic by one if srcB(0) is 0, otherwise right
				if srcB(0) = '0' then
					tdest <= srcA(15 downto 0) & '0'; -- left
				else
					tdest <= srcA(0) & srcA(15) & srcA(15 downto 1); -- right
				end if;
			when "110" =>        -- rotate       dest = srcA rotated left by one if srcB(0) is 0, otherwise right
				if srcB(0) = '0' then
					tdest <= srcA(15) & (srcA rol 1); -- left
				else
					tdest <= srcA(0) & (srcA ror 1); -- right
				end if;
			when "111" =>        -- pass         dest = srcA
				tdest <= '0' & srcA;
			when others =>
				null;
		end case;
	end process;

	-- connect the low 16 bits of tdest to dest here
	dest <= tdest(15 downto 0);
	-- set the four CR output bits here
	process (srcA, srcB, op, tdest)
	begin
		-- CR(0) = 1 if alu resulted in 0s
		-- CR(0) = 1 if others
		if std_logic_vector(tdest(15 downto 0)) = "0000000000000000" then
			CR(0) <= '1';
		else
			CR(0) <= '0';
		end if;
    
		-- CR(1) = 1 if overflow in addition or subtraction
		-- (or check two operands and the result sign in 2's complement)
		if op = "000" then
			if srcA(15) = srcB(15) and srcA(15) /= tdest(15) then
				CR(1) <= '1';
			else
				CR(1) <= '0';
			end if;

		elsif op = "001" then
			if srcA(15) /= srcB(15) and srcA(15) /= tdest(15) then
				CR(1) <= '1';
			else
				CR(1) <= '0';
			end if;

		else
			CR(1) <= '0';
		end if;

	end process;
  
	-- CR(2) = sign bit
	CR(2) <= tdest(15);

	-- CR(3) = carry
	CR(3) <= tdest(16);

end test;
