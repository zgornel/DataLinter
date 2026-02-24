# Interesting article here: https://www.datacamp.com/tutorial/r-formula-tutorial#
module RFormulaParser
	using Automa
	const re = Automa.RegExp

	@enum FormulaToken ERROR WHITESPACE TILDE PLUS MINUS STAR SLASH COLON CARET PIPE LPAREN RPAREN COMMA NUMBER IDENTIFIER BACKTICKED_ID

	# Regex patterns for R formula tokens
	# (whitespace is skipped in extraction; all other tokens ensure complete coverage)
	ws          = re"[\t\n\r\f]+"
	tilde       = re"~"
	plus        = re"\+"
	minus       = re"-"
	star        = re"\*"
	slash       = re"/"
	colon       = re":"
	caret       = re"\^"
	pipe        = re"\|"
	lparen      = re"\("
	rparen      = re"\)"
	comma       = re","
	dec      = re"[-+]?[0-9]+"
	prefloat = re"[-+]?([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)"
	float    = prefloat | ((prefloat | re"[-+]?[0-9]+") * re"[eE][-+]?[0-9]+")
	#oct      = re"0o[0-7]+"
	#hex      = re"0x[0-9A-Fa-f]+"
	number   = dec | float # |oct | hex

	# R identifiers (per R language rules)
	#   - Start with letter or .
	#   - If starts with ., second character cannot be a digit
	#   - Subsequent characters: letters, digits, ., _
	#   - Lone "." is valid (means "all variables" in formulas)
	id_start_letter = re"[a-zA-Z]" * re"[a-zA-Z0-9._]*"
	id_start_dot    = re"\.[a-zA-Z._]" * re"[a-zA-Z0-9._]*"
	id_lone_dot     = re"\."
	identifier      = id_start_letter | id_start_dot | id_lone_dot

	# Backticked identifiers (non-syntactic names, e.g. `odd name`)
	# Supports simple cases; escaped backticks are rare in formulas
	backticked      = re"`([^`]+)`"

	# Token list – order matters for longest-match and tie-breaking
	# (identifiers and numbers appear after operators so longest match wins, e.g. "x1" > "x")
	tokens = [
		WHITESPACE     => ws,
		TILDE          => tilde,
		PLUS           => plus,
		MINUS          => minus,
		STAR           => star,
		SLASH          => slash,
		COLON          => colon,
		CARET          => caret,
		PIPE           => pipe,
		LPAREN         => lparen,
		RPAREN         => rparen,
		COMMA          => comma,
		NUMBER         => number,
		IDENTIFIER     => identifier,
		BACKTICKED_ID  => backticked,
	]

	# Generate the tokenizer (uses the official Automa API)
	make_tokenizer((ERROR, tokens)) |> eval

	"""
		extract_identifiers(formula::AbstractString) -> Vector{String}

	Returns **only the variable names** from an R formula.
	- Function names (I(), factor(), log(), poly(), …) are excluded.
	- The special placeholder `.` is included to match all variables.
	- Backticked names are included (backticks removed).
	- Duplicates are removed.
	"""
	function extract_identifiers(formula::AbstractString)::Vector{String}
		tokens_list = collect(tokenize(FormulaToken, formula))
		vars = String[]
		i = 1
		n = length(tokens_list)
		while i <= n
			pos, len, tok = tokens_list[i]
			if tok == IDENTIFIER || tok == BACKTICKED_ID
				# Extract the name (strip backticks for BACKTICKED_ID)
				name = tok == IDENTIFIER ?
					   SubString(formula, pos, pos + len - 1) :
					   SubString(formula, pos + 1, pos + len - 2)
				# Look ahead (skip whitespace) to see if next token is '(' → function call
				j = i + 1
				while j <= n && tokens_list[j][3] == WHITESPACE
					j += 1
				end
				is_function = (j <= n && tokens_list[j][3] == LPAREN)
				if !is_function# && name != "."
					push!(vars, String(name))
				end
			end
			i += 1
		end
		return unique(vars)
	end
end  # module
