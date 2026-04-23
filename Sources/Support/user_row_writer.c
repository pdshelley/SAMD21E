#include "BridgingHeader.h"
#include <stdbool.h>
#include <stdint.h>

// SAMD21 NVMCTRL register offsets
#define NVMCTRL_BASE_ADDR      0x41004000u
#define NVMCTRL_CTRLA_OFFSET   0x00u  // 16-bit
#define NVMCTRL_CTRLB_OFFSET   0x04u  // 32-bit
#define NVMCTRL_INTFLAG_OFFSET 0x14u  // 8-bit
#define NVMCTRL_STATUS_OFFSET  0x18u  // 16-bit
#define NVMCTRL_ADDR_OFFSET    0x1Cu  // 32-bit

#define USER_ROW_BASE_ADDR     0x00804000u
#define USER_ROW_BYTE_COUNT    64u

// NVM command values (CMD field)
#define NVM_CMD_EAR            0x05u  // Erase auxiliary row
#define NVM_CMD_WAP            0x06u  // Write auxiliary page
#define NVM_CMD_PBC            0x44u  // Page buffer clear

#define NVM_CMDEX_KEY          0xA5u

// Bit definitions
#define NVM_INTFLAG_READY_BIT  (1u << 0)
#define NVM_STATUS_PROGE_BIT   (1u << 2)
#define NVM_STATUS_LOCKE_BIT   (1u << 3)
#define NVM_STATUS_NVME_BIT    (1u << 4)
#define NVM_CTRLB_MANW_BIT     (1u << 7)

#define READY_POLL_LIMIT       1000000u

static inline volatile uint16_t *nvm_ctrla_reg(void) {
    return (volatile uint16_t *)(NVMCTRL_BASE_ADDR + NVMCTRL_CTRLA_OFFSET);
}

static inline volatile uint32_t *nvm_ctrlb_reg(void) {
    return (volatile uint32_t *)(NVMCTRL_BASE_ADDR + NVMCTRL_CTRLB_OFFSET);
}

static inline volatile uint8_t *nvm_intflag_reg(void) {
    return (volatile uint8_t *)(NVMCTRL_BASE_ADDR + NVMCTRL_INTFLAG_OFFSET);
}

static inline volatile uint16_t *nvm_status_reg(void) {
    return (volatile uint16_t *)(NVMCTRL_BASE_ADDR + NVMCTRL_STATUS_OFFSET);
}

static inline volatile uint32_t *nvm_addr_reg(void) {
    return (volatile uint32_t *)(NVMCTRL_BASE_ADDR + NVMCTRL_ADDR_OFFSET);
}

static bool nvm_wait_ready(void) {
    uint32_t polls = 0;
    while (((*nvm_intflag_reg()) & NVM_INTFLAG_READY_BIT) == 0u) {
        polls++;
        if (polls >= READY_POLL_LIMIT) {
            return false;
        }
    }
    return true;
}

static void nvm_clear_errors(void) {
    *nvm_status_reg() = (uint16_t)(NVM_STATUS_PROGE_BIT | NVM_STATUS_LOCKE_BIT | NVM_STATUS_NVME_BIT);
}

static bool nvm_has_error(void) {
    return ((*nvm_status_reg()) & (NVM_STATUS_PROGE_BIT | NVM_STATUS_LOCKE_BIT | NVM_STATUS_NVME_BIT)) != 0u;
}

static bool nvm_execute_command(uint8_t cmd) {
    *nvm_ctrla_reg() = (uint16_t)(((uint16_t)NVM_CMDEX_KEY << 8) | (uint16_t)cmd);
    return nvm_wait_ready();
}

bool user_row_write_mac_c(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4, uint8_t b5) {
    uint8_t bytes[USER_ROW_BYTE_COUNT];
    for (uint32_t i = 0; i < USER_ROW_BYTE_COUNT; i++) {
        bytes[i] = *(volatile uint8_t *)(USER_ROW_BASE_ADDR + i);
    }

    bytes[0] = b0;
    bytes[1] = b1;
    bytes[2] = b2;
    bytes[3] = b3;
    bytes[4] = b4;
    bytes[5] = b5;

    if (!nvm_wait_ready()) return false;

    uint32_t ctrlb_before = *nvm_ctrlb_reg();
    *nvm_ctrlb_reg() = ctrlb_before | NVM_CTRLB_MANW_BIT;

    nvm_clear_errors();
    *nvm_addr_reg() = (USER_ROW_BASE_ADDR >> 1);
    if (!nvm_execute_command(NVM_CMD_EAR)) goto fail;
    if (nvm_has_error()) goto fail;

    if (!nvm_execute_command(NVM_CMD_PBC)) goto fail;
    if (nvm_has_error()) goto fail;

    for (uint32_t i = 0; i < USER_ROW_BYTE_COUNT; i += 2) {
        uint16_t half = (uint16_t)bytes[i] | ((uint16_t)bytes[i + 1] << 8);
        *(volatile uint16_t *)(USER_ROW_BASE_ADDR + i) = half;
    }

    *nvm_addr_reg() = (USER_ROW_BASE_ADDR >> 1);
    if (!nvm_execute_command(NVM_CMD_WAP)) goto fail;
    if (nvm_has_error()) goto fail;

    *nvm_ctrlb_reg() = ctrlb_before;

    for (uint32_t i = 0; i < 6; i++) {
        if (*(volatile uint8_t *)(USER_ROW_BASE_ADDR + i) != bytes[i]) return false;
    }
    return true;

fail:
    *nvm_ctrlb_reg() = ctrlb_before;
    return false;
}
