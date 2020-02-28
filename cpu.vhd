-- Jiyao Chen
-- Fall 2019
-- CS232 Project 8
-- cpu.vhd : top level entity

-- Quartus II VHDL Template
-- Four-State Moore State Machine

-- A Moore machine's outputs are dependent only on the current state.
-- The output is written only when the state changes.  (State
-- transitions are synchronous.)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu is

	port(
    clk   : in  std_logic;                       -- main clock
    reset : in  std_logic;                       -- reset button

    PCview : out std_logic_vector( 7 downto 0);  -- debugging outputs
    IRview : out std_logic_vector(15 downto 0);
    RAview : out std_logic_vector(15 downto 0);
    RBview : out std_logic_vector(15 downto 0);
    RCview : out std_logic_vector(15 downto 0);
    RDview : out std_logic_vector(15 downto 0);
    REview : out std_logic_vector(15 downto 0);

    iport : in  std_logic_vector(7 downto 0);    -- input port
    oport : out std_logic_vector(15 downto 0)  -- output port

	);

end entity;

architecture rtl of cpu is

	-- Build an enumerated type for the state machine
	type state_type is (Startup, Fetch, Execute_Setup, Execute_Process, Execute_Wait, Execute_Write, Execute_Return1, Execute_Return2, Halt);

	-- Register to hold the current state
	signal state   : state_type;

	-- component statements for both ProgramROM and dataRAM
	component arguROM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component;
	
	component DataRAM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	
	end component;

	component alu
	port (
		srcA : in  unsigned(15 downto 0);         -- input A
		srcB : in  unsigned(15 downto 0);         -- input B
		op   : in  std_logic_vector(2 downto 0);  -- operation
	   cr   : out std_logic_vector(3 downto 0);  -- condition outputs
		dest : out unsigned(15 downto 0) -- output value
	);        

	end component;

	-- internal signals
	signal counter : unsigned(2 downto 0);
	-- internal signals for registers (2nd column in the diagram)
	signal RA : std_logic_vector(15 downto 0);
	signal RB : std_logic_vector(15 downto 0);
	signal RC : std_logic_vector(15 downto 0);
	signal RD : std_logic_vector(15 downto 0);
	signal RE : std_logic_vector(15 downto 0);
	signal SP : unsigned(15 downto 0);
	signal IR : std_logic_vector(15 downto 0);
	signal PC : unsigned(7 downto 0);
	signal CR : std_logic_vector(3 downto 0);
	-- internal signals for registers (3rd column in the diagram)
	signal MAR : std_logic_vector(7 downto 0);
	signal MBR : std_logic_vector(15 downto 0);
	-- internal signals for alu input buses and output bus
	signal srcA : unsigned(15 downto 0);
	signal srcB : unsigned(15 downto 0);
	signal DEST : unsigned(15 downto 0);
	-- more internal signals
	signal OUTREG: std_logic_vector(15 downto 0);
	signal ROM_out: std_logic_vector(15 downto 0);
	signal RAM_out: std_logic_vector(15 downto 0);
	signal RAM_we: std_logic;
	signal op : std_logic_vector(2 downto 0);
	signal ALU_Cond: std_logic_vector(3 downto 0);

begin

	-- port map statements
	ROMc : arguROM port map(std_logic_vector(PC), clk, ROM_out);
	RAMc : dataRAM port map(MAR, clk, MBR, RAM_we, RAM_out);
	aluC : alu port map(srcA, srcB, op, ALU_Cond, DEST);

	-- assign signals to their matching outputs
	PCview <= std_logic_vector(PC);
	IRview <= IR;
	RAview <= RA;
	RBview <= RB;
	RCview <= RC;
	RDview <= RD;
	REview <= RE;
	oport <= OUTREG;

	-- Logic to advance to the next state
	process (clk, reset)
	begin
		if reset = '0' then
			RA <= "0000000000000000";
			RB <= "0000000000000000";
			RC <= "0000000000000000";
			RD <= "0000000000000000";
			RE <= "0000000000000000";
			SP <= "0000000000000000";
			IR <= "0000000000000000";
			PC <= "00000000";
			CR <= "0000";
			MAR <= "00000000";
			MBR <= "0000000000000000";
			OUTREG <= "0000000000000000";
			state <= Startup;
			counter <= "000";
		elsif (rising_edge(clk)) then
			case state is
				when Startup=>
					-- increment the small counter and stay there until it reaches 7
					if counter = "111" then
						state <= Fetch;
					end if;
					counter <= counter + 1;
				when Fetch=>
					-- copy the ROM data wire contents to IR and increment PC
					IR <= ROM_out;
					PC <= PC + 1;
					state <= Execute_Setup;
				when Execute_Setup=>
					op <= IR(14 downto 12);
					-- varies among instructions
					case IR(15 downto 12) is
						when "0000"=>
							-- Load from RAM
							if IR(11) = '1' then
								-- low 8 bits of IR + RE
								MAR <= std_logic_vector(unsigned(IR(7 downto 0)) + unsigned(RE(7 downto 0)));
							else
								MAR <= IR(7 downto 0); -- low 8 bits of IR
							end if;
							state <= Execute_Process;
						when "0001"=> 
							-- Store to RAM
							if IR(11) = '1' then
								-- low 8 bits of IR + RE
								MAR <= std_logic_vector(unsigned(IR(7 downto 0)) + unsigned(RE(7 downto 0)));
							else
								MAR <= IR(7 downto 0); -- low 8 bits of IR
							end if;
							case IR(10 downto 8) is -- destination register
								-- interpret various registers based on Table B
								when "000"=>
									MBR <= RA;
								when "001"=>
									MBR <= RB;
								when "010"=>
									MBR <= RC;
								when "011"=>
									MBR <= RD;
								when "100"=>
									MBR <= RE;
								when "101"=>
									MBR <= std_logic_vector(SP);
								when others=>
									null;
							end case;
							state <= Execute_Process;
						when "0010"=> 
							-- Unconditional branch
							PC <= unsigned(IR(7 downto 0));	-- interpret destination
							state <= Execute_Process;
						when "0011"=>
							-- Conditional branch
							case IR(11 downto 10) is
								when "00"=>
									-- condition
									case IR(9 downto 8) is
										when "00"=> 
											-- zero
											if CR(0) = '1' then
												PC <= unsigned(IR(7 downto 0));
											end if;
										when "01"=> 
											-- overflow
											if CR(1) = '1' then
												PC <= unsigned(IR(7 downto 0));
											end if;
										when "10"=> 
											-- negative
											if CR(2) = '1' then
												PC <= unsigned(IR(7 downto 0));
											end if;
										when "11"=> 
											-- carry
											if CR(3) = '1' then
												PC <= unsigned(IR(7 downto 0));
											end if;
										when others=>
											null;
									end case;
									state <= Execute_Process;
								when "01"=> 
									-- Call: push PC on the stack and jump to address
									PC <= unsigned(IR(7 downto 0));
									MAR <= std_logic_vector(SP(7 downto 0));
									MBR <= "0000" & CR & std_logic_vector(PC);
									SP <= SP + 1;
									state <= Execute_Process;
								when "10"=> 
									-- Return: pop PC to continue execution
									MAR <= std_logic_vector(SP(7 downto 0) - 1);
									SP <= SP - 1;
									state <= Execute_Process;
								when "11"=> 
									-- Exit: enter a halt state
									state <= Halt;
								when others=>
									state <= Execute_Process;
									null;
							end case;
						when "0100"=> 
							-- Push: puts the value into into memory location SP and increments SP
							MAR <= std_logic_vector(SP(7 downto 0));
							SP <= SP + 1;
							case IR(11 downto 9) is
								-- interpret various registers based on Table C
								when "000"=>
									MBR <= RA;
								when "001"=>
									MBR <= RB;
								when "010"=>
									MBR <= RC;
								when "011"=>
									MBR <= RD;
								when "100"=>
									MBR <= RE;
								when "101"=>
									MBR <= std_logic_vector(SP);
								when "110"=>
									MBR <= "00000000" & std_logic_vector(PC);
								when "111"=>
									MBR <= "000000000000" & CR;
								when others=>
									null;
							end case;
							state <= Execute_Process;
						when "0101"=> 
							-- Pop: reads the value from memory at location SP-1 and decrements SP
							MAR <= std_logic_vector(SP(7 downto 0) - 1);
							SP <= SP - 1;
							state <= Execute_Process;
						when "1000" | "1001" | "1010" | "1011" | "1100" => 
							op <= IR(14 downto 12);
							-- Add, Subtract, And, Or, Exclusive-or
							case IR(11 downto 9) is
								-- interpret various registers based on Table E
								when "000"=>
									srcA <= unsigned(RA);
								when "001"=>
									srcA <= unsigned(RB);
								when "010"=>
									srcA <= unsigned(RC);
								when "011"=>
									srcA <= unsigned(RD);
								when "100"=>
									srcA <= unsigned(RE);
								when "101"=>
									srcA <= SP;
								when "110"=>
									srcA <= "0000000000000000";
								when "111"=>
									srcA <= "1111111111111111";
								when others=>
									null;
							end case;
							case IR(8 downto 6) is
								-- interpret various registers based on Table E
								when "000"=>
									SrcB <= unsigned(RA);
								when "001"=>
									SrcB <= unsigned(RB);
								when "010"=>
									SrcB <= unsigned(RC);
								when "011"=>
									SrcB <= unsigned(RD);
								when "100"=>
									SrcB <= unsigned(RE);
								when "101"=>
									SrcB <= SP;
								when "110"=>
									SrcB <= "0000000000000000";
								when "111"=>
									SrcB <= "1111111111111111";
								when others=>
									null;
							end case;
							state <= Execute_Process;
						when "1101" | "1110" => 
							-- Shift, Rotate
							case IR(10 downto 8) is
								-- interpret various registers based on Table E
								when "000"=>
									srcA <= unsigned(RA);
								when "001"=>
									srcA <= unsigned(RB);
								when "010"=>
									srcA <= unsigned(RC);
								when "011"=>
									srcA <= unsigned(RD);
								when "100"=>
									srcA <= unsigned(RE);
								when "101"=>
									srcA <= SP;
								when "110"=>
									SrcA <= "0000000000000000";
								when "111"=>
									SrcA <= "1111111111111111";
								when others=>
									null;
							end case;
							SRCB(0) <= IR(11);
							state <= Execute_Process;
						when "1111"=> 
							-- Move
							if IR(11) = '1' then
								-- treat the next 8 bits as a sign-extended immediate value
								case IR(10) is
									when '1' =>
										srcA <= "11111111" & unsigned(IR(10 downto 3));
									when others =>
										srcA <= "00000000" & unsigned(IR(10 downto 3));
								end case;
							else
								case IR(10 downto 8) is
									-- interpret various registers based on Table D
									when "000"=>
										SrcA <= unsigned(RA);
									when "001"=>
										SrcA <= unsigned(RB);
									when "010"=>
										SrcA <= unsigned(RC);
									when "011"=>
										SrcA <= unsigned(RD);
									when "100"=>
										SrcA <= unsigned(RE);
									when "101"=>
										SrcA <= SP;
									when "110"=>
										SrcA <= "00000000" & PC;
									when "111"=>
										SrcA <= unsigned(IR);
									when others=>
										null;
								end case;
							end if;
							state <= Execute_Process;
						when others=>
							state <= Execute_Process;
							null;
					end case;
				when Execute_Process =>
					-- set the RAM write enable signal to high if the operation is a store (opcode 0001, or integer 1), a push, or a CALL
					if IR(15 downto 12) = "0001" or IR(15 downto 12) = "0100" or IR(15 downto 10) = "001101" then
						RAM_we <= '1';
					end if;
					state <= Execute_Wait;
				when Execute_Wait=>
					state <= Execute_Write;
				when Execute_Write=>
					RAM_we <= '0';
					case IR(15 downto 12) is
						when "0000"=> 
							-- Load operation
							case IR(10 downto 8) is
								when "000"=>
									RA <= RAM_out;
								when "001"=>
									RB <= RAM_out;
								when "010"=>
									RC <= RAM_out;
								when "011"=>
									RD <= RAM_out;
								when "100"=>
									RE <= RAM_out;
								when "101"=>
									SP <= unsigned(RAM_out);
								when others=>
									null;
							end case;
							state <= Fetch;
						when "0011"=> 
							if IR(11 downto 10) = "10" then
								-- Return
								PC <= unsigned(RAM_out(7 downto 0));
								CR <= RAM_out(11 downto 8);
								state <= Execute_Return1;
							else
								state <= Fetch;
							end if;
						when "0101"=> 
							-- Pop
							case IR(11 downto 9) is
								when "000"=>
									RA <= RAM_out;
								when "001"=>
									RB <= RAM_out;
								when "010"=>
									RC <= RAM_out;
								when "011"=>
									RD <= RAM_out;
								when "100"=>
									RE <= RAM_out;
								when "101"=>
									SP <= unsigned(RAM_out);
								when "110"=>
									PC <= unsigned(RAM_out(7 downto 0));
								when "111"=>
									CR <= RAM_out(3 downto 0);
								when others=>
									null;
							end case;
							state <= Fetch;
						when "0110"=> 
							-- Store to output
							case IR(11 downto 9) is
								when "000"=>
									OUTREG <= RA;
								when "001"=>
									OUTREG <= RB;
								when "010"=>
									OUTREG <= RC;
								when "011"=>
									OUTREG <= RD;
								when "100"=>
									OUTREG <= RE;
								when "101"=>
									OUTREG <= std_logic_vector(SP);
								when "110"=>
									OUTREG <= "00000000" & std_logic_vector(PC);
								when "111"=>
									OUTREG <= IR;
								when others=>
									null;
							end case;
							state <= Fetch;
						when "0111"=> 
							-- Load from input
							case IR(11 downto 9) is
								when "000"=>
									RA(7 downto 0) <= iport;
								when "001"=>
									RB(7 downto 0) <= iport;
								when "010"=>
									RC(7 downto 0) <= iport;
								when "011"=>
									RD(7 downto 0) <= iport;
								when "100"=>
									RE(7 downto 0) <= iport;
								when "101"=>
									SP(7 downto 0) <= unsigned(iport);
								when others=>
									null;
							end case;
							state <= Fetch;
						when "1000" | "1001" | "1010" | "1011" | "1100" | "1101" | "1110" => 
							-- Add, Subtract, And, Or, Exclusive-or, Shift, Rotate
							case IR(2 downto 0) is
								when "000"=>
									RA <= std_logic_vector(DEST);
								when "001"=>
									RB <= std_logic_vector(DEST);
								when "010"=>
									RC <= std_logic_vector(DEST);
								when "011"=>
									RD <= std_logic_vector(DEST);
								when "100"=>
									RE <= std_logic_vector(DEST);
								when "101"=>
									SP <= DEST;
								when others=>
									null;
							end case;
							CR <= ALU_Cond;
							state <= Fetch;
						when "1111"=> 
							-- Move			
							case IR(2 downto 0) is
								when "000"=>
									RA <= std_logic_vector(DEST);
								when "001"=>
									RB <= std_logic_vector(DEST);
								when "010"=>
									RC <= std_logic_vector(DEST);
								when "011"=>
									RD <= std_logic_vector(DEST);
								when "100"=>
									RE <= std_logic_vector(DEST);
								when "101"=>
									SP <= DEST;
								when others=>
									null;
							end case;
							CR <= ALU_Cond;
							state <= Fetch;
						when others=>
							null;
							state <= Fetch;
					end case;
				when Execute_Return1=>
					state <= Execute_Return2;
				when Execute_Return2=>
					state <= Fetch;
				when Halt=>
					state <= Halt;
			end case;
		end if;
	end process;

end rtl;
