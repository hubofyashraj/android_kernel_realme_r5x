/*
 * With CONFIG_LTO_CLANG, LLD always enables -fdata-sections and
 * -ffunction-sections, which increases the size of the final module.
 * Merge the split sections in the final binary.
 */
SECTIONS {
	/*
	 * LLVM may emit .eh_frame with CONFIG_CFI_CLANG despite
	 * -fno-asynchronous-unwind-tables. Discard the section.
	 */
	/DISCARD/ : {
		*(.eh_frame)
	}

	.bss : {
		*(.bss .bss.[0-9a-zA-Z_]*)
		*(.bss..L*)
	}

	.data : {
		*(.data .data.[0-9a-zA-Z_]*)
		*(.data..L*)
	}

	.rodata : {
		*(.rodata .rodata.[0-9a-zA-Z_]*)
		*(.rodata..L*)
	}

	/*
	 * With CFI_CLANG, ensure __cfi_check is at the beginning of the
	 * .text section, and that the section is aligned to 4k.
	 */
	.text : ALIGN(4096) {
		*(.text.__cfi_check)
		*(.text .text.[0-9a-zA-Z_]* .text..L.cfi*)
	}
}
