section .data
;; input data to encrypt and output encrypted data
	blocklen equ 16
    ;input db 0x32, 0x43, 0xF6, 0xA8, 0x88, 0x5A, 0x30, 0x8D, 0x31, 0x31, 0x98, 0xA2, 0xE0, 0x37, 0x07, 0x34
;    input db 0x0, 0x1, 0x0, 0x1, 0x1, 0xA1, 0x98, 0xAF, 0xDA, 0x78, 0x17, 0x34, 0x86, 0x15, 0x35, 0x66
	input times blocklen db 0
	output times blocklen db 0

;; constants from FIPS 197
	Nb equ 4
	Nk equ 4
	Nr equ 10

;; variables from FIPS 197
;   key db 0x2B, 0x7E, 0x15, 0x16, 0x28, 0xAE, 0xD2, 0xA6, 0xAB, 0xF7, 0x15, 0x88, 0x09, 0xCF, 0x4F, 0x3C
;	key db 0x0, 0x1, 0x20, 0x1, 0x71, 0x1, 0x98, 0xAE, 0xDA, 0x79, 0x17, 0x14, 0x60, 0x15, 0x35, 0x94
	key times blocklen db 0
	State times 4 * Nb db 0
	w times Nb*(Nr + 1) dd 0 ; expanded key
	temp dd 0		 ; temp space for key expansion

;; working space for mixcolumns / invmixcolumns
	mixcolin times Nb db 0
	mixcolout times Nb db 0
	
;; working space for I/O
	pbyte db 0

;;--------------------------------------------------------------------------------
;; Round constant word array - powers of x mod poly in GF(2^8)
	Rcon dd 0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000, 0x20000000, 0x40000000, 0x80000000, 0x1B000000, 0x36000000, 0x6C000000, 0xD8000000, 0xAB000000, 0x4D000000, 0x9A000000, 0x2F000000

;;--------------------------------------------------------------------------------
;; sbox and inverse sbox for AES S盒和逆S盒
	sbox db 0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76
	db 0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0
	db 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15
	db 0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75
	db 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84
	db 0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF
	db 0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8
	db 0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2
	db 0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73
	db 0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB
	db 0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79
	db 0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08
	db 0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A
	db 0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E
	db 0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF
	db 0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16

	inv_sbox db 0x52, 0x09, 0x6A, 0xD5, 0x30, 0x36, 0xA5, 0x38, 0xBF, 0x40, 0xA3, 0x9E, 0x81, 0xF3, 0xD7, 0xFB
	db 0x7C, 0xE3, 0x39, 0x82, 0x9B, 0x2F, 0xFF, 0x87, 0x34, 0x8E, 0x43, 0x44, 0xC4, 0xDE, 0xE9, 0xCB
	db 0x54, 0x7B, 0x94, 0x32, 0xA6, 0xC2, 0x23, 0x3D, 0xEE, 0x4C, 0x95, 0x0B, 0x42, 0xFA, 0xC3, 0x4E
	db 0x08, 0x2E, 0xA1, 0x66, 0x28, 0xD9, 0x24, 0xB2, 0x76, 0x5B, 0xA2, 0x49, 0x6D, 0x8B, 0xD1, 0x25
	db 0x72, 0xF8, 0xF6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xD4, 0xA4, 0x5C, 0xCC, 0x5D, 0x65, 0xB6, 0x92
	db 0x6C, 0x70, 0x48, 0x50, 0xFD, 0xED, 0xB9, 0xDA, 0x5E, 0x15, 0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84
	db 0x90, 0xD8, 0xAB, 0x00, 0x8C, 0xBC, 0xD3, 0x0A, 0xF7, 0xE4, 0x58, 0x05, 0xB8, 0xB3, 0x45, 0x06
	db 0xD0, 0x2C, 0x1E, 0x8F, 0xCA, 0x3F, 0x0F, 0x02, 0xC1, 0xAF, 0xBD, 0x03, 0x01, 0x13, 0x8A, 0x6B
	db 0x3A, 0x91, 0x11, 0x41, 0x4F, 0x67, 0xDC, 0xEA, 0x97, 0xF2, 0xCF, 0xCE, 0xF0, 0xB4, 0xE6, 0x73
	db 0x96, 0xAC, 0x74, 0x22, 0xE7, 0xAD, 0x35, 0x85, 0xE2, 0xF9, 0x37, 0xE8, 0x1C, 0x75, 0xDF, 0x6E
	db 0x47, 0xF1, 0x1A, 0x71, 0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B
	db 0xFC, 0x56, 0x3E, 0x4B, 0xC6, 0xD2, 0x79, 0x20, 0x9A, 0xDB, 0xC0, 0xFE, 0x78, 0xCD, 0x5A, 0xF4
	db 0x1F, 0xDD, 0xA8, 0x33, 0x88, 0x07, 0xC7, 0x31, 0xB1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xEC, 0x5F
	db 0x60, 0x51, 0x7F, 0xA9, 0x19, 0xB5, 0x4A, 0x0D, 0x2D, 0xE5, 0x7A, 0x9F, 0x93, 0xC9, 0x9C, 0xEF
	db 0xA0, 0xE0, 0x3B, 0x4D, 0xAE, 0x2A, 0xF5, 0xB0, 0xC8, 0xEB, 0xBB, 0x3C, 0x83, 0x53, 0x99, 0x61
	db 0x17, 0x2B, 0x04, 0x7E, 0xBA, 0x77, 0xD6, 0x26, 0xE1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0C, 0x7D

;;--------------------------------------------------------------------------------
;; Galois field GF(2^8) multiplication tables for mixcolumns/invmixcolumns
;; Multiply by 2:
	gmul2 db 0x00, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E
	db 0x20, 0x22, 0x24, 0x26, 0x28, 0x2A, 0x2C, 0x2E, 0x30, 0x32, 0x34, 0x36, 0x38, 0x3A, 0x3C, 0x3E
	db 0x40, 0x42, 0x44, 0x46, 0x48, 0x4A, 0x4C, 0x4E, 0x50, 0x52, 0x54, 0x56, 0x58, 0x5A, 0x5C, 0x5E
	db 0x60, 0x62, 0x64, 0x66, 0x68, 0x6A, 0x6C, 0x6E, 0x70, 0x72, 0x74, 0x76, 0x78, 0x7A, 0x7C, 0x7E
	db 0x80, 0x82, 0x84, 0x86, 0x88, 0x8A, 0x8C, 0x8E, 0x90, 0x92, 0x94, 0x96, 0x98, 0x9A, 0x9C, 0x9E
	db 0xA0, 0xA2, 0xA4, 0xA6, 0xA8, 0xAA, 0xAC, 0xAE, 0xB0, 0xB2, 0xB4, 0xB6, 0xB8, 0xBA, 0xBC, 0xBE
	db 0xC0, 0xC2, 0xC4, 0xC6, 0xC8, 0xCA, 0xCC, 0xCE, 0xD0, 0xD2, 0xD4, 0xD6, 0xD8, 0xDA, 0xDC, 0xDE
	db 0xE0, 0xE2, 0xE4, 0xE6, 0xE8, 0xEA, 0xEC, 0xEE, 0xF0, 0xF2, 0xF4, 0xF6, 0xF8, 0xFA, 0xFC, 0xFE
	db 0x1B, 0x19, 0x1F, 0x1D, 0x13, 0x11, 0x17, 0x15, 0x0B, 0x09, 0x0F, 0x0D, 0x03, 0x01, 0x07, 0x05
	db 0x3B, 0x39, 0x3F, 0x3D, 0x33, 0x31, 0x37, 0x35, 0x2B, 0x29, 0x2F, 0x2D, 0x23, 0x21, 0x27, 0x25
	db 0x5B, 0x59, 0x5F, 0x5D, 0x53, 0x51, 0x57, 0x55, 0x4B, 0x49, 0x4F, 0x4D, 0x43, 0x41, 0x47, 0x45
	db 0x7B, 0x79, 0x7F, 0x7D, 0x73, 0x71, 0x77, 0x75, 0x6B, 0x69, 0x6F, 0x6D, 0x63, 0x61, 0x67, 0x65
	db 0x9B, 0x99, 0x9F, 0x9D, 0x93, 0x91, 0x97, 0x95, 0x8B, 0x89, 0x8F, 0x8D, 0x83, 0x81, 0x87, 0x85
	db 0xBB, 0xB9, 0xBF, 0xBD, 0xB3, 0xB1, 0xB7, 0xB5, 0xAB, 0xA9, 0xAF, 0xAD, 0xA3, 0xA1, 0xA7, 0xA5
	db 0xdb, 0xD9, 0xDF, 0xDD, 0xD3, 0xD1, 0xD7, 0xD5, 0xCB, 0xC9, 0xCF, 0xCD, 0xC3, 0xC1, 0xC7, 0xC5
	db 0xFB, 0xF9, 0xFF, 0xFD, 0xF3, 0xF1, 0xF7, 0xF5, 0xEB, 0xE9, 0xEF, 0xED, 0xE3, 0xE1, 0xE7, 0xE5
;; Multiply by 3:
	gmul3 db 0x00, 0x03, 0x06, 0x05, 0x0C, 0x0F, 0x0A, 0x09, 0x18, 0x1B, 0x1E, 0x1D, 0x14, 0x17, 0x12, 0x11
	db 0x30, 0x33, 0x36, 0x35, 0x3C, 0x3F, 0x3A, 0x39, 0x28, 0x2B, 0x2E, 0x2D, 0x24, 0x27, 0x22, 0x21
	db 0x60, 0x63, 0x66, 0x65, 0x6C, 0x6F, 0x6A, 0x69, 0x78, 0x7B, 0x7E, 0x7D, 0x74, 0x77, 0x72, 0x71
	db 0x50, 0x53, 0x56, 0x55, 0x5C, 0x5F, 0x5A, 0x59, 0x48, 0x4B, 0x4E, 0x4D, 0x44, 0x47, 0x42, 0x41
	db 0xC0, 0xC3, 0xC6, 0xC5, 0xCC, 0xCF, 0xCA, 0xC9, 0xD8, 0xdb, 0xDE, 0xDD, 0xD4, 0xD7, 0xD2, 0xD1
	db 0xF0, 0xF3, 0xF6, 0xF5, 0xFC, 0xFF, 0xFA, 0xF9, 0xE8, 0xEB, 0xEE, 0xED, 0xE4, 0xE7, 0xE2, 0xE1
	db 0xA0, 0xA3, 0xA6, 0xA5, 0xAC, 0xAF, 0xAA, 0xA9, 0xB8, 0xBB, 0xBE, 0xBD, 0xB4, 0xB7, 0xB2, 0xB1
	db 0x90, 0x93, 0x96, 0x95, 0x9C, 0x9F, 0x9A, 0x99, 0x88, 0x8B, 0x8E, 0x8D, 0x84, 0x87, 0x82, 0x81
	db 0x9B, 0x98, 0x9D, 0x9E, 0x97, 0x94, 0x91, 0x92, 0x83, 0x80, 0x85, 0x86, 0x8F, 0x8C, 0x89, 0x8A
	db 0xAB, 0xA8, 0xAD, 0xAE, 0xA7, 0xA4, 0xA1, 0xA2, 0xB3, 0xB0, 0xB5, 0xB6, 0xBF, 0xBC, 0xB9, 0xBA
	db 0xFB, 0xF8, 0xFD, 0xFE, 0xF7, 0xF4, 0xF1, 0xF2, 0xE3, 0xE0, 0xE5, 0xE6, 0xEF, 0xEC, 0xE9, 0xEA
	db 0xCB, 0xC8, 0xCD, 0xCE, 0xC7, 0xC4, 0xC1, 0xC2, 0xD3, 0xD0, 0xD5, 0xD6, 0xDF, 0xDC, 0xD9, 0xDA
	db 0x5B, 0x58, 0x5D, 0x5E, 0x57, 0x54, 0x51, 0x52, 0x43, 0x40, 0x45, 0x46, 0x4F, 0x4C, 0x49, 0x4A
	db 0x6B, 0x68, 0x6D, 0x6E, 0x67, 0x64, 0x61, 0x62, 0x73, 0x70, 0x75, 0x76, 0x7F, 0x7C, 0x79, 0x7A
	db 0x3B, 0x38, 0x3D, 0x3E, 0x37, 0x34, 0x31, 0x32, 0x23, 0x20, 0x25, 0x26, 0x2F, 0x2C, 0x29, 0x2A
	db 0x0B, 0x08, 0x0D, 0x0E, 0x07, 0x04, 0x01, 0x02, 0x13, 0x10, 0x15, 0x16, 0x1F, 0x1C, 0x19, 0x1A
;; Multiply by 9:
	gmul9 db 0x00, 0x09, 0x12, 0x1B, 0x24, 0x2D, 0x36, 0x3F, 0x48, 0x41, 0x5A, 0x53, 0x6C, 0x65, 0x7E, 0x77
	db 0x90, 0x99, 0x82, 0x8B, 0xB4, 0xBD, 0xA6, 0xAF, 0xD8, 0xD1, 0xCA, 0xC3, 0xFC, 0xF5, 0xEE, 0xE7
	db 0x3B, 0x32, 0x29, 0x20, 0x1F, 0x16, 0x0D, 0x04, 0x73, 0x7A, 0x61, 0x68, 0x57, 0x5E, 0x45, 0x4C
	db 0xAB, 0xA2, 0xB9, 0xB0, 0x8F, 0x86, 0x9D, 0x94, 0xE3, 0xEA, 0xF1, 0xF8, 0xC7, 0xCE, 0xD5, 0xDC
	db 0x76, 0x7F, 0x64, 0x6D, 0x52, 0x5B, 0x40, 0x49, 0x3E, 0x37, 0x2C, 0x25, 0x1A, 0x13, 0x08, 0x01
	db 0xE6, 0xEF, 0xF4, 0xFD, 0xC2, 0xCB, 0xD0, 0xD9, 0xAE, 0xA7, 0xBC, 0xB5, 0x8A, 0x83, 0x98, 0x91
	db 0x4D, 0x44, 0x5F, 0x56, 0x69, 0x60, 0x7B, 0x72, 0x05, 0x0C, 0x17, 0x1E, 0x21, 0x28, 0x33, 0x3A
	db 0xDD, 0xD4, 0xCF, 0xC6, 0xF9, 0xF0, 0xEB, 0xE2, 0x95, 0x9C, 0x87, 0x8E, 0xB1, 0xB8, 0xA3, 0xAA
	db 0xEC, 0xE5, 0xFE, 0xF7, 0xC8, 0xC1, 0xDA, 0xD3, 0xA4, 0xAD, 0xB6, 0xBF, 0x80, 0x89, 0x92, 0x9B
	db 0x7C, 0x75, 0x6E, 0x67, 0x58, 0x51, 0x4A, 0x43, 0x34, 0x3D, 0x26, 0x2F, 0x10, 0x19, 0x02, 0x0B
	db 0xD7, 0xDE, 0xC5, 0xCC, 0xF3, 0xFA, 0xE1, 0xE8, 0x9F, 0x96, 0x8D, 0x84, 0xBB, 0xB2, 0xA9, 0xA0
	db 0x47, 0x4E, 0x55, 0x5C, 0x63, 0x6A, 0x71, 0x78, 0x0F, 0x06, 0x1D, 0x14, 0x2B, 0x22, 0x39, 0x30
	db 0x9A, 0x93, 0x88, 0x81, 0xBE, 0xB7, 0xAC, 0xA5, 0xD2, 0xdb, 0xC0, 0xC9, 0xF6, 0xFF, 0xE4, 0xED
	db 0x0A, 0x03, 0x18, 0x11, 0x2E, 0x27, 0x3C, 0x35, 0x42, 0x4B, 0x50, 0x59, 0x66, 0x6F, 0x74, 0x7D
	db 0xA1, 0xA8, 0xB3, 0xBA, 0x85, 0x8C, 0x97, 0x9E, 0xE9, 0xE0, 0xFB, 0xF2, 0xCD, 0xC4, 0xDF, 0xD6
	db 0x31, 0x38, 0x23, 0x2A, 0x15, 0x1C, 0x07, 0x0E, 0x79, 0x70, 0x6B, 0x62, 0x5D, 0x54, 0x4F, 0x46
;; Multiply by 11:
	gmul11 db 0x00, 0x0B, 0x16, 0x1D, 0x2C, 0x27, 0x3A, 0x31, 0x58, 0x53, 0x4E, 0x45, 0x74, 0x7F, 0x62, 0x69
	db 0xB0, 0xBB, 0xA6, 0xAD, 0x9C, 0x97, 0x8A, 0x81, 0xE8, 0xE3, 0xFE, 0xF5, 0xC4, 0xCF, 0xD2, 0xD9
	db 0x7B, 0x70, 0x6D, 0x66, 0x57, 0x5C, 0x41, 0x4A, 0x23, 0x28, 0x35, 0x3E, 0x0F, 0x04, 0x19, 0x12
	db 0xCB, 0xC0, 0xDD, 0xD6, 0xE7, 0xEC, 0xF1, 0xFA, 0x93, 0x98, 0x85, 0x8E, 0xBF, 0xB4, 0xA9, 0xA2
	db 0xF6, 0xFD, 0xE0, 0xEB, 0xDA, 0xD1, 0xCC, 0xC7, 0xAE, 0xA5, 0xB8, 0xB3, 0x82, 0x89, 0x94, 0x9F
	db 0x46, 0x4D, 0x50, 0x5B, 0x6A, 0x61, 0x7C, 0x77, 0x1E, 0x15, 0x08, 0x03, 0x32, 0x39, 0x24, 0x2F
	db 0x8D, 0x86, 0x9B, 0x90, 0xA1, 0xAA, 0xB7, 0xBC, 0xD5, 0xDE, 0xC3, 0xC8, 0xF9, 0xF2, 0xEF, 0xE4
	db 0x3D, 0x36, 0x2B, 0x20, 0x11, 0x1A, 0x07, 0x0C, 0x65, 0x6E, 0x73, 0x78, 0x49, 0x42, 0x5F, 0x54
	db 0xF7, 0xFC, 0xE1, 0xEA, 0xdb, 0xD0, 0xCD, 0xC6, 0xAF, 0xA4, 0xB9, 0xB2, 0x83, 0x88, 0x95, 0x9E
	db 0x47, 0x4C, 0x51, 0x5A, 0x6B, 0x60, 0x7D, 0x76, 0x1F, 0x14, 0x09, 0x02, 0x33, 0x38, 0x25, 0x2E
	db 0x8C, 0x87, 0x9A, 0x91, 0xA0, 0xAB, 0xB6, 0xBD, 0xD4, 0xDF, 0xC2, 0xC9, 0xF8, 0xF3, 0xEE, 0xE5
	db 0x3C, 0x37, 0x2A, 0x21, 0x10, 0x1B, 0x06, 0x0D, 0x64, 0x6F, 0x72, 0x79, 0x48, 0x43, 0x5E, 0x55
	db 0x01, 0x0A, 0x17, 0x1C, 0x2D, 0x26, 0x3B, 0x30, 0x59, 0x52, 0x4F, 0x44, 0x75, 0x7E, 0x63, 0x68
	db 0xB1, 0xBA, 0xA7, 0xAC, 0x9D, 0x96, 0x8B, 0x80, 0xE9, 0xE2, 0xFF, 0xF4, 0xC5, 0xCE, 0xD3, 0xD8
	db 0x7A, 0x71, 0x6C, 0x67, 0x56, 0x5D, 0x40, 0x4B, 0x22, 0x29, 0x34, 0x3F, 0x0E, 0x05, 0x18, 0x13
	db 0xCA, 0xC1, 0xDC, 0xD7, 0xE6, 0xED, 0xF0, 0xFB, 0x92, 0x99, 0x84, 0x8F, 0xBE, 0xB5, 0xA8, 0xA3
;; Multiply by 13:
	gmul13 db 0x00, 0x0D, 0x1A, 0x17, 0x34, 0x39, 0x2E, 0x23, 0x68, 0x65, 0x72, 0x7F, 0x5C, 0x51, 0x46, 0x4B
	db 0xD0, 0xDD, 0xCA, 0xC7, 0xE4, 0xE9, 0xFE, 0xF3, 0xB8, 0xB5, 0xA2, 0xAF, 0x8C, 0x81, 0x96, 0x9B
	db 0xBB, 0xB6, 0xA1, 0xAC, 0x8F, 0x82, 0x95, 0x98, 0xD3, 0xDE, 0xC9, 0xC4, 0xE7, 0xEA, 0xFD, 0xF0
	db 0x6B, 0x66, 0x71, 0x7C, 0x5F, 0x52, 0x45, 0x48, 0x03, 0x0E, 0x19, 0x14, 0x37, 0x3A, 0x2D, 0x20
	db 0x6D, 0x60, 0x77, 0x7A, 0x59, 0x54, 0x43, 0x4E, 0x05, 0x08, 0x1F, 0x12, 0x31, 0x3C, 0x2B, 0x26
	db 0xBD, 0xB0, 0xA7, 0xAA, 0x89, 0x84, 0x93, 0x9E, 0xD5, 0xD8, 0xCF, 0xC2, 0xE1, 0xEC, 0xFB, 0xF6
	db 0xD6, 0xdb, 0xCC, 0xC1, 0xE2, 0xEF, 0xF8, 0xF5, 0xBE, 0xB3, 0xA4, 0xA9, 0x8A, 0x87, 0x90, 0x9D
	db 0x06, 0x0B, 0x1C, 0x11, 0x32, 0x3F, 0x28, 0x25, 0x6E, 0x63, 0x74, 0x79, 0x5A, 0x57, 0x40, 0x4D
	db 0xDA, 0xD7, 0xC0, 0xCD, 0xEE, 0xE3, 0xF4, 0xF9, 0xB2, 0xBF, 0xA8, 0xA5, 0x86, 0x8B, 0x9C, 0x91
	db 0x0A, 0x07, 0x10, 0x1D, 0x3E, 0x33, 0x24, 0x29, 0x62, 0x6F, 0x78, 0x75, 0x56, 0x5B, 0x4C, 0x41
	db 0x61, 0x6C, 0x7B, 0x76, 0x55, 0x58, 0x4F, 0x42, 0x09, 0x04, 0x13, 0x1E, 0x3D, 0x30, 0x27, 0x2A
	db 0xB1, 0xBC, 0xAB, 0xA6, 0x85, 0x88, 0x9F, 0x92, 0xD9, 0xD4, 0xC3, 0xCE, 0xED, 0xE0, 0xF7, 0xFA
	db 0xB7, 0xBA, 0xAD, 0xA0, 0x83, 0x8E, 0x99, 0x94, 0xDF, 0xD2, 0xC5, 0xC8, 0xEB, 0xE6, 0xF1, 0xFC
	db 0x67, 0x6A, 0x7D, 0x70, 0x53, 0x5E, 0x49, 0x44, 0x0F, 0x02, 0x15, 0x18, 0x3B, 0x36, 0x21, 0x2C
	db 0x0C, 0x01, 0x16, 0x1B, 0x38, 0x35, 0x22, 0x2F, 0x64, 0x69, 0x7E, 0x73, 0x50, 0x5D, 0x4A, 0x47
	db 0xDC, 0xD1, 0xC6, 0xCB, 0xE8, 0xE5, 0xF2, 0xFF, 0xB4, 0xB9, 0xAE, 0xA3, 0x80, 0x8D, 0x9A, 0x97
;; Multiply by 14:
	gmul14 db 0x00, 0x0E, 0x1C, 0x12, 0x38, 0x36, 0x24, 0x2A, 0x70, 0x7E, 0x6C, 0x62, 0x48, 0x46, 0x54, 0x5A
	db 0xE0, 0xEE, 0xFC, 0xF2, 0xD8, 0xD6, 0xC4, 0xCA, 0x90, 0x9E, 0x8C, 0x82, 0xA8, 0xA6, 0xB4, 0xBA
	db 0xdb, 0xD5, 0xC7, 0xC9, 0xE3, 0xED, 0xFF, 0xF1, 0xAB, 0xA5, 0xB7, 0xB9, 0x93, 0x9D, 0x8F, 0x81
	db 0x3B, 0x35, 0x27, 0x29, 0x03, 0x0D, 0x1F, 0x11, 0x4B, 0x45, 0x57, 0x59, 0x73, 0x7D, 0x6F, 0x61
	db 0xAD, 0xA3, 0xB1, 0xBF, 0x95, 0x9B, 0x89, 0x87, 0xDD, 0xD3, 0xC1, 0xCF, 0xE5, 0xEB, 0xF9, 0xF7
	db 0x4D, 0x43, 0x51, 0x5F, 0x75, 0x7B, 0x69, 0x67, 0x3D, 0x33, 0x21, 0x2F, 0x05, 0x0B, 0x19, 0x17
	db 0x76, 0x78, 0x6A, 0x64, 0x4E, 0x40, 0x52, 0x5C, 0x06, 0x08, 0x1A, 0x14, 0x3E, 0x30, 0x22, 0x2C
	db 0x96, 0x98, 0x8A, 0x84, 0xAE, 0xA0, 0xB2, 0xBC, 0xE6, 0xE8, 0xFA, 0xF4, 0xDE, 0xD0, 0xC2, 0xCC
	db 0x41, 0x4F, 0x5D, 0x53, 0x79, 0x77, 0x65, 0x6B, 0x31, 0x3F, 0x2D, 0x23, 0x09, 0x07, 0x15, 0x1B
	db 0xA1, 0xAF, 0xBD, 0xB3, 0x99, 0x97, 0x85, 0x8B, 0xD1, 0xDF, 0xCD, 0xC3, 0xE9, 0xE7, 0xF5, 0xFB
	db 0x9A, 0x94, 0x86, 0x88, 0xA2, 0xAC, 0xBE, 0xB0, 0xEA, 0xE4, 0xF6, 0xF8, 0xD2, 0xDC, 0xCE, 0xC0
	db 0x7A, 0x74, 0x66, 0x68, 0x42, 0x4C, 0x5E, 0x50, 0x0A, 0x04, 0x16, 0x18, 0x32, 0x3C, 0x2E, 0x20
	db 0xEC, 0xE2, 0xF0, 0xFE, 0xD4, 0xDA, 0xC8, 0xC6, 0x9C, 0x92, 0x80, 0x8E, 0xA4, 0xAA, 0xB8, 0xB6
	db 0x0C, 0x02, 0x10, 0x1E, 0x34, 0x3A, 0x28, 0x26, 0x7C, 0x72, 0x60, 0x6E, 0x44, 0x4A, 0x58, 0x56
	db 0x37, 0x39, 0x2B, 0x25, 0x0F, 0x01, 0x13, 0x1D, 0x47, 0x49, 0x5B, 0x55, 0x7F, 0x71, 0x63, 0x6D
	db 0xD7, 0xD9, 0xCB, 0xC5, 0xEF, 0xE1, 0xF3, 0xFD, 0xA7, 0xA9, 0xBB, 0xB5, 0x9F, 0x91, 0x83, 0x8D


section .text
global _begin
global _begintoencry
global _begintodecry

_begin:
;; encryption algorithm starts here
;首先加载密钥
	mov ecx, 4
	mov r8, rdi
	mov r9, key
looploadkey:
	mov eax, [r8]
	;bswap eax
	mov [r9], eax
	add r8, 4
	add r9, 4
	dec ecx
	cmp ecx, 0
	jne looploadkey

;加载输入，可能是明文也可能是密文
	mov ecx, 4
	mov r8, rsi
	mov r9, input
looploadinput:
	mov eax, [r8]
	;bswap eax
	mov [r9], eax
	add r8, 4
	add r9, 4
	dec ecx
	cmp ecx, 0
	jne looploadinput
	xor ecx, ecx
	xor r8, r8
	xor r9, r9
  	call keyexpansion		; 密钥扩展
;	mov rax, key
	ret

_begintoencry:
	call inptostate
	mov rax, w              ; first round key starts at w[0]
	call addroundkey		; 第一轮加密之前的轮密钥加，密钥使用w[0]，实际就是初始密钥
cipherloop0:
   	mov r13, 1              ; round number, 执行轮数，这里为1实际上循环9次，因为最后一次没有列混合，要单独处理
cipherloop:
	
   	call subbytes
   	call shiftrows
   	call mixcolumns

	mov r14, r13
	shl r14, 4		; mul by 16
	lea rax, [w + r14]
   	call addroundkey
	;mov rax, State
	;call printary16
	;call newline

	inc r13
	cmp r13, Nr
   	jne cipherloop
	call subbytes
   	call shiftrows

	mov r14, r13
	shl r14, 4
	lea rax, [w + r14]    ; last round key
   	call addroundkey
	call statetoout
	mov rax, output
	ret

;;--------------------------------------------------------------------------------
;; Decrypt output with inverse cipher
_begintodecry:
	call inptostate

	lea rax, [w + Nr * Nb * Nb] ; start at end of extended key
	call addroundkey
	;mov rax, State
	;call printary16
	;call newline
	lea rax, [w + Nr * Nb * Nb]
	mov r13, Nr-1		; round number

invcipherloop:
	call invshiftrows
	call invsubbytes

	mov r14, r13
	shl r14, 4
	;lea rax, [w + r14]
	;call printary16
	;call newline
	lea rax, [w + r14]
	call addroundkey
	;mov rax, State
	;call printary16
	;call newline
	;lea rax, [w + 14]
	call invmixcolumns
	;lea rax, [w + r14]
	;call addroundkey
	;mov rax, State
	;call printary16
	;call newline
	dec r13
	cmp r13, 0
	jne invcipherloop

	call invshiftrows
	call invsubbytes
	mov rax, w
	call addroundkey
	
	call statetoout

	mov rax, output
	ret

;;--------------------------------------------------------------------------------
;; FIPS 197 Section 5.1.1
subbytes:
	xor rax, rax
    xor rcx, rcx
	xor rdi, rdi
subbytesloop:
	mov al, [State + rdi]
	mov cl, [sbox + rax]
	mov [State + rdi], cl
	inc rdi
	cmp rdi, blocklen
	jne subbytesloop
	ret

;; FIPS 197 Section 5.3.2
invsubbytes:
	xor rax, rax
    xor rcx, rcx
	xor rdi, rdi
invsubbytesloop:
	mov al, [State + rdi]
	mov cl, [inv_sbox + rax]
	mov [State + rdi], cl
	inc rdi
	cmp rdi, blocklen
	jne invsubbytesloop
	ret
	
;;--------------------------------------------------------------------------------
;; FIPS 197 Section 3.4
;; 这个函数里面进行了一个转换，因为我们输入时候是横向的in0、in1等等，但是输出时候我们想要的输入字节4*4矩阵第一行实际对应的是in0、in4、in8、in12，所以这里在装入state时候进行了下替换
;; 这个函数对State进行了初始化
inptostate:
	xor r9, r9
	xor rax, rax 		; row, 外层循环
inptostateloop2:
	xor rdi, rdi		; col, 内层循环
inptostateloop:
	mov r9b, [input + rax + Nb*rdi];注意这里和下面的加上的地址偏移是不同的，也就是进行了上面提到的转换
	mov [State + rdi + Nb*rax], r9b
	inc rdi				;加1个
	cmp rdi, Nb			;Nb=4
	jne inptostateloop
	inc rax
	cmp rax, Nb
	jne inptostateloop2
	ret
;; 类似上面的State初始化，只不过这个是用在解密过程中的，因为单独解密过程时候State并没有数据，所以要将密文装入，思路与上面相同
outtostate:
	xor r9, r9
	xor rax, rax 		; row
outtostateloop2:
	xor rdi, rdi		; col
outtostateloop:
	mov r9b, [output + rax + Nb*rdi]
	mov [State + rdi + Nb*rax], r9b
	;mov [State + rax + Nb*rdi], r9b
	inc rdi
	cmp rdi, Nb
	jne outtostateloop
	inc rax
	cmp rax, Nb
	jne outtostateloop2
	ret

;; FIPS 197 Section 3.4
;; 将最后的State转换为密文
statetoout:
	xor r9, r9
	xor rax, rax		; row
statetooutloop2:
	xor rdi, rdi		; col
statetooutloop:
	mov r9b, [State + rax + Nb*rdi]
	mov [output + rdi + Nb*rax], r9b
	;mov [output + rax + Nb*rdi], r9b
	inc rdi
	cmp rdi, Nb
	jne statetooutloop
	inc rax
	cmp rax, Nb
	jne statetooutloop2
	ret
	
;;--------------------------------------------------------------------------------
;; FIPS 197 Section 5.1.2
shiftrows:
	mov eax, [State + Nb]	; row 1
	ror eax, 8
	mov [State + Nb], eax
	mov eax, [State + 2*Nb]	; row 2
	ror eax, 16
	mov [State + 2*Nb], eax
	mov eax, [State + 3*Nb]	; row 3
	ror eax, 24
	mov [State + 3*Nb], eax
	ret

;; FIPS 197 Section 5.3.1
invshiftrows:
	mov eax, [State + Nb]	; row 1
	rol eax, 8
	mov [State + Nb], eax
	mov eax, [State + 2*Nb] ; row 2
	rol eax, 16
	mov [State + 2*Nb], eax
	mov eax, [State + 3*Nb]	; row 3
	rol eax, 24
	mov [State + 3*Nb], eax
	ret

;;--------------------------------------------------------------------------------
;; FIPS 197 Section 5.1.3

mixcolumns:
	xor rax, rax 		; column
mixcolumnsloop2:
	xor rbx, rbx		; row
mixcolumnsloop:
	mov cl, [State + rax + 4*rbx]
	mov [mixcolin + rbx], cl
	inc rbx
	cmp rbx, Nb
	jne mixcolumnsloop
	call mixcolumn		; complete column in [mixcolin]

	xor rbx, rbx		; copy computed column into state
mixcolumnsloop3:
	mov r8b, [mixcolout + rbx]
	mov [State + rax + 4*rbx], r8b
	inc rbx
	cmp rbx, Nb
	jne mixcolumnsloop3

	inc rax
	cmp rax, Nb
	jne mixcolumnsloop2
	ret

mixcolumn:
	xor r8, r8
	mov r8b, [mixcolin]	; r8b = input term, r9b = accumulator
	mov r9b, [gmul2 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul3 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, r8b
	mov r8b, [mixcolin + 3]
	xor r9b, r8b
	mov [mixcolout], r9b

	mov r9b, [mixcolin]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul2 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul3 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, r8b
	mov [mixcolout + 1], r9b

	mov r9b, [mixcolin]
	mov r8b, [mixcolin + 1]
	xor r9b, r8b
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul2 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul3 + r8]
	mov [mixcolout + 2], r9b

	mov r8b, [mixcolin]
	mov r9b, [gmul3 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, r8b
	mov r8b, [mixcolin + 2]
	xor r9b, r8b
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul2 + r8]
	mov [mixcolout + 3], r9b

	ret

;; FIPS 197 Section 5.3.3

invmixcolumns:
	xor rax, rax		; column
invmixcolumnsloop2:
	xor rbx, rbx		; row
invmixcolumnsloop:
	mov cl, [State + rax + 4*rbx]
	mov [mixcolin + rbx], cl
	inc rbx
	cmp rbx, Nb
	jne invmixcolumnsloop
	call invmixcolumn	; complete column in [mixcolin]

	xor rbx, rbx		; copy computed column into state
invmixcolumnsloop3:
	mov r8b, [mixcolout + rbx]
	mov [State + rax + 4*rbx], r8b
	inc rbx
	cmp rbx, Nb
	jne invmixcolumnsloop3

	inc rax
	cmp rax, Nb
	jne invmixcolumnsloop2
	ret

invmixcolumn:
	xor r8, r8
	mov r8b, [mixcolin]	; r8b = input term, r9b = accumulator
	mov r9b, [gmul14 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul11 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul13 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul9 + r8]
	mov [mixcolout], r9b
	
	mov r8b, [mixcolin]
	mov r9b, [gmul9 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul14 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul11 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul13 + r8]
	mov [mixcolout + 1], r9b

	mov r8b, [mixcolin]
	mov r9b, [gmul13 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul9 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul14 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul11 + r8]
	mov [mixcolout + 2], r9b

	mov r8b, [mixcolin]
	mov r9b, [gmul11 + r8]
	mov r8b, [mixcolin + 1]
	xor r9b, [gmul13 + r8]
	mov r8b, [mixcolin + 2]
	xor r9b, [gmul9 + r8]
	mov r8b, [mixcolin + 3]
	xor r9b, [gmul14 + r8]
	mov [mixcolout + 3], r9b

	ret

;;--------------------------------------------------------------------------------
;; FIPS 197 Section 5.2
keyexpansion:
	xor rax, rax ;rax置零
;首先将密钥分为四个部分存储到W中
keyexpansionloop:
	mov cl, [key + 4*rax]   ;rax为最开始0，也就是密钥前8位存储到cl
	shl ecx, 8				;ecx左移8位，准备继续存储密钥
   	mov bl, [key + 4*rax + 1];密钥第2个字节存储到bl里面
    or ecx, ebx				;并加到ecx中
    shl ecx, 8				;ecx继续移8位
    mov bl, [key + 4*rax + 2];密钥第3个字节移动到bl中
    or ecx, ebx				;加到ecx里面
	shl ecx, 8				;移动8位
    mov bl, [key + 4*rax + 3];密钥第四个字节移动到bl中
    or ecx, ebx				;加到ecx里面
	bswap ecx				;bswap表示将ecx中的数据字节次序取反
	mov [w + 4*rax], ecx	;存储到w矩阵中
   	inc rax					;rax+1，准备存储下一个4字节
	cmp rax, Nk				;一直到分割完原先的密钥
	jne keyexpansionloop	
;; rax = Nk here

keyexpansionloop2:
	mov rsi, rax 		;4 * rax指向w[4]，暂时是空的
    dec rsi				;4 * rsi指向了w[3]
	mov ecx, [w + 4*rsi];也就是w[3]
	mov [temp], ecx		;tmp里面存储w[3]
	mov rdx, rax		;rdx这时应该是4
	and rdx, 0x3		;第一次循环里面4&3=0
	cmp rdx, 0			;比较rdx是不是0
	jne keyexpansionelse 	; if rax mod Nk != 0 是0的话跳转到else,实际上也是if,不过这里跳转表示这里是4的倍数，可以直接跳转亦或w[i-1]，否则不是的话还有一个函数T，需要以下代码解决之后存储到temp中
	mov rdx, rax		;到这里代表rax不是4的倍数
	mov rax, temp		;
	call rotword		;[rax]循环右移8位
	call subword		;将rax右移之后的结果作为S盒的输入，得到输出,最终结果存储在[rax]中，也就是[temp]中
	mov rax, rdx		;原先的rax，也就是上面不是4的倍数之后的序号
	mov ecx, [temp]		;将S盒变换之后的值存入ecx中
	shr rdx, 2		; rdx = rax / Nk (Nk = 4)，也就是对应的w[i]中i序号，抹去了低位
	dec rdx			; rdx-1,表示W[i-1]
	mov esi, [Rcon + 4*rdx];esi存储写常量Rcon[1]的值
    bswap esi			;将Rcon[1]的值字节倒序
	xor ecx, esi		;与ecx进行疑惑运算，这里ecx也就是S盒之后的结果
	mov [temp], ecx		;得到T函数输出，接下来可以进行计算了，计算过程与else相同
	jmp keyexpansionendif

keyexpansionelse:
	; in AES-128, Nk is always 4, don't have to deal with this case separately.
keyexpansionendif:
	mov ebx, [w + 4*rax - 4*Nk]	; ebx存储W[i-4]
	xor ebx, [temp]				; w[i-4] ^ w[i-1]，在是4倍数时候代表w[i-1]
	mov [w + 4*rax], ebx		;w[i] = w[i-4]^w[i-1]
	inc rax						;rax增加1
	cmp rax, Nb * (Nr + 1)		;比较是否完成了所有密钥扩展
	jne keyexpansionloop2

	ret

;; rax points to input/output word
;; uses r8, r9, r10
subword:
	xor r8, r8;r8作为计数变量
subwordloop:
	mov r9b, [rax + r8]
	mov r10b, [sbox + r9]
	mov [rax + r8], r10b
	inc r8
	cmp r8, Nb
	jne subwordloop
	ret

;; rax points to input/output word
;; uses r8
;; 循环右移
rotword:
	mov r8d, [rax]
	ror r8d, 8
	mov [rax], r8d
	ret

;;--------------------------------------------------------------------------------
;; FIPS 197 Section 5.1.4
;; rax = ptr to round key
;; rax存储密钥的地址
addroundkey:
	xor rbx, rbx 		; row 外层循环
addroundkeyloop2:
	xor rcx, rcx		; column 内层循环
addroundkeyloop:
	mov r8b, [State + rcx + 4*rbx]
	mov r9, rax
	add r9, rbx
	xor r8b, [r9 + 4*rcx]
	mov [State + rcx + 4*rbx], r8b
	inc rcx
	cmp rcx, Nb
	jne addroundkeyloop
	inc rbx
	cmp rbx, Nb
	jne addroundkeyloop2
	ret

;;--------------------------------------------------------------------------------
;; rax = return code to shell
exit:
	mov rax, output
	ret
	;mov rdi, rax
	;mov rax, 60
	;syscall

;; print a 16-byte array
;; uses: all regs, [pbyte]
;; rax - array to print
printary16:
	mov r12, rax ;rax存放要打印字符串的地址，转移到r12寄存器中
	xor r10, r10 ;r10置零

printary16loop:
	mov al, [r12 + r10];r10为当前打印到的字节指针，将要打印的数据转移到al寄存器中，8位
	call printhex;打印16进制字节数据
	inc r10;打印完1个
	cmp r10, blocklen ;blocklen = 16，16字节
	jne printary16loop ;一共打印16个字节
	ret

;; print a 4-byte array
;; uses: all regs, [pbyte]
;; rax - array to print
printary4:
	mov r12, rax
	xor r10, r10

printary4loop:
	mov al, [r12 + r10]
	call printhex
	inc r10
	cmp r10, Nb
	jne printary4loop
	ret

;; print a single byte in hex.
;; al = byte to print
;;打印al寄存器中的数，0也会打印出来
printhex:
	mov r9b, al		;r9b表示r9寄存器低8位，此处暂时存储要打印字节数据，因为下面要对al操作
	shr al, 4	;取al高4位
	and al, 0x0f;取al高4位
	call printhexnib ;先打印高4位
	mov al, r9b	;从r9b中取得原先的数据
	and al, 0x0f;取得低4位
	call printhexnib;打印低4位
	ret
	
;; print a single nibble in hex
;; al - nibble to print
printhexnib:
	add al, '0';将数字转移到相应的ASCII上
	cmp al, '9';看是否超过9
	jbe digit
	add al, 7		; 'A' - '0'超过9要加到A
digit:
	mov [pbyte], al	;最后通过printchar打印字符
	call printchar
	ret

;; print a single character
;; [pbyte] - byte to print
	;x86_64 通过中断（syscall）指令来实现
	;寄存器 rax 中存放系统调用号，同时系统调用返回值也存放在 rax 中
printchar:
	mov rax, 1 ;sys_write的系统调用编号为1
	mov rdi, 1 ;write to stdout
	mov rsi, pbyte ;打印字符串地址
	mov rdx, 1;打印长度
	syscall
	ret

;; print a newline，使用printchar打印换行
newline:
	mov [pbyte], byte 0x0a	;换行键对应ASCII
	call printchar
	ret
