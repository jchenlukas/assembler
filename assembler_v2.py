# Jiyao Chen
# Fall 2019
# CS232 Project 8
# assembler_v2.py : read in files with function arguments and convert
#                   the lines into machine code

# Template by Bruce A. Maxwell, 2015
#
# implements a simple assembler for the following assembly language
# 
# - One instruction or label per line.
#
# - Blank lines are ignored.
#
# - Comments start with a # as the first character and all subsequent
# - characters on the line are ignored.
#
# - Spaces delimit instruction elements.
#
# - A label ends with a colon and must be a single symbol on its own line.
#
# - A label can be any single continuous sequence of printable
# - characters; a colon or space terminates the symbol.
#
# - All immediate and address values are given in decimal.
#
# - Address values must be positive
#
# - Negative immediate values must have a preceeding '-' with no space
# - between it and the number.
#

# Language definition:
#
# LOAD D A   - load from address A to destination D
# LOADA D A  - load using the address register from address A + RE to destination D
# STORE S A  - store value in S to address A
# STOREA S A - store using the address register the value in S to address A + RE
# BRA L      - branch to label A
# BRAZ L     - branch to label A if the CR zero flag is set
# BRAN L     - branch to label L if the CR negative flag is set
# BRAO L     - branch to label L if the CR overflow flag is set
# BRAC L     - branch to label L if the CR carry flag is set
# CALL L     - call the routine at label L
# RETURN     - return from a routine
# HALT       - execute the halt/exit instruction
# PUSH S     - push source value S to the stack
# POP D      - pop form the stack and put in destination D
# OPORT S    - output to the global port from source S
# IPORT D    - input from the global port to destination D
# ADD A B C  - execute C <= A + B
# SUB A B C  - execute C <= A - B
# AND A B C  - execute C <= A and B  bitwise
# OR  A B C  - execute C <= A or B   bitwise
# XOR A B C  - execute C <= A xor B  bitwise
# SHIFTL A C - execute C <= A shift left by 1
# SHIFTR A C - execute C <= A shift right by 1
# ROTL A C   - execute C <= A rotate left by 1
# ROTR A C   - execute C <= A rotate right by 1
# MOVE A C   - execute C <= A where A is a source register
# MOVEI V C  - execute C <= value V
#

# 2-pass assembler
# pass 1: read through the instructions and put numbers on each instruction location
#         calculate the label values
#
# pass 2: read through the instructions and build the machine instructions
#

import sys

# tables of terms
tableB = {"ra": "000", "rb": "001", "rc": "010", "rd": "011", "re": "100", "sp": "101"}
tableC = {"ra": "000", "rb": "001", "rc": "010", "rd": "011", "re": "100", "sp": "101", "pc": "110", "cr": "111"}
tableD = {"ra": "000", "rb": "001", "rc": "010", "rd": "011", "re": "100", "sp": "101", "pc": "110", "ir": "111"}
tableE = {"ra": "000", "rb": "001", "rc": "010", "rd": "011", "re": "100", "sp": "101", "zeros": "110", "ones": "111"}

# converts d to an 8-bit 2-s complement binary value
def dec2comp8( d, linenum ):
	try:
		if d > 0:
			l = d.bit_length()
			v = "00000000"
			v = v[0:8-l] + format( d, 'b')
		elif d < 0:
			dt = 128 + d
			l = dt.bit_length()
			v = "10000000"
			v = v[0:8-l] + format( dt, 'b')[:]
		else:
			v = "00000000"
	except:
		# print 'Invalid decimal number on line %d' % (linenum)
		print ('Invalid decimal number on line %d' % (linenum))
		exit()

	return v

# converts d to an 8-bit unsigned binary value
def dec2bin8( d, linenum ):
	if d > 0:
		l = d.bit_length()
		v = "00000000"
		v = v[0:8-l] + format( d, 'b' )
	elif d == 0:
		v = "00000000"
	else:
		# print 'Invalid address on line %d: value is negative' % (linenum)
		print ('Invalid address on line %d: value is negative' % (linenum))
		exit()

	return v


# Tokenizes the input data, discarding white space and comments
# returns the tokens as a list of lists, one list for each line.
#
# The tokenizer also converts each character to lower case.
def tokenize( fp ):
	tokens = []

	# start of the file
	fp.seek(0)

	lines = fp.readlines()

	# strip white space and comments from each line
	for line in lines:
		ls = line.strip()
		uls = ''
		for c in ls:
			if c != '#':
				uls = uls + c
			else:
				break

		# skip blank lines
		if len(uls) == 0:
			continue

		# split on white space
		words = uls.split()

		newwords = []
		for word in words:
			newwords.append( word.lower() )

		tokens.append( newwords )

	return tokens


# takes in the list of lists tokens and return symbols with their corresponding line numbers
def pass1( tokens, argu = False ):
	symbols = {}
	number = 0

	# parse each line
	# a line with a symbol ":" at the end
	for line in tokens:
		if line[0][-1] == ":":
			# error check : duplicate symbols
			if line[0][:-1] in symbols:
				print("duplicate symbol detected : \"" + line[0][:-1] + "\"")
				exit()
			symbols[line[0][:-1]] = number
		else:
			number += 1

	# remove lines from tokens
	if argu == False:
		lineNumbers = list(symbols.values())
		for num in lineNumbers:
			del tokens[num]

	return symbols

# takes in tokens and the dictionary to generate instructions
# output a list of machine instructions
def pass2( tokens, labels, argu = False ):
	code = []
	arguments = {} # used to store function lables
	
	for i,line in enumerate(tokens):
		instr = line[0]
		# error check : undefined instructions
		try:
			if instr == "load":
				code.append("00000"+tableB[line[1]]+dec2comp8(line[2],i))
			elif instr == "loada":
				if argu == True:
					if line[2] in arguments:
						line[2] = arguments[line[2]]
				code.append("00001"+tableB[line[1]]+dec2comp8(line[2],i))
			elif instr == "store":
				code.append("00010"+tableB[line[1]]+dec2comp8(line[2],i))
			elif instr == "storea":
				if argu == True:
					if line[2] in arguments:
						line[2] = arguments[line[2]]
				code.append("00011"+tableB[line[1]]+dec2comp8(line[2],i))
			elif instr == "bra":
				code.append("00100000"+dec2bin8(labels[line[1]],i))
			elif instr == "braz":
				code.append("00110000"+dec2bin8(labels[line[1]],i))
			elif instr == "bran":
				code.append("00110010"+dec2bin8(labels[line[1]],i))
			elif instr == "brao":
				code.append("00110001"+dec2bin8(labels[line[1]],i))
			elif instr == "brac":
				code.append("00110011"+dec2bin8(labels[line[1]],i))
			elif instr == "call":
				if argu == True:
					labels.update((m, n + 2 * len(line)-3) for m, n in labels.items() if n > len(code))
					code.append("0100000000000000") # return
					# append the code which push the ra and rb
					for k in range (2, len(line)):
						code.append("0100"+tableC[line[k]]+"000000000")

					# normal routine: call the function
					code.append("00110100"+dec2bin8(labels[line[1]],k))

					# pop the two things
					for k in range (2, len(line)):
						code.append("0101011000000000")

					#reset the dictionary for arguments
					arguments = {}
				else:
					code.append("00110100"+dec2bin8(labels[line[1]],i))
			elif instr == "return":
				code.append("0011100000000000")
			elif instr == "halt":
				code.append("0011110000000000")
			elif instr == "push":
				code.append("0100"+tableC[line[1]]+"000000000")
			elif instr == "pop":
				code.append("0101"+tableC[line[1]]+"000000000")
			elif instr == "oport":
				code.append("0110"+tableD[line[1]]+"000000000")
			elif instr == "iport":
				code.append("0111"+tableB[line[1]]+"000000000")
			elif instr == "add":
				code.append("1000"+tableE[line[1]]+tableE[line[2]]+"000"+tableB[line[3]])
			elif instr == "sub":
				code.append("1001"+tableE[line[1]]+tableE[line[2]]+"000"+tableB[line[3]])
			elif instr == "and":
				code.append("1010"+tableE[line[1]]+tableE[line[2]]+"000"+tableB[line[3]])
			elif instr == "or":
				code.append("1011"+tabelE[line[1]]+tableE[line[2]]+"000"+tableB[line[3]])
			elif instr == "xor":
				code.append("1100"+tableE[line[1]]+tableE[line[2]]+"000"+tableB[line[3]])
			elif instr == "shiftl":
				code.append("11100"+tableE[line[1]]+"00000"+tableB[line[2]])
			elif instr == "shiftr":
				code.append("11101"+tableE[line[1]]+"00000"+tableB[line[2]])
			elif instr == "rotl":
				code.append("11100"+tableE[line[1]]+"00000"+tableB[line[2]])
			elif instr == "rotr":
				code.append("11101"+tableE[line[1]]+"00000"+tableB[line[2]])
			elif instr == "move":
				code.append("11110"+tableD[line[1]]+"00000"+tableB[line[2]])
			elif instr == "movei":
				if argu == True:
					if line[2] in arguments:
						line[2] = arguments[line[2]]
				code.append("11111"+dec2comp8(int(line[1]),i)+tableB[line[2]])

			elif argu == True and instr[:-1] in labels:
				# parse the arguments here because pass1() only returns the dictionary of symbols/labels
				labels.update((m, n + 1) for m, n in labels.items() if n > len(code))
				for k in range (1, len(line) - 1):
					arguments[line[k]] =- len(line)
				arguments[line[-1]] =- len(line)
				code.append("1111010100000100") # move the stake pointer to RE
			else:
				# throw an error message
				print("instruction not defined : \"" + line[0] + "\"")
				exit()
		# KeyError : access a key that is not in the dictionary
		except KeyError as e:
			print("key not found : " + str(e))
	return code

def main( argv ):
	if len(argv) < 2:
		print ('Usage: python %s <filename>' % (argv[0]))
		exit()

	fp = open( argv[1], 'r' )

	tokens = tokenize( fp )

	fp.close()

	# execute pass1 and pass2 then print it out as an MIF file
	symbols = pass1(tokens, True)
	instructions = pass2(tokens, symbols, True)

	# start writing the MIF file
	outputName = str(argv[1]).replace(".txt", "") + ".mif"
	fout = open(outputName, 'w')
	# construct the header
	fout.write("-- Jiyao Chen\n-- 2019 Fall\n--CS232 Project 8\n-- MIF Program\nDEPTH = 256;\nWIDTH = 16;\nADDRESS_RADIX = HEX;\nDATA_RADIX = BIN;\nCONTENT\nBEGIN\n")

	for i, inst in enumerate(instructions):
		fout.write("%02X : %s;\n" %(i,inst)) # write instructions

	if i < 256:
		fout.write("[%02X..FF] : 1111111111111111;\n"%(i+1))
	
	fout.write("END")
	fout.close()
	return


if __name__ == "__main__":
	main(sys.argv)
	