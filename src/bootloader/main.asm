org 0x7C00
bits 16

jmp short main
nop

bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

ebr_drive_number: db 0
db 0
ebr_signature: db 29h
ebr_volume_id db 12h,34h,56h,78h
ebr_volume_label: db 'CRADEX OS  '
ebr_system_id: db 'FAT12   '

main:

    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ;mov [ebr_drive_number], dl
    ;mov ax, 1
    ;mov cl, 1
    ;mov bx, 0x7E00
    ;call disk_read

    mov si, os_boot_msg
    call print
    
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax ;LBA of root dir

    mov ax, [bdb_dir_entries_count]
    shl ax, 5 ;ax *= 32
    xor dx, dx
    div word [bdb_bytes_per_sector] ; (num entries * 32)/bytes per sector
    
    test dx, dx
    jz root_dir_after
    inc ax

root_dir_after:
    mov [ebr_drive_number], dl
    mov cl, al
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    xor bx, bx
    mov di, buffer

search_kernel:
    mov si, file_kernel_bin
    mov cx, 11 ;length of the kernel filename
    push di
    repe cmpsb
    pop di
    je found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl search_kernel
    jmp kernel_not_found

kernel_not_found:
    mov si, msg_kernel_not_found
    call print

    hlt
    jmp halt

found_kernel:
    mov ax, [di + 26] ;26 is the offset to the first logical cluster
    mov [kernel_cluster], ax
    
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    mov bx, kernel_load_segment
    mov es, bx
    mov bx, kernel_load_offset

load_kernel:
    mov ax, [kernel_cluster]
    add ax, 31 ;floppy disk offset to cluster (change to dynamic later)
    mov cl, 1
    mov dl, [ebr_drive_number]

    call disk_read

    add bx, [bdb_bytes_per_sector]

    mov ax, [kernel_cluster] ;next cluster location = (kernel cluster * 3)/2
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz even

odd:
    shr ax, 4
    jmp next_cluster_after

even:
    and ax, 0x0FFF

next_cluster_after:
    cmp ax, 0x0FF8
    jae read_finish

    mov [kernel_cluster], ax
    jmp load_kernel
    
read_finish:
    mov dl, [ebr_drive_number]
    mov ax, kernel_load_segment
    mov ds, ax
    mov es, ax

    jmp kernel_load_segment:kernel_load_offset

    hlt
    jmp halt


halt:
    jmp halt

;input:
;LBA index: ax
;sectors to read: cl
;drive number: dl

;output:
;sector number: cx [bits 0-5]
;cylinder: cx [bits 6-15]
;head: dh

lba_to_chs:
    push ax
    push dx

    xor dx,dx
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx ;sector output cx
 
    xor dx, dx
    div word [bdb_heads]
    mov dh, dl ;head output dh

    mov ch, al
    shl ah, 6
    or cl, ah ;cylinder output [bits 6-15]

    pop ax
    mov dl, al
    pop ax
    ret

disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    call lba_to_chs

    mov ah, 2
    mov di, 3 ;counter

disk_retry:
    push di
    mov di, 0x7E00 
    stc
    int 13h
    pop di

    jnc done_read

    call disk_reset

    dec di
    test di, di
    jnz disk_retry

fail_disk_read:
    mov si, read_failure
    call print
    hlt
    jmp halt

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc fail_disk_read
    popa
    ret

done_read:
    mov si, read_success
    call print

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print: 
    push si
    push ax
    push bx

print_loop:
    lodsb
    or al, al
    jz done_print
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    jmp print_loop

done_print:
    pop bx
    pop ax
    pop si
    ret

os_boot_msg: db "Loading...", 0x0D, 0x0A, 0
read_failure: db "Failed to read disk!", 0x0D, 0x0A, 0
read_success: db "Successfuly read disk!", 0x0D, 0x0A, 0
file_kernel_bin: db "KERNEL  BIN"
msg_kernel_not_found: db "KERNEL.BIN not found."
kernel_cluster: dw 0

kernel_load_segment equ 0x2000
kernel_load_offset equ 0

TIMES 510-($-$$) DB 0
dw 0xAA55

buffer: 