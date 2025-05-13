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
.equ UART_DATA_REGISTER, 0xff201000
.equ UART_CONTROL_REGISTER, 0xff201004

// Symbolic constants
.equ DISPLAYS_BASE_1, 0xff200020
.equ DISPLAYS_BASE_2, 0xff200030
.equ DISPLAYS_BASE_3, 0xff200040
.equ UART_BASE, 0xff201000

.data
numbers: .word 0x3F, 0x6, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x7, 0xff, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

counter: .word 0


.text // Code section
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
    PUSH {r0,r1,r2,r3,r4,r5,r6,r12,lr}
    LDR r12, =counter
    LDR r4, =numbers
    LDR r5, =DISPLAYS_BASE_1
    LDR r6, =DISPLAYS_BASE_2
    LDR r3, [r12]
    //first display
    AND r0, r3, #0xf
    
    LDR r1, [r4, r0, LSL #2]    
    MOV r2, r1              
    //disp 2
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    
    LSL r1, #8
    ORR r2, r1

    //disp 3
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    
    LSL r1, #16
    ORR r2, r1
    
    //disp 4
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]    
    LSL r1, #24
    ORR r2, r1

    STR r2, [r5]  

   //first display
    LSR r3, #4
    AND r0, r3, #0xf
    
    LDR r1, [r4, r0, LSL #2]    
    MOV r2, r1              
    //disp 2
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]   
    LSL r1, #8
    ORR r2, r1

    //disp 3
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]   
    LSL r1, #16
    ORR r2, r1
    
    //disp 4
                            
    LSR r3, #4
    AND r0, r3, #0xf
    LDR r1, [r4, r0, LSL #2]   
    LSL r1, #24
    ORR r2, r1

    STR r2, [r6] 

    POP {r0,r1,r2,r3,r4,r5,r6,r12,pc}
    

increment:
PUSH {lr}
LDR r12, =counter
LDR r3, [r12]
ADD r3, r3, #1
STR r3, [r12]
bl update_display
POP {pc}

decrement: 
PUSH {lr}
LDR r12, =counter
LDR r3, [r12]
SUB r3, r3, #1
STR r3, [r12]
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
    LDR r0, =UART_DATA_REGISTER
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
   /* 1. Set up stack pointers for IRQ and SVC processor modes */
    MSR CPSR_c, #0b11010010 // change to IRQ mode with interrupts disabled
    LDR SP, =IRQ_MODE_STACK_BASE // initiate IRQ mode stack

    MSR CPSR, #0b11010011 // change to supervisor mode, interrupts disabled
    LDR SP, =SVC_MODE_STACK_BASE // initiate supervisor mode stack


/* 2. Configure the Generic Interrupt Controller (GIC). Use the given help function CONFIG_GIC! */
    // R0: The Interrupt ID to enable (only one supported for now)
    MOV R0, #73  // UART Interrupt ID = 80 //think 73 is push buttons 
    BL CONFIG_GIC // configure the ARM GIC




// Initialize the UART with receive interrupts enabled
    LDR R0, =BTN_BASE
    MOV R1, #3 // enable REceive interrupts
    STR R1, [R0, #8]


 /* 4. Change to the processor mode for the main program loop (for example supervisor mode) */
    /* 5. Enable the processor interrupts (IRQ in our case) */
    MSR CPSR_c, #0b01010011  // IRQ unmasked, MODE = SVC



_main:
    bl readUART
    B _main  // Just wait for interrupts to handle!





SERVICE_IRQ:
    PUSH {R0-R7, LR}
    /* 1. Read and acknowledge the interrupt at the GIC.The GIC returns the interrupt ID. */
    /* Read and acknowledge the interrupt at the GIC: Read the ICCIAR from the CPU Interface */
    LDR R4, =GIC_CPU_INTERFACE_BASE  // 0xFFFEC100
    LDR R5, [R4, #0x0C] // read current Interrupt ID from ICCIAR

    /* 2. Check which device raised the interrupt */
CHECK_UART_INTERRUPT:
    CMP R5, #73  // UART Interrupt ID

    BNE SERVICE_IRQ_DONE 

    LDR R0, =BTN_BASE               
    LDR R1, [R0, #0x0C]     

    CMP R1, #1
    BNE check_decrement
    BL increment
    B SERVICE_IRQ_DONE

    check_decrement:
    CMP R1, #2
    BNE SERVICE_IRQ_DONE
    BL decrement
    B SERVICE_IRQ_DONE

    
   

SERVICE_IRQ_DONE:
    STR R1, [R0, #0x0C]  
    /* 5. Inform the GIC that the interrupt is handled */
    STR R5, [R4, #0x10] // write to ICCEOIR


/* 6. Return from interrupt */
    POP {R0-R7, LR}
    SUBS PC, LR, #4




 /* Undefined instructions */
SERVICE_UND:
    B SERVICE_UND
    /* Software interrupts */
SERVICE_SVC:
    B SERVICE_SVC
    /* Aborted data reads */
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
    /* Aborted instruction fetch */
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
    /* FIQ */
SERVICE_FIQ:
    B SERVICE_FIQ


/*******************************************************************
    HELP FUNCTION!
    --------------
Configures the Generic Interrupt Controller (GIC)

Arguments:
    R0: Interrupt ID
*******************************************************************/
CONFIG_GIC:
    PUSH {LR}
    /* To configure a specific interrupt ID:
    * 1. set the target to cpu0 in the ICDIPTRn register
    * 2. enable the interrupt in the ICDISERn register */
    /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    MOV R1, #1 // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT
    /* configure the GIC CPU Interface */
    LDR R0, =GIC_CPU_INTERFACE_BASE // base address of CPU Interface, 0xFFFEC100
    /* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
    /* Set the enable bit in the CPU Interface Control Register (ICCICR).
    * This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
    /* Set the enable bit in the Distributor Control Register (ICDDCR).
    * This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =GIC_DISTRIBUTOR_BASE   // 0xFFFED000
    STR R1, [R0]
    POP {PC}


/*********************************************************************
    HELP FUNCTION!
    --------------
Configure registers in the GIC for an individual Interrupt ID.

We configure only the Interrupt Set Enable Registers (ICDISERn) and
Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
values are used for other registers in the GIC.

Arguments:
    R0 = Interrupt ID, N
    R1 = CPU target
*********************************************************************/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
    /* Configure Interrupt Set-Enable Registers (ICDISERn).
     * reg_offset = (integer_div(N / 32) * 4
     * value = 1 << (N mod 32) */
    LSR R4, R0, #3 // calculate reg_offset
    BIC R4, R4, #3 // R4 = reg_offset
    LDR R2, =0xFFFED100 // Base address of ICDISERn
    ADD R4, R2, R4 // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1 // enable
    LSL R2, R5, R2 // R2 = value
    /* Using the register address in R4 and the value in R2 set the
     * correct bit in the GIC register */
    LDR R3, [R4] // read current register value
    ORR R3, R3, R2 // set the enable bit
    STR R3, [R4] // store the new register value
    /* Configure Interrupt Processor Targets Register (ICDIPTRn)
     * reg_offset = integer_div(N / 4) * 4
     * index = N mod 4 */
    BIC R4, R0, #3 // R4 = reg_offset
    LDR R2, =0xFFFED800 // Base address of ICDIPTRn
    ADD R4, R2, R4 // R4 = word address of ICDIPTR
    AND R2, R0, #0x3 // N mod 4
    ADD R4, R2, R4 // R4 = byte address in ICDIPTR
    /* Using register address in R4 and the value in R2 write to
     * (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}