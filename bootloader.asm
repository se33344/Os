BITS 16

jmp short boot_start
nop 

OEM_Label         db "TRIXBOOT"
Bytes_Per_Sector  dw 512
SecotrsPerCluster db 1
ReservedForBoot   dw 1
NumberOfFats      db 2
RootDirEntries    dw 224

LogicalSectors    dw 2880
MinimumByte       db 0F0h
SectorPerFat      dw 9
SectorsPerTrack   dw 18
Sides             dw 2
HiddenSectors     dd 0
LargeSectors      dd 0
DriveNo           dd 0
Signature         dw 41
VolumeID          dd 00000000h
VolumeLabel       db "TRIXOS"
FileSystem        db "FAT32"

boot_start:
    mov ax,  07C0h
    add ax, 544
    cli
    mov ss, ax
    mov sp, 4096
    sti 
    mov ax, 07C0h
    mov ds, ax
    mov byte [bootdev], dl
    mov eax, 0

floppy_ok:
    mov ax, 19
    call l2hts
    mov si, buffer
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2
    mov al ,14
    pusha

readroot_dir:
    popa
    pusha
    stc 
    int 13h
    jnc search_dir
    call reset_floppy
    jnc readroot_dir
    jmp reboot 

search_dir:
    popa
    mov ax, ds
    mov es, ax
    mov di, buffer
    mov cx, word [RootDirEntries]
    mov ax, 0

nextroot_entry:
    xchg cx, dx
    mov si, kern_filename
    mov cx, 11
    rep cmpsb
    je foundfile_toload
    add ax, 32
    mov di, buffer
    add di, ax
    xchg dx, cx
    loop nextroot_entry
    mov si, file_notfound
    call print_string
    jmp reboot

foundfile_toload:
    mov ax, word [es:di+0Fh]
    mov word [cluster], ax
    mov ax, 1
    call l2hts
    mov di ,buffer 
    mov bx, di
    mov ah, 2
    mov al, 9
    pusha 

read_fat:
    popa
    pusha
    stc
    int 13h
    jnc read_fat_ok
    call reset_floppy
    mov si, disk_error
    call print_string
    jmp reboot

read_fat_ok:
    popa
    mov ax, 2000h
    mov es, ax
    mov bx, 0
    mov ah, 2
    mov al, 1
    push ax

load_file_sector:
    mov ax, word [cluster]
    add ax, 31
    call l2hts
    mov ax, 2000h
    mov es, ax
    mov bx, word [pointer]
    pop ax
    push ax
    stc 
    int 13h
    jnc calc_next_cluster
    call reset_floppy
    jmp load_file_sector

calc_next_cluster:
    mov ax, [cluster]
    mov dx, 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, buffer
    add si, ax
    mov ax, word [ds:si]
    or dx, dx
    jz even

odd:
    shr ax, 4
    jmp short next_cluster_cont

even:
    and ax, 0FFFh

next_cluster_cont:
    mov word [cluster], ax
    cmp ax, 0FF8h
    jae end
    add word [pointer], 512
    jmp load_file_sector

end:
    pop ax
    mov dl, byte [bootdev]
    jmp 2000h:0000h
    push ax

reboot:
    mov ax, 0
    int 16h
    mov ax, 0
    int 19h

print_string:
    pusha 
    mov ah, 0Eh

.repeat:
    lodsb 
    cmp al, 0
    je .done 
    int 10h
    jmp short .repeat 

.done:
    popa
    ret 

reset_floppy:
    push ax
    push dx
    mov ax, 0
    mov dl, byte [bootdev]
    stc
    int 13h
    pop dx
    pop ax
    ret

l2hts:
    push bx
    push ax
    mov bx, ax
    mov dx, 0
    div word [SectorsPerTrack]
    add dl, 01h
    mov cl, dl
    mov ax, bx
    mov dx, 0
    div word [SectorsPerTrack]
    mov dx, 0
    div word [Sides]
    mov dh, dl
    mov ch, al
    pop ax
    pop bx
    mov dl, byte [bootdev]
    ret

kern_filename    db "KERNEL BIN"
disk_error       db "Floppy Disk Error!Press any key to continue.", 0
file_notfound    db "File Not Found!Press any key to continue.", 0

bootdev          db 0
cluster          dw 0
pointer          dw 0

times 510-($-$$) db 0
dw 0AA55h

buffer: