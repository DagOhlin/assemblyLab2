// Symbolic constants
.equ LEDS_BASE, 0xff200000
.equ SWITCHES_BASE, 0xff200040
.equ PUSH_BUTTONS_BASE, 0xff200050
.equ DISPLAYS_BASE_1, 0xff200020
.equ DISPLAYS_BASE_2, 0xff200030
.equ DISPLAYS_BASE_3, 0xff200040
.equ UART_BASE, 0xff201000
.equ UART_DATA_REGISTER_ADDRESS, 0xff201000
.equ UART_CONTROL_REGISTER_ADDRESS, 0xff201004

/******************************************************************************
    Define symbols
******************************************************************************/
// Proposed stack base addresses
.equ SVC_MODE_STACK_BASE, 0x3FFFFFFF - 3 // set SVC stack to top of DDR3 memory
.equ IRQ_MODE_STACK_BASE, 0xFFFFFFFF - 3 // set IRQ stack to A9 onchip memory

// GIC Base addresses
.equ GIC_CPU_INTERFACE_BASE, 0xFFFEC100
.equ GIC_DISTRIBUTOR_BASE, 0xFFFED000

// Other I/O device base addresses
.equ LED_BASE, 0xff200000
.equ SW_BASE, 0xff200040
.equ BTN_BASE, 0xff200050
.equ DISPLAYS_BASE, 0xff200020
.equ UART_BASE, 0xff201000
.equ UART_DATA_REGISTER, 0xff201000
.equ UART_CONTROL_REGISTER, 0xff201004


numbers: .word 0x3F, 0x6, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x7, 0xff, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

.text
.org 0x00  // Address of interrupt vector
    B _start    // reset vector
    B SERVICE_UND // undefined instruction vector
    B SERVICE_SVC // software interrrupt (supervisor call) vector
    B SERVICE_ABT_INST // aborted prefetch vector
    B SERVICE_ABT_DATA // aborted data vector
    .word 0 // unused vector
    B SERVICE_IRQ // IRQ interrupt vector
    B SERVICE_FIQ // FIQ interrupt vector

.global _start





update_display_segment:

update_display:
    PUSH {r3, lr}

    //first display
    AND r0, r3, #0xf
    
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    MOV r2, r1              // Write to the display
    //disp 2
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #8
    ORR r2, r1

    //disp 3
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #16
    ORR r2, r1
    
    //disp 4
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #24
    ORR r2, r1

    STR r2, [r5]  //write to first 5 displays

   //first display
    LSR r3, #4
    AND r0, r3, #0xf
    
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    MOV r2, r1              // Write to the display
    //disp 2
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #8
    ORR r2, r1

    //disp 3
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #16
    ORR r2, r1
    
    //disp 4
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    // Hexadecimal value to write
    LSL r1, #24
    ORR r2, r1

    STR r2, [r6] 

    POP {r3, pc}
    

increment:
PUSH {lr}
ADD r3, r3, #1
bl update_display
POP {pc}

decrement: 
PUSH {lr}
SUB r3, r3, #1
bl update_display
POP {pc}

call_decrement:
    BL decrement
    B _halt

call_increment:
    BL increment
    B _halt


readUART:
    push {lr}
    // UART read
    LDR r0, =UART_DATA_REGISTER_ADDRESS
    LDR r1, [r0]                // Read the data register
    ANDS r2, r1, #0x8000         // Check if data is valid, bit 15
    BEQ _halt                   // If not valid, halt
    AND r1, r1, #0x00ff          // Mask the read data bits 0-7
    CMP r1, #0x73
    BEQ call_decrement
    CMP r1, #0x77
    BEQ call_increment

_halt: 
    POP {pc}

_start:
    MOV r3, #0
    LDR r4, =numbers
    LDR r5, =DISPLAYS_BASE_1
    LDR r6, =DISPLAYS_BASE_2


    /* 1. Set up stack pointers for IRQ and SVC processor modes */
    MSR CPSR_c, #0b11010010 // change to IRQ mode with interrupts disabled
    LDR SP, =IRQ_MODE_STACK_BASE // initiate IRQ mode stack

    MSR CPSR, #0b11010011 // change to supervisor mode, interrupts disabled
    LDR SP, =SVC_MODE_STACK_BASE // initiate supervisor mode stack

    /* 2. Configure the Generic Interrupt Controller (GIC). Use the given help function CONFIG_GIC! */
    // R0: The Interrupt ID to enable (only one supported for now)
    MOV R0, #80  // UART Interrupt ID = 80
    BL CONFIG_GIC // configure the ARM GIC

loop: 
    //bl readUART
    B loop


_end:
    B _end

.end