import math.unsigned

fn test_str() {
	// converting from a string and then back to a string
	// should always give the original string.
	test_strings := [
		'0',
		'1',
		'9',
		'10',
		'11',
		'99',
		'100',
		'101',
		'65534',
		'65535',
		'65536', // 16-bit boundary
		'65537',
		'65538',
		'4294967294',
		'4294967295',
		'4294967296', // 32-bit boundary
		'4294967297',
		'4294967298',
		'281474976710654',
		'281474976710655',
		'281474976710656', // 48-bit boundary,
		'281474976710657',
		'281474976710658',
		'18446744073709551614',
		'18446744073709551615',
		'18446744073709551616', // 64-bit boundary
		'18446744073709551617',
		'18446744073709551618',
		'1208925819614629174706174',
		'1208925819614629174706175',
		'1208925819614629174706176', // 80-bit boundary
		'1208925819614629174706177',
		'1208925819614629174706178',
		'79228162514264337593543950334',
		'79228162514264337593543950335',
		'79228162514264337593543950336', // 96-bit boundary
		'79228162514264337593543950337',
		'79228162514264337593543950338',
		'5192296858534827628530496329220094',
		'5192296858534827628530496329220095',
		'5192296858534827628530496329220096', // 112-bit boundary
		'5192296858534827628530496329220097',
		'5192296858534827628530496329220098',
		'340282366920938463463374607431768211454',
		'340282366920938463463374607431768211455',
		'340282366920938463463374607431768211456', // 128-bit boundary
		'340282366920938463463374607431768211457',
		'340282366920938463463374607431768211458',
		'22300745198530623141535718272648361505980414',
		'22300745198530623141535718272648361505980415',
		'22300745198530623141535718272648361505980416', // 144-bit boundary
		'22300745198530623141535718272648361505980417',
		'22300745198530623141535718272648361505980418',
		'1461501637330902918203684832716283019655932542974',
		'1461501637330902918203684832716283019655932542975',
		'1461501637330902918203684832716283019655932542976', // 160-bit boundary
		'1461501637330902918203684832716283019655932542977',
		'1461501637330902918203684832716283019655932542978',
		'95780971304118053647396689196894323976171195136475134',
		'95780971304118053647396689196894323976171195136475135',
		'95780971304118053647396689196894323976171195136475136', // 176-bit boundary
		'95780971304118053647396689196894323976171195136475137',
		'95780971304118053647396689196894323976171195136475138',
		'6277101735386680763835789423207666416102355444464034512894',
		'6277101735386680763835789423207666416102355444464034512895',
		'6277101735386680763835789423207666416102355444464034512896', // 192-bit boundary
		'6277101735386680763835789423207666416102355444464034512897',
		'6277101735386680763835789423207666416102355444464034512898',
		'411376139330301510538742295639337626245683966408394965837152254',
		'411376139330301510538742295639337626245683966408394965837152255',
		'411376139330301510538742295639337626245683966408394965837152256', // 208-bit boundary
		'411376139330301510538742295639337626245683966408394965837152257',
		'411376139330301510538742295639337626245683966408394965837152258',
		'26959946667150639794667015087019630673637144422540572481103610249214',
		'26959946667150639794667015087019630673637144422540572481103610249215',
		'26959946667150639794667015087019630673637144422540572481103610249216', // 224-bit boundary
		'26959946667150639794667015087019630673637144422540572481103610249217',
		'26959946667150639794667015087019630673637144422540572481103610249218',
		'1766847064778384329583297500742918515827483896875618958121606201292619774',
		'1766847064778384329583297500742918515827483896875618958121606201292619775',
		'1766847064778384329583297500742918515827483896875618958121606201292619776', // 240-bit boundary
		'1766847064778384329583297500742918515827483896875618958121606201292619777',
		'1766847064778384329583297500742918515827483896875618958121606201292619778',
		'115792089237316195423570985008687907853269984665640564039457584007913129639934',
		'115792089237316195423570985008687907853269984665640564039457584007913129639935', // 2^256 - 1
	]

	for ts in test_strings {
		number := unsigned.uint256_from_dec_str(ts) or {
			assert false, 'invalid Uint256 string ${ts}'
			panic('')
		}

		assert number.str() == ts
	}

	fundamental_constant := unsigned.uint256_from_64(42)
	assert fundamental_constant.str() == '42'
}

fn test_ops() {
	x := unsigned.uint256_from_64(18446744073709551615)
	y := unsigned.uint256_from_64(18446744073709551615)
	z := unsigned.uint256_from_dec_str('340282366920938463426481119284349108225') or {
		assert false
		panic('')
	}
	assert (x * y).str() == '340282366920938463426481119284349108225'
	assert (x + y).str() == '36893488147419103230'
	assert (z / unsigned.uint256_from_64(2)).str() == '170141183460469231713240559642174554112'
	assert (unsigned.uint256_from_dec_str('170141183460469231713240559642174554112') or {
		panic('')
	} - unsigned.uint256_from_64(2)).str() == '170141183460469231713240559642174554110'

	assert x == y
	assert unsigned.uint256_from_dec_str('340282366920938463426481119284349108225') or {
		assert false
		panic('')
	} > y
}

struct LeadingZeros {
	l     unsigned.Uint256
	r     unsigned.Uint256
	zeros int
}

fn new(x unsigned.Uint128, y unsigned.Uint128) unsigned.Uint256 {
	return unsigned.Uint256{x, y}
}

fn test_leading_zeros() {
	tcs := [
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xf000000000000000))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x8000000000000000))
			zeros: 65
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xf000000000000000))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xc000000000000000))
			zeros: 66
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xf000000000000000))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xe000000000000000))
			zeros: 67
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xffff000000000000))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0xff00000000000000))
			zeros: 72
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x000000000000ffff))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x000000000000ff00))
			zeros: 120
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0xf000000000000000), unsigned.uint128_from_64(0x01))
			r:     new(unsigned.uint128_from_64(0x4000000000000000), unsigned.uint128_from_64(0x00))
			zeros: 127
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0xf000000000000000), unsigned.uint128_from_64(0x00))
			r:     new(unsigned.uint128_from_64(0x4000000000000000), unsigned.uint128_from_64(0x00))
			zeros: 192
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0xf000000000000000), unsigned.uint128_from_64(0x00))
			r:     new(unsigned.uint128_from_64(0x8000000000000000), unsigned.uint128_from_64(0x00))
			zeros: 193
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x00))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x00))
			zeros: 256
		},
		LeadingZeros{
			l:     new(unsigned.uint128_from_64(0x01), unsigned.uint128_from_64(0x00))
			r:     new(unsigned.uint128_from_64(0x00), unsigned.uint128_from_64(0x00))
			zeros: 255
		},
	]

	for tc in tcs {
		zeros := tc.l.xor(tc.r).leading_zeros()
		assert zeros == tc.zeros
	}
}

fn test_separators() {
	// numbers of varying lengths and a random
	// scattering of '_' throughout.
	test_strings := [
		'_',
		'__',
		'_0',
		'0_',
		'_0_',
		'_1',
		'1_',
		'_1_',
		'1_2',
		'_12',
		'12_',
		'12_3',
		'1_23_4',
		'12_345',
		'_123_456_',
		'1_234_567',
		'1234_5678',
		'_123456789',
		'1234567890_',
		'0_123_456_789_0',
		'90_12_345_67890',
		'8901_234_567890_',
		'_7890_123456789_0',
		'678901234_567890',
		'567890_1234567890',
		'4567890123__4567890',
		'_34567890123_4567890',
		'2345678_90123_4567890',
		'123456789_01_234567890',
		'01234567_8901234567890',
		'9012345678901_234567890__',
		'8_90123456_78901234567890',
		'78901234567890_123_4567890',
		'___67890123_4_5_6_78901234567890___',
		'567890123_45678901234567890',
		'45_67890123456789_01234567890',
		'3456789012_345678901234567890',
		'234_567890_1234_5__67890_1234567890_',
		'12345678_90123_456789_0123_4567890',
		'0_123_456_789_012_345_678_901_234_567_890',
		'90_123456__78901__234567_8901_234567890',
		'890123456789012345678901234567_890',
		'7890_1234567_8901234567890_1234567890',
		'67890123_45678_901234567_8901234567890',
		'567890_1234567890_12345678901_234567890',
		'45678_9012345_6789012345678901234567890_',
		'34567890123456_789012345678901234567890',
		'234567_890_1234567890_1234567890_1234567890',
		'334567890_1234567890_1234567890_1234567890',
		'340282360_0000000000_0000000000_0000000000',
		'340282366_9209384634_2648111928_4349108225',
		'340282366_9209384634_6337460743_1768211455',
		'6805_647__338418769269_267492148635_36422912',
		'13611294676837_5385385__34984297_27072845824_',
		'272225893_53675077077_0699685_94_5414569_1648',
		'_5444517_8707350154_1541_3993718908291383296',
		'223007_45198_5306231_4153571_8272648_361505_980416_',
		'146_150_163_733_090_291_820_368_483_271_628_301_965_593_254_297_6',
		'6_27_71_01_7353866807638_35789423207666416_1_0_2355444464034512896',
		'2695994_666715063_979466701508701_9630673637144422_540572481103610249216_',
		'11579208_923731619_5423570985008687_907853269_98_46_656405640__39457584_00791_3129639935',
	]

	for ts in test_strings {
		with := unsigned.uint256_from_dec_str(ts) or {
			assert false, 'invalid Uint256 string ${ts}'
			panic('')
		}

		without := unsigned.uint256_from_dec_str(ts.replace('_', '')) or {
			assert false, 'invalid Uint256 string ${ts.replace('_', '')}'
			panic('')
		}

		assert with == without
	}
}
