fn test_utf8_char_len() {
	assert utf8_char_len(`a`) == 1
	s := 'п'
	assert utf8_char_len(s[0]) == 2
}
